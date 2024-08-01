#!/bin/bash

# Get the script directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Include WriteLog function.
source "${script_dir}/inc/WriteLog.sh"
# Prints the help.
#
function ShowHelp {
	echo "Usage: ${0} [<options>] [<directory/file> ...]
  Options:
  -h, --help      : Show this help.
  -r, --recursive : Recursively iterate through all subdirectory arguments.
  --git-hook      : Use git-diff to get the staged filenames and preferred for a pre-commit git-hook.
  -g, --git       : Use git-diff to get both staged and unstaged filenames.
  -s, --show      : Show the differences.
  -d, --depth     : Maximum directory depth.
  -f, --format    : Format all found files.
  -q, --quiet     : Quiet, report only when files are not formatted correctly.
  arguments     : Directories to start looking for code-files.

  The is script formats the code using the file '.clang_format' found in one of the parent arguments.
  Files from git and given directories are limited to extensions '.c', '.cc', '.cpp', '.h', '.hh' and '.hpp'.

  See for formatting options for configuration file:
     https://clang.llvm.org/docs/ClangFormatStyleOptions.html
"
}
# Initialize the options with the regular expression.
regex='.*\.\(c\|cc\|cpp\|h\|hh\|hpp\)'
find_options=('-iregex' "${regex}")
# Recursion is disabled by default.
flag_recursive=false
# Format file for real.
flag_format=false
# Enables show diff.
flag_show_diff=false
# Disable being quiet by default.
flag_quiet=false
# Append arguments using the git diff noticed changes of staged and unstaged files.
flag_git_unstaged=false
# Append arguments using the git diff noticed changes of staged files only.
flag_git_staged=false
# File counter of all failed files.
file_fail_count=0
# Max depth is only valid when recursion is enabled.
max_depth=""

# Check if the needed commands are installed.
commands=(
	"colordiff"
	"dos2unix"
	"grep"
	"clang-format"
)
for command in "${commands[@]}"; do
	if ! command -v "${command}" >/dev/null; then
		WriteLog "Missing command '${command}' for this script!"
		exit 1
	fi
done

# Parse the passed options.
temp=$(getopt -o 'hrgfsqd:' --long 'help,recursive,git,git-hook,format,show,quiet,depth:' -n "$(basename "${0}")" -- "$@")
# shellcheck disable=SC2181
if [[ $? -ne 0 || $# -eq 0 ]]; then
	ShowHelp
	exit 1
fi
eval set -- "$temp"
unset temp
while true; do
	case "$1" in

		-h | --help)
			ShowHelp
			exit 0
			;;

		-r | --recursive)
			flag_recursive=true
			shift 1
			;;

		-g | --git)
			flag_git_staged=true
			flag_git_unstaged=true
			shift 1
			;;

		--git-hook)
			flag_git_staged=true
			flag_git_unstaged=false
			shift 1
			;;

		-f | --format)
			flag_format=true
			shift 1
			;;

		-s | --show)
			flag_show_diff=true
			shift 1
			;;

		-q | --quiet)
			flag_quiet=true
			shift 1
			;;

		-d | --depth)
			flag_recursive=true
			max_depth="$2"
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
if ${flag_recursive}; then
	# When max directory depth is set.
	find_options+=("-maxdepth ${max_depth:-1}")
fi

# Find the cfg_file file for clang-format up the tree.
cfg_file="$("${script_dir}/find-up.sh" --type f ".clang-format")" || exit 1
# Report the format configuration file.
if ! "${flag_quiet}"; then
	WriteLog "# Format config file: ${cfg_file}"
	if ${flag_git_staged}; then
		WriteLog "# Git diff staged files are added."
	fi
	if ${flag_git_unstaged}; then
		WriteLog "# Git diff unstaged files are added."
	fi
fi

##
# $1: filename
#
function check_format {
	local file_name="$1"
	# Compare formatted unix file with original one.
	if clang-format --style="file:${cfg_file}" "${file_name}" | dos2unix | diff -s "${file_name}" - >/dev/null; then
		if ! "${flag_quiet}"; then
			WriteLog "= ${file_name}"
		fi
	else
		# Increment the fail counter.
		((file_fail_count += 1))
		WriteLog "! ${file_name}"
		# Show differences when flag is set.
		if ${flag_show_diff}; then
			clang-format --style="file:${cfg_file}" "${file_name}" | dos2unix | colordiff "${file_name}" -
			echo "==="
		fi
		# Format the file when the option flag was set.
		if ${flag_format}; then
			# Check for DOS line endings.
			if file "${file_name}" | grep -q 'CRLF'; then
				# And fix it.
				dos2unix "${file_name}" 2>/dev/null || exit 1
			fi
			# Format C/C++ using the style config file.
			clang-format --style="file:${cfg_file}" "${file_name}" -i || exit 1
		fi
	fi
}

arguments=()
# Get the relative start directory which must exist otherwise show help and bailout.
for arg in "${argument[@]}"; do
	if ! realpath --relative-to="$(pwd)" -e "${arg}" >/dev/null; then
		WriteLog "Given argument '${arg}' is not relative to current working directory!"
		exit 1
	else
		arguments+=("${arg}")
	fi
done
# Check if git diff detected changes are to be added.
if ${flag_git_staged} || ${flag_git_unstaged}; then
	while IFS= read -rd $'\n' line; do
		arguments+=("$line")
	done < <(
		${flag_git_staged} && git diff --cached --name-only --diff-filter=ACMR "*.c" "*.cc" "*.cpp" "*.h" "*.hh" "*.hpp"
		${flag_git_unstaged} && git diff --name-only --diff-filter=ACMR "*.c" "*.cc" "*.cpp" "*.h" "*.hh" "*.hpp"
	)
fi

# Add the needed find option to separate the each entry.
find_options+=("-print0")
# Iterate through all arguments directories and/or files.
for argument in "${arguments[@]}"; do
	# When the argument is a directory.
	if [[ -d "${argument}" ]]; then
		if ! "${flag_quiet}"; then
			WriteLog "# Entering directory: ${argument}"
		fi
		while read -rd $'\0' fn; do
			check_format "${fn}"
		done < <(find "${argument}" "${find_options[@]}")
	# When the argument is a file.
	elif [[ -f "${argument}" ]]; then
		check_format "${argument}"
	else
		WriteLog "# Ignoring non-existing entry: ${argument}"
	fi
done

# When incorrect formatted files were found.
if [[ "${file_fail_count}" -gt 0 ]]; then
	WriteLog "Total of (${file_fail_count}) files were incorrectly clang-formatted.
Run command '${0}' with option '--format' to auto fix these files."
	# Signal failure.
	exit 1
fi
