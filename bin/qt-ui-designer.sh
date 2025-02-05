#!/bin/bash

# Get the script directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Include WriteLog function.
source "${script_dir}/inc/WriteLog.sh"

# Check if the extension is ok.
if [[ "${1##*.}" != "ui" ]]; then
	if command -v "yad" >/dev/null; then
		yad \
		--center --on-top --no-markup --text-align=center \
		--width=270 \
		--title="Qt Designer" \
		--text "\nDesigner only handles UI-files?" \
		--image="${script_dir}/../img/qt-ui-designer.svg" \
		--window-icon="${script_dir}/../img/qt-ui-designer.svg" \
		--button="Close"
	fi
	exit 1
fi

# Form the actual command.
if [[ "$(uname -o)" == "Cygwin" ]]; then
	cmd="$("${script_dir}/QtLibDir.sh")/mingw_64/bin/designer"
else
	cmd="$("${script_dir}/QtLibDir.sh")/gcc_64/bin/designer"
fi

if ! command -v "${cmd}" &>/dev/null; then
	WriteLog "Command '${cmd}' not found!"
	exit 1
fi

# Use the working directory as the location for locating needed dynamic libraries.
LD_LIBRARY_PATH="${PWD}" "${cmd}" "$@"
