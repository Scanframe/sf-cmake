#!/bin/bash

# Get the script directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Include WriteLog function.
source "${SCRIPT_DIR}/inc/WriteLog.sh"
# Prints the help.
#
function ShowHelp {
	echo "Usage: ${0} [<options>] [<directories...>]
  Options:
  -h, --help      : Show this help.
  -r, --recursive : Recursively iterate through all sub directories.
  -s, --show      : Show the differences.
  -d, --depth     : Maximum directory depth.
  -f, --format    : Format all found files.
  -q, --quiet     : Quiet, report only when files are not formatted correctly.
  directories     : Directories to start looking for code-files.

  The is script formats the code using the file '.clang_format' found in one of the parent directories.

  See for formatting options for configuration file:
     https://clang.llvm.org/docs/ClangFormatStyleOptions.html
"
}
# Initialize the options with the regular expression.
REGEX='.*\.\(c\|cc\|cpp\|h\|hh\|hpp\)'
FIND_OPTIONS=('-iregex' "${REGEX}")
# Recursion is disabled by default.
FLAG_RECURSIVE=false
# Format file for real.
FLAG_FORMAT=false
# Enables show diff.
FLAG_SHOW_DIFF=false
# Disable by default.
FLAG_QUIET=false
# File counter of all failed files.
FILE_FAIL_COUNT=0
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
		WriteLog "Missing command '${COMMAND}' for this script!"
		exit 1
	fi
done

# Parse the passed options.
TEMP=$(getopt -o 'hrfsqd:' --long 'help,recursive,format,show,quiet,depth:' -n "$(basename "${0}")" -- "$@")
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

		-q | --quiet)
			FLAG_QUIET=true
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
# Check for recursive operation.
if ${FLAG_RECURSIVE}; then
	# When max directory depth is set.
	FIND_OPTIONS+=("-maxdepth ${MAX_DEPTH:-1}")
fi

# Find the cfg_file file for clang-format up the tree.
CFG_FILE="$("${SCRIPT_DIR}/find-up.sh" --type f ".clang-format")" || exit 1
# Report the format configuration file.
if ! "${FLAG_QUIET}"; then
	WriteLog "# Format config file: ${CFG_FILE}"
	WriteLog "# Files regex matching: ${REGEX}"
fi

DIRECTORIES=()
# Get the relative start directory which must exist otherwise show help and bailout.
for dir in "${argument[@]}"; do
	if ! realpath --relative-to="$(pwd)" -e "${dir}" >/dev/null; then
		WriteLog "Given directory '${dir}' is not relative to current working directory!"
		exit 1
	else
		DIRECTORIES+=("${dir}")
	fi
done

# Add the needed find option to separate the each entry.
FIND_OPTIONS+=("-print0")
# Iterate through all directories.
for START_DIR in "${DIRECTORIES[@]}"; do
	if ! "${FLAG_QUIET}"; then
		WriteLog "# Entering directory: ${START_DIR}"
	fi
	# While loop keeping used variables local to be able to update.
	while read -rd $'\0' FILE; do
		# Compare formatted unix file with original one.
		if clang-format --style="file:${CFG_FILE}" "${FILE}" | dos2unix | diff -s "${FILE}" - >/dev/null; then
			if ! "${FLAG_QUIET}"; then
				WriteLog "= ${FILE}"
			fi
		else
			# Increment the fail counter.
			((FILE_FAIL_COUNT+=1))
			WriteLog "! ${FILE}"
			# Show differences when flag is set.
			if ${FLAG_SHOW_DIFF}; then
				clang-format --style="file:${CFG_FILE}" "${FILE}" | dos2unix | colordiff "${FILE}" -
				echo "==="
			fi
			# Format the file when the option flag was set.
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
	done < <(find "${START_DIR}" "${FIND_OPTIONS[@]}")
done

# When incorrect formatted files were found.
if [[ "${FILE_FAIL_COUNT}" -gt 0 ]]; then
 WriteLog "Total of (${FILE_FAIL_COUNT}) files were incorrectly clang-formatted.
Run command '${0}' with option '--format' to auto fix these files."
 # Signal failure.
 exit 1
fi
