#!/usr/bin/env bash
#set -x

##
## Install only 64bit compilers.
##

#sudo apt install gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64 gdb-mingw-w64
# Command 'cp -p'  means 'cp --preserve=mode,ownership,timestamps'

# Bailout on first error.
set -e
# Directory of this script.
script_dir="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
# Include WriteLog function.
source "${script_dir}/inc/WriteLog.sh"
# Defaults to dry run.
cmd_pf="echo"

# Prints the help to stderr.
#
function ShowHelp {
	echo "Usage: ${0} [options...] [<qt-dir>]

  Fixes Windows Qt toolkit library to operate under besides the Linux Qt library/toolkit.
  The script expects Linux and Windows libraries to be installed/downloaded in respectively
  the ~/lib/Qt and ~/lib/QtWin directories (symlinks allowed).
  This script creates relative symlinks to the needed toolkit applications needed for building targets.
  It also changes or copies cmake-files to the Windows from the Linux one.

  -h, --help    : Shows this help.
  -r, --run     : Run the script for real.
  -d, --dry-run : Dry run the script for testing.

  qt-dir        : Linux installed Qt directory (defaults to '~/lib/Qt').
"
}

# Parse options.
temp=$(getopt -o 'hrd' \
	--long 'help,run,dry-run' \
	-n "$(basename "${0}")" -- "$@")
# No arguments, show help and bailout.
if [[ "${#}" -eq 0 ]]; then
	ShowHelp
	exit 1
fi
eval set -- "${temp}"
unset temp
while true; do
	case $1 in

		-h | --help)
			ShowHelp
			exit 0
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

# Harvest the arguments in an array.
argument=()
while [ "${#}" -gt 0 ] && ! [[ "${1}" =~ ^- ]]; do
	argument+=("${1}")
	shift
done

[[ -z "${cmd_pf}" ]] && WriteLog "# Running for real..." || WriteLog "# Running dry..."

# Get the Qt installed directory.
qt_ver_dir="$(bash "${script_dir}/QtLibDir.sh" "${argument[0]}")"
# When found
qt_win_dir="${qt_ver_dir}/../../QtWin"
if [[ -d "${qt_win_dir}" ]]; then
	qt_win_dir="$(realpath -s "${qt_win_dir}")"
else
	WriteLog "Associated Window Qt directory '${qt_win_dir}' not found!"
fi
# Qt version on Linux.
qt_ver="$(basename "${qt_ver_dir}")"
# Qt lib sub directory build by certain compiler version.
qt_lib_sub="mingw_64"
# Directory where the Linux Qt library cmake files are located.
dir_from="${qt_ver_dir}/gcc_64/lib/cmake"
# Directory where the Windows Qt library cmake files are located.
dir_to="${qt_win_dir}/${qt_ver}/${qt_lib_sub}/lib/cmake"

# Check if source directory exists.
if [[ ! -d "${dir_from}" ]]; then
	WriteLog "Directory '${dir_from}' does not exist!"
	exit 1
fi

# Check if destination directory exists.
if [[ ! -d "${dir_to}" ]]; then
	WriteLog "Directory '${dir_to}' does not exist!"
	exit 1
fi

# Set the tab size to 2.
tabs -2
# Show intent.
WriteLog -e "Fixing Windows Qt version ${qt_ver} for Cross-compiling: \n\tSource: '${dir_from}'\n\tDestination: '${dir_to}'"
# Ask for permission
read -rp "Continue [y/N]? " && if [[ "${REPLY}" = [yY] ]]
then
	WriteLog "Starting..."
else
	exit 0
fi

##
## Create symlinks to Linux 'libexec' files in Windows one.
##
win_libexec="${qt_win_dir}/${qt_ver}/${qt_lib_sub}/libexec"
WriteLog "Create symlinks into required '${win_libexec}'."
# Create the directory when it does not exist yet.
if [[ ! -d "${win_libexec}" ]]; then
	${cmd_pf} mkdir "${win_libexec}"
fi
# Create symlink from each file.
while read -r file; do
	case $(basename "${file}") in
		rcc)
			${cmd_pf} ln --symbolic --force --relative "${file}" "${win_libexec}/$(basename "${file}").bin"
			WriteLog "Creating script for '${win_libexec}/$(basename "${file}")'"
			# Check if dry running.
			if [[ "${#cmd_pf}" -eq 0 ]] ; then
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
			${cmd_pf} ln --symbolic --force --relative "${file}" "${win_libexec}/$(basename "${file}")"
			;;
	esac
done < <(ls "${qt_ver_dir}/gcc_64/libexec/"*)

##
## Create symlinks or dummies for applications needed in the make files.
##
for fn in "qtpaths" "qmake" \
	"qmldom" "qmllint" "qmlformat" "qmlprofiler" "qmlprofiler" "qmltime" "qmlplugindump" "qmltc" \
	"qmltestrunner"	"androiddeployqt" "androidtestrunner" "windeployqt" "qmlls" ; do
	if [[ ! -f "${qt_ver_dir}/gcc_64/bin/${fn}" ]] ; then
		WriteLog "Creating dummy to missing binary file to symlink: ${qt_ver_dir}/gcc_64/bin/${fn}"
		cat <<EOD > "${qt_win_dir}/${qt_ver}/${qt_lib_sub}/bin/${fn}"
#!/bin/bash
###
### Dummy executable to fool Windows cmake files.
###
EOD
	else
		WriteLog "Creating symlink to: ${qt_ver_dir}/gcc_64/bin/${fn}"
		${cmd_pf} ln --symbolic --force --relative "${qt_ver_dir}/gcc_64/bin/${fn}" "${qt_win_dir}/${qt_ver}/${qt_lib_sub}/bin"
	fi
done

#
# Replace all cmake files referencing windows EXE-tools.
#
pushd "${dir_to}" > /dev/null || exit
declare -a files
while IFS='' read -r -d $'\n'; do
	# Only file with a reverence to a '.exe' in it.
	if grep -qli "\.exe\"" "${REPLY}" ; then
		files+=("${REPLY}")
	fi
done < <(find "${dir_to}" -type f -name "*-relwithdebinfo.cmake" -printf "%P\n")
popd > /dev/null || exit

# Iterate through the files.
for fn in "${files[@]}" ; do
	WriteLog "Overwriting CMake files using Linux version: $fn"
	${cmd_pf} cp "${dir_from}/${fn}" "${dir_to}/${fn}"
	if [[ $fn == "Qt6CoreTools/Qt6CoreToolsTargets-relwithdebinfo.cmake" ]] ; then
		cat <<EOF >> "${dir_to}/${fn}"

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
