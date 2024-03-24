#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status. (is the same as '-o errexit')
set -e
# Make sure the 'tee pipes' fail correctly. Don't hide errors within pipes.
set -o pipefail

# Get the include directory which is this script's directory.
INCLUDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Include the Miscellaneous functions.
source "${INCLUDE_DIR}/inc/Miscellaneous.sh"

## Trap script exit with function.
trap 'ScriptExit "${BASH_SOURCE}" "${BASH_LINENO}" "${BASH_COMMAND}"' EXIT

# When the script directory is not set then
if [[ -z "${SCRIPT_DIR}" ]]; then
	SCRIPT_DIR="${PWD}"
	WriteLog "Environment variable 'SCRIPT_DIR' not set using current working directory."
fi

# Prints the help to stderr.
#
function ShowHelp {
	echo "Usage: ${0} [options...]

  Bumps/predicts versions according conventional commits.

  -h, --help    : Shows this help.
  -v, --verbose : Print extra processing information.
  -i, --info    : Report information collected on the repository regarding version tags.
  -b, --bump    : Creates/predicts the next version from the the conventional commits.
  -c, --commit  : Commit hash to tag as new version (defaults to last commit/HEAD).
  -m, --merges  : Use only merge commits.
  --dbg-msgs    : Script file containing associated array 'declare -A commit_messages' where
                  the key is the full hash to replace commit messages for debugging purposes.
"
}

# When no arguments are passed show help.
if [[ $# -eq 0 ]]; then
	ShowHelp
	# Signal error when nothing to upload when called from CI-pipeline.
	exit 0
fi

declare -A flags
flags['info']=false
flags['verbose']=false
flags['bump']=false
flags['merges']=false
flags['commit']="$(git rev-parse --verify HEAD)"

# Parse options.
temp=$(getopt -o 'hrivbc:m' \
	--long 'help,info,verbose,bump,commit:,merges,dbg-msgs:' \
	-n "$(basename "${0}")" -- "$@")
# No arguments, show help and bailout.
if [[ "${#}" -eq 0 ]]; then
	ShowHelp
	exit 1
fi
eval set -- "${temp}"
unset temp
while true; do
	case $1 in

		-h | --help)
			ShowHelp
			exit 0
			;;

		-c | --commit)
			WriteLog "# Commit hash for tagging '${2}'."
			flags['commit']="${2}"
			shift 2
			continue
			;;

		--dbg-msgs)
			WriteLog "# Sourcing '${2}'."
			# shellcheck source=version-bump.msgs.sh
			source "${2}"
			shift 2
			continue
			;;

		-i | --info)
			flags['info']=true
			shift 1
			continue
			;;

		-v | --verbose)
			flags['verbose']=true
			shift 1
			continue
			;;

		-m | --merges)
			flags['merges']=true
			shift 1
			continue
			;;

		-b | --bump)
			flags['bump']=true
			shift 1
			continue
			;;

		'--')
			shift
			break
			;;

		*)
			echo "Internal error on argument (${1}) !" >&2
			exit 1
			;;
	esac
done

# Harvest the arguments in an array.
argument=()
while [ "${#}" -gt 0 ] && ! [[ "${1}" =~ ^- ]]; do
	argument+=("${1}")
	shift
done

# Initialize the flag that a tag was found.
flag_tag_found=true
# Get the top level repository directory.
git_top_level="$(git rev-parse --show-toplevel)"
# Get the current non release-candidate version.
cur_ver_tag="$(git tag --list --format '%(tag)' | sort --version-sort --reverse | grep -P '^v\d+\.\d+\.\d+$' | head -n 1 || true)"
# When no tag available set the flag.
if [[ -n "${cur_ver_tag}" ]];then
	flag_tag_found=false
	cur_ver_tag="v0.0.0"
fi

