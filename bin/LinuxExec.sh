#!/usr/bin/env bash

# Bailout on first error.
set -e

# Get this script's directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Include WriteLog function.
source "${script_dir}/inc/WriteLog.sh"

# Check if the executable directory has been set.
if [[ -z "${EXECUTABLE_DIR}" || ! -d "${EXECUTABLE_DIR}" ]]; then
	WriteLog "Environment variable 'EXECUTABLE_DIR' does not exist or has not been set!"
	exit 1
fi

function GetExecutablesFiles
{
	for fn in "${EXECUTABLE_DIR}"/*; do
  	if [[ "$(file -ib "${fn}")" =~ ^application/x-pie-executable ]]; then
 			basename "${fn}"
  	fi
  done
}

# When nothing is passed show help and wine version.
if [[ "$#" -eq 0 ]]; then
	WriteLog \
		"Executes a cross-compiled Windows binary from the target directory.
Usage: $0 <executable> [[<options>]...]

Available exe-files:
$(GetExecutablesFiles)
	"
	exit 1
fi

# Only when it could find the script.
if [[ -f "${script_dir}/QtLibDir.sh" ]]; then
	# Get the Qt installed directory.
	qt_ver_dir="$(bash "${script_dir}/QtLibDir.sh" "$(realpath "${HOME}/lib/Qt")")"
	# Location of Qt DLLs.
	dir_qt_lib="$(realpath "${qt_ver_dir}/gcc_64/lib")"
else
	WriteLog "File not found: ${script_dir}/QtLibDir.sh"
	dir_qt_lib=""
fi

# Get the command.
executable="${1}"
shift 1

dir_bin_lnx="${EXECUTABLE_DIR}"
export LD_LIBRARY_PATH="${dir_qt_lib}:${LD_LIBRARY_PATH}"


# When the path is relative add './' to it.
if [[ "${executable:0:1}" != "/" ]]; then
	executable="./${executable}"
fi

# Execute it in the directory.
cd "${dir_bin_lnx}" && "${executable}" "${@}"
