#!/bin/bash

# Get the script directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Include WriteLog function.
source "${script_dir}/inc/WriteLog.sh"

# When set in the environment do not look any further.
if [[ -n "${QT_VER_DIR}" ]]; then
	if [[ ! -d "${QT_VER_DIR}" ]]; then
		WriteLog "Environment QT_VER_DIR set to non existing directory: ${QT_VER_DIR} !"
		exit 1
	fi
	echo -n "${QT_VER_DIR}"
	exit 0
fi

# Set the directory the local QT root expected.
if [[ -z "$1" ]] ; then
	LOCAL_QT_ROOT="${HOME}/lib/Qt"
else
	LOCAL_QT_ROOT="$1"
fi

# Find newest local Qt version directory.
#
function GetLocalQtDir()
{
	local LocalQtDir=""
	# Check is the Qt install can be found.
	if [[ ! -d "${LOCAL_QT_ROOT}" ]] ; then
		WriteLog "Qt install directory or symbolic link '${LOCAL_QT_ROOT}' was not found!"
		exit 1
	fi
	# Find the newest Qt library installed also following symlinks.
	LocalQtDir="$(find -L "${LOCAL_QT_ROOT}/" -maxdepth 1 -type d -regex ".*\/[0-9]\\.[0-9]+\\.[0-9]+$" | sort --reverse --version-sort | head -n 1)"
	if [[ -z "${LocalQtDir}" ]] ; then
		WriteLog "Could not find local installed Qt directory."
		exit 1
	fi
	if [[ "$(uname -s)" == "CYGWIN_NT"* ]]; then
		LocalQtDir="$(cygpath --mixed "${LocalQtDir}")"
	fi
	echo -n "${LocalQtDir}"
}

if ! GetLocalQtDir ; then
	exit 1
fi 
