#!/usr/bin/env bash

# Get this script's directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Include WriteLog function.
source "${SCRIPT_DIR}/inc/WriteLog.sh"

# Check if the executable directory has been set.
if [[ -z "${EXECUTABLE_DIR}" || ! -d "${EXECUTABLE_DIR}" ]]; then
	WriteLog "Environment variable 'EXECUTABLE_DIR' does not exist or has not been set!"
	exit 1
fi

function GetExecutablesFiles
{
	for fn in "${EXECUTABLE_DIR}"/*; do
  	if [[ "$(file -ib "${fn}")" =~ ^application/x-pie-executable ]]; then
 			echo "$(basename "${fn}")"
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
if [[ -f "${SCRIPT_DIR}/QtLibDir.sh" ]]; then
	# Get the Qt installed directory.
	QT_VER_DIR="$(bash "${SCRIPT_DIR}/QtLibDir.sh" "$(realpath "${HOME}/lib/Qt")")"
	# Location of Qt DLLs.
	DIR_QT_LIB="$(realpath "${QT_VER_DIR}/gcc_64/lib")"
else
	WriteLog "File not found: ${SCRIPT_DIR}/QtLibDir.sh"
	DIR_QT_LIB=""
fi

# Get the command.
EXECUTABLE="${1}"
shift 1

DIR_BIN_LNX="${EXECUTABLE_DIR}"
export LD_LIBRARY_PATH="${DIR_QT_LIB}:${LD_LIBRARY_PATH}"


# When the path is relative add './' to it.
if [[ "${EXECUTABLE:0:1}" != "/" ]]; then
	EXECUTABLE="./${EXECUTABLE}"
fi

# Execute it in the directory.
cd "${DIR_BIN_LNX}" && "${EXECUTABLE}" "$@"
