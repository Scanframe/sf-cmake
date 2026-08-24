# Required first entry checking the cmake version.
cmake_minimum_required(VERSION 3.29...4.4)
# Include the file to have the variable `FETCHCONTENT_BASE_DIR` set so it can be used.
include(FetchContent)
# Import for the ExternalProject_Add() function.
include(ExternalProject)
# Get the URL to download from .
Sf_GetGitHubVersionFileUrl(_FileUrl "Scanframe" "win-launch" "${SfWinLaunch_VERSION}")
# Create a target from the external project.
ExternalProject_Add(
	"win-launch"
	# Slow and large foot print using cloning of GitHub repository.
	#GIT_REPOSITORY "https://github.com/Scanframe/win-launch.git" GIT_TAG "${SfWinLaunch_VERSION}" GIT_SHALLOW 1
	# This is a much faster option to get the source then using Git cloning.
	URL "${_FileUrl}"
	# Put the project also in the same directory as 'FetchContent_MakeAvailable()' uses.
	PREFIX "${FETCHCONTENT_BASE_DIR}/win-launch-${SfWinLaunch_VERSION}"
	#INSTALL_DIR "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}"
	CMAKE_ARGS
	#
	-DSF_COMPILER=${SF_COMPILER}
	# Use the same toolchain file.
	-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
	# Same build type as well.
	-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
	# Executable is in the same directory as the others from this project. (optional)
	# -DCMAKE_RUNTIME_OUTPUT_DIRECTORY=${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
	# Determine executable name. (optional)
	#-DLAUNCHER_TARGET_NAME=my-launcher
	# Sets a different resource icon file. (optional)
	#-DAPP_ICON_PATH=my-path/my.ico
	# Sets a different version the the git version for in the meta data in the resource. (optional)
	#-DAPP_VERSION_STR=1.0.0
	# Rebuild if the launcher source changes. (optional)
	#BUILD_ALWAYS 1
	# During the main project build the
	-DCMAKE_INSTALL_PREFIX:PATH=${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
	# Only build the target to build the 'cmd-pass.exe' binary.
	BUILD_COMMAND "${CMAKE_COMMAND}" --build . --target cmd-pass
	# Disable default installation to prevent building everything else.
	#INSTALL_COMMAND ""
)




# Force Ninja to re-run the external configure step on every invocation
ExternalProject_Add_Step("win-launch" reconfigure
	COMMAND ${CMAKE_COMMAND} -E echo "Bypassing Ninja cache for external project..."
	DEPENDERS configure
	ALWAYS 1
)
