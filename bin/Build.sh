#!/usr/bin/env bash
# Exit immediately if a command exits with a non-zero status. (is the same as '-o errexit')
set -e
# Make sure the 'tee pipes' fail correctly. Don't hide errors within pipes.
set -o pipefail

# When the script directory is not set then
if [[ -z "${SCRIPT_DIR}" ]]; then
	WriteLog "Environment variable 'SCRIPT_DIR' not set!"
	exit 1
fi

# Check if the needed commands are installed.1+
COMMANDS=("git" "jq" "cmake" "ctest" "ninja")
# Add interactive commands when running interactively.
if [[ "${CI}" != "true" ]]; then
	COMMANDS+=("dialog")
fi
for COMMAND in "${COMMANDS[@]}"; do
	if ! command -v "${COMMAND}" >/dev/null; then
		WriteLog "Missing command '${COMMAND}' for this script!"
		exit 1
	fi
done

# Get the include directory which is this script's directory.
INCLUDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Include the WriteLog function.
source "${INCLUDE_DIR}/inc/WriteLog.sh"

# When the script directory is not set then use the this scripts directory.
if [[ -z "${SCRIPT_DIR}" ]]; then
	SCRIPT_DIR="${INCLUDE_DIR}"
fi

# Change to the scripts directory to operated from when script is called from a different location.
if ! cd "${SCRIPT_DIR}"; then
	WriteLog "Change to operation directory '${SCRIPT_DIR}' failed!"
	exit 1
fi

# Prints the help to stderr.
#
function ShowHelp() {
	echo "Usage: ${0} [<options>] [<presets> ...]
  -d, --debug      : Debug: Show executed commands rather then executing them.
  -i, --info       : Return information on all available build and test presets.
  -s, --submodule  : Return branch information on all Git submodules of last commit.
  -p, --packages   : Install required Linux packages using debian apt package manager.
  -m, --make       : Create build directory and makefiles only.
  -f, --fresh      : Configure a fresh build tree, removing any existing cache file.
  -C, --wipe       : Wipe clean build tree directory.
  -c, --clean      : Cleans build targets first (adds build option '--clean-first')
  -b, --build      : Build target and make config when it does not exist.
  -B, --build-only : Build target only and fail when the configuration does note exist.
  -t, --test       : Runs the ctest application using a test-preset.
  -l, --list-only  : Lists the ctest test defined application by the project and selected preset.
  -n, --target     : Overrides the build targets set in the preset by a single target.
  -r, --regex      : Regular expression on which test names are to be executed.
  --gitlab-ci      : Simulate CI server by setting CI_SERVER environment variable (disables colors i.e.).
  Where <sub-dir> is the directory used as build root for the CMakeLists.txt in it.
  This is usually the current directory '.'.
  When the <target> argument is omitted it defaults to 'all'.
  The <sub-dir> is also the directory where cmake will create its 'cmake-build-???' directory.

  Examples:
    Make/Build project: ${0} -b my-preset
	"
}

function PrependAndEscape() {
	while read -r line; do
		WriteLog -e "${1}${line}"
	done
}

# Amount of CPU cores to use for compiling when make build is used.
MAKEFLAGS=" -j $(nproc --ignore 1)"
export MAKEFLAGS

# Get the target OS.
SF_TARGET_OS="$(uname -o)"

##
# Installs needed packages depending in the Windows(cygwin) or Linux environment it is called from.
#
function InstallPackages() {
	WriteLog "About to install required packages for ($1)..."
	if [[ "$1" == "GNU/Linux/x86_64" || "$1" == "GNU/Linux/arm64" || "$1" == "GNU/Linux/aarch64" ]]; then
		if ! sudo apt-get --yes install make cmake ninja-build gcc g++ doxygen graphviz libopengl0 libgl1-mesa-dev \
			libxkbcommon-dev libxkbfile-dev libvulkan-dev libssl-dev exiftool default-jre-headless "${LINUX_PACKAGES[@]}"; then
			WriteLog "Failed to install 1 or more packages!"
			exit 1
		fi
	elif [[ "$1" == "GNU/Linux/x86_64/Cross" ]]; then
		if ! sudo apt install mingw-w64 make cmake doxygen graphviz wine winbind exiftool \
			default-jre-headless "${CROSS_PACKAGES[@]}"; then
			WriteLog "Failed to install 1 or more packages!"
			exit 1
		fi
	elif [[ "$1" == "Cygwin/x86_64" ]]; then
		if ! apt-cyg install doxygen graphviz perl-Image-ExifTool; then
			WriteLog "Failed to install 1 or more Cygwin packages (Try the Cygwin setup tool when elevation is needed) !"
			exit 1
		fi
	else
		# shellcheck disable=SC2128
		WriteLog "Unknown '$1' environment selection passed to function '${FUNCNAME}' !"
	fi
}

