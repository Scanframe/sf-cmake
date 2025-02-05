#!/usr/bin/env bash
#set -x

# Bailout on first error.
set -e

# Get the scripts run directory weather it is a symlink or not.
run_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# When a symlink determine the script directory.
if [[ -L "${BASH_SOURCE[0]}" ]]; then
	include_dir="${run_dir}/$(dirname "$(readlink "$0")")"
else
	include_dir="${run_dir}"
	run_dir="$(pwd)"
fi

# Include the Miscellaneous functions.
source "${include_dir}/inc/Miscellaneous.sh"

## Trap script exit with function.
trap 'ScriptExit "${BASH_SOURCE}" "${BASH_LINENO}" "${BASH_COMMAND}"' EXIT

# Change to the run directory to operated from when script is called from a different location.
if ! cd "${run_dir}"; then
	WriteLog "Change to operation directory '${run_dir}' failed!"
	exit 1
fi

# Defaults to dry run.
cmd_pf="echo"

# Find the newest Qt library installed also following symlinks.
qt_ver="$(basename "$(find -L "lnx-$(uname -m)/" -maxdepth 1 -type d -regex ".*\/[0-9]\\.[0-9]+\\.[0-9]+$" | sort --reverse --version-sort | head -n 1)")"
if [[ -z "${qt_ver}" ]]; then
	WriteLog "# Did not find version directory in 'lnx-$(uname -m)'."
else
	WriteLog "# Found Linux ($(uname -m)) Qt highest version: '${qt_ver}'."
fi

# Prints the help to stderr.
#
function show_help {
	echo "Usage: ${0} [options...]

  Fixes Windows Qt framework toolkit library to operate next to the Linux Qt framework.
  The script expects Linux and Windows Qt framework to be installed in respectively
  the in 'lnx-x86_64' and 'win-x86_64' subdirectories (symlinks allowed).
  This script creates relative symlinks to the needed Qt tools needed for building targets.
  Copies cmake-files from Linux to the Windows directory.

  -h, --help    : Shows this help.
  --qt-ver      : Version Qt framework and directory to fix.
                  Defaults to the highest current version '${qt_ver}'.
  -r, --run     : Run the script for real.
  -d, --dry-run : Dry run the script for testing.
"
}

# Parse options.
temp=$(getopt -o 'hrd' \
	--long 'help,qt-ver:,run,dry-run' \
	-n "$(basename "${0}")" -- "$@")
# No arguments, show help and bailout.
if [[ "${#}" -eq 0 ]]; then
	show_help
	exit 0
fi
eval set -- "${temp}"
unset temp
while true; do
	case $1 in

		-h | --help)
			show_help
			exit 0
			;;

		--qt-ver)
			qt_ver="${2}"
			shift 2
			continue
			;;

		-r | --run)
			cmd_pf=
			shift 1
			continue
			;;

		-d | --dry-run)
			cmd_pf='echo'
			shift 1
			continue
			;;

		'--')
			shift
			break
			;;

		*)
			WriteLog "Internal error on argument (${1}) !"
			exit 1
			;;
	esac
done

# Get the Qt installed directories.
qt_lnx_ver_dir="lnx-$(uname -m)/${qt_ver}/gcc_64"
qt_win_ver_dir="win-$(uname -m)/${qt_ver}/mingw_64"

[[ -z "${cmd_pf}" ]] && WriteLog "# Running for real..." || WriteLog "# Running dry..."

WriteLog "Proposed directories:
Linux  : ${qt_lnx_ver_dir}
Windows: ${qt_win_ver_dir}
"
flag_error=false

# Check if the needed source directory exists.
if [[ ! -d "${qt_lnx_ver_dir}" ]]; then
	WriteLog "Associated Linux Qt directory '${qt_lnx_ver_dir}' not found!"
	flag_error=true
fi

# Check if the needed target directory exists.
if [[ ! -d "${qt_win_ver_dir}" ]]; then
	WriteLog "Associated Windows Qt directory '${qt_win_ver_dir}' not found!"
	flag_error=true
fi

# Directory where the Linux Qt library cmake files are located.
cmake_dir_from="${qt_lnx_ver_dir}/lib/cmake"
# Directory where the Windows Qt library cmake files are located.
cmake_dir_to="${qt_win_ver_dir}/lib/cmake"

# Check if source directory exists.
if [[ ! -d "${cmake_dir_from}" ]]; then
	WriteLog "Directory '${cmake_dir_from}' does not exist!"
	flag_error=true
fi

# Check if destination directory exists.
if [[ ! -d "${cmake_dir_to}" ]]; then
	WriteLog "Directory '${cmake_dir_to}' does not exist!"
	flag_error=true
fi

# When an error occurred bailout here.
${flag_error} && exit 1

# Set the tab size to 2.
tabs -2
# Show intent.
WriteLog -e "Modifying Windows Qt version ${qt_ver} for Cross-compiling on Linux:
\tSource     : ${cmake_dir_from}
\tDestination: ${cmake_dir_to}"

# Ask for permission
read -rp "Continue [y/N]? " && if [[ "${REPLY}" = [yY] ]]; then
	WriteLog "# Starting..."
else
	exit 0
fi


# Offset directory between most directories which symlinks are placed.
offset_dir="../../../.."

##
## Create symlinks to Linux 'libexec' files in Windows one.
##
win_libexec="${qt_win_ver_dir}/libexec"


