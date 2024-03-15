#!/usr/bin/env bash
# Exit immediately if a command exits with a non-zero status. (is the same as '-o errexit')
set -e
# Make sure the 'tee pipes' fail correctly. Don't hide errors within pipes.
set -o pipefail

# Get the include directory which is this script's directory.
INCLUDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Include the Miscellaneous functions.
source "${INCLUDE_DIR}/inc/Miscellaneous.sh"

## Trap script exit with function.
trap 'ScriptExit "${BASH_SOURCE}" "${BASH_LINENO}" "${BASH_COMMAND}"' EXIT

	# When the script directory is not set then
if [[ -z "${SCRIPT_DIR}" ]]; then
	WriteLog "Environment variable 'SCRIPT_DIR' not set!"
	exit 1
fi

# Check if the needed commands are installed.1+
COMMANDS=("git" "jq" "cmake" "ctest" "cpack" "ninja")
# Add interactive commands when running interactively.
if [[ "${CI}" != "true" ]]; then
	COMMANDS+=(dialog)
fi
for COMMAND in "${COMMANDS[@]}"; do
	if ! command -v "${COMMAND}" >/dev/null; then
		WriteLog "Missing command '${COMMAND}' for this script!"
		exit 1
	fi
done

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
function ShowHelp {
	echo "Executes CMake commands using the 'CMakePresets.json' and 'CMakeUserPresets.json' files
of which the first is mandatory to exist.

Usage: ${0} [<options>] [<presets> ...]
  -h, --help       : Shows this help.
  -d, --debug      : Debug: Show executed commands rather then executing them.
  -i, --info       : Return information on all available build, test and package presets.
  -s, --submodule  : Return branch information on all Git submodules of last commit.
  -p, --package    : Create packages using a preset.
  --required       : Install required Linux packages using debian apt package manager.
  -m, --make       : Create build directory and makefiles only.
  -f, --fresh      : Configure a fresh build tree, removing any existing cache file.
  -C, --wipe       : Wipe clean build tree directory.
  -c, --clean      : Cleans build targets first (adds build option '--clean-first')
  -b, --build      : Build target and make config when it does not exist.
  -B, --build-only : Build target only and fail when the configuration does note exist.
  -t, --test       : Runs the ctest application using a test-preset.
  -w, --workflow   : Runs the passed work flow presets.
  -l, --list-only  : Lists the ctest test defined application by the project and selected preset.
  -n, --target     : Overrides the build targets set in the preset by a single target.
  -r, --regex      : Regular expression on which test names are to be executed.
  Where <sub-dir> is the directory used as build root for the CMakeLists.txt in it.
  This is usually the current directory '.'.
  When the <target> argument is omitted it defaults to 'all'.
  The <sub-dir> is also the directory where cmake will create its 'cmake-build-???' directory.

  Examples:
    Get all project presets info: ${0} -i
    Make/Build project: ${0} -b my-build-preset1 my-build-preset2
    Test project: ${0} -t my-test-preset1 my-test-preset2
    Make/Build/Test/Pack project: ${0} -w my-workflow-preset
	"
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
	#if [[ "$(lsb_release -is)" == "Ubuntu" ]]; then
		# Install packages needed for installing other packages.
		sudo apt-get update
		sudo apt-get --yes upgrade
		sudo apt --yes install wget curl gpg lsb-release software-properties-common
		# Check if the package repository has been added.
		if ! apt-add-repository --list | grep "llvm-toolchain">/dev/null; then
			wget https://apt.llvm.org/llvm-snapshot.gpg.key -O - | sudo tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc >/dev/null
			sudo apt-add-repository --yes --no-update "deb http://apt.llvm.org/$(lsb_release -sc)/ llvm-toolchain-$(lsb_release -sc) main"
		fi
		# Check if the package repository has been added.
		if ! apt-add-repository --list | grep "apt.kitware.com/ubuntu" >/dev/null; then
			wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null
			sudo apt-add-repository --yes --no-update "deb https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main"
		fi
		# Update after repositories were added.
		sudo apt-get update
		sudo apt-get --yes upgrade
		if ! sudo apt-get --yes install make cmake ninja-build gcc g++ doxygen graphviz libopengl0 libgl1-mesa-dev \
			libxkbcommon-dev libxkbfile-dev libvulkan-dev libssl-dev exiftool default-jre-headless "${LINUX_PACKAGES[@]}"; then
			WriteLog "Failed to install 1 or more packages!"
			exit 1
		fi
	elif [[ "$1" == "GNU/Linux/x86_64/Cross" ]]; then
		if ! sudo apt install mingw-w64 make cmake doxygen graphviz wine winbind exiftool default-jre-headless ; then
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
# Selects a build preset from the passed CMakePreset.json file.
# @param: Select '' for info only value 'info'.
# @param: Json file.
#
function SelectBuildPreset {
	local action preset name desc presets preset_names cfg_preset cfg_name cfg_name dlg_options idx selection binary_dir
	# Action is the first argument.
	action="${1}"
	# Remove the first argument from the list.
	shift 1
	# Initialize the array.
	presets=("None")
	preset_names=("")
	# shellcheck disable=SC2034
	while read -r preset config; do
		preset="${preset//\"/}"
		name="$(jq -r ".buildPresets[]|select(.name==\"${preset}\").displayName" "${@}")"
		# Ignore entries with display names starting with '#'.
		[[ "${name:0:1}" == "#" && "${action}" != "info" ]] && continue
		desc="$(jq -r ".buildPresets[]|select(.name==\"${preset}\").description" "${@}")"
		cfg_preset="$(jq -r ".buildPresets[]|select(.name==\"${preset}\").configurePreset" "${@}")"
		cfg_name="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").displayName" "${@}")"
		cfg_desc="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").description" "${@}")"
		binary_dir="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").binaryDir" "${@}")"
		# Expand used 'sourceDir' variable using 'SCRIPT_DIR' variable.
		eval "sourceDir=\"${SCRIPT_DIR}\" binary_dir=${binary_dir//\$env{/\${}"
		# When only information is requested.
		if [[ "${action}" == "info" ]]; then
			WriteLog "Build: ${preset} '${name}' ${desc}"
			WriteLog -e "\t-Configuration: ${cfg_preset} '${cfg_name}' ${cfg_desc}"
		fi
		#  Using Directory: ${binary_dir}"
		presets+=("${name} (${cfg_name}) ${desc}")
		preset_names+=("${preset}")
	done < <(cmake --list-presets build | tail -n +3)
	if [[ "${action}" != "info" ]]; then
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
		selection=$(dialog --backtitle "Build Selection" --menu "Select a preset to build" 20 100 80 "${dlg_options[@]}" 2>&1 >/dev/tty)
		# Return by echoing the value.
		echo "${preset_names[$selection]}"
	fi
}

