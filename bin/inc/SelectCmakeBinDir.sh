#!/usr/bin/env bash

# Selected toolset where empty is to auto select.
TOOLSET=""
# Toolset cmake binary and directory.
declare -A TOOLSET_NAME
declare -A TOOLSET_CMAKE
declare -A TOOLSET_CTEST
# Directory location of the toolsets.
declare -A TOOLSET_DIR
# Shell command to call before make or build.
declare -A TOOLSET_PRE

# Configure cmake location.
if ${FLAG_WINDOWS}; then
	# Order of preference
	TOOLSET_ORDER="qt clion studio native"
	# Actual order of preference is reversed due the bash array.
	TOOLSET_NAME['native']="Native Cygwin compiler"
	TOOLSET_NAME['clion']="JetBrains CLion accompanied MinGW"
	TOOLSET_NAME['qt']="QT Platform accompanied MinGW"
	TOOLSET_NAME['studio']="Microsoft Visual Studio accompanied MSVC"
	# Try adding CLion cmake.
	TOOLSET_CMAKE['native']="$(which cmake)"
	TOOLSET_CTEST['native']="$(which ctest)"
	# shellcheck disable=SC2154
	TOOLSET_DIR['native']="/usr/bin"
	TOOLSET_PRE['native']=""
	# shellcheck disable=SC2154
	# shellcheck disable=SC2012
	TOOLSET_CMAKE['clion']="$(ls "$(cygpath -u "${ProgramW6432}")/JetBrains/CLion"*/bin/cmake/win/x64/bin/cmake.exe)"
	# shellcheck disable=SC2012
	TOOLSET_CTEST['clion']="$(ls "$(cygpath -u "${ProgramW6432}")/JetBrains/CLion"*/bin/cmake/win/x64/bin/ctest.exe 2>/dev/null | tail -n 1)"
	# shellcheck disable=SC2012
	TOOLSET_DIR['clion']="$(ls -d "$(cygpath -u "${ProgramW6432}")/JetBrains/CLion"*/bin/mingw/bin | tail -n 1)"
	TOOLSET_PRE['clion']=""
	# Try adding QT cmake.
	TOOLSET_CMAKE["qt"]="$(ls -d "${LOCAL_QT_ROOT}/Tools/CMake_64/bin/cmake.exe" 2>/dev/null)"
	TOOLSET_CTEST["qt"]="$(ls -d "${LOCAL_QT_ROOT}/Tools/CMake_64/bin/ctest.exe" 2>/dev/null)"
	# shellcheck disable=SC2012
	TOOLSET_DIR['qt']="$(ls -d "${LOCAL_QT_ROOT}/Tools/mingw"*"/bin" | sort --version-sort | tail -n 1)"
	TOOLSET_PRE['qt']=""
	# Try adding Visual Studio cmake.
	TOOLSET_CMAKE['studio']="$(ls -d "$(cygpath -u "${ProgramW6432}")/Microsoft Visual Studio/"*/*"/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe" 2>/dev/null)"
	TOOLSET_CTEST['studio']="$(ls -d "$(cygpath -u "${ProgramW6432}")/Microsoft Visual Studio/"*/*"/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/ctest.exe" 2>/dev/null)"
	# Toolset directory for Visual studio is set using a batch file provided by visual studio.
	# shellcheck disable=SC2012
	TOOLSET_DIR['studio']="/usr/bin"
	TOOLSET_PRE['studio']="if not defined VisualStudioVersion ( call \"$(cygpath -w "$(ls -d "$(cygpath -u "${ProgramW6432}")/Microsoft Visual Studio/"*/*"/VC/Auxiliary/Build/vcvarsall.bat")")\" x64 -vcvars_ver=14 )"
	# Show debug info on found toolsets.
	if ${FLAG_DEBUG}; then
		for key in "${!TOOLSET_NAME[@]}"; do
			WriteLog "= TOOLSET_CMAKE[${key}]=${TOOLSET_CMAKE[${key}]}"
			WriteLog "= TOOLSET_CTEST[${key}]=${TOOLSET_CTEST[${key}]}"
			WriteLog "= TOOLSET_DIR[${key}]=${TOOLSET_DIR[${key}]}"
			WriteLog "= TOOLSET_PRE[${key}]=${TOOLSET_PRE[${key}]}"
		done
	fi
	# When not set select the toolset select the first that is set according the preferred toolset order.
	if [[ -z "${TOOLSET}" ]]; then
		for key in ${TOOLSET_ORDER}; do
			# Check if this entry was found.
			if [[ -n "${TOOLSET_CMAKE[${key}]}" ]]; then
				WriteLog "- Selecting toolset: ${TOOLSET_NAME[${key}]}"
				TOOLSET="${key}"
				break
			fi
		done
	else
		# Check if the obligatory toolset is present.
		if [[ -z "${TOOLSET_CMAKE[${TOOLSET}]}" ]]; then
			# shellcheck disable=SC2154
			WriteLog "Requested toolset '${TOOLSET}' is not available!"
			exit 1
		fi
	fi
	# Convert to windows path format.
	CMAKE_BIN="$(cygpath -w "${TOOLSET_CMAKE[${TOOLSET}]}")"
	# Convert to windows path format.
	CTEST_BIN="$(cygpath -w "${TOOLSET_CTEST[${TOOLSET}]}")"
	# Convert the prefix path to Windows format.
	PATH_PREFIX="$(cygpath -w "${TOOLSET_DIR[${TOOLSET}]}")"
	# Assemble the Windows build directory.
	BUILD_DIR="$(cygpath -aw "${SCRIPT_DIR}/${BUILD_SUBDIR}")"
	# Convert the source path to Windows format.
	SOURCE_DIR="$(cygpath -aw "${SOURCE_DIR}")"
	# Visual Studio wants of course wants something else again.
	if [[ "${TOOLSET}" == "studio" ]]; then
		BUILD_GENERATOR="CodeBlocks - NMake Makefiles"
		#BUILD_GENERATOR="CodeBlocks - Ninja"
	else
		BUILD_GENERATOR="CodeBlocks - MinGW Makefiles"
	fi
	# Report used cmake and its version.
	WriteLog "- CMake '${CMAKE_BIN}' $("$(cygpath -u "${CMAKE_BIN}")" --version | head -n 1)"
	WriteLog "- CTest '${CTEST_BIN}' $("$(cygpath -u "${CTEST_BIN}")" --version | head -n 1)"
else
	# Try to use the CLion installed version of the cmake command.
	CMAKE_BIN="${HOME}/lib/clion/bin/cmake/linux/bin/cmake"
	CTEST_BIN="${HOME}/lib/clion/bin/cmake/linux/bin/ctest"
	if ! command -v "${CMAKE_BIN}" &>/dev/null; then
		# Try to use the Qt installed version of the cmake command.
		CMAKE_BIN="${LOCAL_QT_ROOT}/Tools/CMake/bin/cmake"
		CTEST_BIN="${LOCAL_QT_ROOT}/Tools/CMake/bin/ctest"
		if ! command -v "${CMAKE_BIN}" &>/dev/null; then
			CMAKE_BIN="$(which cmake)"
			CTEST_BIN="$(which ctest)"
		fi
	fi
	BUILD_DIR="${SCRIPT_DIR}/${BUILD_SUBDIR}"
	BUILD_GENERATOR="CodeBlocks - Unix Makefiles"
	WriteLog "- CMake '$(realpath "${CMAKE_BIN}")' $(${CMAKE_BIN} --version | head -n 1)"
	WriteLog "- CTest '$(realpath "${CTEST_BIN}")' $(${CTEST_BIN} --version | head -n 1)"
fi