WriteLog "- Create symlinks into required '${win_libexec}'."
# Create the directory when it does not exist yet.
if [[ ! -d "${win_libexec}" ]]; then
	${cmd_pf} mkdir "${win_libexec}"
fi
# Create symlink from each file.
while read -r file; do
	case $(basename "${file}") in
		rcc)
			${cmd_pf} ln --symbolic --force "${offset_dir}/${file}" "${win_libexec}/$(basename "${file}").bin"
			WriteLog "- Creating script for '${win_libexec}/$(basename "${file}")'"
			# Check if dry running.
			if [[ "${#cmd_pf}" -eq 0 ]]; then
				cat <<'EOD' >"${win_libexec}/rcc"
#!/bin/bash
# Get this script's directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# Check if the version number is above 6.6.2.
if [[ "$(printf "$("${script_dir}/rcc.bin" --version | grep -o '[^ ]*$')\\n6.6.2\\n" | sort -r -V | head -n 1)" == "6.6.2" ]]; then
	# Run rcc as is.
	"${script_dir}/rcc.bin" "${@}"
else
	# Run rcc with option '--no-zstd' to use zlib where zstd is Linux default since least 6.6.3.
	"${script_dir}/rcc.bin" --no-zstd "${@}"
fi
EOD
			fi
			${cmd_pf} chmod +x "${win_libexec}/rcc"
			;;

		*)
			WriteLog "Symlinking file: ${file}"
			${cmd_pf} ln --symbolic --force "${offset_dir}/${file}" "${win_libexec}/$(basename "${file}")"
			;;
	esac
done < <(ls "${qt_lnx_ver_dir}/libexec/"*)

##
## Create symlinks or dummies for applications needed in the make files.
##
for fn_to in "qtpaths" "qmake" \
	"qmldom" "qmllint" "qmlformat" "qmlprofiler" "qmlprofiler" "qmltime" "qmlplugindump" "qmltc" \
	"qmltestrunner" "androiddeployqt" "androidtestrunner" "windeployqt" "qmlls"; do
	if [[ ! -f "${qt_lnx_ver_dir}/bin/${fn_to}" ]]; then
		WriteLog "Creating dummy to missing binary file to symlink: ${qt_lnx_ver_dir}/bin/${fn_to}"
		cat <<EOD >"${qt_win_ver_dir}/bin/${fn_to}"
#!/bin/bash
###
### Dummy executable to fool Windows cmake files.
###
EOD
	else
		WriteLog "- Creating symlink to: ${qt_lnx_ver_dir}/bin/${fn_to}"
		${cmd_pf} ln --symbolic --force "${offset_dir}/${qt_lnx_ver_dir}/bin/${fn_to}" "${qt_win_ver_dir}/bin/${fn_to}"
	fi
done

#
# Replace all cmake files referencing windows EXE-tools.
#
declare -a files
while IFS='' read -r -d $'\n'; do
	# Only file with a reverence to a '.exe' in it.
	if grep -qli "\.exe\"" "${cmake_dir_to}/${REPLY}"; then
		files+=("${REPLY}")
	fi
done < <(find "${cmake_dir_to}" -type f -regextype egrep -regex '.*-(release|relwithdebinfo)\.cmake$' -printf "%P\n")

# Iterate through the cmake files containing '.exe' references.
for fn_to in "${files[@]}"; do
	fn_from="${fn_to}"
	# Check if the source file exists.
	if [[ ! -f "${cmake_dir_from}/${fn_from}" ]]; then
		# Try a similar file but prefixed using '-release'.
		# This is the solution when the Linux Qt framework is build from source and not downloaded.
		fn_from="${fn_to%%-*}-release.cmake"
		WriteLog "- Trying 'release' instead of 'relwithdebinfo' for:  ${fn_to}"
		if [[ ! -f "${cmake_dir_from}/${fn_from}" ]]; then
			WriteLog "- Skipping file: ${fn_to}"
			continue
		fi
	fi
	WriteLog "- Overwriting CMake files using Linux version: $fn_to"
	# Copy the file into.
	${cmd_pf} cp "${cmake_dir_from}/${fn_from}" "${cmake_dir_to}/${fn_to}"
	# Special handling of single file needing an addition.
	if [[ "${fn_to%%-*}" == "Qt6CoreTools/Qt6CoreToolsTargets" ]]; then
		WriteLog "- Appending to file: ${cmake_dir_to}/${fn_to}"
		cat <<EOF >>"${cmake_dir_to}/${fn_to}"

# ===================================================================================================
# == Appended from Windows version because it is missed when cross compiling on Linux for Windows. ==
# ===================================================================================================

# Import target "Qt6::windeployqt" for configuration "RelWithDebInfo"
set_property(TARGET Qt6::windeployqt APPEND PROPERTY IMPORTED_CONFIGURATIONS RELWITHDEBINFO)
set_target_properties(Qt6::windeployqt PROPERTIES
  IMPORTED_LOCATION_RELWITHDEBINFO "\${_IMPORT_PREFIX}/bin/windeployqt"
  )

list(APPEND _IMPORT_CHECK_TARGETS Qt6::windeployqt )
list(APPEND _IMPORT_CHECK_FILES_FOR_Qt6::windeployqt "\${_IMPORT_PREFIX}/bin/windeployqt" )

EOF

	fi
done