##
# Returns the version number of the git version tag.
# Expected tag format is 'vM.N.P' where:
#   M: Major version number.
#   N: Minor version number.
#   P: Patch version number.
#
function GetGitTagVersion() {
	local tag
	git describe --tags --dirty --match 'v*' 2>/dev/null
	# Match on vx.x.x version tag.
	if [[ $? && ! "${tag}" =~ ^v([0-9]+\.[0-9]+\.[0-9]).* ]]; then
		echo "0.0.0"
	else
		echo "${BASH_REMATCH[1]}"
	fi
}

##
# Selects a build preset from the passed CMakePreset.json file.
# @param: Json file.
# @param: Select '' for info only value 'info'.
#
function SelectBuildPreset {
	local file_presets build_preset build_name build_desc build_presets build_preset_names dlg_options idx selection binary_dir
	# Assign argument to named variable.
	file_presets="${1}"
	# Initialize the array.
	build_presets=("None")
	build_preset_names=("")
	# shellcheck disable=SC2034
	while read -r build_preset config; do
		build_preset="${build_preset//\"/}"
		build_name="$(jq -r ".buildPresets[]|select(.name==\"${build_preset}\").displayName" "${file_presets}")"
		# Ignore entries with display names starting with '#'.
		[[ "${build_name:0:1}" == "#" && "${2}" != "info" ]] && continue
		build_desc="$(jq -r ".buildPresets[]|select(.name==\"${build_preset}\").description" "${file_presets}")"
		cfg_preset="$(jq -r ".buildPresets[]|select(.name==\"${build_preset}\").configurePreset" "${file_presets}")"
		cfg_name="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").displayName" "${file_presets}")"
		cfg_desc="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").description" "${file_presets}")"
		binary_dir="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").binaryDir" "${file_presets}")"
		# Remove the sourceDir variable from the value.
		binary_dir="${binary_dir//\$\{sourceDir\}\//}"
		# Set variable for expansion by eval command.
		#eval "sourceDir=\"${SCRIPT_DIR}\" binary_dir=${binary_dir}"
		if [[ "${2}" == "info" ]]; then
			WriteLog "Build: ${build_preset} '${build_name}' ${build_desc}"
			WriteLog -e "\tConfiguration: ${cfg_preset} '${cfg_name}' ${cfg_desc}\n"
		fi
		#  Using Directory: ${binary_dir}"
		build_presets+=("${build_name} (${cfg_name}) ${build_desc}")
		build_preset_names+=("${build_preset}")
	done < <(cmake --list-presets build | tail -n +3)
	if [[ "${2}" != "info" ]]; then
		# Form the dialog options from the build presets.
		dlg_options=()
		for idx in "${!build_presets[@]}"; do
			dlg_options+=("${idx}")
			dlg_options+=("${build_presets[$idx]} ")
		done
		# Check if the 'dialog' command exists.
		if ! command -v "dialog" >/dev/null; then
			WriteLog "Missing command 'dialog', use a build preset on the command line instead!"
			exit 1
		fi
		# Create a dialog returning a selection index.
		selection=$(dialog --backtitle "Build Selection" --menu "Select a preset to build" 20 100 80 "${dlg_options[@]}" 2>&1 >/dev/tty)
		# Return by echoing the value.
		echo "${build_preset_names[$selection]}"
	fi
}

