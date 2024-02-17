#!/bin/bash

# Get the script directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Include WriteLog function.
source "${SCRIPT_DIR}/inc/WriteLog.sh"
# Prints the help.
#
function ShowHelp {
	echo "Usage: ${0} [<options>] [<directory>]
  Options:
  -h, --help      : Show this help.
  -r, --recursive : Recursively iterate through all sub directories.
  -s, --show      : Show the differences.
  -d, --depth     : Maximum directory depth.
  -f, --format    : Format found files.
  directory       : Optional directory to start.

  The is script formats the code using the file '.clang_format' found in one of the parent directories.

  See for formatting options for configuration file:
     https://clang.llvm.org/docs/ClangFormatStyleOptions.html
"
}
# Initialize the options with the regular expression.
FIND_OPTIONS='-iregex .*\.\(c\|cc\|cpp\|h\|hh\|hpp\).*'
# Recursion is disabled by default.
FLAG_RECURSIVE=false
# Format file for real.
FLAG_FORMAT=false
# Enables show diff.
FLAG_SHOW_DIFF=false
# Max depth is only valid when recursion is enabled.
MAX_DEPTH=""

# Check if the needed commands are installed.
COMMANDS=(
	"colordiff"
	"dos2unix"
	"grep"
	"clang-format"
)
for COMMAND in "${COMMANDS[@]}"; do
	if ! command -v "${COMMAND}" >/dev/null; then
		echo "Missing command '${COMMAND}' for this script"
		exit 1
	fi
done

# Parse options.
TEMP=$(getopt -o 'hrfsd:' --long 'help,recursive,format,show,depth:' -n "$(basename "${0}")" -- "$@")
# shellcheck disable=SC2181
if [[ $? -ne 0 ]]; then
	ShowHelp
	exit 1
fi
eval set -- "$TEMP"
unset TEMP
while true; do
	case "$1" in

		-h | --help)
			ShowHelp
			exit 0
			;;

		-r | --recursive)
			FLAG_RECURSIVE=true
			shift 1
			;;

		-f | --format)
			FLAG_FORMAT=true
			shift 1
			;;

		-s | --show)
			FLAG_SHOW_DIFF=true
			shift 1
			;;

		-d | --depth)
			FLAG_RECURSIVE=true
			MAX_DEPTH="$2"
			shift 2
			continue
			;;

		'--')
			shift
			break
			;;

		*)
			WriteLog "Internal error on argument (${1}) !"
			exit 1
			;;
	esac
done
# Get the arguments in an array.
argument=()
while [[ $# -gt 0 ]] && ! [[ "$1" =~ ^- ]]; do
	argument=("${argument[@]}" "$1")
	shift
done
# Get the relative start directory which must exist otherwise show help and bailout.
#
if ! START_DIR="$(realpath --relative-to="$(pwd)" -e "${argument[0]}")"; then
	ShowHelp
	exit 0
fi
# Check for recursive operation.
if ${FLAG_RECURSIVE}; then
	# When max directory depth is set.
	if [[ -n "${MAX_DEPTH}" ]]; then
		FIND_OPTIONS="-maxdepth ${MAX_DEPTH} ${FIND_OPTIONS}"
	fi
else
	# Only the current directory.
	FIND_OPTIONS="-maxdepth 1 ${FIND_OPTIONS}"
fi
# Set tab to 4 spaces.
tabs -4
# Find the cfg_file file for clang-format up the tree.
CFG_FILE="$("${SCRIPT_DIR}/find-up.sh" --type f ".clang-format")" || exit 1
# Report the format configuration file.
WriteLog "Using configuration: ${CFG_FILE}."
# While loop keeping used variables local to be able to update.
while read -rd $'\0' FILE; do
	# Compare formatted unix file with original one.
	if clang-format --style="file:${CFG_FILE}" "${FILE}" | dos2unix | diff -s "${FILE}" - >/dev/null; then
		WriteLog "= ${FILE}"
	else
		WriteLog "~ ${FILE}"
		# Show differences when flag is set.
		if ${FLAG_SHOW_DIFF}; then
			clang-format --style="file:${CFG_FILE}" "${FILE}" | dos2unix | colordiff "${FILE}" -
			echo "==="
		fi
		if ${FLAG_FORMAT}; then
			# Check for DOS line endings.
			if file "${FILE}" | grep -q 'CRLF'; then
				# And fix it.
				dos2unix "${FILE}" 2>/dev/null || exit 1
			fi
			# Format C/C++ using the style config file.
			clang-format --style="file:${CFG_FILE}" "${FILE}" -i || exit 1
		fi
	fi
done < <(find "${START_DIR}" ${FIND_OPTIONS} -print0)
