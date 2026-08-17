# Required first entry checking the cmake version.
cmake_minimum_required(VERSION 3.25...4.4)

# Include the CPackComponent module.
include(CPackComponent)

# Check if the include file for variables is set.
if (DEFINED CPACK_SF_INCLUDE_VARS_FILE)
	message(STATUS "Including: ${CPACK_SF_INCLUDE_VARS_FILE}")
	include("${CPACK_SF_INCLUDE_VARS_FILE}")
endif ()

# Make it so our own packages are found and also the ones in the sub-module library.
list(APPEND CMAKE_PREFIX_PATH "${CMAKE_CURRENT_LIST_DIR}/../..")

# Package needed for Sf_GetGitTagVersion().
find_package(SfBase CONFIG REQUIRED)
find_package(SfQtLibraryCommon CONFIG REQUIRED)

# Report the found Git tag found version.
Sf_ReportGitTagVersion("${SF_GIT_TAG_VERSIONS}")
# Split the list into separate values.
list(GET SF_GIT_TAG_VERSIONS 0 SF_GIT_TAG_VERSION)
list(GET SF_GIT_TAG_VERSIONS 1 SF_GIT_TAG_RC)
list(GET SF_GIT_TAG_VERSIONS 2 SF_GIT_TAG_COMMITS)

# If set to TRUE, values of variables prefixed with CPACK_ will be escaped before being written to
# the configuration files, so that the cpack program receives them exactly as they were specified
set(CPACK_VERBATIM_VARIABLES TRUE)

# Get the compiler or toolchain subdirectory.
Sf_GetQtCompilerSubdirectory(_CompilerSubDir)
string(REPLACE "_" "" _Toolchain "${_CompilerSubDir}")
# Get the compiler architecture subdirectory from the current environment.
Sf_GetQtArchitectureSubdirectory(_QtArchDir)

# Do not include the directory named the same as the ZIP file. (ARCHIVE generator only)
set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY OFF)
# Enable the component-based installation mechanism.
set(CPACK_MONOLITHIC_INSTALL OFF)
# Needed for the archive generator.
#set(CPACK_SET_DESTDIR ON)

# Initialize the package release variable for Debian it is limited to regex "^[A-Za-z0-9.+~]+$"
set(SF_PACKAGE_RELEASE "0")
# Check for a release candidate of the Git tag and if so append the RC reference.
if (NOT SF_GIT_TAG_RC STREQUAL "")
	set(SF_PACKAGE_RELEASE "rc${SF_GIT_TAG_RC}")
endif ()
# Check for an offset in commits from the tag then append the number the release name.
if (NOT SF_GIT_TAG_COMMITS STREQUAL "")
	set(SF_PACKAGE_RELEASE "${SF_PACKAGE_RELEASE}+${SF_GIT_TAG_COMMITS}")
endif ()

# Set the package name for all generator types when not overridden.
set(CPACK_PACKAGE_NAME "${CPACK_PACKAGE_NAME}-${SF_TOOLCHAIN_STRING}")
# Set the package version for all generator types when not overridden.
set(CPACK_PACKAGE_VERSION "${CMAKE_PROJECT_VERSION}~${SF_PACKAGE_RELEASE}")
# Add the package revision to the package version.
if (SF_PACKAGE_REVISION)
	set(CPACK_PACKAGE_VERSION "${CPACK_PACKAGE_VERSION}.${SF_PACKAGE_REVISION}")
endif ()

##
## To check the format of a version is correct use dpkg:
##   dpkg --compare-versions "0.1.0.rc2" le "0.1.0.rc2+4" && echo ignore || echo upgrade
##

#[[
# When called from a CI-pipeline append its IID and when not the timestamp.
if (DEFINED ENV{CI_PIPELINE_IID})
	set(SF_PACKAGE_RELEASE "${SF_PACKAGE_RELEASE}~$ENV{CI_PIPELINE_IID}")
else ()
	string(TIMESTAMP NOW "%Y%m%d%H%M%S")
	set(SF_PACKAGE_RELEASE "${SF_PACKAGE_RELEASE}~${NOW}")
endif ()
]]

# Don't make the 'install' target depend on the 'all' target.
set(CMAKE_SKIP_INSTALL_ALL_DEPENDENCY TRUE)
# Number of threads to use when performing parallelized operations, such as compressing the installer package.
# When zero all available CPU's are used.
set(CPACK_THREADS 0)

# Set the supported archive generators.
if (WIN32)
	set(SF_SUPPORTED_ARCHIVE_GENERATORS "ZIP")
else ()
	set(SF_SUPPORTED_ARCHIVE_GENERATORS "ZIP" "TGZ")
endif ()

# Supported archive types.

