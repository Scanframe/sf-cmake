# Required first entry checking the cmake version.
cmake_minimum_required(VERSION 3.25...4.4)

# Make it so our own packages are found and also the ones in the sub-module library.
list(APPEND CMAKE_PREFIX_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake" "${CMAKE_CURRENT_LIST_DIR}/cmake/lib")

# Package needed for Sf_GetGitTagVersion().
find_package(SfBase CONFIG REQUIRED)
# Package setting the correct tool chain according the host and SF_COMPILER.
find_package(SfToolChain CONFIG REQUIRED)

# Get the Git versions from the repository of this files directory.
Sf_GetGitTagVersion(_Versions "${CMAKE_CURRENT_LIST_DIR}")

# Report the found Git tag found version.
Sf_ReportGitTagVersion("${_Versions}")
# Split the list into separate values.
list(GET _Versions 0 SF_GIT_TAG_VERSION)
list(GET _Versions 1 SF_GIT_TAG_RC)
list(GET _Versions 2 SF_GIT_TAG_COMMITS)

# Start the top level project.
project("devops-shared"
	VERSION "${SF_GIT_TAG_VERSION}"
	DESCRIPTION "Scanframe DevOps Trial App"
	HOMEPAGE_URL "https://git.scanframe.com/shared/devops.git"
	LANGUAGES C CXX
)

# Check if the cmake is available and include it to maybe overrule CMakePresets.json cache variables.
if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/user.cmake")
	include("${CMAKE_CURRENT_LIST_DIR}/user.cmake")
endif ()

# Add top target for displaying info on the compiled target where Sf_AddExifTarget() is called on.
add_custom_target("exif" ALL)

# Prevent error when configuring for cross compile for Windows in Linux.
if (WIN32 AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
	# Make some cmake files happy so they do report "Not found".
	set(Vulkan_INCLUDE_DIR "/tmp")
endif ()

# Make sure builds do not wind up in the source directory.
find_package(SfMacros CONFIG REQUIRED)
find_package(SfBuildCheck CONFIG REQUIRED)
if (SF_BUILD_QT)
	# Install/fetch the Qt Libraries when ENV{QT_VER_DIR} is not set.
	find_package(SfQtLibrary 6.10.1 CONFIG REQUIRED)
endif ()

# Set the C++ standard to 20 for all projects which is required for the SfCompiler package.
set(CMAKE_CXX_STANDARD 17)
find_package(SfCompiler CONFIG REQUIRED)

if (SF_BUILD_TESTING)
	# Sets the version for SfCatch2 package other then the default.
	find_package(SfCatch2 3.12.0 CONFIG)
	# Prevents Catch2 from adding targets.
	set_property(GLOBAL PROPERTY CTEST_TARGETS_ADDED 1)
	# Enable the tests added with add_test.
	enable_testing()
	# Include CDash dashboard testing module and it sets the BUILD_TESTING to 'ON'.
	include(CTest)
endif ()

#[[
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH FALSE)
set(CMAKE_SKIP_INSTALL_RPATH TRUE)
set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)
set(CMAKE_BUILD_RPATH_USE_ORIGIN TRUE)
set(CMAKE_SKIP_RPATH TRUE)
]]

if (FALSE)
	# Configure the rpath to make the Linux compiled instances find
	# libraries without using the LD_LIBRARY_PATH.
	if (SF_BUILD_QT)
		# Need to have the Qt directory in the RPATH.
		Sf_GetQtVersionLibraryDirectory(_QtVerLibDir)
		if (_QtVerDir STREQUAL "")
			message(FATAL_ERROR "Qt version directory not found or set!")
		else ()
			Sf_SetRPath("\${ORIGIN}:\${ORIGIN}/lib:${_QtVerLibDir}")
		endif ()
	else ()
		Sf_SetRPath("\${ORIGIN}:\${ORIGIN}/lib")
	endif ()
endif ()

# Satisfy cmake to prevent warning.
if (CMAKE_VERBOSE_MAKEFILE)
	message(STATUS "Verbosity enabled.")
endif ()

# Clear the tests from previous by passing an empty string.
Sf_AddAsCoverageTest("")

# Add Sub Projects in the right order of dependencies.
add_subdirectory(src)
# Add Doxygen document project.
if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/doc")
	add_subdirectory(doc)
endif ()

# Set the RUNPATH for all targets and report each target's values.
sf_SetRunPath(REPORT)

# Coverage report generator in the form af a test is added.
# Only when testing is enabled and the build type is 'Coverage'.
# This must be the last test added since it relies on previous the calls
# to 'Sf_AddAsCoverageTest()'.
Sf_AddTestCoverageReport("coverage-report" "${CMAKE_CURRENT_LIST_DIR}/bin/gcov" "--html flat --json --cleanup --verbose" "src")

# Add package build config when not building coverage.
if (NOT CMAKE_BUILD_TYPE STREQUAL "Coverage")
	if (EXISTS "${SF_CPACK_PREPARE_FILE}")
		include("${SF_CPACK_PREPARE_FILE}")
	endif ()
endif ()

#[[
# Show all target's RUNPATH values.
Sf_GetAllTargets(_AllTargets "${PROJECT_SOURCE_DIR}" "TRUE")
foreach (_trg IN LISTS _AllTargets)
	get_target_property(_type "${_trg}" TYPE)
	# Only use executables and shared libraries.
	if (_type STREQUAL "EXECUTABLE" OR _type STREQUAL "SHARED_LIBRARY" OR _type STREQUAL "MODULE_LIBRARY")
		get_target_property(_prop "${_trg}" BUILD_RPATH)
		message(NOTICE "# BUILD_RPATH(${_trg}): ${_prop}")
		get_target_property(_prop "${_trg}" INSTALL_RPATH)
		message(NOTICE "# INSTALL_RPATH(${_trg}): ${_prop}")
	endif ()
endforeach ()]]