function ReportVersionTags {
	local IFS REPLY
	WriteLog -e "\n# Top level directory"
	WriteLog "${git_top_level}"

	## Split the version ';' separated string into an array.
	WriteLog -e "\n# Current versions"
	{
		echo -e "Package (Git)\t$(GitTagVersionString "$(GetGitTagVersion)")"
		## Get the last version tag non-RC.
		echo -e "Last non-rc\t${cur_ver_tag} \"$(git cat-file tag "${cur_ver_tag}" 2>/dev/null | sed '1,/^$/d')\""
	} | column --table --separator $'\t' --output-separator ' : '
	# Check if the current version tag is the initial one.
	if ! ${flag_tag_found}; then
		WriteLog ": No current git version tag was found using '${cur_ver_tag}'."
	fi

	echo -e "\n# Annotated version-tags"
	{
		# Print the header.
		echo -e "~Tag\tHash\tAnnotation"
		while IFS= read -r -d $'\n'; do
			echo -e "${REPLY%%:*}\t${REPLY#*:} "
		done < <(git tag --list --format '%(tag):%(object)\t"%(subject)"' 2>/dev/null | sort --version-sort --reverse | grep -P '^v\d+\.\d+\.\d+(-rc\.\d+)?:')
	} | sed -e "s/\`/'/g" | column --table --separator $'\t' --output-separator ' | '

	echo -e "\n# All merge commits"
	{
		# Print the header.
		echo -e "~Tag\tHash\tCommit heading"
		# Iterate over the Git merges.
		while IFS= read -r -d $'\n'; do
			echo -e "$(git describe --exact-match "${REPLY}" 2>/dev/null || echo "...")\t${REPLY}\t$(GetCommitMessage "${REPLY}" |
				head -n 1 | Highlight '^[a-z_\\-]+(\([a-z_\\-]+\\))?!?:' cyan)"
		done < <(git log --merges --pretty=format:"%H" 2>/dev/null)
	} | sed -e "s/\`/'/g" | column --table --separator $'\t' --output-separator ' | '

	echo -e "\n# Commits since version: ${cur_ver_tag} upto '${flags['commit']}'"
	{
		# Print the header.
		echo -e "~Tag\tHash\tCommit heading"
		# Iterate over the Git merges.
		while IFS= read -r -d $'\n'; do
			echo -e "$(git describe --exact-match "${REPLY}" 2>/dev/null || echo "...")\t${REPLY}\t$(GetCommitMessage "${REPLY}" |
				head -n 1 | Highlight '^[a-z_\\-]+(\([a-z_\\-]+\\))?!?:' cyan)"
			#WriteLog "$(git show --format=%B "${REPLY}")"
		done < <(
			# When the no tag found use all log entries from the start.
			if ! ${flag_tag_found}; then
				# When only merge commits are to be used.
				if ${flags['merges']}; then
					git log --merges --pretty=format:"%H" "${flags['commit']}" 2>/dev/null
				else
					git log --pretty=format:"%H" "${flags['commit']}" 2>/dev/null
				fi
			else
				# When only merge commits are to be used.
				if ${flags['merges']}; then
					git log --merges --pretty=format:"%H" "${cur_ver_tag}^..${flags['commit']}" 2>/dev/null
				else
					git log --pretty=format:"%H" "${cur_ver_tag}^..${flags['commit']}" 2>/dev/null
				fi
			fi
		)
	} | sed -e "s/\`/'/g" | column --table --separator $'\t' --output-separator ' | '
}

##
# Get commit message and replaces it for testing.
# Arg1: Commit hash.
#
function GetCommitMessage {
	# Check if the hash is overruled for testing purposes.
	if [[ -v commit_messages[@] && -v "commit_messages['${1}']" ]]; then
		# shellcheck disable=SC2154
		echo "${commit_messages[${1}]}"
	else
		git show --no-patch --format="%B" "${1}" 2>/dev/null
	fi
}

##
# Returns the the version effect of a conventional commit type.
#
function GetTypeProperty {
	case "$1" in
		build)
			if [[ -z "$2" ]]; then
				echo "patch"
			else
				echo "Build Tool/Process"
			fi
			;;
		chore)
			if [[ -z "$2" ]]; then
				echo "patch"
			else
				echo "Chore"
			fi
			;;
		ci)
			if [[ -z "$2" ]]; then
				echo "patch"
			else
				echo "CI Configuration"
			fi
			;;
		docs)
			if [[ -z "$2" ]]; then
				echo "patch"
			else
				echo "Documentation"
			fi
			;;
		feat)
			if [[ -z "$2" ]]; then
				echo "minor"
			else
				echo "Feature"
			fi
			;;
		fix)
			if [[ -z "$2" ]]; then
				echo "patch"
			else
				echo "Bugfix"
			fi
			;;
		perf)
			if [[ -z "$2" ]]; then
				echo "patch"
			else
				echo "Performance"
			fi
			;;
		refactor)
			if [[ -z "$2" ]]; then
				echo "patch"
			else
				echo "Code Refactoring"
			fi
			;;
		revert)
			if [[ -z "$2" ]]; then
				echo "patch"
			else
				echo "Revert of Commit"
			fi
			;;
		style)
			if [[ -z "$2" ]]; then
				echo "patch"
			else
				echo "Code Formatting/Styling"
			fi
			;;
		test)
			if [[ -z "$2" ]]; then
				echo "none"
			else
				echo "Test Addition/Modification"
			fi
			;;
	esac
}