##
# Selects a test preset from the passed CMakePreset.json file.
# @param: Select '' for info only value 'info'.
# @param: Json file.
#
function SelectTestPreset {
	local preset name desc presets preset_names cfg_preset cfg_name cfg_name dlg_options idx selection
	# Action is the first argument.
	action="${1}"
	# Remove the first argument from the list.
	shift 1
	# Initialize the array.
	presets=("None")
	preset_names=("")
	# shellcheck disable=SC2034
	while read -r preset config; do
		preset="${preset//\"/}"
		name="$(jq -r ".testPresets[]|select(.name==\"${preset}\").displayName" "${@}")"
		# Ignore entries with display names starting with '#'.
		[[ "${name:0:1}" == "#" && "${action}" != "info" ]] && continue
		desc="$(jq -r ".testPresets[]|select(.name==\"${preset}\").description" "${@}")"
		cfg_preset="$(jq -r ".testPresets[]|select(.name==\"${preset}\").configurePreset" "${@}")"
		cfg_name="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").displayName" "${@}")"
		cfg_desc="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").description" "${@}")"
		# When only information is requested.
		if [[ "${action}" == "info" ]]; then
			WriteLog "Test: ${preset} '${name}' ${desc}"
			WriteLog -e "\t-Configuration: ${cfg_preset} '${cfg_name}' ${cfg_desc}"
			# List the test names only and fail when 'grep' does not match.
			if ! ctest --preset "${preset}" --show-only | grep -P "\s+Test #\d+:" | PrependAndEscape "\t\t-"; then
				# Get the binary directory from the configuration.
				binary_dir="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").binaryDir" "${@}")"
				# Expand used 'sourceDir' variable using 'SCRIPT_DIR' variable.
				eval "sourceDir=\"${SCRIPT_DIR}\" binary_dir=${binary_dir//\$env{/\${}"
				# Check if the configuration step has been performed.
				if [[ ! -f "${binary_dir}/CMakeCache.txt" ]]; then
					WriteLog -e "\t\t:Need cmake configuration step for this information."
				fi
			fi
		fi
		presets+=("${name} (${cfg_name}) ${desc}")
		preset_names+=("${preset}")
	done < <(cmake --list-presets test | tail -n +3)
	if [[ "${action}" != "info" ]]; then
		# Form the dialog options from the build presets.
		dlg_options=()
		for idx in "${!presets[@]}"; do
			dlg_options+=("${idx}")
			dlg_options+=("${presets[$idx]} ")
		done
		# Check if the 'dialog' command exists.
		if ! command -v "dialog" >/dev/null; then
			WriteLog "Missing command 'dialog', use a test preset on the command line instead!"
			exit 1
		fi
		# Create a dialog returning a selection index.
		selection=$(dialog --backtitle "Test Selection" --menu "Select a preset for testing" 20 100 80 "${dlg_options[@]}" 2>&1 >/dev/tty)
		# Return by echoing the value.
		echo "${preset_names[$selection]}"
	fi
}

