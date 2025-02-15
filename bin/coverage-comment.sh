#!/usr/bin/env bash

set -e

# Get the script directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Credential file for testing
cred_file=".comment-credentials"

# Include WriteLog function.
source "${SCRIPT_DIR}/inc/Miscellaneous.sh"

trap 'ScriptExit "${BASH_SOURCE}" "${BASH_LINENO}" "${BASH_COMMAND}"' EXIT

# Prints the help.
#
function ShowHelp {
	echo "Usage: ${0} <flag>

  Adds a message about the generated coverage report from a merge request commit.
  When 'flag' is set with any value the operation is performed.

  For testing credentials are not passed as environment variables a bash include
  file named '${cred_file}' is sourced containing the following variables e.g.:
    SF_PROJECT_TOKEN='<project-api-access-token>'
    SF_PARENT_PIPELINE_ID='<parent-pipeline-id>'
    CI_API_V4_URL='https://git.scanframe.com/api/v4'
    CI_SERVER_URL='https://git.scanframe.com'
    CI_PROJECT_PATH='shared/devops'
    NEXUS_SERVER_URL='https://nexus.scanframe.com'
    NEXUS_EXCHANGE_REPO='exchange'

  Additional variables for forming a merge-request comment when available:
    CI_MERGE_REQUEST_PROJECT_ID=...
    CI_MERGE_REQUEST_IID=...
"
}

# When any arguments are passed.
if [[ "${1}" -eq 0 ]]; then
	ShowHelp
	exit 0
fi

# Check if the user was configured and if not try to read the credentials file.
if [[ -z "${SF_PROJECT_TOKEN}" ]]; then
	WriteLog "# Reading credentials file: ${cred_file}"
	# Try finding the credential file up the directories.
	# shellcheck disable=SC1090
	source "$(FindUp --type f "${cred_file}")"
fi

# When set this flag indicates a missing variable in the credentials file.
flag_var=false
# List of needed variables.
cred_vars=(
	SF_PROJECT_TOKEN
	SF_PARENT_PIPELINE_ID
	CI_API_V4_URL
	CI_SERVER_URL
	CI_PROJECT_PATH
	NEXUS_SERVER_URL
	NEXUS_EXCHANGE_REPO
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

# Check if the needed CI-variables exist to create add a comment for a merge request.
if [[ -n "${CI_MERGE_REQUEST_PROJECT_ID}" && -n "${CI_MERGE_REQUEST_IID}" && -n "${SF_PARENT_PIPELINE_ID}" ]]; then
	# URL to the report on Nexus.
	report_url="${NEXUS_SERVER_URL}/repository/${NEXUS_EXCHANGE_REPO}/gitlab-ci/${CI_PROJECT_PATH}/pipeline/${SF_PARENT_PIPELINE_ID}/report.html"
	# URL to the pipeline generating the report.
	pipeline_url="${CI_SERVER_URL}/${CI_PROJECT_PATH}/-/pipelines/${SF_PARENT_PIPELINE_ID}"
	# Create a temporary json file.
	json_file="$(mktemp --suffix=.json)"
	cat <<EOF >"${json_file}"
{
  "body": "[Coverage report](${report_url} \"Link to coverage report on nexus.\") generated by [pipeline-${SF_PARENT_PIPELINE_ID}](${pipeline_url} \"Link to responsible pipeline.\") is available."
}
EOF
	# Form the curl command.
	curl_mcd=(curl)
	curl_mcd+=(--fail --silent)
	curl_mcd+=(--header "PRIVATE-TOKEN: ${SF_PROJECT_TOKEN}")
	curl_mcd+=(--header "Content-Type: application/json")
	curl_mcd+=(--request POST)
	curl_mcd+=(--no-buffer)
	curl_mcd+=(--data-binary "@${json_file}")
	curl_mcd+=("${CI_API_V4_URL}/projects/${CI_MERGE_REQUEST_PROJECT_ID}/merge_requests/${CI_MERGE_REQUEST_IID}/notes")
else
	WriteLog "Not adding comment!"
fi

# Execute the curl command.
# shellcheck disable=SC2002
if "${curl_mcd[@]}" >/dev/null; then
	WriteLog -e "\nCoverage comment succeeded."
else
	WriteLog -e "\nCoverage comment failed [$?]!"
	WriteLog "Command" "${curl_mcd[@]}"
	WriteLog "# Posted json:"
	cat "${json_file}"
fi
