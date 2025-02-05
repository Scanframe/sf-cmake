#!/usr/bin/env bash
# Exit immediately if a command exits with a non-zero status. (is the same as '-o errexit')
set -e
# Make sure the 'tee pipes' fail correctly. Don't hide errors within pipes.
set -o pipefail


# Bailout on first error.
set -e
# Get the script directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Include WriteLog function.
source "${script_dir}/inc/Miscellaneous.sh"

## Trap script exit with function.
trap 'ScriptExit "${BASH_SOURCE}" "${BASH_LINENO}" "${BASH_COMMAND}"' EXIT

# Get the architecture.
architecture="$(uname -m)"
# Download link URL.
download_url="https://nexus.scanframe.com/repository/shared/library/qt/w64-${architecture}-tools.zip"
# Temporary filepath for the zip file.
zip_filepath="/tmp/w64-${architecture}-toolchain.zip"
# Filepath of the tools directory file.
tools_dir_file=".tools-dir-$(uname -n)"

function show_help {
	echo "Installs MinGW toolchain for Windows 64-bit only under Cygwin.

Usage: $(basename "${0}") [command] <args...>
  download      : Download zip-file to temporary location.
  unzip <dir>   : Unzip the downloaded tools file into the given directory which defaults to this project './lib' directory.
                  Creates file '.tools-dir-$(uname -n)' in the current directory with the install path
                  which is included by the 'build.sh' script to prefix its PATH.
  install <dir> : Download and unzip commands combined.

  Download URL: ${download_url}
"
}

# Check if destination is given otherwise use the default.
if [[ -z "${2}" ]]; then
	target_dir="${PWD}/lib"
else
	target_dir="${2}"
fi

function cmd_download {
	wget -cO "${zip_filepath}" "${download_url}"
	# Report the file.
	ls -lah "${zip_filepath}"
}

function cmd_unzip {
	WriteLog "Target tools unzip directory: ${target_dir}"
	mkdir --parents "${target_dir}/tools"
	unzip -qd "${target_dir}/tools" "${zip_filepath}"
	if [[ -d "${target_dir}/tools" ]]; then
		ls -d "${target_dir}"/tools/mingw*/bin >"${tools_dir_file}"
		WriteLog "Written location into file '${tools_dir_file}'."
	fi
}

# Check if a command is give and Cygwin is running.
if [[ $# -eq 0 ]]; then
	show_help
else
	# Process the given commands additional to the 'build.sh' script.
	case "${1}" in

		download)
			cmd_download
			;;

		unzip)
			cmd_unzip
			;;

		install)
			cmd_download
			cmd_unzip
			;;

		*)
			WriteLog "!Invalid command: ${1}"
			show_help
			exit 1
			;;
	esac
fi