##
# Selects a build preset from the passed CMakePreset.json file.
# @param: Json file.
# @param: Select '' for info only value 'info'.
#
function SelectTestPreset {
	local preset test_name test_desc file_presets presets preset_names dlg_options idx selection
	# Assign argument to named variable.
	file_presets="${1}"
	# Initialize the array.
	presets=("None")
	preset_names=("")
	# shellcheck disable=SC2034
	while read -r preset config; do
		preset="${preset//\"/}"
		test_name="$(jq -r ".testPresets[]|select(.name==\"${preset}\").displayName" "${file_presets}")"
		# Ignore entries with display names starting with '#'.
		[[ "${test_name:0:1}" == "#" && "${2}" != "info" ]] && continue
		test_desc="$(jq -r ".testPresets[]|select(.name==\"${preset}\").description" "${file_presets}")"
		cfg_preset="$(jq -r ".testPresets[]|select(.name==\"${preset}\").configurePreset" "${file_presets}")"
		cfg_name="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").displayName" "${file_presets}")"
		cfg_desc="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").description" "${file_presets}")"
		if [[ "${2}" == "info" ]]; then
			WriteLog "Test: ${preset} '${test_name}' ${test_desc}"
			WriteLog -e "\tConfiguration: ${cfg_preset} '${cfg_name}' ${cfg_desc}"
			ctest --preset "${preset}" --show-only | tail -n +2 | head -n -1 | PrependAndEscape "\t\t"
		fi
		presets+=("${test_name} (${cfg_name}) ${test_desc}")
		preset_names+=("${preset}")
	done < <(cmake --list-presets test | tail -n +3)
	if [[ "${2}" != "info" ]]; then
		# Form the dialog options from the build presets.
		dlg_options=()
		for idx in "${!presets[@]}"; do
			dlg_options+=("${idx}")
			dlg_options+=("${presets[$idx]} ")
		done
		# Check if the 'dialog' command exists.
		if ! command -v "dialog" >/dev/null; then
			WriteLog "Missing command 'dialog', use a build preset on the command line instead!"
			exit 1
		fi
		# Create a dialog returning a selection index.
		selection=$(dialog --backtitle "Test Selection" --menu "Select a preset for testing" 20 100 80 "${dlg_options[@]}" 2>&1 >/dev/tty)
		# Return by echoing the value.
		echo "${preset_names[$selection]}"
	fi
}

# Detect windows using the cygwin 'uname' command.
if [[ "${SF_TARGET_OS}" == "Cygwin" ]]; then
	WriteLog "# Windows OS detected through Cygwin shell"
	export SF_TARGET_OS="Cygwin"
	FLAG_WINDOWS=true
	# Set the directory the local QT root.
	# shellcheck disable=SC2012
	LOCAL_QT_ROOT="$( (ls -d /cygdrive/?/Qt | head -n 1) 2>/dev/null)"
	if [[ -d "$LOCAL_QT_ROOT" ]]; then
		WriteLog "# Found QT in '${LOCAL_QT_ROOT}'"
	fi
	# Create temporary file for executing cmake.
	#EXEC_SCRIPT="$(mktemp --suffix .bat)"
elif [[ "${SF_TARGET_OS}" == "Msys" ]]; then
	WriteLog "# Windows OS detected through Msys shell"
	export SF_TARGET_OS="Msys"
	FLAG_WINDOWS=true
	# Set the directory the local QT root.
	# shellcheck disable=SC2012
	LOCAL_QT_ROOT="$( (ls -d /?/Qt | tail -n 1) 2>/dev/null)"
	if [[ -d "$LOCAL_QT_ROOT" ]]; then
		WriteLog "# Found QT in '${LOCAL_QT_ROOT}'"
	fi
	# Create temporary file for executing cmake.
	#EXEC_SCRIPT="$(mktemp --suffix .bat)"
elif [[ "${SF_TARGET_OS}" == "GNU/Linux" ]]; then
	WriteLog "# Linux detected"
	export SF_TARGET_OS="GNU/Linux"
	FLAG_WINDOWS=false
	# Set the directory the local QT root.
	LOCAL_QT_ROOT="${HOME}/lib/Qt"
	# Check if it exists.
	if [[ -d "${LOCAL_QT_ROOT}" ]]; then
		WriteLog "# QT found in '${LOCAL_QT_ROOT}'"
	else
		LOCAL_QT_ROOT=""
	fi
	# Create temporary file for executing cmake.
	#EXEC_SCRIPT="$(mktemp --suffix .sh)"
	#chmod +x "${EXEC_SCRIPT}"
else
	WriteLog "Targeted OS '${SF_TARGET_OS}' not supported!"
fi

