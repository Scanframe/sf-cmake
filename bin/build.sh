#!/usr/bin/env bash
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
	include_dir="${run_dir}/cmake/lib/bin"
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

# Prints the help to stderr.
#
function ShowHelp {
	echo "Executes CMake commands using the 'CMakePresets.json' and 'CMakeUserPresets.json' files
of which the first is mandatory to exist.

Usage: $(basename "${0}") [<options>] [<presets> ...]
  -h, --help       : Shows this help.
  -d, --debug      : Debug: Show executed commands rather then executing them.
  -i, --info       : Return information on all available build, test and package presets.
  -s, --submodule  : Return branch information on all Git submodules of last commit.
  -p, --package    : Create packages using a preset.
  --required <trg> : Install required packages using the package manager under Linux.
                     For Windows package managers apt-cyg (Cygwin) and WinGet are used.
                     Where <trg> is the targeted system to build for like 'lnx', 'win', 'arm' on Linux
                     and for Windows only 'win'.
  -m, --make       : Create build directory and makefiles only.
  -f, --fresh      : Configure a fresh build tree, removing any existing cache file.
  -C, --wipe       : Wipe clean build tree directory by removing all contents from the build directory.
  -c, --clean      : Cleans build targets first (adds build option '--clean-first')
  -b, --build      : Build target and make config when it does not exist.
  -B, --build-only : Build target only and fail when the configuration does not exist.
  -t, --test       : Runs the ctest application using a test-preset.
  -r, --regex      : Regular expression on which test names are to be executed.
  -w, --workflow   : Runs the passed work flow presets.
  -l, --list-only  : Lists the ctest test defined application by the project and selected preset.
  -n, --target     : Overrides the build targets set in the preset by a single target.
  --run -- <cmd>   : Run a command with the modified PATH for (Windows).

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
sf_target_os="$(uname -o)"

##
# Installs needed packages depending in the Windows(cygwin) or Linux environment it is called from.
#
function InstallPackages {
	WriteLog "About to install required packages for ($1)..."
	if [[ "${1}" == "GNU/Linux/lnx" ]]; then
		#if [[ "$(lsb_release -is)" == "Ubuntu" ]]; then
		# Install packages needed for installing other packages.
		sudo apt-get update
		sudo apt-get --yes upgrade
		sudo apt --yes install wget curl gpg lsb-release software-properties-common ccache
		# Some xcb related libraries for Qt6 to run.
		sudo apt --yes install xcb libxkbcommon-x11-0 libxcb-xinput0 libxcb-cursor0 libxcb-shape0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-render-util0 libpcre2-16-0
		# Check if the package repository has been added.
		if ! apt-add-repository --list | grep "llvm-toolchain" >/dev/null; then
			wget https://apt.llvm.org/llvm-snapshot.gpg.key -O - | sudo tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc >/dev/null
			sudo apt-add-repository --yes --no-update "deb http://apt.llvm.org/$(lsb_release -sc)/ llvm-toolchain-$(lsb_release -sc) main"
		fi
		# Check if the package repository has been added when this is an ubuntu distro only.
		if ! apt-add-repository --list | grep "apt.kitware.com/ubuntu" >/dev/null; then
			if [[ "$(lsb_release -is)" == 'Ubuntu' ]]; then
				wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null
				sudo apt-add-repository --yes --no-update "deb https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main"
			else
				WriteLog "# Cannot install latest 'cmake' from Kitware since this in no Ubuntu distribution."
			fi
		fi
		# Update after repositories were added.
		sudo apt-get update
		sudo apt-get --yes upgrade
		if ! sudo apt-get --yes install make cmake ninja-build gcc g++ doxygen graphviz libopengl0 libgl1-mesa-dev libxkbcommon-dev libxkbfile-dev libvulkan-dev \
			libssl-dev exiftool default-jre-headless chrpath colordiff dialog dos2unix pcregrep clang-format; then
			WriteLog "Failed to install 1 or more packages!"
			exit 1
		fi
	elif [[ "$1" == "GNU/Linux/win" ]]; then
		if ! sudo apt install mingw-w64; then
			WriteLog "Failed to install 1 or more packages!"
			exit 1
		fi
		# When Wine HQ is installed do not revert it back to the distro default version.
		if ! command -v "wine" >/dev/null; then
			if ! sudo apt-get --yes install wine; then
				WriteLog "Failed to install package wine!"
				exit 1
			fi
		fi
	elif [[ "$1" == "GNU/Linux/arm" ]]; then
		if ! sudo apt-get --yes install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu; then
			WriteLog "Failed to install 1 or more packages!"
			exit 1
		fi
		# Install arm64 architecture packages when in dpkg 'arm64' is present.
		if dpkg --print-foreign-architectures | grep --quiet '^arm64$'; then
			if ! sudo apt-get --yes install gcc-aarch64-linux-gnu:amd64 g++-aarch64-linux-gnu:amd64 binutils-aarch64-linux-gnu:amd64 \
				libgles-dev:arm64 libegl-dev:arm64 libgl-dev:arm64 libpcre2-16-0:arm64 libglvnd-dev:arm64 libpng16-16t64:arm64 \
				xcb:arm64 libxkbcommon-x11-0:arm64 libxcb-xinput0:arm64 libxcb-cursor0:arm64 libxcb-shape0:arm64 \
				libxcb-icccm4:arm64 libxcb-image0:arm64 libxcb-keysyms1:arm64 libxcb-render-util0:arm64 libdbus-1-3:arm64 \
				libcairo-gobject2:arm64 libxkbcommon-dev:arm64 libxkbfile-dev:arm64; then
				WriteLog "Failed to install 1 or more packages!"
				exit 1
			fi
		else
			WriteLog "Architecture 'arm64' is not enabled and packages are therefore not installed!"
		fi
	elif [[ "$1" == "Cygwin/win" ]]; then
		# List of WinGet packages to install.
		declare -A wg_pkgs
		wg_pkgs["CMake C++ build tool"]="Kitware.CMake"
		wg_pkgs["Ninja build system"]="Ninja-build.Ninja"
		wg_pkgs["Nullsoft Install System"]="NSIS.NSIS"
		wg_pkgs["Oracle JRE"]="Oracle.JavaRuntimeEnvironment"
		wg_pkgs["LLVM Clang-Format"]="LLVM.ClangFormat"
		#wg_pkgs["GNU Make"]="GnuWin32.Make"
		# Iterate through the associative array of subdirectories (key) and remotes (value).
		for name in "${!wg_pkgs[@]}"; do
			if winget list --disable-interactivity --accept-source-agreements --exact --id "${wg_pkgs["${name}"]}" >/dev/null; then
				WriteLog "-WinGet Package '${name}' already installed."
			else
				WriteLog "-Installing WinGet package'${name}' ..."
				winget install --disable-interactivity --accept-source-agreements --exact --id "${wg_pkgs["${name}"]}"
			fi
		done
		# List of Cygwin packages to install.
		cg_pkgs=(
			"dialog"
			"recode"
			"doxygen"
			"perl-Image-ExifTool"
			"graphviz"
			"pcre"
			"jq"
			"unzip"
			"colordiff"
			"dos2unix"
		)
		for pkg in "${cg_pkgs[@]}"; do
			if ! apt-cyg install "${pkg}"; then
				WriteLog "Failed to install 1 or more Cygwin packages (Try the Cygwin setup tool when elevation is needed) !"
				exit 1
			fi
		done
	else
		WriteLog "Invalid requirements target '$1', see help for valid ones!"
		exit 1
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
		# Expand used 'sourceDir' variable using 'run_dir' variable.
		eval "sourceDir=\"${run_dir}\" binary_dir=${binary_dir//\$env{/\${}"
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
		selection="$(dialog --backtitle "Build Selection" --menu "Select a preset to configure or build" 20 100 80 "${dlg_options[@]}" 2>&1 >/dev/tty)"
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
				# Expand used 'sourceDir' variable using 'run_dir' variable.
				eval "sourceDir=\"${run_dir}\" binary_dir=${binary_dir//\$env{/\${}"
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
		selection=$(dialog --backtitle "Package Selection" --menu "Select a preset for packaging" 20 100 80 "${dlg_options[@]}" 2>&1 >/dev/tty)
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
	local preset name desc presets preset_names dlg_options idx selection target_os
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
		# Get the custom create vendor flag 'target_os' to check if the work flow applies.
		target_os="$(jq -r ".workflowPresets[]|select(.name==\"${preset}\").vendor.target_os" "${@}")"
		# When not set allow the workflow and when set it must conform to the result of 'uname -o' command.
		if [[ "${target_os}" != 'null' && "${target_os}" != "${sf_target_os}" ]]; then
			continue
		fi
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
		selection=$(dialog --backtitle "Workflow Selection" --menu "Select a preset workflow" 20 100 80 "${dlg_options[@]}" 2>&1 >/dev/tty)
		# Return by echoing the value.
		echo "${preset_names[$selection]}"
	fi
}

# Detect windows using the cygwin 'uname' command.
if [[ "${sf_target_os}" == "Cygwin" ]]; then
	tools_dir_file="${run_dir}/.tools-dir-$(uname -n)"
	WriteLog "# Cygwin tools location file: $(basename "${tools_dir_file}")"
	# Check if the tools directory file exists.
	if [[ -f "${tools_dir_file}" ]]; then
		# Read the first line of the file and strip the newline.
		tools_dir="$(head -n 1 "${tools_dir_file}" | tr -d '\n' | tr -d '\n' | tr -d '\r')"
		if [[ -d "${tools_dir}" ]]; then
			export PATH="${tools_dir}:${PATH}"
			WriteLog "# Tools directory added to PATH: ${tools_dir}"
		else
			WriteLog "# Non-existing tools directory: ${tools_dir}"
		fi
	fi
elif [[ "${sf_target_os}" == "GNU/Linux" ]]; then
	WriteLog "# Linux $(uname -m) detected"
else
	WriteLog "Targeted OS '${sf_target_os}' not supported!"
fi

# No arguments at show help and bailout.
if [[ $# == 0 ]]; then
	ShowHelp
	exit 0
fi

# Initialize arguments and switches.
flag_run=false
flag_debug=false
flag_config=false
flag_build=false
flag_build_only=false
flag_test=false
flag_package=false
flag_workflow=false
flag_wipe=false
flag_info=false
flag_list=false
# Initialize the cmake configure command as an array.
cmake_config=("cmake")
# Create file for exploring in Chrome using URL "chrome://tracing/".
#cmake_config+=("--profiling-output=perf.json" "--profiling-format=google-trace")
# Initialize the cmake build command as an array.
cmake_build=("cmake" "--build")
# Initialize the ctest command as an array.
ctest_build=("ctest")
# Initialize the cpack command as an array.
cpackage_build=("cpack")
# When empty the target is not overridden.
target_name=""
# When empty the regex is not applied to test names.
test_regex=""

# Parse options.
temp=$(getopt -o 'n:hisdpfCcmbwBtlr:' \
	--long 'target:,help,info,submodule,required:,debug,fresh,wipe,clean,make,build,workflow,-B,build-only,test,list-only,package,list,regex:,gitlab-ci,run' \
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

		--run)
			shift 2
			flag_run=true
			break
			;;

		-i | --info)
			WriteLog "# Information on presets"
			# Set the flag to wipe the build directory first.
			flag_info=true
			shift 1
			continue
			;;

		-d | --debug)
			WriteLog "# Script debugging is enabled"
			flag_debug=true
			shift 1
			continue
			;;

		--required)
			InstallPackages "${sf_target_os}/$2"
			exit 0
			;;

		-C | --wipe)
			WriteLog "# Wipe clean build directory commenced"
			# Set the flag to wipe the build directory first.
			flag_wipe=true
			shift 1
			continue
			;;

		-f | --fresh)
			WriteLog "# Configure a fresh build tree, removing any existing cache file."
			# Set the flag to wipe the build directory first.
			cmake_config+=("--fresh")
			shift 1
			continue
			;;

		-c | --clean)
			WriteLog "# Clean first enabled"
			cmake_build+=("--clean-first")
			shift 1
			continue
			;;

		-s | --submodule)
			WriteLog "# Information on Git-submodules."
			shift 1
			# shellcheck disable=SC2016
			script='echo "$(pwd): $(git log -n 1 --oneline --decorate | pcregrep -o1 ", ([^ ]*)\) ")";GIT_COLOR_UI="always git status" git status --short'
			# shellcheck disable=SC2086
			eval "${script}"
			git -C "${run_dir}" submodule foreach --quiet "${script}"
			exit 0
			;;

		-m | --make)
			WriteLog "# Create build directory and makefile(s) only"
			flag_config=true
			shift 1
			continue
			;;

		-b | --build)
			WriteLog "# Build the given presets and make the configuration when not present."
			flag_build=true
			shift 1
			continue
			;;

		-B | --build-only)
			WriteLog "# Build the given presets only and fail when the configuration has not been made."
			flag_build=true
			flag_build_only=true
			shift 1
			continue
			;;

		-t | --test)
			WriteLog "# Run enabled tests."
			flag_test=true
			shift 1
			continue
			;;

		-w | --workflow)
			WriteLog "# Run workflow presets."
			flag_workflow=true
			shift 1
			continue
			;;

		-p | --package)
			WriteLog "# Running packaging enabled."
			flag_package=true
			shift 1
			continue
			;;

		-n | --target)
			WriteLog "# Setting different target then default."
			target_name="${2}"
			shift 2
			continue
			;;

		-l | --list-only)
			WriteLog "# Listing is enabled"
			flag_list=true
			shift 1
			continue
			;;

		-r | --regex)
			WriteLog "# Setting regex for test names."
			test_regex="${2}"
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