# Include specific settings for each generator.
if (CPACK_GENERATOR STREQUAL "DEB")
	include("${CMAKE_CURRENT_LIST_DIR}/config-debian.cmake")
elseif (CPACK_GENERATOR STREQUAL "RPM")
	include("${CMAKE_CURRENT_LIST_DIR}/config-rpm.cmake")
elseif (CPACK_GENERATOR STREQUAL "NSIS" OR CPACK_GENERATOR STREQUAL "NSIS64")
	include("${CMAKE_CURRENT_LIST_DIR}/config-nsis.cmake")
elseif (CPACK_GENERATOR IN_LIST SF_SUPPORTED_ARCHIVE_GENERATORS)
	include("${CMAKE_CURRENT_LIST_DIR}/config-archive.cmake")
else ()
	message(FATAL_ERROR "Unsupported CPack '${CPACK_GENERATOR}' generator!")
endif ()

# Package the Qt library instead of the Application when the flag is set.
if (NOT DEFINED SF_PACKAGE_QT OR SF_PACKAGE_QT STREQUAL "")
	set(SF_PACKAGE_QT FALSE)
	message(NOTICE "SF_PACKAGE_QT: Not passed, creating application package.")
else ()
	# Version Configuration using optional tweak.
	math(EXPR QT_TWEAK_VERSION "${SF_PACKAGE_QT}" OUTPUT_FORMAT DECIMAL)
	# override previous application version for this time.
	set(CPACK_PACKAGE_VERSION "${SF_QT_VERSION}-${QT_TWEAK_VERSION}")
	# Make flag boolean.
	set(SF_PACKAGE_QT TRUE)
endif ()

# Check if the package revision was given.
if (DEFINED SF_PACKAGE_REVISION)
	# Number is required.
	math(EXPR SF_PACKAGE_REVISION "${SF_PACKAGE_REVISION}" OUTPUT_FORMAT DECIMAL)
	message(NOTICE "SF_PACKAGE_REVISION: ${SF_PACKAGE_REVISION}")
else ()
	message(NOTICE "SF_PACKAGE_REVISION: Not set, creating base package.")
endif ()

# This the also the default for variable CPACK_DEBIAN_PACKAGE_MAINTAINER.
set(CPACK_PACKAGE_CONTACT "${SF_PROVIDER_NAME} <${SF_PROVIDER_EMAIL}>")

# Report all components at the start.
message(STATUS "Components Initially (${CPACK_GENERATOR}): ${CPACK_COMPONENTS_ALL}")
# Will hold the allowed components.
set(_Components)
# Remove components not fit for the current generator or QT group related.
foreach (_Component IN LISTS CPACK_COMPONENTS_ALL)
	# Exclude default components as well since this excludes all fetched module installs as well.
	if (_Component STREQUAL "${CMAKE_INSTALL_DEFAULT_COMPONENT_NAME}")
		message(NOTICE "Removing the default component '${CMAKE_INSTALL_DEFAULT_COMPONENT_NAME}'.")
		continue()
	endif ()
	# When there are generator entries left in the list and the current generator is not part of it.
	if ((SF_PACKAGE_QT AND NOT _Component MATCHES "^${SF_QT_COMPONENT_PREFIX}.*")
		OR (NOT SF_PACKAGE_QT AND _Component MATCHES "^${SF_QT_COMPONENT_PREFIX}.*"))
		continue()
	else ()
		list(APPEND _Components "${_Component}")
	endif ()
endforeach ()
# Set the new components list.
set(CPACK_COMPONENTS_ALL "${_Components}")

# When packaging QT
if (SF_PACKAGE_QT)
	if (NOT CPACK_COMPONENTS_ALL)
		message(FATAL_ERROR "Missing Qt Library Components (prefix '${SF_QT_COMPONENT_PREFIX}') are not available!")
	else ()
		message(STATUS "Packaging Qt Library Components: ${CPACK_COMPONENTS_ALL}")
	endif ()
	include("${CMAKE_CURRENT_LIST_DIR}/pkg-qt-lib.cmake")
else ()
	set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${CMAKE_PROJECT_DESCRIPTION}")
	set(CPACK_PACKAGE_DESCRIPTION "The long description of this DevOps template application having more then one line.")
	include("${CMAKE_CURRENT_LIST_DIR}/pkg-app.cmake")
endif ()

# The include here creates the all variable which have not been set yet to the defaults.
# So CPACK_PACKAGE_FILE_NAME is set "${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-${CPACK_SYSTEM_NAME}"
# The variable CPACK_ARCHIVE_FILE_NAME is bugged in 3.27.8 and not set or used by 'CPack' include file here.
# Resolve CPack's built-in resources from the active CMake installation. This is
# important when a build directory was configured with another CMake version.
set(CPACK_PACKAGE_DESCRIPTION_FILE "${CMAKE_ROOT}/Templates/CPack.GenericDescription.txt")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_ROOT}/Templates/CPack.GenericLicense.txt")
set(CPACK_RESOURCE_FILE_README "${CMAKE_ROOT}/Templates/CPack.GenericDescription.txt")
set(CPACK_RESOURCE_FILE_WELCOME "${CMAKE_ROOT}/Templates/CPack.GenericWelcome.txt")