##
# Selects a package preset from the passed CMakePreset.json file.
# @param: Select '' for info only value 'info'.
# @param: Json file.
#
function SelectPackagePreset {
	local preset name desc presets preset_names cfg_preset cfg_name cfg_name dlg_options idx selection
	# Action is the first argument.
	action="${1}"
	# Remove the first argument from the list.
	shift 1
	# Initialize the array.
	presets=("None")
	preset_names=("")
	# shellcheck disable=SC2034
	while read -r preset config; do
		preset="${preset//\"/}"
		name="$(jq -r ".packagePresets[]|select(.name==\"${preset}\").displayName" "${@}")"
		# Ignore entries with display names starting with '#'.
		[[ "${name:0:1}" == "#" && "${action}" != "info" ]] && continue
		desc="$(jq -r ".packagePresets[]|select(.name==\"${preset}\").description" "${@}")"
		cfg_preset="$(jq -r ".packagePresets[]|select(.name==\"${preset}\").configurePreset" "${@}")"
		cfg_name="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").displayName" "${@}")"
		cfg_desc="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").description" "${@}")"
		# When only information is requested.
		if [[ "${action}" == "info" ]]; then
			WriteLog "Package: ${preset} '${name}' ${desc}"
			WriteLog -e "\t-Configuration: ${cfg_preset} '${cfg_name}' ${cfg_desc}"
		fi
		presets+=("${name} (${cfg_name}) ${desc}")
		preset_names+=("${preset}")
	done < <(cmake --list-presets package | tail -n +3)
	if [[ "${action}" != "info" ]]; then
		# Form the dialog options from the build presets.
		dlg_options=()
		for idx in "${!presets[@]}"; do
			dlg_options+=("${idx}")
			dlg_options+=("${presets[$idx]} ")
		done
		# Check if the 'dialog' command exists.
		if ! command -v "dialog" >/dev/null; then
			WriteLog "Missing command 'dialog', use a package preset on the command line instead!"
			exit 1
		fi
		# Create a dialog returning a selection index.
		selection=$(dialog --backtitle "Test Selection" --menu "Select a preset for packaging" 20 100 80 "${dlg_options[@]}" 2>&1 >/dev/tty)
		# Return by echoing the value.
		echo "${preset_names[$selection]}"
	fi
}