# No arguments at show help and bailout.
if [[ $# == 0 ]]; then
	ShowHelp
	exit 1
fi

# When in windows determine which cmake to use and where to get it including ninja and the compiler.
if ${FLAG_WINDOWS}; then
	# shellcheck disable=SC2154
	if ! command -v cmake >/dev/null; then
		PATH="$(ls -d "$(cygpath -u "${ProgramW6432}")/JetBrains/CLion"*/bin/cmake/win/x64/bin):${PATH}"
	fi
	if ! command -v ninja >/dev/null; then
		PATH="$(ls -d "$(cygpath -u "${ProgramW6432}")/JetBrains/CLion"*/bin/ninja/win/x64):${PATH}"
	fi
	PATH="${LOCAL_QT_ROOT}/Tools/mingw1120_64/bin:${PATH}"
	export PATH
fi

# Initialize arguments and switches.
FLAG_DEBUG=false
FLAG_CONFIG=false
FLAG_BUILD=false
FLAG_BUILD_ONLY=false
FLAG_TEST=false
FLAG_WIPE=false
FLAG_INFO=false
FLAG_LIST=false
# Initialize the cmake configure command as an array.
CMAKE_CONFIG=("cmake")
# Initialize the cmake build command as an array.
CMAKE_BUILD=("cmake" "--build")
CTEST_BUILD=("ctest")
# When empty the target is not overridden.
TARGET_NAME=""
# When empty the regex is not applied to test names.
TEST_REGEX=""

# Create file for exploring in Chrome using URL "chrome://tracing/".
#CMAKE_CONFIG+=("--profiling-output=perf.json" "--profiling-format=google-trace")

##
# Joins an array with glue.
# Arg1: The glue which can be a multi character string.
# Arg2+n: The array as separate arguments like "${myarray[@]}"

function join_by {
	local d=${1-} f=${2-}
	if shift 2; then
		printf %s "$f" "${@/#/$d}"
	fi
}

# Parse options.
temp=$(getopt -o 'n:hisdpfCcmbBtlr:' --long \
	'target:,help,info,submodule,debug,packages,fresh,wipe,clean,make,build,-B,build-only,test,list,regex:,gitlab-ci' \
	-n "$(basename "${0}")" -- "$@")
# shellcheck disable=SC2181
# No arguments at show help and bailout.
if [[ $# == 0 ]]; then
	ShowHelp
	exit 1
fi
eval set -- "${temp}"
unset temp
while true; do
	case $1 in

		--gitlab-ci)
			export CI_SERVER="yes"
			shift 1
			continue
			;;

		-h | --help)
			ShowHelp
			exit 0
			;;

		-i | --info)
			WriteLog "# Information on presets"
			# Set the flag to wipe the build directory first.
			FLAG_INFO=true
			shift 1
			continue
			;;

		-d | --debug)
			WriteLog "# Script debugging is enabled"
			FLAG_DEBUG=true
			shift 1
			continue
			;;

		-p | --packages)
			InstallPackages "${SF_TARGET_OS}/$(uname -m)/Cross"
			InstallPackages "${SF_TARGET_OS}/$(uname -m)"
			exit 0
			;;

		-C | --wipe)
			WriteLog "# Wipe clean build directory commenced"
			# Set the flag to wipe the build directory first.
			FLAG_WIPE=true
			shift 1
			continue
			;;

		-f | --fresh)
			WriteLog "# Configure a fresh build tree, removing any existing cache file."
			# Set the flag to wipe the build directory first.
			CMAKE_CONFIG+=("--fresh")
			shift 1
			continue
			;;

		-c | --clean)
			WriteLog "# Clean first enabled"
			CMAKE_BUILD+=("--clean-first")
			shift 1
			continue
			;;

		-s | --submodule)
			WriteLog "# Information on Git-submodules."
			shift 1
			# shellcheck disable=SC2016
			SCRIPT='echo "$(pwd): $(git log -n 1 --oneline --decorate | pcregrep -o1 ", ([^ ]*)\) ")";GIT_COLOR_UI="always git status" git status --short'
			# shellcheck disable=SC2086
			eval "${SCRIPT}"
			git -C "${SCRIPT_DIR}" submodule foreach --quiet "${SCRIPT}"
			exit 0
			;;

		-m | --make)
			WriteLog "# Create build directory and makefile(s) only"
			FLAG_CONFIG=true
			shift 1
			continue
			;;

		-b | --build)
			WriteLog "# Build the given presets and make the configuration when not present."
			FLAG_BUILD=true
			shift 1
			continue
			;;

		-B | --build-only)
			WriteLog "# Build the given presets only and fail when the configuration has not been made."
			FLAG_BUILD=true
			FLAG_BUILD_ONLY=true
			shift 1
			continue
			;;

		-t | --test)
			WriteLog "# Running tests enabled."
			FLAG_TEST=true
			shift 1
			continue
			;;

		-n | --target)
			WriteLog "# Setting different target then default."
			TARGET_NAME="${2}"
			shift 2
			continue
			;;

		-l | --list-only)
			WriteLog "# Listing is enabled"
			FLAG_LIST=true
			shift 1
			continue
			;;

		-r | --regex)
			WriteLog "# Setting regex for test names."
			TEST_REGEX="${2}"
			shift 2
			continue
			;;

		'--')
			shift
			break
			;;

		*)
			echo "Internal error on argument (${1}) !" >&2
			exit 1
			;;
	esac
