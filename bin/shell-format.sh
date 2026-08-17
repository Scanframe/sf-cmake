#!/usr/bin/env bash
#
# Script to format
#

# Bail out on first error.
set -e

# Get the scripts run directory weather it is a symlink or not.
run_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# When a symlink determine the script directory.
if [[ -L "${BASH_SOURCE[0]}" ]]; then
	include_dir="$(dirname "$(readlink "$0")")"
# Check if the library directory exists when not called from a sym-link.
elif [[ -d "${run_dir}/cmake/lib" ]]; then
	include_dir="${run_dir}/cmake/lib/bin"
else
	include_dir="${run_dir}"
fi

# Include the Miscellaneous functions.
source "${include_dir}/inc/Miscellaneous.sh"

## Trap script exit with function.
trap 'ScriptExit "${BASH_SOURCE}" "${BASH_LINENO}" "${BASH_COMMAND}"' EXIT

# Prints the help.
#
function show_help {
	echo "Usage: ${0} <files>...
  Formats shell scripts."
}

if [[ $# -eq 0 ]]; then
	show_help
	exit 0
fi
# Format the given files.
shfmt -i 0 --case-indent --diff --write "${@}"