##
# Selects a workflow preset from the passed CMakePreset.json file.
# @param: Select '' for info only value 'info'.
# @param: Json file.
#
function SelectWorkflowPreset {
	local preset name desc presets preset_names dlg_options idx selection
	# Action is the first argument.
	action="${1}"
	# Remove the first argument from the list.
	shift 1
	# Initialize the array.
	presets=("None")
	preset_names=("")
	# shellcheck disable=SC2034
	while read -r preset config; do
		preset="${preset//\"/}"
		name="$(jq -r ".workflowPresets[]|select(.name==\"${preset}\").displayName" "${@}")"
		# Ignore entries with display names starting with '#'.
		[[ "${name:0:1}" == "#" && "${action}" != "info" ]] && continue
		desc="$(jq -r ".workflowPresets[]|select(.name==\"${preset}\").description" "${@}")"
		# When only information is requested.
		if [[ "${action}" == "info" ]]; then
			WriteLog "Workflow: ${preset} '${name}' ${desc}"
			jq -r "(.workflowPresets[]|select(.name==\"${preset}\").steps[]| .type + \"(\"  + .name + \")\")" "${@}" | PrependAndEscape "\t-Step #\${counter}: " || true
		fi
		presets+=("${name} > ${desc}")
		preset_names+=("${preset}")
	done < <(cmake --list-presets workflow | tail -n +3)
	if [[ "${action}" != "info" ]]; then
		# Form the dialog options from the build presets.
		dlg_options=()
		for idx in "${!presets[@]}"; do
			dlg_options+=("${idx}")
			dlg_options+=("${presets[$idx]} ")
		done
		# Check if the 'dialog' command exists.
		if ! command -v "dialog" >/dev/null; then
			WriteLog "Missing command 'dialog', use a package preset on the command line instead!"
			exit 1
		fi
		# Create a dialog returning a selection index.
		selection=$(dialog --backtitle "Test Selection" --menu "Select a preset for packaging" 20 100 80 "${dlg_options[@]}" 2>&1 >/dev/tty)
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
	exit 0
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
FLAG_PACKAGE=false
FLAG_WORKFLOW=false
FLAG_WIPE=false
FLAG_INFO=false
FLAG_LIST=false
# Initialize the cmake configure command as an array.
CMAKE_CONFIG=("cmake")
# Create file for exploring in Chrome using URL "chrome://tracing/".
#CMAKE_CONFIG+=("--profiling-output=perf.json" "--profiling-format=google-trace")
# Initialize the cmake build command as an array.
CMAKE_BUILD=("cmake" "--build")
# Initialize the ctest command as an array.
CTEST_BUILD=("ctest")
# Initialize the cpack command as an array.
CPACKAGE_BUILD=("cpack")
# When empty the target is not overridden.
TARGET_NAME=""
# When empty the regex is not applied to test names.
TEST_REGEX=""

# Parse options.
temp=$(getopt -o 'n:hisdpfCcmbwBtlr:' \
	--long 'target:,help,info,submodule,required,debug,fresh,wipe,clean,make,build,workflow,-B,build-only,test,package,list,regex:,gitlab-ci' \
	-n "$(basename "${0}")" -- "$@")
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

		--required)
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
			WriteLog "# Run enabled tests."
			FLAG_TEST=true
			shift 1
			continue
			;;

		-w | --workflow)
			WriteLog "# Run workflow presets."
			FLAG_WORKFLOW=true
			shift 1
			continue
			;;

		-p | --package)
			WriteLog "# Running packaging enabled."
			FLAG_PACKAGE=true
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
file_presets=("${SCRIPT_DIR}/CMakePresets.json")

# Check if the presets file is present.
if [[ ! -f "${file_presets[0]}" ]]; then
	WriteLog "File '${file_presets[0]}' is missing!"
	exit 1
fi

