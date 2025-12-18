#!/usr/bin/env bash

# Bailout on first error.
set -e

# Get this script's directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Include WriteLog function.
source "${script_dir}/inc/Miscellaneous.sh"

# Set the default.
dir_bin_win="${SF_EXECUTABLE_DIR:-${PWD}}"

# Get the Qt installed directory.
if qt_ver_dir="$("${script_dir}/QtLibDir.sh" "Windows")"; then
	# Location of Qt DLLs.
	dir_qt_dll="$(realpath "${qt_ver_dir}/mingw_64/bin")"
else
	dir_qt_dll=
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
dir_bin_win="$(realpath "${dir_bin_win}")"
# Location of MinGW DLLs.
dir_mingw_dll="/usr/x86_64-w64-mingw32/lib"
# Location of MinGW posix DLLs 2.
dir_mingw_dll2="$(find /usr/lib/gcc/x86_64-w64-mingw32 -name "*-posix" | sort -V | tail -n 1)"


# When no executable name is passed show selection dialog.
if [[ -z "${1}" ]]; then
	WriteLog "! No executable was passed."
	exit 1
fi

# Selected binary file from command line.
bin_file="${1}"
shift 1

# Check if all directories exist.
for dir_name in "${dir_bin_win}" "${dir_mingw_dll}" "${dir_mingw_dll2}" "${dir_qt_dll}"; do
	if [[ -n "${dir_name}" && ! -d "${dir_name}" ]]; then
		WriteLog "Missing directory '${dir_name}', probably something is not installed."
		exit 1
	fi
done
# Path to executable and its DLL's in the lib subdirectory and suppress any error messages.
wdir_exe_dll="$(winepath -w "${dir_bin_win}/lib")"
# Path to mingw runtime DLL's
wdir_mingw_dll="$(winepath -w "${dir_mingw_dll}")"
# Path to mingw runtime DLL's second path.
wdir_mingw_dll2="$(winepath -w "${dir_mingw_dll2}")"
# Path to QT runtime DLL's
wdir_qt_dll="$(winepath -w "${dir_qt_dll}")"
# Export the path to find the needed DLLs in where MinGW DLLs are at the beginning.
# Correct version of 'libstdc++-6.dll' is required.
export WINEPATH="${wdir_qt_dll};${wdir_mingw_dll};${wdir_mingw_dll2};${wdir_exe_dll};${WINEPATH}"
# Suppress warnings.
export WINEDEBUG="fixme-all"
# Architecture is 64-bit.
export WINEARCH=win64

# Report some useful information.
WriteLog "- WINEPATH: ${WINEPATH}"
# Create array from the ctest arguments variable.
IFS=" " read -ra ctest_arguments <<<"${CTEST_ARGS}"
# Check if 'CTEST_ARGS' arguments were passed before reporting them.
if [[ -n "${CTEST_ARGS}" ]]; then
	# Argument CTEST_ARGS allows passing arguments to a ctest call.
	WriteLog "- CTEST_ARGS:" "${ctest_arguments[@]}"
fi

## Execute it in its own shell to contain the temp dir change.
## Redirect wine stderr to be ignored.
cd "${dir_bin_win}" || exit 1
if [[ -n "${GDBSERVER_BIN}" ]]; then
	# Trap Ctrl-C and call exit() to exit the while loop.
	trap exit INT
	# Run the GDB-server infinitely.
	while true; do
		# Execute the binary with all options.
		WriteLog "- ${wine_bin}" "${GDBSERVER_BIN}" :1234 "${bin_file}" "$@" "${ctest_arguments[@]}"
		"${wine_bin}" "${GDBSERVER_BIN}" :1234 "${bin_file}" "$@" "${ctest_arguments[@]}"
		WriteLog "Exit code ($?)!"
	done
else
# Check if the binary file is actually a command.
if [[ "${bin_file:0:1}" == '@' ]]; then
	# Append this scripts directory for finding commands.
	export PATH="${PATH}:${script_dir}"
	# Remove the first character.
	bin_file="${bin_file:1}"
	# Execute the command found in the path.
	"${bin_file}" "${@}"
else
	# Execute the binary with all options.
	"${wine_bin}" "${bin_file}" "${@}" "${ctest_arguments[@]}"
fi
fi

