#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="${SCRIPT_DIR}/.apt-repo-credentials"

# Include the WriteLog function.
source "${SCRIPT_DIR}/inc/WriteLog.sh"

# Prints the help to stderr.
#
function ShowHelp() {
	echo "Usage: ${0} <file-to-upload...>
  Uploads files to a Sonatype Nexus repository allowing wildcards.

  When the credentials are not passed as environment variables a file named
  '${CRED_FILE}'
  is sourced containing the following variables e.g.:
    NEXUS_USER='uploader'
    NEXUS_PASSWORD='<uploader-password>'
    NEXUS_SERVER_URL='https://nexus.scanframe.com'
    NEXUS_REPO_NAME='apt-hosted'

  These environment variables can be set in GitLab for a project for CI-pipeline
  or partially by the pipeline configuration.
"
}

function PrependAndEscape() {
	while read -r line; do
		WriteLog -e "${1}${line}"
	done
}

# When no arguments are passed show help.
if [[ $# -eq 0 ]]; then
	ShowHelp
	exit 0
fi

# Import the credentials and repo details...
#NEXUS_USER="uploader"
#NEXUS_PASSWORD="<password>"
#NEXUS_SERVER_URL="https://nexus.scanframe.com"
#NEXUS_REPO_NAME="apt-hosted"

# Check if the user was configured and if not try to read the credentials file.
if [[ -z "${NEXUS_USER}" ]]; then
	WriteLog "# Reading credentials file: ${CRED_FILE}"
	if [[ ! -f "${CRED_FILE}" ]]; then
		WriteLog "Credential file not found: ${CRED_FILE} !"
		exit 1
	fi
	source "${SCRIPT_DIR}/.apt-repo-credentials"
fi

# Check if the credentials were set fully.
if [[ -z "${NEXUS_USER}" || -z "${NEXUS_PASSWORD}" || -z "${NEXUS_SERVER_URL}" || -z "${NEXUS_REPO_NAME}" ]]; then
	WriteLog "Credentials are not fully set!"
	exit 1
fi

# iterate over all the command-line arguments.
for UPLOAD_FILE in "$@"; do
	# Check if the file exists.
	if [[ ! -f "${UPLOAD_FILE}" ]]; then
		WriteLog "File not found: ${UPLOAD_FILE} !"
		exit 1
	else
		WriteLog "- Uploading file: ${UPLOAD_FILE}"
	fi
	# Perform curl and retrieve the HTTP response_code.
	response_code="$(curl \
		--silent --include \
		--request 'POST' \
		--user "${NEXUS_USER}:${NEXUS_PASSWORD}" \
		--header 'Accept: application/json' \
		--header 'Content-Type: multipart/form-data' \
		--form "apt.asset=@${UPLOAD_FILE};type=application/vnd.debian.binary-package" \
		"${NEXUS_SERVER_URL}/service/rest/v1/components?repository=${NEXUS_REPO_NAME}" | \
		tee >(cat | PrependAndEscape "- " 1>&2 ) | grep -P "^HTTP/" | tail -n 1 | cut -d$' ' -f2)"
	# Check the response code for failure.
	if [[ "${response_code}" -lt 200 || "${response_code}" -ge 300 ]]; then
		WriteLog "Upload failed (${response_code}) of file: ${UPLOAD_FILE} !"
		exit 1
	fi
done
