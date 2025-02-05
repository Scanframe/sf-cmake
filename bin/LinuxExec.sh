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
qemu_static=''

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
	WriteLog "- Selected binary: ${EXECUTABLE_DIR}/${bin_file}"
fi

# Get the local variable for the binary directory.
dir_bin="${EXECUTABLE_DIR}"
# Get the architecture from the binary file.
architecture_file="$(file "${dir_bin}/${bin_file}" | grep -oE 'x86-64|aarch64' | head -n 1)"
# Replace the '-' in the file architecture. Meaning replacing it in x86-64.
architecture="${architecture_file/-/_}"
# Check if the architecture could be detected.
if [[ -z "${architecture}" ]]; then
	WriteLog "A valid architecture 'x86_64' or 'aarch64' could not be determined of '${bin_file}' (${architecture}) !"
	exit 1
fi

# Get the Qt installed directory.
if qt_ver_dir="$("${script_dir}/QtLibDir.sh" "Linux" "${architecture}")"; then
	# Location of Qt DLLs.
	dir_qt_lib="$(realpath "${qt_ver_dir}/gcc_64/lib")"
	WriteLog "# dir_qt_lib=${dir_qt_lib}"
else
	dir_qt_lib=
fi

# Set or expand the library path adding the Qt library.
if [[ -n "${LD_LIBRARY_PATH}" ]]; then
	export LD_LIBRARY_PATH="${dir_qt_lib}:${LD_LIBRARY_PATH}"
else
	export LD_LIBRARY_PATH="${dir_qt_lib}"
fi
# Report some useful information about dynamic library files and architecture.
WriteLog "- Architecture: ${architecture}"
# When the Linux architecture is different check if Qemu is installed and the binfmt-support package.
if [[ "$(uname -m | head -n 1)" != "${architecture}" ]]; then
	# Check if the needed command is installed used by
	if ! command -v "qemu-${architecture_file}-static" >/dev/null; then
		WriteLog "Command 'qemu-${architecture_file}-static' is not installed on $(uname -m) !"
		exit 1
	fi
	# Since docker can not easily run a service for binfmt_misc use the Qemu command directly.
	if [[ -f "/.dockerenv" ]]; then
		qemu_static="/usr/bin/qemu-${architecture_file}-static"
	else
		# Check if the package for binfmt_misc is installed.
		if [[ ! -d "/proc/sys/fs/binfmt_misc" ]]; then
			WriteLog "# System is missing 'binfmt_misc' module from 'binfmt-support' package executing the architecture."
		else
			# Check if architecture format is configured and enabled.
			if [[ "$(head -n 1 "/proc/sys/fs/binfmt_misc/qemu-${architecture_file}")" != "enabled" ]]; then
				WriteLog "System has qemu architecture not enabled!"
				exit 1
			fi
		fi
	fi
	# Export the setting for the Qemu to find the libraries of the architecture.
	export QEMU_LD_PREFIX="/usr/${architecture_file}-linux-gnu"
	WriteLog "- QEMU_LD_PREFIX: ${QEMU_LD_PREFIX}"
fi
WriteLog "- LD_LIBRARY_PATH: ${LD_LIBRARY_PATH}"
WriteLog "- $(chrpath --list "${dir_bin}/${bin_file}" | sed 's/.*: //')"
# Create array from the ctest arguments variable.
IFS=" " read -ra ctest_arguments <<<"${CTEST_ARGS}"
# Check if 'CTEST_ARGS' arguments were passed before reporting them.
if [[ -n "${CTEST_ARGS}" ]]; then
	# Argument CTEST_ARGS allows passing arguments to a ctest call.
	WriteLog "- CTEST_ARGS[${#ctest_arguments[@]}]:" "${ctest_arguments[@]}"
fi

# When the path is relative add './' to it.
if [[ "${bin_file:0:1}" != "/" ]]; then
	bin_file="./${bin_file}"
fi

# Execute it in its own directory.
cd "${dir_bin}"
if [[ -n "${qemu_static}" ]]; then
	"${qemu_static}" "${bin_file}" "${@}" "${ctest_arguments[@]}"
else
	"${bin_file}" "${@}" "${ctest_arguments[@]}"
fi
