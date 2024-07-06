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
SCRIPT_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
# Include WriteLog function.
source "${SCRIPT_DIR}/inc/WriteLog.sh"
# Defaults to dry run.
CMD_PF="echo"

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
			CMD_PF=
			shift 1
			continue
			;;

		-d | --dry-run)
			CMD_PF='echo'
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

[[ -z "${CMD_PF}" ]] && WriteLog "# Running for real..." || WriteLog "# Running dry..."

# Get the Qt installed directory.
QT_VER_DIR="$(bash "${SCRIPT_DIR}/QtLibDir.sh" "${argument[0]}")"
# When found
QT_WIN_DIR="${QT_VER_DIR}/../../QtWin"
if [[ -d "${QT_WIN_DIR}" ]]; then
	QT_WIN_DIR="$(realpath -s "${QT_WIN_DIR}")"
else
	WriteLog "Associated Window Qt directory '${QT_WIN_DIR}' not found!"
fi
# Qt version on Linux.
QT_VER="$(basename "${QT_VER_DIR}")"
# Qt lib sub directory build by certain compiler version.
QT_LIB_SUB="mingw_64"
# Directory where the Linux Qt library cmake files are located.
DIR_FROM="${QT_VER_DIR}/gcc_64/lib/cmake"
# Directory where the Windows Qt library cmake files are located.
DIR_TO="${QT_WIN_DIR}/${QT_VER}/${QT_LIB_SUB}/lib/cmake"

# Check if source directory exists.
if [[ ! -d "${DIR_FROM}" ]]; then
	WriteLog "Directory '${DIR_FROM}' does not exist!"
	exit 1
fi

# Check if destination directory exists.
if [[ ! -d "${DIR_TO}" ]]; then
	WriteLog "Directory '${DIR_TO}' does not exist!"
	exit 1
fi

# Set the tab size to 2.
tabs -2
# Show intent.
WriteLog -e "Fixing Windows Qt version ${QT_VER} for Cross-compiling: \n\tSource: '${DIR_FROM}'\n\tDestination: '${DIR_TO}'"
# Ask for permission
read -rp "Continue [y/N]? " && if [[ $REPLY = [yY] ]]
then
	WriteLog "Starting..."
else
	exit 0
fi

##
## Create symlinks to Linux 'libexec' files in Windows one.
##
win_libexec="${QT_WIN_DIR}/${QT_VER}/${QT_LIB_SUB}/libexec"
WriteLog "Create symlinks into required '${win_libexec}'."
# Create the directory when it does not exist yet.
if [[ ! -d "${win_libexec}" ]]; then
	${CMD_PF} mkdir "${win_libexec}"
fi
# Create symlink from each file.
while read -r file; do
	case $(basename "${file}") in
		rcc)
			${CMD_PF} ln --symbolic --force --relative "${file}" "${win_libexec}/$(basename "${file}").bin"
			WriteLog "Creating script for '${win_libexec}/$(basename "${file}")'"
			# Check if dry running.
			if [[ "${#CMD_PF}" -eq 0 ]] ; then
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
			${CMD_PF} chmod +x "${win_libexec}/rcc"
			;;

		*)
			WriteLog "Symlinking file: ${file}"
			${CMD_PF} ln --symbolic --force --relative "${file}" "${win_libexec}/$(basename "${file}")"
			;;
	esac
done < <(ls "${QT_VER_DIR}/gcc_64/libexec/"*)

##
## Create symlinks or dummies for applications needed in the make files.
##
for fn in "qtpaths" "qmake" \
	"qmldom" "qmllint" "qmlformat" "qmlprofiler" "qmlprofiler" "qmltime" "qmlplugindump" "qmltc" \
	"qmltestrunner"	"androiddeployqt" "androidtestrunner" "windeployqt" "qmlls" ; do
	if [[ ! -f "${QT_VER_DIR}/gcc_64/bin/${fn}" ]] ; then
		WriteLog "Creating dummy to missing binary file to symlink: ${QT_VER_DIR}/gcc_64/bin/${fn}"
		cat <<EOD > "${QT_WIN_DIR}/${QT_VER}/${QT_LIB_SUB}/bin/${fn}"
#!/bin/bash
###
### Dummy executable to fool Windows cmake files.
###
EOD
	else
		WriteLog "Creating symlink to: ${QT_VER_DIR}/gcc_64/bin/${fn}"
		${CMD_PF} ln -sf "${QT_VER_DIR}/gcc_64/bin/${fn}" "${QT_WIN_DIR}/${QT_VER}/${QT_LIB_SUB}/bin"
	fi
done

#
# Replace all cmake files referencing windows EXE-tools.
#
pushd "${DIR_TO}" > /dev/null || exit
declare -a files
while IFS='' read -r -d $'\n'; do
	# Only file with a reverence to a '.exe' in it.
	if grep -qli "\.exe\"" "${REPLY}" ; then
		files+=("${REPLY}")
	fi
done < <(find "${DIR_TO}" -type f -name "*-relwithdebinfo.cmake" -printf "%P\n")
popd > /dev/null || exit

# Iterate through the files.
for fn in "${files[@]}" ; do
	WriteLog "Overwriting CMake files using Linux version: $fn"
	${CMD_PF} cp "${DIR_FROM}/${fn}" "${DIR_TO}/${fn}"
	if [[ $fn == "Qt6CoreTools/Qt6CoreToolsTargets-relwithdebinfo.cmake" ]] ; then
		cat <<EOF >> "${DIR_TO}/${fn}"

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
