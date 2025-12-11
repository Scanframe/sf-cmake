#!/bin/bash

# Stop on first error or pipeline errors.
set -o pipefail -e

# Get the script directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Include WriteLog function.
source "${script_dir}/inc/Miscellaneous.sh"

## Trap script exit with function.
trap 'ScriptExit "${BASH_SOURCE}" "${BASH_LINENO}" "${BASH_COMMAND}"' EXIT

# Prints the help.
#
function show_help {
	echo "Usage: ${0} [options]
  Lists all version tags formated like 'v1.2.3' from given GitHub repository.
  Options:
    -o, --owner <...> : Repository owner.
    -n, --repo <...>  : Repository name.
    -u, --url  <...>  : Browser URL from git hub.
    -f, --find        : Find the nearest version.
    -l, --latest      : Get the latest version possible.
    -j, --joined      : Get the versions joined in a single string separated by ';'.
        --json        : Get the response from API request for tags.
    -h, --help        : Show this help.
"
}

# Declare the options array for.
declare -A options
# Initialize a flag.
options['latest']=0
options['joined']=0
options['json']=0

# Parse options.
temp=$(getopt -o 'o:n:u:f:ljh' --long 'owner:,repo:,url:,find:,latest,joined,json,help' -n "$(basename "${0}")" -- "$@")
# shellcheck disable=SC2181
if [[ $? -ne 0 ]]; then
	show_help
	exit 1
fi
eval set -- "${temp}"
unset temp
while true; do
	case "${1}" in

		-h | --help)
			show_help
			exit 0
			;;

		-o | --owner)
			options['owner']="${2}"
			shift 2
			continue
			;;

		-n | --repo)
			options['repo']="${2}"
			shift 2
			continue
			;;

		-u | --url)
			# Remove the protocol and domain, get rid of the '.git' and split into owner and repo.
			path="${2}"
			path="${path#https://github.com/}"
			path="${path%.git}"
			options['owner']="${path%/*}"
			options['repo']="${path##*/}"
			shift 2
			continue
			;;

		-f | --find)
			options['find-ver']="${2}"
			shift 2
			continue
			;;

		-l | --latest)
			options['latest']=1
			shift 1
			continue
			;;

		-j | --joined)
			options['joined']=1
			shift 1
			continue
			;;

		--json)
			options['json']=1
			shift 1
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
if [[ ! -v options['owner'] || ! -v options['repo'] ]]; then
	WriteLog "Missing owner or repository!"
	show_help
	exit 1
fi

# GitHub API URL for fetching tags.
api_url="https://api.github.com/repos/${options['owner']}/${options['repo']}/tags"
# Cache file reducing the amount of calls  to GitHub.
cache_file="$(GetTemporaryDirectory)/${USER}-github-tags-catchorg-Catch2.json"
if [[ -f "${cache_file}" ]]; then
	cache_age="$(FileAgeInSeconds "${cache_file}")"
	if [[ "${cache_age}" -gt 600 ]]; then
		WriteLog "~ Removing the cache file (${cache_age}s): ${cache_file}"
		rm "${cache_file}"
	fi
fi
if [[ ! -f "${cache_file}" ]]; then
	curl --fail --silent "${api_url}" > "${cache_file}"
	WriteLog "# Updating cache file (${cache_age}s): ${cache_file}"
else
	WriteLog "# Using cache file (${cache_age}s): ${cache_file}"
fi

# When find version is requested.
if [[ ! -v options['find-ver'] ]]; then
	WriteLog "- Available versions of '${options['owner']}/${options['repo']}':"
	if [[ "${options['json']}" -ne 0 ]]; then
		cat "${cache_file}"
	elif [[ "${options['latest']}" -ne 0 ]]; then
		cat "${cache_file}" |
			jq -r '.[] | select(.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | .name | sub("^.";"")' |
			sort --version-sort |
			tail -n 1
	elif [[ "${options['joined']}" -ne 0 ]]; then
		cat "${cache_file}" |
			jq -r '[.[] | (select(.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | .name | sub("^.";""))] | join(";")'
	else
		cat "${cache_file}" |
			jq -r '.[] | select(.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | .name | sub("^.";"")' |
			sort --version-sort --reverse
	fi
else
	# Get all tags formated like v1.2.3 and put only the version part 1.2.3 in a list.
	versions="$(cat "${cache_file}" |
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
