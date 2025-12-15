#!/bin/bash

# Get the current script directory.
dir="$(cd "$( dirname "${BASH_SOURCE[0]}")" && pwd)"

# Assemble the actual executable directory.
EXECUTABLE_DIR="${dir}/win64${SF_OUTPUT_DIR_SUFFIX}"

# When running from Cygwin Windows is the host so Wine is not there.
if [[ "$(uname -o)" != "Cygwin" ]]; then
	# Set the env variables for the script to act on.
	EXECUTABLE_DIR="${EXECUTABLE_DIR}" "${dir}/../cmake/lib/bin/WineExec.sh" "${@}"
else
	tools_dir_file="${dir}/../.tools-dir-$(uname -n)"
	echo "# Cygwin tools location file: $(basename "${tools_dir_file}")"
	# Check if the tools directory file exists.
	if [[ -f "${tools_dir_file}" ]]; then
		# Read the first line of the file and strip the newline.
		tools_dir="$(head -n 1 "${tools_dir_file}" | tr -d '\n' | tr -d '\n' | tr -d '\r')"
		if [[ -d "${tools_dir}" ]]; then
			export PATH="${tools_dir}:${PATH}"
			echo "# Tools directory added to PATH: ${tools_dir}"
		else
			echo "# Non-existing tools directory: ${tools_dir}"
		fi
	fi
	# Set the env variables for the script to act on.
	EXECUTABLE_DIR="${EXECUTABLE_DIR}" "${dir}/../cmake/lib/bin/WindowsExec.sh" "${@}"
fi
