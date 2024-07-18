#!/bin/bash

# Bailout on first error.
set -e
# Get the script directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Include WriteLog function.
source "${script_dir}/inc/Miscellaneous.sh"
# Prints the help.
#
function ShowHelp {
	echo "Usage: ${0} [options]
  Lists all version tags formated like 'v1.2.3' from given GitHub repository.
  Options:
    -o, --owner     : Repository owner.
    -n, --repo-name : Repository name.
    -f, --find      : Find the nearest version.
    -h, --help      : Show this help.
"
}

# Declare the options array for.
declare -A options

# Parse options.
temp=$(getopt -o 'o:n:f:h' --long 'owner:,repo-name:,find:' -n "$(basename "${0}")" -- "$@")
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

		-o | --owner)
			options['owner']="${2}"
			shift 2
			continue
			;;

		-n | --repo-name)
			options['repo-name']="${2}"
			shift 2
			continue
			;;

		-f | --find)
			options['find-ver']="${2}"
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

# Check if the needed keys are filled in.
if [[ ! -v options['owner'] || ! -v options['repo-name'] ]]; then
	ShowHelp
	exit 0
fi

# GitHub API URL for fetching tags
api_url="https://api.github.com/repos/${options['owner']}/${options['repo-name']}/tags"

# When find version is requested.
if [[ ! -v options['find-ver'] ]]; then
	WriteLog "-Available version of '${options['owner']}/${options['repo-name']}':"
	curl -s "${api_url}" |
  		jq -r '.[] | select(.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | .name | sub("^.";"")' |
  		sort --version-sort
else
	# Get all tags formated like v1.2.3 and put only the version part 1.2.3 in a list.
	versions="$(curl -s "${api_url}" |
		jq -r '.[] | select(.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | .name | sub("^.";"")' |
		sort --version-sort)"
	# Iterate through all versions
	for version in ${versions}; do
		# Compare the versions.
		cmp=$(VersionCompare "${version}" "${options['find-ver']}")
		#WriteLog "- '${version}' <> '${options['find-ver']}': ${cmp}"
		# When exact return the version and quit.
		if [[ "${cmp}" -eq 0 ]]; then
			echo "${version}"
			exit 0
		# When less then the current version use the previous version and quit.
		elif [[ "${cmp}" -lt 0 ]]; then
			echo "${prev_tag}"
			exit 0
		fi
		# Holds the previous version
		prev_tag="${version}"
	done
fi
