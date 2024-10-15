#!/usr/bin/env bash
# Exit immediately if a command exits with a non-zero status. (is the same as '-o errexit')
set -e
# Make sure the 'tee pipes' fail correctly. Don't hide errors within pipes.
set -o pipefail

# Get the scripts run directory weather it is a symlink or not.
run_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# When a symlink determine the script directory.
if [[ -L "${BASH_SOURCE[0]}" ]]; then
	include_dir="$(dirname "$(readlink "$0")")"
# Check if the library directory exists when not called from a sym-link.
elif [[ -d "${run_dir}/cmake/lib" ]]; then
	include_dir="${run_dir}/cmake/lib/bin"
else
	include_dir="${run_dir}"
fi

# Include the Miscellaneous functions.
source "${include_dir}/inc/Miscellaneous.sh"

## Trap script exit with function.
trap 'ScriptExit "${BASH_SOURCE}" "${BASH_LINENO}" "${BASH_COMMAND}"' EXIT

# Change to the run directory to operated from when script is called from a different location.
if ! cd "${run_dir}"; then
	WriteLog "Change to operation directory '${run_dir}' failed!"
	exit 1
fi

# Get the target OS.
#target_os="$(uname -o)"

# Download link URL.
download_url="https://nexus.scanframe.com/repository/shared/library/qt-w64-tools.zip"
# Temporary filepath for the zip file.
zip_filepath="/tmp/qt-w64-tools.zip"

function show_help {
	echo "Installs GNU/Qt tools for Windows 64-bit only under Cygwin.

Usage: $(basename "${0}") [command] <args...>
  download      : Download zip-file to temporary location.
  unzip <dir>   : Unzip the downloaded zip-file into the specified destination directory.
  install <dir> : Download and unzip commands combined.

  Download URL: ${download_url}
"
}

# Filepath of the tools directory file.
tools_dir_file="${run_dir}/.tools-dir-$(uname -n)"

# Check if a command is give and Cygwin is running.
if [[ $# -eq 0 || "$(uname -o)" != "Cygwin" ]]; then
	show_help
else
	cmd="${1}"
	# Process the given commands additional to the 'build.sh' script.
	case "${cmd}" in

		download)
			if [[ ! -f "${zip_filepath}" ]]; then
				wget -cO "${zip_filepath}" "${download_url}"
			fi
			# Report the file.
			ls -la "${zip_filepath}"
			;;

		unzip)
			# Check if destination
			if [[ -z "${2}" ]]; then
				WriteLog "!Missing unzip destination directory: ${cmd}"
				show_help
				exit 1
			fi
			# Check if Tools directory exists.
			if [[ -d "${2}/Tools" ]]; then
				WriteLog "!Destination subdirectory 'Tools' already exists."
			else
				unzip -d "${2}" "${zip_filepath}"
				chmod -R 770 "${2}/Tools"
			fi
			if [[ -d "${2}/Tools" ]]; then
				ls -d "${2}"/Tools/mingw*/bin > "${tools_dir_file}"
				WriteLog "Written location into file '${tools_dir_file}'."
			fi
			;;

		install)
			${0} download
			${0} unzip "${2}"
			;;

		*)
			WriteLog "!Invalid command: ${cmd}"
			show_help
			exit 1
			;;
	esac
fi