done

# Get the arguments/presets in an array.
argument=()
while [ $# -gt 0 ] && ! [[ "$1" =~ ^- ]]; do
	argument=("${argument[@]}" "$1")
	shift
done

# Form the presets file location.
file_presets="${SCRIPT_DIR}/CMakePresets.json"

# Check if the presets file is present.
if [[ -d "${file_presets}" ]]; then
	WriteLog "File '${SCRIPT_DIR}/CMakePresets.json' is missing!"
	exit 1
fi

if ${FLAG_INFO}; then
	WriteLog "# Build preset information:"
	SelectBuildPreset "${file_presets}" "info"
	WriteLog "# Test preset information:"
	SelectTestPreset "${file_presets}" "info"
	exit 0
fi

## Do not allow to test and build at the same time.
#if ${FLAG_BUILD} && ${FLAG_TEST}; then
#	WriteLog "Cannot build and test at the same time!"
#	exit 1
#fi

# First argument is mandatory.
if [[ "${#argument[@]}" -eq 0 ]]; then
	# Assign an argument.
	if ${FLAG_BUILD} || ${FLAG_CONFIG}; then
		preset="$(SelectBuildPreset "${file_presets}")"
	elif ${FLAG_TEST}; then
		preset="$(SelectTestPreset "${file_presets}")"
	fi
	if [[ -z "${preset}" ]]; then
		WriteLog "Preset not selected."
		exit 1
	else
		argument=("${preset}")
	fi
fi

# Check if wiping can be performed.
if [[ "${TARGET}" == @(help|install) && ${FLAG_WIPE} == true ]]; then
	FLAG_WIPE=false
	WriteLog "Wiping clean with target '${TARGET}' not possible!"
fi

# When building is requested.
if ${FLAG_BUILD} || ${FLAG_CONFIG}; then
	for preset in "${argument[@]}"; do
		# Retrieve the configuration preset.
		cfg_preset="$(jq -r ".buildPresets[]|select(.name==\"${preset}\").configurePreset" "${file_presets}")"
		# Retrieve the configuration preset.
		binary_dir="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").binaryDir" "${file_presets}")"
		# Check if preset exists by checking the configuration preset value.
		if [[ -z "${cfg_preset}" ]]; then
			WriteLog "Build preset '${preset}' does not exist!"
			cmake --list-presets build
		else
			# Expand used 'sourceDir' variable using local 'SCRIPT_DIR' variable.
			binary_dir="${binary_dir//\$env{/\${}"
			eval "sourceDir=\"${SCRIPT_DIR}\" binary_dir=${binary_dir}"
			# Notify the build of the preset.
			WriteLog "# Building preset '${preset}' with configuration '${cfg_preset}' in directory '${binary_dir}' ..."
			# When the binary directory exists and the Wipe flag is set.
			if ${FLAG_WIPE} && [[ -d "${binary_dir}" ]]; then
				# Sanity check to see if to be wiped directory is a sub-directory.
				if [[ "${binary_dir}" != "${SCRIPT_DIR}/"* ]]; then
					WriteLog "Cannot wipe non subdirectory '${binary_dir}' !"
					exit 0
				fi
				WriteLog "# Wiping clean build-dir '${binary_dir}'"
				# When the directory exists only.
				if ${FLAG_DEBUG}; then
					WriteLog "rm --verbose --recursive --one-file-system --interactive=never --preserve-root \"${binary_dir}\""
				else
					if [[ -d "${binary_dir}" ]]; then
						# Remove the build directory.
						rm --verbose --recursive --one-file-system --interactive=never --preserve-root "${binary_dir}" >/dev/null 2>&1
					fi
				fi
			fi
			# When the binary directory does not exists or configure is required.
			if [[ ! -d "${binary_dir}" ]] || ${FLAG_CONFIG} && ! ${FLAG_BUILD_ONLY}; then
				CMAKE_CONFIG+=("--preset ${cfg_preset}")
				if ${FLAG_DEBUG}; then
					WriteLog "$(join_by ' ' "${CMAKE_CONFIG[@]}")"
				else
					WriteLog "# $(join_by ' ' "${CMAKE_CONFIG[@]}")"
					# shellcheck disable=SC2091
					$(join_by " " "${CMAKE_CONFIG[@]}")
				fi
			fi
			# Build when flag is set.
			if ${FLAG_BUILD}; then
				CMAKE_BUILD+=("--preset ${cfg_preset}")
				# Add flag to list targets.
				if ${FLAG_LIST}; then
					CMAKE_BUILD+=("--target help")
				# Otherwise just set the given target when it was set.
				else
					if [[ -n "${TARGET_NAME}" ]]; then
						CMAKE_BUILD+=("--target ${TARGET_NAME}")
					fi
				fi
				WriteLog "$(join_by " " "${CMAKE_BUILD[@]}")"
				if ! ${FLAG_DEBUG}; then
					WriteLog "# $(join_by " " "${CMAKE_BUILD[@]}")"
					# Run the build preset.
					# shellcheck disable=SC2091
					if ! eval "$(join_by " " "${CMAKE_BUILD[@]}")"; then
						WriteLog "CMake failed!"
						exit 1
					fi
				fi
			fi
		fi
	done