# Add user presets to the list.
if [[ -f "${SCRIPT_DIR}/CMakeUserPresets.json" ]]; then
	file_presets+=("${SCRIPT_DIR}/CMakeUserPresets.json")
fi

# Check if information is to be shown only.
if ${FLAG_INFO}; then
	# Set tabs distance 2 spaces.
	tabs -2
	WriteLog "# Build preset information:"
	SelectBuildPreset "info" "${file_presets[@]}"
	WriteLog "# Test preset information:"
	SelectTestPreset "info" "${file_presets[@]}"
	WriteLog "# Package preset information:"
	SelectPackagePreset "info" "${file_presets[@]}"
	WriteLog "# Workflow preset information:"
	SelectWorkflowPreset "info" "${file_presets[@]}"
	# Reset the tab distance.
	tabs -8
	exit 0
fi

# First argument is mandatory.
if [[ "${#argument[@]}" -eq 0 ]]; then
	if ${FLAG_WORKFLOW}; then
		preset="$(SelectWorkflowPreset "select" "${file_presets[@]}")"
	# Assign an argument.
	elif ${FLAG_BUILD} || ${FLAG_CONFIG}; then
		preset="$(SelectBuildPreset "select" "${file_presets[@]}")"
	elif ${FLAG_TEST}; then
		preset="$(SelectTestPreset "select" "${file_presets[@]}")"
	elif ${FLAG_PACKAGE}; then
		preset="$(SelectPackagePreset "select" "${file_presets[@]}")"
	fi
	if [[ -z "${preset}" ]]; then
		WriteLog "- Preset not selected."
		exit 0
	else
		argument=("${preset}")
	fi
fi

# When workflow is requested.
if ${FLAG_WORKFLOW}; then
	for preset in "${argument[@]}"; do
		cmake --workflow --preset "${preset}"
	done
	# Work flow is already a combination.
	exit 0
fi

# Check if wiping can be performed.
if [[ "${TARGET}" == @(help|install) && ${FLAG_WIPE} == true ]]; then
	FLAG_WIPE=false
	WriteLog "Wiping clean with target '${TARGET}' not possible!"
fi

# When configure and/or build is requested.
if ${FLAG_BUILD} || ${FLAG_CONFIG}; then
	#  Make a copy of the array.
	SAVED_CMAKE_CONFIG=("${CMAKE_CONFIG[@]}")
	for preset in "${argument[@]}"; do
		CMAKE_CONFIG=("${SAVED_CMAKE_CONFIG[@]}")
		# Retrieve the configuration preset.
		cfg_preset="$(jq -r ".buildPresets[]|select(.name==\"${preset}\").configurePreset" "${file_presets[@]}")"
		# Retrieve the configuration preset.
		binary_dir="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").binaryDir" "${file_presets[@]}")"
		# Check if preset exists by checking the configuration preset value.
		if [[ -z "${cfg_preset}" ]]; then
			WriteLog "Build preset '${preset}' does not exist!"
			cmake --list-presets build
		else
			# Expand used 'sourceDir' variable using local 'SCRIPT_DIR' variable.
			eval "sourceDir=\"${SCRIPT_DIR}\" binary_dir=${binary_dir//\$env{/\${}"
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
					WriteLog "$(JoinBy ' ' "${CMAKE_CONFIG[@]}")"
				else
					WriteLog "# $(JoinBy ' ' "${CMAKE_CONFIG[@]}")"
					# shellcheck disable=SC2091
					$(JoinBy " " "${CMAKE_CONFIG[@]}")
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
				WriteLog "$(JoinBy " " "${CMAKE_BUILD[@]}")"
				if ! ${FLAG_DEBUG}; then
					WriteLog "# $(JoinBy " " "${CMAKE_BUILD[@]}")"
					# Run the build preset.
					# shellcheck disable=SC2091
					if ! eval "$(JoinBy " " "${CMAKE_BUILD[@]}")"; then
						WriteLog "CMake failed!"
						exit 1
					fi
				fi
			fi
		fi
	done
