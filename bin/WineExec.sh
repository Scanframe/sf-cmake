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

# Only when it could find the script.
if [[ -f "${script_dir}/QtLibDir.sh" ]]; then
	# Get the Qt installed directory.
	qt_ver_dir="$(bash "${script_dir}/QtLibDir.sh" "$(realpath "${HOME}/lib/QtWin")")"
	# Location of Qt DLLs.
	dir_qt_dll="$(realpath "${qt_ver_dir}/mingw_64/bin")"
else
	WriteLog "File not found: ${script_dir}/QtLibDir.sh"
	dir_qt_dll=""
fi

# Wine command to execute.
wine_bin="wine"
# Check if the command is available/installed.
if ! command -v "${wine_bin}" >/dev/null; then
	WriteLog "Missing command '${wine_bin}', so skipping it and exiting with zero."
	# Deliberate return zero so tests do not fail when wine is not installed.
	exit 0
fi

# Form the binary target directory for cross Windows builds.
dir_bin_win="$(realpath "${EXECUTABLE_DIR}")"
# Location of MinGW DLLs.
dir_mingw_dll="/usr/x86_64-w64-mingw32/lib"
# Location of MinGW posix DLLs 2.
dir_mingw_dll2="$(find /usr/lib/gcc/x86_64-w64-mingw32 -name "*-posix" | sort -V | tail -n 1)"

##
# Select executable from the available ones using a dialog.
#
function SelectBinary {
	local files
	declare -A files
	local dlg_options=("0" "<None>")
	local idx=0
	# 'None' as first entry.
	files[0]=""
	# Split the output into an array using the newline character as the delimiter
	while IFS= read -r -d $'\n'; do
		idx=$((idx + 1))
		files[${idx}]="${REPLY}"
		dlg_options+=("${idx}" "${REPLY}")
	done < <(cd "${dir_bin_win}" && ls -1A *.exe)
	# Create a dialog returning a selection index.
	idx="$(dialog --backtitle "Run Windows Binary" \
		--menu "Select a windows binary to run using Wine $("${wine_bin}" --version)" \
		22 60 80 "${dlg_options[@]}" 2>&1 >/dev/tty)"
	# Echoing the binary filename as the return value.
	echo "${files[${idx}]}"
}

# When nothing is passed show help and wine version.
if [[ -z "${1}" ]]; then
	bin_file="$(SelectBinary)"
else
	# Selected binary file from command line.
	bin_file="${1}"
	shift 1
fi

# When no selection made exit.
if [[ -z "${bin_file}" ]]; then
	WriteLog "- No selection made."
	exit 0
else
	WriteLog "- Selected binary: ${bin_file}"
fi

# Check if all directories exist.
for dir_name in "${dir_bin_win}" "${dir_mingw_dll}" "${dir_mingw_dll2}" "${dir_qt_dll}"; do
	if [[ -n "${dir_name}" && ! -d "${dir_name}" ]]; then
		WriteLog "Missing directory '${dir_name}', probably something is not installed."
		exit 1
	fi
done

# Path to executable and its DLL's in the lib subdirectory.
wdir_exe_dll="$(winepath -w "${dir_bin_win}/lib")"
# Path to mingw runtime DLL's
wdir_mingw_dll="$(winepath -w "${dir_mingw_dll}")"
# Path to mingw runtime DLL's second path.
wdir_mingw_dll2="$(winepath -w "${dir_mingw_dll2}")"
# Path to QT runtime DLL's
wdir_qt_dll="$(winepath -w "${dir_qt_dll}")"
# Export the path to find the needed DLLs in where MinGW DLLs are at the beginning.
# Correct version of 'libstdc++-6.dll' is required.
export WINEPATH="${wdir_mingw_dll};${wdir_mingw_dll2};${WINEPATH};${wdir_exe_dll};${wdir_qt_dll}"
# Suppress warnings.
export WINEDEBUG="fixme-all"

## Execute it in its own shell to contain the temp dir change.
## Redirect wine stderr to be ignored.
cd "${dir_bin_win}" || exit 1
if [[ -n "${GDBSERVER_BIN}" ]]; then
	# Trap Ctrl-C and call exit() to exit the while loop.
	trap exit INT
	# Run the GDB-server infinitely.
	while true; do
		# Execute the binary with all options.
		WriteLog "- ${wine_bin}" "${GDBSERVER_BIN}" :1234 "${bin_file}" "$@"
		"${wine_bin}" "${GDBSERVER_BIN}" :1234 "${bin_file}" "$@"
		WriteLog "Exit code ($?)!"
	done
else
	# Execute the binary with all options.
	"${wine_bin}" "${bin_file}" "$@"
fi
