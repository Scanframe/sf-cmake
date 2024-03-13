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

trap 'ScriptExit "${BASH_SOURCE}" "${BASH_LINENO}" "${BASH_COMMAND}"' EXIT

# Prints the help to stderr.
#
function ShowHelp() {
	echo "Usage: $(basename "${0}") [options...] <file...>

  Uploads files to a Sonatype Nexus repository exchange repository.

  -h, --help   : Shows this help.
  -d, --debug  : Debug: Show executed curl commands rather then executing them.
  -n, --repo   : Sets or overrules variable 'NEXUS_EXCHANGE_REPO' as the repository name.
  -r, --remote : Remote subdirectory on the Nexus server.
  -l, --local  : Download the passed files from the remote where non given means all of them.

  When the credentials are not passed as environment variables a bash include file named
  '${cred_file}' is sourced containing the following variables e.g.:
    NEXUS_USER='<uploader-user>'
    NEXUS_PASSWORD='<uploader-password>'
    NEXUS_SERVER_URL='https://nexus.scanframe.com'
    NEXUS_EXCHANGE_REPO='exchange'

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
	source "$(FindUp --type f .nexus-upload-credentials)"
fi

# When set this flag indicates a missing variable in the credentials file.
flag_var=false
# Show command en verbose curl output.
flag_debug=false
# Directory on nexus where all files are copied.
remote_dir=""
local_dir=""

# Parse options.
temp=$(getopt -o 'dhr:r:s:' \
	--long 'help,debug,repo:,remote:,local:' \
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
			WriteLog "# Debug is enabled"
			flag_debug=true
			shift 1
			continue
			;;

		-r | --remote)
			WriteLog "# Remote directory set to '${2}'."
			remote_dir="${2}"
			shift 2
			continue
			exit 0
			;;

		-l | --local)
			WriteLog "# Local directory set to '${2}'."
			local_dir="${2}"
			shift 2
			continue
			exit 0
			;;

		-n | --repo)
			WriteLog "# Nexus repository set to '${2}'."
			NEXUS_EXCHANGE_REPO="${2}"
			shift 2
			continue
			exit 0
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

# Check if the needed commands are installed.1+
commands=("curl" "jq" "numfmt")
for command in "${commands[@]}"; do
	if ! command -v "${command}" >/dev/null; then
		WriteLog "Missing command '${command}' for this script!"
		exit 1
	fi
done

##!
# Upload files to target nexus file.
# ArgN: Files to upload.
#
function UploadFiles {
	local fn response_code curl_cmd curl_cmd_add
	# Curl command to execute basically.
	curl_cmd=(curl --silent --include)
	#"${flag_debug}" && curl_cmd+=(--verbose)
	curl_cmd+=(--user "${NEXUS_USER}:${NEXUS_PASSWORD}")
	# Iterate over all the command-line arguments.
	for fn in "${@}"; do
		# Check if the file exists.
		if [[ ! -f "${fn}" ]]; then
			WriteLog "! File not found: ${fn}"
			exit 1
		fi
		WriteLog "- Uploading file ($(numfmt --format %6f --to=iec-i --suffix=B "$(stat --printf="%s" "${fn}")")): ${fn}"
		curl_cmd_add=(--upload-file "${fn}")
		curl_cmd_add+=("${NEXUS_SERVER_URL}/repository/$(UrlEncode "${NEXUS_EXCHANGE_REPO}")/${remote_dir}/$(basename -- "${fn}")")
		# Show command when debugging.
		"${flag_debug}" && echo "${curl_cmd[@]}" "${curl_cmd_add[@]}"
		# Perform curl and retrieve the HTTP response_code.
		if "${flag_debug}"; then
			response_code="$("${curl_cmd[@]}" "${curl_cmd_add[@]}" | tee >(cat | PrependAndEscape "- ") | grep -P "^HTTP/" | tail -n 1 | cut -d$' ' -f2)"
		else
			response_code="$("${curl_cmd[@]}" "${curl_cmd_add[@]}" | grep -P "^HTTP/" | tail -n 1 | cut -d$' ' -f2)"
		fi
		# Check the response code for failure.
		if [[ "${response_code}" -lt 200 || "${response_code}" -ge 300 ]]; then
			WriteLog "! Upload failed (${response_code}) of file: ${fn}"
			exit 1
		fi
	done
}

##!
# Download files to from nexus file.
# ArgN: Files to download when existing or all when non given.
#
function DownloadFiles {
	local response_code curl_cmd json_file fn
	# Create temporary file to store the json result.
	json_file="$(mktemp --suffix '.json')"
	# Curl command to execute basically.
	curl_cmd=(curl --silent)
	# Fail silently (no output at all) on HTTP errors.
	curl_cmd+=(--fail)
	#"${flag_debug}" &&	curl_cmd+=(--verbose)
	curl_cmd+=(--user "${NEXUS_USER}:${NEXUS_PASSWORD}")
	# Include headers to check the response code.
	curl_cmd_add=(--include)
	curl_cmd_add+=("${NEXUS_SERVER_URL}/service/rest/v1/search?repository=$(UrlEncode "${NEXUS_EXCHANGE_REPO}")&group=/$(UrlEncode "${remote_dir}")")
	# Perform curl and retrieve the HTTP response_code.
	response_code="$("${curl_cmd[@]}" "${curl_cmd_add[@]}" | tee >(sed '1,/^\r$/d' | cat >"${json_file}") | grep -P "^HTTP/" | tail -n 1 | cut -d$' ' -f2)"
	# Check the response code for failure.
	if [[ "${response_code}" -ne 200 ]]; then
		WriteLog "! Downloads failed (${response_code}) of directory: ${remote_dir}"
		exit 1
	fi
	# Check if debug reporting is requested.
	if "${flag_debug}"; then
		echo -e "Response JSON:\n"
		cat "${json_file}"
	fi
	# Iterate through the assets list generated by 'jq'.
	while IFS=$'\t' read -r -a asset; do
		# Get only the filename from the asset path.
		fn=$(basename "${asset[0]}")
		# Check if the filename is part of the requested files if any.
		[[ "$#" -ne 0 ]] && ! InArray "${fn}" "${@}" && continue
		# Create the local directory when it does not exist.
		[[ ! -d "${local_dir}" ]] && mkdir -p "${local_dir}"
		# Report downloading
		WriteLog "- Downloading file ($(numfmt --format %6f --to=iec-i --suffix=B "${asset[1]}")): ${asset[0]}"
		if ! "${curl_cmd[@]}" --output "${local_dir}/$(basename "${asset[0]}")" "${asset[2]}"; then
			WriteLog "! Download failed ($?) from '${asset[0]}' '${local_dir}/$(basename "${asset[0]}")'"
		fi
	done < <(jq -r ".items[].assets[]|\"\\(.path)\\t\\(.fileSize)\\t\\(.downloadUrl)\\t\\(.checksum.sha1)\"" "${json_file}")
}

# Uploading or downloading depends on the local directory.
if [[ -z "${local_dir}" ]]; then
	UploadFiles "${argument[@]}"
else
	DownloadFiles "${argument[@]}"
fi
