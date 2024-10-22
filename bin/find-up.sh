#!/bin/bash

# Get the script directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Include WriteLog function.
source "${script_dir}/inc/WriteLog.sh"
# Prints the help.
#
function ShowHelp {
	echo "Usage: ${0} [options] <name>
  Find directory or file equal to the passed name.
  Options:
    -h, --help      : Show this help.
    -t, --type <d|f>: File or directory.
"
}

# Type 'd' for directory
type=""
# Parse options.
temp=$(getopt -o 'ht:' --long 'help,type:' -n "$(basename "${0}")" -- "$@")
# shellcheck disable=SC2181
if [[ $? -ne 0 ]]; then
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

		-t | --type)
			type="${2:0:1}"
			shift 2
			continue
			;;

		'--')
			shift
			break
			;;

		*)
			WriteLog "Internal error on argument (${1}) !" >&2
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
# Target name to look for.
name="${argument[0]}"
# When no argument passed show help.
if [[ -z "${name}" ]]; then
	ShowHelp
	exit 0
fi
# Get the current working directory.
path="$(pwd)"
# Iterate up the tree.
while [[ "${path}" != "" ]]; do
	# Per type check if it exist and so, then break the loop.
	case "${type}" in
		d)
			if [[ -d "${path}/${name}" ]]; then
				break
			fi
			;;
		f)
			if [[ -f "${path}/${name}" ]]; then
				break
			fi
			;;
		*)
			if [[ -e "${path}/${name}" ]]; then
				break
			fi
			;;
	esac
	# One directory up.
	path="${path%/*}"
done
# When the path is empty the file was not found.
if [[ -z "${path}" ]]; then
	# Print error on not finding to stderr.
	case "${type}" in
		d) WriteLog "Directory '${name}' not found." ;;
		f) WriteLog "File '${name}' not found." ;;
		*) WriteLog "File or directory '${name}' not found." ;;
	esac
	exit 1
fi
# Print the
echo "${path}/${name}"