function(ShowAllVars)
	# Retrieve all variables defined in the current CMake context
	get_cmake_property(_variable_names VARIABLES)
	# Somehow there are names double in the list.
	list(REMOVE_DUPLICATES _variable_names)
	# Loop through and write any CMAKE_PROJECT_* variable directly to the file
	foreach (_var IN LISTS _variable_names)
		# Properly escape backslashes and quotes to handle paths and strings safely
		message("${_var}: ${${_var}}")
	endforeach ()
endfunction()

function(ShowAllEnvVars)
	# Run the built-in cross-platform CMake command to output the current environment
	execute_process(
		COMMAND "${CMAKE_COMMAND}" "-E" "environment"
		OUTPUT_VARIABLE env_output
		OUTPUT_STRIP_TRAILING_WHITESPACE
	)
	# Replace newlines with semicolons to convert the output string into a CMake list
	string(REPLACE "\n" ";" env_list "${env_output}")
	# Sort the list alphabetically for better scannability
	list(SORT env_list)
	# Iterate and print each variable name and value
	foreach (env_entry IN LISTS env_list)
		message(STATUS "  ${env_entry}")
	endforeach ()
endfunction()

set(_IncFile "${SF_BINARY_DIR}/.sf/SfInstallInclude.cmake")
#set(_RootLocation "${CPACK_PACKAGE_DIRECTORY}/_CPack_Packages/${CMAKE_HOST_SYSTEM_NAME}/${CPACK_GENERATOR}/${CPACK_PACKAGE_FILE_NAME}/${SF_DEFAULT_COMPONENT_NAME}")
set(_RootLocation "${CPACK_PACKAGE_DIRECTORY}/tmp")

if (CPACK_GENERATOR IN_LIST SF_SUPPORTED_ARCHIVE_GENERATORS)
	file(WRITE "${_IncFile}" "  set(SF_ROOT_PREFIX \"${_RootLocation}\")
  message(STATUS \"SF_ROOT_PREFIX: \${SF_ROOT_PREFIX}\")\n")
else ()
	file(WRITE "${_IncFile}" [[
message(STATUS "SF_ROOT_PREFIX: ${SF_ROOT_PREFIX}\n")
]])
endif ()
file(APPEND "${_IncFile}" [[

macro(ShowAllVars)
	# Retrieve all variables defined in the current CMake context
	get_cmake_property(_variable_names VARIABLES)
	# Somehow there are names double in the list.
	list(REMOVE_DUPLICATES _variable_names)
	# Loop through and write any CMAKE_PROJECT_* variable directly to the file
	foreach (_var IN LISTS _variable_names)
		# Properly escape backslashes and quotes to handle paths and strings safely
		message(NOTICE "${_var}: ${${_var}}")
	endforeach ()
endmacro()
#ShowAllVars()
]])

#ShowAllVars()
#ShowAllEnvVars()

message(NOTICE "SF_OUTPUT_PATHS_${SF_DEFAULT_COMPONENT_NAME}: ${SF_OUTPUT_PATHS_${SF_DEFAULT_COMPONENT_NAME}}")
message(NOTICE "SF_DEPENDENCY_PATHS_IGNORED: ${SF_DEPENDENCY_PATHS_IGNORED}")

# Pre-resolve ignored paths once outside the loops
set(_ignored_paths_resolved)
foreach (_ignore IN LISTS SF_DEPENDENCY_PATHS_IGNORED)
	get_filename_component(_ignore_real "${_ignore}" REALPATH)
	list(APPEND _ignored_paths_resolved "${_ignore_real}")
endforeach ()

foreach (_bin_file IN LISTS SF_OUTPUT_PATHS_${SF_DEFAULT_COMPONENT_NAME})
	# Get the binary file's dependencies passing the paths to be ignored (no-quotes on list!).
	Sf_GetDependencies(_bin_dependencies "${_bin_file}" IGNORE_PATHS ${SF_DEPENDENCY_PATHS_IGNORED})
	foreach (_bin_dep IN LISTS _bin_dependencies)
		file(APPEND "${_IncFile}" "\n  file(INSTALL DESTINATION \"\${CMAKE_INSTALL_PREFIX}\" TYPE EXECUTABLE FILES \"${_bin_dep}\")")
	endforeach ()
	break()
	# Get the destination for the dependencies.
	get_filename_component(_deps_dest "${_bin_file}" DIRECTORY)
endforeach ()
