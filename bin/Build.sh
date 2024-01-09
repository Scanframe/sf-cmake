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
# Get the include directory which is this script's directory.
INCLUDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Include the WriteLog function.
source "${INCLUDE_DIR}/inc/WriteLog.sh"

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
  -i, --info       : Return information on all available build presets.
  -s, --submodule  : Return branch information on all Git submodules of last commit.
  -r, --required   : Install required Linux packages using debian package manager.
  -m, --make       : Create build directory and makefiles only.
  -f, --fresh      : Configure a fresh build tree, removing any existing cache file.
  -C, --wipe       : Wipe clean build tree directory.
  -b, --build      : Build target only.
  -c, --clean      : Cleans build targets first (adds build option '--clean-first')
  -t, --test       : Runs the ctest application in the cmake-build-* directory.
  --toolset <name> : Preferred toolset in Windows (clion,qt,studio) where:
                     qt = QT Group Framework, studio = Microsoft Visual Studio, clion = JetBrains CLion.
  --gitlab-ci      : Simulate CI server by setting CI_SERVER environment variable (disables colors i.e.).
  Where <sub-dir> is the directory used as build root for the CMakeLists.txt in it.
  This is usually the current directory '.'.
  When the <target> argument is omitted it defaults to 'all'.
  The <sub-dir> is also the directory where cmake will create its 'cmake-build-???' directory.

  Examples:
    Make/Build project: ${0} -b my-preset
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
		if ! sudo apt install --install-recommends make cmake gcc g++ doxygen graphviz libopengl0 libgl1-mesa-dev libxkbcommon-dev \
			libxkbfile-dev libvulkan-dev libssl-dev exiftool default-jre; then
			WriteLog "Failed to install 1 or more packages!"
			exit 1
		fi
	elif [[ "$1" == "GNU/Linux/x86_64/Cross" ]]; then
		if ! sudo apt install --install-recommends mingw-w64 make cmake doxygen graphviz wine winbind exiftool default-jre; then
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
#
function GetGitTagVersion() {
	local tag
	tag="$(git describe --tags --dirty --match "v*")"
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
	local file_presets build_presets build_preset_names dlg_options idx selection
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
FLAG_TEST=false
FLAG_WIPE=false
FLAG_INFO=false
# Initialize the cmake configure command as an array.
CMAKE_CONFIG=("cmake")
# Initialize the cmake build command as an array.
CMAKE_BUILD=("cmake" "--build")

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
temp=$(getopt -o 'dhiscfCbtmr' --long \
	'toolset:,help,info,submodule,debug,required,wipe,fresh,clean,make,build,test,studio,gitlab-ci' \
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

		--toolset)
			TOOLSET="$2"
			if [[ "${TOOLSET}" =~ [^(clion|qt|studio)$] ]]; then
				WriteLog "Toolset selection '${TOOLSET}' invalid!"
				ShowHelp
				exit 1
			fi
			shift 2
			continue
			;;

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
			WriteLog "# Information on targets"
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

		-r | --required)
			InstallPackages "${SF_TARGET_OS}/$(uname -m)/Cross"
			InstallPackages "${SF_TARGET_OS}/$(uname -m)"
			exit 0
			;;

		-C | --wipe)
			WriteLog "# Wipe clean targeted build directory commenced"
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

		-m | --make)
			WriteLog "# Create build directory and makefiles only"
			FLAG_CONFIG=true
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

		-b | --build)
			WriteLog "# Build the given preset"
			FLAG_BUILD=true
			shift 1
			continue
			;;

		-t | --test)
			WriteLog "# Running tests enabled"
			FLAG_TEST=true
			shift 1
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
	exit 0
fi

# First argument is mandatory.
if [[ "${#argument[@]}" -eq 0 ]]; then
	# Assign an argument.
	preset="$(SelectBuildPreset "${file_presets}")"
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

# Check if the needed commands are installed.
COMMANDS=("dialog" "git" "recode" "jq" "cmake")
for COMMAND in "${COMMANDS[@]}"; do
	if ! command -v "${COMMAND}" >/dev/null; then
		WriteLog "Missing command '${COMMAND}' for this script"
		exit 1
	fi
done

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
			WriteLog "# Building preset '${preset}' with configuration '${cfg_preset}' in directory '${binary_dir}' ..."
			binary_dir="${binary_dir//\$env{/\${}"
			# Expand used 'sourceDir' variable using local 'SCRIPT_DIR' variable.
			eval "sourceDir=\"${SCRIPT_DIR}\" binary_dir=${binary_dir}"
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
			if [[ ! -d "${binary_dir}" ]] || ${FLAG_CONFIG}; then
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
				if ${FLAG_DEBUG}; then
					WriteLog "$(join_by " " "${CMAKE_BUILD[@]}")"
				else
					WriteLog "# $(join_by " " "${CMAKE_BUILD[@]}")"
					# shellcheck disable=SC2091
					$(join_by " " "${CMAKE_BUILD[@]}")
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
		# Check if preset exists by checking the configuration preset value.
		if [[ -z "${cfg_preset}" ]]; then
			WriteLog "Configure or Test preset '${preset}' does not exist!"
			# Show the available presets.
			ctest --list-presets
		else
			WriteLog "# Test preset '${preset}' with configuration '${cfg_preset}' in directory '${binary_dir}' ..."
			# Build the build preset.
			WriteLog "# ctest --preset ${preset}"
		fi
	done
fi

