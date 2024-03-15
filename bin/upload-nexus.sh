#!/usr/bin/env bash
# Exit immediately if a command exits with a non-zero status. (is the same as '-o errexit')
set -e
# Make sure the 'tee pipes' fail correctly. Don't hide errors within pipes.
set -o pipefail

# This scripts directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Credential file for testing
cred_file=".nexus-upload-credentials"

# Include the WriteLog function.
source "${SCRIPT_DIR}/inc/Miscellaneous.sh"

# Prints the help to stderr.
#
function ShowHelp() {
	echo "Usage: ${0} [options...] <files-to-upload...>

  Uploads files to a Sonatype Nexus repository depending on their extension to
  the correct repository for multiple files at once.

  -h, --help     : Shows this help.
  -d, --debug    : Show debugging information and enables verbosity on curl.
  -a, --apt-repo : Sets or overrules variable 'NEXUS_APT_REPO' as the apt-repository name.
  -r, --raw-repo : Sets or overrules variable 'NEXUS_RAW_REPO' as the raw-repository name.
  -s, --raw-sub  : Sets or overrules variable 'NEXUS_RAW_SUBDIR' as the subdirectory.

  When the credentials are not passed as environment variables a bash include file named
  '${cred_file}' is sourced containing the following variables e.g.:
    NEXUS_USER='uploader'
    NEXUS_PASSWORD='<uploader-password>'
    NEXUS_SERVER_URL='https://nexus.scanframe.com'
    NEXUS_APT_REPO='develop'
    NEXUS_RAW_REPO='shared'
    NEXUS_RAW_SUBDIR='dist/develop'

  These environment variables can be set in GitLab for a project for CI-pipeline
  or partially by the pipeline configuration when needed.

  When a NEXUS_USER variable is not provided the credentials file named '${cred_file}'
  is looked for when e.g. there is a need for testing outside the CI-pipeline.
"
}

# When no arguments are passed show help.
if [[ $# -eq 0 ]]; then
	WriteLog "No files to upload!"
	ShowHelp
	# Signal error when nothing to upload when called from CI-pipeline.
	exit 1
fi

# Check if the user was configured and if not try to read the credentials file.
if [[ -z "${NEXUS_USER}" ]]; then
	WriteLog "# Reading credentials file: ${cred_file}"
	# Try finding the credential file up the directories.
	# shellcheck disable=SC1090
	source "$(FindUp --type f "${cred_file}")"
fi

# When set this flag indicates a missing variable in the credentials file.
flag_var=false
# Show command en verbose curl output.
flag_debug=false

# Parse options.
temp=$(getopt -o 'hdr:a:s:' \
	--long 'help,debug,raw-repo:apt-repo:,raw-sub:' \
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

		-d | --debug)
			WriteLog "# Debug enabled."
			flag_debug=true
			shift 1
			continue
			;;

		-r | --raw-repo)
			WriteLog "# RAW repository set to '${2}'."
			NEXUS_RAW_REPO="${2}"
			shift 2
			continue
			;;

		-s | --raw-sub)
			WriteLog "# RAW subdirectory set to '${2}'."
			NEXUS_RAW_SUBDIR="${2}"
			shift 2
			continue
			;;

		-a | --apt-repo)
			WriteLog "# APT repository set to '${2}'."
			NEXUS_APT_REPO="${2}"
			shift 2
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

# List of needed credential variables.
cred_vars=(
	NEXUS_USER
	NEXUS_PASSWORD
	NEXUS_SERVER_URL
	NEXUS_APT_REPO
	NEXUS_RAW_REPO
	NEXUS_RAW_SUBDIR
)
# Iterate over the variable-names and check them.
for var in "${cred_vars[@]}"; do
	if [[ -z "${!var}" ]]; then
		WriteLog "Required credentials/config variable '$var' is not set by credentials file or by parent environment!"
		flag_var=true
	fi
done
# Check all needed variables were present.
if ${flag_var}; then
	ShowHelp
	exit 1
fi

# Check if the needed commands are installed.1+
commands=("curl")
for command in "${commands[@]}"; do
	if ! command -v "${command}" >/dev/null; then
		WriteLog "Missing command '${command}' for this script!"
		exit 1
	fi
done

# Curl command to execute basically.
curl_cmd=(curl)
curl_cmd+=(--silent)
curl_cmd+=(--include)
if "${flag_debug}"; then
	curl_cmd+=(--verbose)
fi
curl_cmd+=(--user "${NEXUS_USER}:${NEXUS_PASSWORD}")

# Iterate over all the command-line arguments.
for upload_file in "${argument[@]}"; do
	# Check if the file exists.
	if [[ ! -f "${upload_file}" ]]; then
		WriteLog "! File not found: ${upload_file}"
		exit 1
	fi
	# Depending on the file extension the upload destination and method is selected.
	case "${upload_file##*.}" in
		deb)
			WriteLog "- Uploading APT repo file: ${upload_file}"
			curl_cmd+=(--request 'POST')
			curl_cmd_add=(--header 'Accept: application/json')
			curl_cmd_add+=(--header 'Content-Type: multipart/form-data')
			curl_cmd_add+=(--form "apt.asset=@${upload_file};type=application/vnd.debian.binary-package")
			curl_cmd_add+=("${NEXUS_SERVER_URL}/service/rest/v1/components?repository=$(UrlEncode "${NEXUS_APT_REPO}")")
			# Show command when debugging.
			"${flag_debug}" && echo "${curl_cmd[@]}" "${curl_cmd_add[@]}"
			response_code="$("${curl_cmd[@]}" "${curl_cmd_add[@]}" |
				tee >(cat | PrependAndEscape "- " 1>&2) | grep -P "^HTTP/" | tail -n 1 | cut -d$' ' -f2)"
			# Check the response code for failure.
			if [[ "${response_code}" -lt 200 || "${response_code}" -ge 300 ]]; then
				WriteLog "! Upload APT package failed (${response_code}) of file: ${upload_file}"
				exit 1
			fi
			;;

		zip | exe)
			WriteLog "- Uploading RAW repo file: ${upload_file}"
			curl_cmd_add=(--upload-file "${upload_file}")
			curl_cmd_add+=("${NEXUS_SERVER_URL}/repository/$(UrlEncode "${NEXUS_RAW_REPO}")/$(UrlEncode "${NEXUS_RAW_SUBDIR}")/$(basename -- "${upload_file}")")
			# Show command when debugging.
			"${flag_debug}" && echo "${curl_cmd[@]}" "${curl_cmd_add[@]}"
			# Perform curl and retrieve the HTTP response_code.
			response_code="$("${curl_cmd[@]}" "${curl_cmd_add[@]}" |
				tee >(cat | PrependAndEscape "- " 1>&2) | grep -P "^HTTP/" | tail -n 1 | cut -d$' ' -f2)"
			# Check the response code for failure.
			if [[ "${response_code}" -lt 200 || "${response_code}" -ge 300 ]]; then
				WriteLog "! Upload RAW package failed (${response_code}) of file: ${upload_file}"
				exit 1
			fi
			;;

		*)
			WriteLog "! No upload method for extension '${upload_file##*.}' file: ${upload_file}"
			;;

	esac
done
