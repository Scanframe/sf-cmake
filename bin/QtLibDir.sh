#!/bin/bash

# Exit immediately if a command exits with a non-zero status. (is the same as '-o errexit')
set -e
# Make sure the 'tee pipes' fail correctly. Don't hide errors within pipes.
set -o pipefail

# Get the scripts run directory weather it is a symlink or not.
run_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# When a symlink determine the script directory.
if [[ -L "${BASH_SOURCE[0]}" ]]; then
	include_dir="${run_dir}/$(dirname "$(readlink "$0")")"
else
	include_dir="${run_dir}"
fi

# Include WriteLog function.
source "${include_dir}/inc/Miscellaneous.sh"

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
	qt_subdir="qt/w64-$(uname -m)"
elif [[ "$(uname -o)" == "GNU/Linux" && "$1" == "Windows" ]]; then
	qt_subdir="qt/win-$(uname -m)"
elif [[ "$(uname -o)" == "GNU/Linux" && "$1" == "Linux" && -n "$2" ]]; then
	qt_subdir="qt/lnx-${2}"
else
	qt_subdir="qt/lnx-$(uname -m)"
fi

# When in Docker do not locate the directory.
if [[ -f /.dockerenv ]]; then
	##
	## In Docker use the home directory.
	##
	local_qt_root="${HOME}/lib/${qt_subdir}"
else
	##
	## Try finding the Qt library of the project first using the file 'build.sh' location.
	##
	# Move 1 directory up since the 'build.sh' is also in this directory.
	pushd "${run_dir}/.." >/dev/null
	# Look for file 'build.sh' up the directory path from the scripts directory.
	if filepath="$(FindUp --type f build.sh)"; then
		# Form the expected directory for the Qt library.
		local_qt_root="$(dirname "${filepath}")/lib/${qt_subdir}"
	fi
	popd >/dev/null
fi

# Check is the Qt install can be found.
if [[ ! -d "${local_qt_root}" ]]; then
	WriteLog "Qt install directory or symbolic link '${local_qt_root}' was not found!"
	exit 1
fi
# Find the newest Qt library installed also following symlinks.
local_qt_dir="$(find -L "${local_qt_root}/" -maxdepth 1 -type d -regex ".*\/[0-9]\\.[0-9]+\\.[0-9]+$" | sort --reverse --version-sort | head -n 1)"
if [[ -z "${local_qt_dir}" ]]; then
	WriteLog "Could not find local installed ${qt_subdir} directory."
	exit 1
fi
if [[ "$(uname -o)" == "Cygwin" ]]; then
	local_qt_dir="$(cygpath --mixed "${local_qt_dir}")"
fi
# Return the found value.
echo -n "${local_qt_dir}"
