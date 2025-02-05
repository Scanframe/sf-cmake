#!/usr/bin/env bash

# Bailout on first error.
set -e

# Get this script's directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Include WriteLog function.
source "${script_dir}/inc/Miscellaneous.sh"

# Check if the executable directory has been set.
if [[ -z "${EXECUTABLE_DIR}" || ! -d "${EXECUTABLE_DIR}" ]]; then
	WriteLog "Environment variable 'EXECUTABLE_DIR' does not exist or has not been set!"
	exit 1
fi

# Get the Qt installed directory.
if qt_ver_dir="$("${script_dir}/QtLibDir.sh" "Windows")"; then
	# Location of Qt DLLs.
	dir_qt_dll="$(realpath "${qt_ver_dir}/mingw_64/bin")"
else
	dir_qt_dll=
fi

# Form the binary target directory for Windows builds.
dir_bin_win="$(realpath "${EXECUTABLE_DIR}")"

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
	# Split the output into an array using the newline character as the delimiter.
	# The '@clion' option is added so the Qt library DLLs are found when running binary.
	while IFS= read -r -d $'\n'; do
		idx=$((idx + 1))
		files[${idx}]="${REPLY}"
		dlg_options+=("${idx}" "${REPLY}")
	done < <(cd "${dir_bin_win}" && ls -1A *.exe && echo '@clion')
	# Create a dialog returning a selection index.
	idx="$(dialog --backtitle "Run Windows Binary" \
		--menu "Select a Windows binary to run on Windows $(uname -s)" \
		22 60 80 "${dlg_options[@]}" 2>&1 >/dev/tty)"
	# Echoing the binary filename as the return value.
	echo "${files[${idx}]}"
}

# When no executable name is passed show selection dialog.
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
	WriteLog "- Selected binary: ${EXECUTABLE_DIR}/${bin_file}"
fi

# Check if all directories exist.
for dir_name in "${dir_bin_win}" "${dir_qt_dll}"; do
	if [[ -n "${dir_name}" && ! -d "${dir_name}" ]]; then
		WriteLog "Missing directory '${dir_name}', probably something is not installed."
		exit 1
	fi
done
# Path to executable and its DLL's in the lib subdirectory and suppress any error messages.
wdir_exe_dll="$(cygpath -w "${dir_bin_win}/lib")"
# Path to QT runtime DLL's
wdir_qt_dll="$(cygpath -w "${dir_qt_dll}")"
# Export the path to find the needed DLLs in where MinGW DLLs are at the beginning.
# Correct version of 'libstdc++-6.dll' is required.
echo "PATH prefix: ${wdir_qt_dll};${wdir_exe_dll}"
export PATH="${wdir_qt_dll};${wdir_exe_dll};${PATH}"

# Report some useful information.
WriteLog "- PATH prefix: ${wdir_qt_dll};${wdir_exe_dll}"
# Create array from the ctest arguments variable.
IFS=" " read -ra ctest_arguments <<<"${CTEST_ARGS}"
# Check if 'CTEST_ARGS' arguments were passed before reporting them.
if [[ -n "${CTEST_ARGS}" ]]; then
	# Argument CTEST_ARGS allows passing arguments to a ctest call.
	WriteLog "- CTEST_ARGS:" "${ctest_arguments[@]}"
fi

if [[ "${bin_file:0:1}" == '@' ]]; then
	# Remove the first character.
	bin_file="${bin_file:1}"
	# Execute the command found in the path.
	"${bin_file}" "${@}"
else
	# Execute the binary with all options.
	"${EXECUTABLE_DIR}/${bin_file}" "${@}" "${ctest_arguments[@]}"
fi