##
# Bumps the version.
# Arg1: 'info' for showing info only, 'test' Creating release notes. 'tag' Release notes and tags the given commit.
#
function BumpVersion {
	local IFS REPLY msg_header msg_heading msg_body msg_type msg_scope regex effect effect_max next_ver_tag
	local md_file md_table md_changes counter
	# Regular expression to match the message header to.
	regex='^([a-z_\-]+)(\(([a-z_\-]+)\))?(!)?:\s(.*)$'
	# Check if the current version tag was found, if not the max_effect is set to 'minor' to start with.
	if [[ "${cur_ver_tag}" == 'v0.0.0' ]]; then
		# Get the highest version effect.
		effect_max='minor'
		WriteLog ": No current git version tag was found so max effect is set to '${effect_max}'."
	else
		# Initialize the maximum effect for the next version.
		effect_max="none"
	fi
	counter=0
	# When verbose is enabled.
	if "${flags['verbose']}"; then
		WriteLog -e "\n# Conventional commits from version: ${cur_ver_tag} to (${flags['commit']})"
	fi
	# Info only, so no release notes.
	if [[ "$1" != 'info' ]]; then
		# File for writing markdown into.
		md_table="/tmp/release-notes-list.md"
		md_changes="/tmp/release-notes-changes.md"
		# Make sure the files exists.
		for fn in "${md_table}" "${md_changes}"; do
			echo >${fn} ""
		done
		# Create the header of the table.
		{
			echo "| # | Type | Effect | Scope | Change |"
			echo "|---:|:---|:---|:---|:---|"
		} >${md_table}
	fi
	# Iterate over the Git merges.
	while IFS= read -r -d $'\n'; do
		msg_string="$(GetCommitMessage "${REPLY}")"
		# Get the first line/header of the message.
		msg_header="${msg_string%%$'\n'*}"
		# When the header does not match skip it.
		if [[ ! "${msg_header}" =~ $regex ]]; then
			if "${flags['verbose']}"; then
				WriteLog "~ Ignoring commit: ${REPLY}"
			fi
			continue
		fi
		# Get the commit type.
		msg_type="${BASH_REMATCH[1]}"
		# Get the commit scope.
		msg_scope="${BASH_REMATCH[3]}"
		# Get the breaking change flag.
		msg_breaking="${BASH_REMATCH[4]}"
		# Head text.
		msg_heading="${BASH_REMATCH[5]}"
		# Get the body of the message.
		msg_body="${msg_string#*$'\n'}"
		# Check if the message type is valid.
		if [[ -n "${msg_type}" ]]; then
			# Check for a breaking change.
			[[ "${msg_breaking}" == "!" ]] && effect="major" || effect="$(GetTypeProperty "${msg_type}")"
			# Get the highest version effect.
			effect_max="$(CompareIncrements "${effect}" "${effect_max}")"
			# when verbose is enabled.
			if "${flags['verbose']}"; then
				WriteLog "= Accepting commit: ${REPLY}"
				echo -e "
Heading\t${msg_heading}
Type\t${msg_type}
Scope\t${msg_scope}
Break\t[${msg_breaking}]
Version Effect\t${effect}
" | column --table --separator $'\t' --output-separator ' : '
				echo "${msg_body}" | PrependAndEcho "Body #\${counter}: "
			fi
			# Only info no release notes.
			if [[ "$1" != 'info' ]]; then
				((counter += 1))
				echo >>"${md_table}" "| **${counter}** | $(GetTypeProperty "${msg_type}" 1) | ${effect} | ${msg_scope} | ${msg_heading} |"
				{
					echo -e "#### ${counter}) $(GetTypeProperty "${msg_type}" 1): $(EscapeMarkdown "${msg_heading}")\n\n"
					echo "${msg_body}"
					echo -e "\n\n---\n"
				} >>"${md_changes}"
			fi
		fi
	done < \
		<(
			# When only merge commits are to be used.
			if ${flags['merges']}; then
				git log --merges --pretty=format:"%H" "${cur_ver_tag}^..${flags['commit']}" 2>/dev/null
			else
				git log --pretty=format:"%H" "${cur_ver_tag}^..${flags['commit']}" 2>/dev/null
			fi
		)
	# Version bump result.
	WriteLog -e "\n# Version Bump"
	# Check if it results a newer version.
	if [[ "${effect_max}" == "none" ]]; then
		WriteLog ": Changes maximum effect (${effect_max}) do not bump the version."
	else
		# Determine next version number using the effect.
		next_ver_tag="v$(IncrementVersion "${cur_ver_tag:1}" "${effect_max}")"
		{
			echo -e "Current version/tag\t${cur_ver_tag}"
			echo -e "Max-effect\t${effect_max}"
			echo -e "Upto commit\t${flags['commit']}"
			echo -e "Next version/tag:\t${next_ver_tag}"
		} | column --table --separator $'\t' --output-separator ' : '
		# Info only, so no release notes.
		if [[ "$1" != 'info' ]]; then
			# Create the directory when it does not exist.
			mkdir -p "${git_top_level}/doc/release"
			# File for the release notes.
			md_file="${git_top_level}/doc/release/notes-${next_ver_tag}.md"
			{
				echo "# Release-notes Version ${next_ver_tag}"
				echo "
		## Changelist since version ${cur_ver_tag}
		"
				cat "${md_table}"
				echo -e "\n### Changes"
				cat "${md_changes}"
			} >"${md_file}"
		fi
	fi
}

# Change to the root directory of this repository.
pushd "${git_top_level}" >/dev/null
# Restore the working directory.
popd >/dev/null

# When information is requested.
if ${flags['info']}; then
	ReportVersionTags | PrependAndEscape
	BumpVersion 'info'
fi

# When information is requested.
if ${flags['bump']}; then
	BumpVersion 'test'
fi

exit 0