fi

# When building is requested.
if ${FLAG_TEST}; then
	for preset in "${argument[@]}"; do
		# Retrieve the configuration preset.
		cfg_preset="$(jq -r ".testPresets[]|select(.name==\"${preset}\").configurePreset" "${file_presets}")"
		# Retrieve the configuration preset.
		binary_dir="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").binaryDir" "${file_presets}")"
		# Check if preset exists by checking the configuration preset value.
		if [[ -z "${cfg_preset}" ]]; then
			WriteLog "Configure or Test preset '${preset}' does not exist!"
			# Show the available presets.
			ctest --list-presets
		else
			# Expand used 'sourceDir' variable using local 'SCRIPT_DIR' variable.
			binary_dir="${binary_dir//\$env{/\${}"
			eval "sourceDir=\"${SCRIPT_DIR}\" binary_dir=${binary_dir}"
			WriteLog "# Testing preset '${preset}' with configuration '${cfg_preset}' in directory '${binary_dir}' ..."
			CTEST_BUILD+=("--preset ${preset}")
			# Add flag to list tests.
			if ${FLAG_LIST}; then
				CTEST_BUILD+=("--show-only")
			fi
			# Add regular expression for test when given.
			if [[ -n "${TEST_REGEX}" ]]; then
				CTEST_BUILD+=("--tests-regex ${TEST_REGEX}")
				# Regard no tests found as no error and ignore it (exit code is 0 otherwise 8).
				#CTEST_BUILD+=("--no-tests=ignore")
			fi
			WriteLog "$(join_by " " "${CTEST_BUILD[@]}")"
			if ! ${FLAG_DEBUG}; then
				set +e
				# Run the test preset.
				# shellcheck disable=SC2091
				$(join_by " " "${CTEST_BUILD[@]}")
				exitcode="$?"
				case "${exitcode}" in
					0) WriteLog "CTest success." ;;

					8)
						# When the regex is empty the test failed.
						if [[ -z "${TEST_REGEX}" ]]; then exit 1; else
							WriteLog "CTest no tests matched '${TEST_REGEX}'."
						fi
						;;
					*)
						WriteLog "CTest failed [${exitcode}]!"
						exit 1
						;;
				esac
			fi
		fi
	done
fi