fi

# When test is requested.
if ${FLAG_TEST}; then
	SAVED_CTEST_BUILD=("${CTEST_BUILD[@]}")
	for preset in "${argument[@]}"; do
		CTEST_BUILD=("${SAVED_CTEST_BUILD[@]}")
		# Retrieve the configuration preset.
		cfg_preset="$(jq -r ".testPresets[]|select(.name==\"${preset}\").configurePreset" "${file_presets[@]}")"
		# Retrieve the configuration preset.
		binary_dir="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").binaryDir" "${file_presets[@]}")"
		# Check if preset exists by checking the configuration preset value.
		if [[ -z "${cfg_preset}" ]]; then
			WriteLog "Configure or Test preset '${preset}' does not exist!"
			# Show the available presets.
			ctest --list-presets
		else
			# Expand used 'sourceDir' variable using local 'SCRIPT_DIR' variable.
			eval "sourceDir=\"${SCRIPT_DIR}\" binary_dir=${binary_dir//\$env{/\${}"
			WriteLog "# Testing preset '${preset}' with configuration '${cfg_preset}' in directory '${binary_dir}' ..."
			CTEST_BUILD+=(--preset "${preset}")
			CTEST_BUILD+=(--verbose)
			# Add flag to list tests.
			if ${FLAG_LIST}; then
				CTEST_BUILD+=(--show-only)
			fi
			# Add regular expression for test when given.
			if [[ -n "${TEST_REGEX}" ]]; then
				CTEST_BUILD+=(--tests-regex "${TEST_REGEX}")
				# Regard no tests found as no error and ignore it (exit code is 0 otherwise 8).
				#CTEST_BUILD+=("--no-tests=ignore")
			fi
			WriteLog "$(JoinBy " " "${CTEST_BUILD[@]}")"
			if ! ${FLAG_DEBUG}; then
				set +e
				# Run the test preset.
				# shellcheck disable=SC2091
				"${CTEST_BUILD[@]}"
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

# When package is requested.
if ${FLAG_PACKAGE}; then
	SAVED_CPACKAGE_BUILD=("${CPACKAGE_BUILD[@]}")
	for preset in "${argument[@]}"; do
		CPACKAGE_BUILD=("${SAVED_CPACKAGE_BUILD[@]}")
		# Retrieve the configuration preset.
		cfg_preset="$(jq -r ".packagePresets[]|select(.name==\"${preset}\").configurePreset" "${file_presets[@]}")"
		# Retrieve the configuration preset.
		package_dir="$(jq -r ".packagePresets[]|select(.name==\"${cfg_preset}\").packageDirectory" "${file_presets[@]}")"
		# Expand used 'sourceDir' variable using local 'SCRIPT_DIR' variable.
		eval "sourceDir=\"${SCRIPT_DIR}\" package_dir=${package_dir//\$env{/\${}"
		# Check if preset exists by checking the configuration preset value.
		if [[ -z "${cfg_preset}" ]]; then
			WriteLog "Configure or Package preset '${preset}' does not exist!"
			# Show the available presets.
			cmake --list-presets configure
		else
			CPACKAGE_BUILD+=(--preset "${preset}")
			CPACKAGE_BUILD+=(--verbose)
			WriteLog "$(JoinBy " " "${CPACKAGE_BUILD[@]}")"
			if ! ${FLAG_DEBUG}; then
				set +e
				# Run the package preset.
				# shellcheck disable=SC2091
				"${CPACKAGE_BUILD[@]}"
				exitcode="$?"
				# Check the exit code.
				if [[ "${exitcode}" -ne 0 ]]; then
					WriteLog "CPackage failed [${exitcode}]!"
					# Only NSIS produces log files and report only lines containing 'err' or 'warn'.
					# shellcheck disable=SC2038
					find "${package_dir}" -type f -name "*.log" | xargs cat | grep --perl-regexp --ignore-case "(err|warn)"
				else
					WriteLog "CPack success."
				fi
			fi
		fi
	done
fi
