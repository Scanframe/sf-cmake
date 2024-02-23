#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="${SCRIPT_DIR}/.apt-repo-credentials"

# Include the WriteLog function.
source "${SCRIPT_DIR}/inc/WriteLog.sh"

# Prints the help to stderr.
#
function ShowHelp() {
	echo "Usage: ${0} [options...] <files-to-upload...>

  Uploads files to a Sonatype Nexus repository depending on their extension to
  the correct repository for multiple files at once.

  -h, --help     : Shows this help.
  -d, --debug    : Debug: Show executed commands rather then executing them.
  -a, --apt-repo : Sets or overrules variable 'NEXUS_APT_REPO' as the apt-repository name.
  -r, --raw-repo : Sets or overrules variable 'NEXUS_RAW_REPO' as the raw-repository name.
  -s, --raw-sub  : Sets or overrules variable 'NEXUS_RAW_SUBDIR' as the subdirectory.

  When the credentials are not passed as environment variables a file named
  '${CRED_FILE}'
  is sourced containing the following variables e.g.:
    NEXUS_USER='uploader'
    NEXUS_PASSWORD='<uploader-password>'
    NEXUS_SERVER_URL='https://nexus.scanframe.com'
    NEXUS_APT_REPO='develop'
    NEXUS_RAW_REPO='shared'
    NEXUS_RAW_SUBDIR='dist/develop'

  These environment variables can be set in GitLab for a project for CI-pipeline
  or partially by the pipeline configuration when needed.

  When a NEXUS_USER variable is not provided the credentials file named
  '${CRED_FILE}'
  is looked for when e.g. there is need for testing outside the CI-pipeline.
"
}

function PrependAndEscape() {
	while read -r line; do
		WriteLog -e "${1}${line}"
	done
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
	WriteLog "# Reading credentials file: ${CRED_FILE}"
	if [[ ! -f "${CRED_FILE}" ]]; then
		WriteLog "Credential file not found: ${CRED_FILE} !"
		exit 1
	fi
	source "${SCRIPT_DIR}/.apt-repo-credentials"
fi

# When set this flag indicates a missing variable in the credentials file.
FLAG_VAR=false

# Parse options.
temp=$(getopt -o 'hr:a:' \
	--long 'help,raw-repo:apt-repo:' \
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

		-r | --raw-repo)
			WriteLog "# RAW repository set to '${2}'."
			NEXUS_RAW_REPO="${2}"
			shift 2
			continue
			exit 0
			;;

		-s | --raw-sub)
			WriteLog "# RAW subdirectory set to '${2}'."
			NEXUS_RAW_SUBDIR="${2}"
			shift 2
			continue
			exit 0
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
while [ $# -gt 0 ] && ! [[ "$1" =~ ^- ]]; do
	argument=("${argument[@]}" "$1")
	shift
done

# List of needed variables.
NEXUS_VARS=(
	NEXUS_USER
	NEXUS_PASSWORD
	NEXUS_SERVER_URL
	NEXUS_APT_REPO
	NEXUS_RAW_REPO
	NEXUS_RAW_SUBDIR
)
# Iterate over the variable-names and check them.
for var in "${NEXUS_VARS[@]}"; do
	if [[ -z "${!var}" ]]; then
		WriteLog "Required credentials/config variable '$var' is not set credentials file or environment!"
		FLAG_VAR=true
	fi
done
# Check all needed variables were present.
if ${FLAG_VAR}; then
	ShowHelp
	exit 1
fi

# Iterate over all the command-line arguments.
for UPLOAD_FILE in "${argument[@]}"; do
	# Check if the file exists.
	if [[ ! -f "${UPLOAD_FILE}" ]]; then
		WriteLog "! File not found: ${UPLOAD_FILE}"
		exit 1
	fi
	# Depending on the file extension the upload destination and method is selected.
	case "${UPLOAD_FILE##*.}" in
		deb)
			WriteLog "- Uploading APT repo file: ${UPLOAD_FILE}"
			# Perform curl and retrieve the HTTP response_code.
			response_code="$(curl \
				--silent --include \
				--request 'POST' \
				--user "${NEXUS_USER}:${NEXUS_PASSWORD}" \
				--header 'Accept: application/json' \
				--header 'Content-Type: multipart/form-data' \
				--form "apt.asset=@${UPLOAD_FILE};type=application/vnd.debian.binary-package" \
				"${NEXUS_SERVER_URL}/service/rest/v1/components?repository=${NEXUS_APT_REPO}" |
				tee >(cat | PrependAndEscape "- " 1>&2) | grep -P "^HTTP/" | tail -n 1 | cut -d$' ' -f2)"
			# Check the response code for failure.
			if [[ "${response_code}" -lt 200 || "${response_code}" -ge 300 ]]; then
				WriteLog "! Upload APT package failed (${response_code}) of file: ${UPLOAD_FILE}"
				exit 1
			fi
			;;

		zip | exe)
			WriteLog "- Uploading RAW repo file: ${UPLOAD_FILE}"
			response_code="$(curl \
				--silent --include \
				--user "${NEXUS_USER}:${NEXUS_PASSWORD}" \
				--upload-file "${UPLOAD_FILE}" \
				"${NEXUS_SERVER_URL}/repository/${NEXUS_RAW_REPO}/$NEXUS_RAW_SUBDIR}/$(basename -- "${UPLOAD_FILE}")" |
				tee >(cat | PrependAndEscape "- " 1>&2) | grep -P "^HTTP/" | tail -n 1 | cut -d$' ' -f2)"
			# Check the response code for failure.
			if [[ "${response_code}" -lt 200 || "${response_code}" -ge 300 ]]; then
				WriteLog "! Upload RAW package failed (${response_code}) of file: ${UPLOAD_FILE}"
				exit 1
			fi
			;;

		*)
			WriteLog "! No upload method for extension '${UPLOAD_FILE##*.}' file: ${UPLOAD_FILE}"
			;;

	esac
done
