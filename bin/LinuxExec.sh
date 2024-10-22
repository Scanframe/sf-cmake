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

# Form the binary target directory for Linux builds.
dir_bin="$(realpath "${EXECUTABLE_DIR}")"

function GetExecutablesFiles {
	for fn in "${EXECUTABLE_DIR}"/*; do
		if [[ "$(file -ib "${fn}")" =~ ^application/x-pie-executable ]]; then
			basename "${fn}"
		fi
	done
}

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
	done < <(GetExecutablesFiles)
	# Create a dialog returning a selection index.
	idx="$(dialog --backtitle "Run Linux Binary" \
		--menu "Select a Linux binary to run" \
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

# Get the Qt installed directory.
qt_ver_dir="$("${script_dir}/QtLibDir.sh" "Linux")"
# Location of Qt DLLs.
dir_qt_lib="$(realpath "${qt_ver_dir}/gcc_64/lib")"

dir_bin="${EXECUTABLE_DIR}"

if [[ -n "${LD_LIBRARY_PATH}" ]]; then
	export LD_LIBRARY_PATH="${dir_qt_lib}:${LD_LIBRARY_PATH}"
else
	export LD_LIBRARY_PATH="${dir_qt_lib}"
fi

# Report some useful information about dynamic library files.
WriteLog "- LD_LIBRARY_PATH: ${LD_LIBRARY_PATH}"
WriteLog "- RPATH: $(chrpath --list "${dir_bin}/${bin_file}")"

# When the path is relative add './' to it.
if [[ "${bin_file:0:1}" != "/" ]]; then
	bin_file="./${bin_file}"
fi

# Execute it in its own directory.
cd "${dir_bin}" && "${bin_file}" "${@}"
