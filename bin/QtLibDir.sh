#!/bin/bash

# Exit immediately if a command exits with a non-zero status. (is the same as '-o errexit')
set -e
# Make sure the 'tee pipes' fail correctly. Don't hide errors within pipes.
set -o pipefail

# Get the script directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Include WriteLog function.
source "${script_dir}/inc/Miscellaneous.sh"

# When set in the environment do not look any further.
if [[ -n "${QT_VER_DIR}" ]]; then
	if [[ ! -d "${QT_VER_DIR}" ]]; then
		WriteLog "Environment QT_VER_DIR set to non existing directory: ${QT_VER_DIR} !"
		exit 1
	fi
	echo -n "${QT_VER_DIR}"
	exit 0
fi

# Get the subdirectory for the OS and target.
if [[ "$(uname -o)" == "Cygwin" ]]; then
	qt_subdir="QtW64"
elif [[ "$(uname -o)" == "GNU/Linux" && "$1" == "Windows" ]]; then
	qt_subdir="QtWin"
else
	qt_subdir="Qt"
fi

##
## Try finding the Qt library of the project first using the file 'build.sh' location.
##
# Move 1 directory up since the 'build.sh' is also in this directory.
pushd "${script_dir}/.." >/dev/null
# Look for file 'build.sh' up the directory path from the scripts directory.
if filepath="$(FindUp --type f build.sh)"; then
	# Form the expected directory for the Qt library.
	local_qt_root="$(dirname "${filepath}")/lib/${qt_subdir}"
fi
popd >/dev/null

# Check is the Qt install can be found.
if [[ ! -d "${local_qt_root}" ]] ; then
	WriteLog "Qt install directory or symbolic link '${local_qt_root}' was not found!"
	exit 1
fi
# Find the newest Qt library installed also following symlinks.
local_qt_dir="$(find -L "${local_qt_root}/" -maxdepth 1 -type d -regex ".*\/[0-9]\\.[0-9]+\\.[0-9]+$" | sort --reverse --version-sort | head -n 1)"
if [[ -z "${local_qt_dir}" ]] ; then
	WriteLog "Could not find local installed ${qt_subdir} directory."
	exit 1
fi
if [[ "$(uname -o)" == "Cygwin" ]]; then
	local_qt_dir="$(cygpath --mixed "${local_qt_dir}")"
fi
# Return the found value.
echo -n "${local_qt_dir}"