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

# Only when it could find the script.
if [[ -f "${SCRIPT_DIR}/QtLibDir.sh" ]]; then
	# Get the Qt installed directory.
	QT_VER_DIR="$(bash "${SCRIPT_DIR}/QtLibDir.sh" "$(realpath "${HOME}/lib/QtWin")")"
	# Location of Qt DLLs.
	DIR_QT_DLL="$(realpath "${QT_VER_DIR}/mingw_64/bin")"
else
	WriteLog "File not found: ${SCRIPT_DIR}/QtLibDir.sh"
	DIR_QT_DLL=""
fi
# Form the binary target directory for cross Windows builds.
#DIR_BIN_WIN="$(realpath "${EXECUTABLE_DIR}")"
DIR_BIN_WIN="${EXECUTABLE_DIR}"
# Location of MinGW DLLs.
DIR_MINGW_DLL="/usr/x86_64-w64-mingw32/lib"
# Location of MinGW posix DLLs 2.
DIR_MINGW_DLL2="$(find /usr/lib/gcc/x86_64-w64-mingw32 -name "*-posix" | sort -V | tail -n 1)"
# Wine command.
WINE_BIN="wine64"

# When nothing is passed show help and wine version.
if [[ -z "$1" ]]; then
	WriteLog \
		"Executes a cross-compiled Windows binary from the target directory.
Usage: $0 <win-exe-in-binwin-dir> [[<options>]...]
Wine Version: $("${WINE_BIN}" --version)

Available exe-files:
$(cd "${DIR_BIN_WIN}" && ls *.exe)
	"
	exit 1
fi

# Check if the command is available/installed.
if ! command -v "${WINE_BIN}" >/dev/null; then
	WriteLog "Missing '${WINE_BIN}', probably not installed."
	exit 1
fi

# Check if all directories exist.
for DIR_NAME in "${DIR_BIN_WIN}" "${DIR_MINGW_DLL}" "${DIR_MINGW_DLL2}" "${DIR_QT_DLL}"; do
	if [[ ! -z "${DIR_NAME}" && ! -d "${DIR_NAME}" ]]; then
		WriteLog "Missing directory '${DIR_NAME}', probably something is not installed."
		exit 1
	fi
done

# Path to executable and its DLL's.
WDIR_EXE_DLL="$(winepath -w "${DIR_BIN_WIN}")"
# Path to mingw runtime DLL's
WDIR_MINGW_DLL="$(winepath -w "${DIR_MINGW_DLL}")"
# Path to mingw runtime DLL's second path.
WDIR_MINGW_DLL2="$(winepath -w "${DIR_MINGW_DLL2}")"
# Path to QT runtime DLL's
WDIR_QT_DLL="$(winepath -w "${DIR_QT_DLL}")"
# Export the path to find the needed DLLs in.
export WINEPATH="${WINEPATH};${WDIR_EXE_DLL};${WDIR_QT_DLL};${WDIR_MINGW_DLL};${WDIR_MINGW_DLL2}"

# Execute it in its own shell to contain the temp dir change.
# Redirect wine stderr to be ignored.
#(cd "${DIR_BIN_WIN}" && wine "$@" 2> /dev/null)
cd "${DIR_BIN_WIN}" && wine "$@"