if ${flag_run}; then
	echo "${*}"
	"${@}"
	exit 0
fi

# Check if the needed commands are installed.
commands=("git" "jq" "cmake" "ctest" "cpack" "ninja" "doxygen")
# Add interactive commands when running interactively.
if [[ "${CI}" != "true" ]]; then
	commands+=("dialog" "pcregrep")
fi
for cmd in "${commands[@]}"; do
	if ! command -v "${cmd}" >/dev/null; then
		WriteLog "Missing command '${cmd}' for this script!"
		WriteLog "Run option with '--required' to install tool dependencies."
		exit 1
	fi
done

# Get the arguments/presets in an array.
argument=()
while [ $# -gt 0 ] && ! [[ "$1" =~ ^- ]]; do
	argument+=("$1")
	shift
done

# When in a docker container the Qt version directories are fixed in the user home '~/lib' directory.
if [[ -f /.dockerenv ]]; then
	# Only on a x86_64 machine cross compiling is possible.
	if [[ "$(uname -m)" == 'x86_64' ]]; then
		# shellcheck disable=SC2155
		export QT_WIN_VER_DIR="$("${include_dir}/QtLibDir.sh" "Windows")"
	fi
	# shellcheck disable=SC2155
	export QT_LNX_VER_DIR="$("${include_dir}/QtLibDir.sh" "Linux")"
	# shellcheck disable=SC2155
	export QT_LNX_VER_DIR_AARCH64="$("${include_dir}/QtLibDir.sh" "Linux" "aarch64")"
fi

# Form the presets file location.
file_presets=("${run_dir}/CMakePresets.json")

# Check if the presets file is present.
if [[ ! -f "${file_presets[0]}" ]]; then
	WriteLog "File '${file_presets[0]}' is missing!"
	exit 1
fi

# Add user presets to the list.
if [[ -f "${run_dir}/CMakeUserPresets.json" ]]; then
	file_presets+=("${run_dir}/CMakeUserPresets.json")
fi

# Check if information is to be shown only.
if ${flag_info}; then
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
	if ${flag_workflow}; then
		preset="$(SelectWorkflowPreset "select" "${file_presets[@]}")"
	# Assign an argument.
	elif ${flag_build} || ${flag_config}; then
		preset="$(SelectBuildPreset "select" "${file_presets[@]}")"
	elif ${flag_test}; then
		preset="$(SelectTestPreset "select" "${file_presets[@]}")"
	elif ${flag_package}; then
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
if ${flag_workflow}; then
	for preset in "${argument[@]}"; do
		cmake --workflow --preset "${preset}"
	done
	# Work flow is already a combination.
	exit 0
fi

# Check if wiping can be performed.
if [[ "${target_name}" == @(help|install) && ${flag_wipe} == true ]]; then
	flag_wipe=false
	WriteLog "Wiping clean with target '${target_name}' not possible!"
fi

# When configure and/or build is requested.
if ${flag_build} || ${flag_config}; then
	#  Make a copy of the array.
	saved_cmake_config=("${cmake_config[@]}")
	for preset in "${argument[@]}"; do
		cmake_config=("${saved_cmake_config[@]}")
		# Retrieve the configuration preset.
		cfg_preset="$(jq -r ".buildPresets[]|select(.name==\"${preset}\").configurePreset" "${file_presets[@]}")"
		# Retrieve the configuration preset.
		binary_dir="$(jq -r ".configurePresets[]|select(.name==\"${cfg_preset}\").binaryDir" "${file_presets[@]}")"
		# Check if preset exists by checking the configuration preset value.
		if [[ -z "${cfg_preset}" ]]; then
			WriteLog "Build preset '${preset}' does not exist!"
			cmake --list-presets build
		else
			# Expand used 'sourceDir' variable using local 'run_dir' variable.
			eval "sourceDir=\"${run_dir}\" binary_dir=${binary_dir//\$env{/\${}"
			# Notify the build of the preset.
			WriteLog "# Building preset '${preset}' with configuration '${cfg_preset}' in directory '${binary_dir}' ..."
			# When the '--fresh' option is has been passed delete the depending repository CMakeCache.txt files as well.
			if InArray '--fresh' "${cmake_config[@]}"; then
				while read -r cache_file; do
					WriteLog "Deleting cache file: ${cache_file}"
					rm "${cache_file}"
				done < <(find "${binary_dir}/_deps" -type f -name "CMakeCache.txt" 2>/dev/null)
			fi
			# When the binary directory exists and the Wipe flag is set.
			if ${flag_wipe} && [[ -d "${binary_dir}" ]]; then
				# Sanity check to see if to be wiped directory is a sub-directory.
				if [[ "${binary_dir}" != "${run_dir}/"* ]]; then
					WriteLog "Cannot wipe non subdirectory '${binary_dir}' !"
					exit 0
				fi
				WriteLog "# Wiping clean build-dir '${binary_dir}'"
				# When the directory exists only.
				if ${flag_debug}; then
					WriteLog "rm --verbose --recursive --one-file-system --interactive=never --preserve-root \"${binary_dir}\""
				else
					if [[ -d "${binary_dir}" ]]; then
						# Remove the build directory.
						rm --verbose --recursive --one-file-system --interactive=never --preserve-root "${binary_dir}" >/dev/null 2>&1
					fi
				fi
			fi
			# When the binary directory does not exists or configure is required.
			if [[ ! -d "${binary_dir}" ]] || ${flag_config} && ! ${flag_build_only}; then
				cmake_config+=("--preset ${cfg_preset}")
				#cmake_config+=("--trace")
				if ${flag_debug}; then
					WriteLog "$(JoinBy ' ' "${cmake_config[@]}")"
				else
					WriteLog "# $(JoinBy ' ' "${cmake_config[@]}")"
					# shellcheck disable=SC2091
					$(JoinBy " " "${cmake_config[@]}")
				fi
			fi
			# Build when flag is set.
			if ${flag_build}; then
				cmake_build+=("--preset ${cfg_preset}")
				#cmake_build+=("--parallel $(nproc)")
				# Add flag to list targets.
				if ${flag_list}; then
					cmake_build+=("--target help")
				# Otherwise just set the given target when it was set.
				else
					if [[ -n "${target_name}" ]]; then
						cmake_build+=("--target ${target_name}")
					fi
				fi
				if ! ${flag_debug}; then
					WriteLog "# $(JoinBy " " "${cmake_build[@]}")"
					# Run the build preset.
					# shellcheck disable=SC2091
					if ! eval "$(JoinBy " " "${cmake_build[@]}")"; then
						WriteLog "CMake failed!"
						exit 1
					fi
				fi
			fi
		fi
	done
fi

# When test is requested.
if ${flag_test}; then
	saved_ctest_build=("${ctest_build[@]}")
	for preset in "${argument[@]}"; do
		ctest_build=("${saved_ctest_build[@]}")
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
			# Expand used 'sourceDir' variable using local 'run_dir' variable.
			eval "sourceDir=\"${run_dir}\" binary_dir=${binary_dir//\$env{/\${}"
			WriteLog "# Testing preset '${preset}' with configuration '${cfg_preset}' in directory '${binary_dir}' ..."
			ctest_build+=(--preset "${preset}")
			ctest_build+=(--verbose)
			ctest_build+=(--progress)
			# Add flag to list tests.
			if ${flag_list}; then
				ctest_build+=(--show-only)
			fi
			# Add regular expression for test when given.
			if [[ -n "${test_regex}" ]]; then
				ctest_build+=(--tests-regex "${test_regex}")
				# Regard no tests found as no error and ignore it (exit code is 0 otherwise 8).
				#ctest_build+=("--no-tests=ignore")
			fi
			WriteLog "$(JoinBy " " "${ctest_build[@]}")"
			if ! ${flag_debug}; then
				set +e
				# Run the test preset.
				# shellcheck disable=SC2091
				"${ctest_build[@]}"
				exitcode="$?"
				case "${exitcode}" in
					0) WriteLog "CTest success." ;;
					8)
						# When the regex is empty the test failed.
						if [[ -z "${test_regex}" ]]; then exit 1; else
							WriteLog "CTest no tests matched '${test_regex}'."
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
if ${flag_package}; then
	saved_cpackage_build=("${cpackage_build[@]}")
	for preset in "${argument[@]}"; do
		cpackage_build=("${saved_cpackage_build[@]}")
		# Retrieve the configuration preset.
		cfg_preset="$(jq -r ".packagePresets[]|select(.name==\"${preset}\").configurePreset" "${file_presets[@]}")"
		# Retrieve the configuration preset.
		package_dir="$(jq -r ".packagePresets[]|select(.name==\"${cfg_preset}\").packageDirectory" "${file_presets[@]}")"
		# Expand used 'sourceDir' variable using local 'run_dir' variable.
		eval "sourceDir=\"${run_dir}\" package_dir=${package_dir//\$env{/\${}"
		# Check if preset exists by checking the configuration preset value.
		if [[ -z "${cfg_preset}" ]]; then
			WriteLog "Configure or Package preset '${preset}' does not exist!"
			# Show the available presets.
			cmake --list-presets configure
		else
			cpackage_build+=(--preset "${preset}")
			cpackage_build+=(--verbose)
			WriteLog "$(JoinBy " " "${cpackage_build[@]}")"
			if ! ${flag_debug}; then
				set +e
				# Run the package preset.
				# shellcheck disable=SC2091
				"${cpackage_build[@]}"
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
