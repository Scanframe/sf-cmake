##
## This file is included in the cmake project configuration.
## It prepares stuff for CPack to run its project.
##

install(CODE [[
## Hack for allowing ZIP/ARCHIVE generator to avoid absolute file to be created.
set(SF_ROOT_PREFIX ".")
include("${CMAKE_CURRENT_LIST_DIR}/.sf/SfInstallInclude.cmake")
]]
	COMPONENT "runtime")

# Set some variables required by this script and CPack as well.
# The provider name for using as an install prefix (directory like: /opt/<provider-name>/my-app).
set(SF_PROVIDER_NAME "Scanframe")
set(SF_PROVIDER_EMAIL "info@scanframe.nl")

if (WIN32)
	# FIXME: Somehow the you cannot specify a sub-folder since it mixes slashes.
	set(CPACK_PACKAGE_INSTALL_DIRECTORY "${SF_PROVIDER_NAME}")
	set(CPACK_PACKAGING_INSTALL_PREFIX "/${SF_PROVIDER_NAME}/${CMAKE_PROJECT_NAME}")
else ()
	set(CPACK_PACKAGE_INSTALL_DIRECTORY "${SF_PROVIDER_NAME}/${CMAKE_PROJECT_NAME}")
	set(CPACK_PACKAGING_INSTALL_PREFIX "/opt/${SF_PROVIDER_NAME}/${CMAKE_PROJECT_NAME}")
endif ()

# Assemble the basename for the packages of this project.
if (WIN32)
	set(SF_PACKAGE_BASE_NAME "${CMAKE_PROJECT_NAME}-win")
else ()
	set(SF_PACKAGE_BASE_NAME "${CMAKE_PROJECT_NAME}-lnx")
endif ()
# Add toolchain information to package name
if (CMAKE_CXX_COMPILER_ID)
	string(TOLOWER "${CMAKE_CXX_COMPILER_ID}" SF_TOOLCHAIN_ID)
	if (CMAKE_CXX_COMPILER_VERSION)
		string(REGEX REPLACE "([0-9]+\\.[0-9]+).*" "\\1" SF_TOOLCHAIN_VERSION "${CMAKE_CXX_COMPILER_VERSION}")
		set(SF_TOOLCHAIN_STRING "${SF_TOOLCHAIN_ID}-${SF_TOOLCHAIN_VERSION}")
	else ()
		set(SF_TOOLCHAIN_STRING "${SF_TOOLCHAIN_ID}")
	endif ()
	Sf_GetSafeArchitectureName(SF_ARCHITECTURE_SAFE "${SF_ARCHITECTURE}")
	# Set custom package filename including toolchain
	set(SF_PACKAGE_NAME "${SF_PACKAGE_BASE_NAME}-${SF_ARCHITECTURE_SAFE}-${SF_TOOLCHAIN_STRING}")
endif ()
##
## Make some variables available for the CPack environment.
##
# Call install for all non-test targets and return the executables.
Sf_TargetsInstall(_ExecTargets)
# When building with QT is enabled allow packaging the runtime.
if (SF_BUILD_QT)
	# Make the QT library version to be present when cpack is running.
	set(SF_QT_VERSION "${SfQtLibrary_VERSION}")
	# Call install for all files in the Qt library. Pass TRUE for separate development package.
	Sf_QtLibraryInstall(FALSE)
endif ()
# Define the path for the include file in the binary build directory.
set(CPACK_SF_INCLUDE_VARS_FILE "${CMAKE_CURRENT_BINARY_DIR}/.sf/SfCPackProjectVars.cmake")
# Pass the top level project git tag version string to CPack.
Sf_GetGitTagVersion(SF_GIT_TAG_VERSIONS "${CMAKE_CURRENT_SOURCE_DIR}")

# Only for Linux targeted OSes.
if (NOT WIN32)
	# Create the ld.so configuration file content.
	file(WRITE
		"${CMAKE_CURRENT_BINARY_DIR}/.sf/debian/${CMAKE_PROJECT_NAME}-libs.conf"
		"${CPACK_PACKAGING_INSTALL_PREFIX}/lib\n"
	)
	# Install the '.conf' file to the system directory.
	install(FILES "${CMAKE_CURRENT_BINARY_DIR}/.sf/debian/${CMAKE_PROJECT_NAME}-libs.conf"
		DESTINATION "/\${SF_ROOT_PREFIX}/etc/ld.so.conf.d"
		# The double underscore is a generator separator.
		COMPONENT "runtime" #--DEB
	)
	# Create the 'postinst' script (runs ldconfig after installation).
	file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/.sf/debian/postinst" [[
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
	ldconfig
fi
exit 0
]])
	# Create the 'postrm' script (runs ldconfig after removal).
	file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/.sf/debian/postrm" [[
#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
	ldconfig
fi
exit 0
]])
	# Point CPack to the newly generated files in the build directory.
	set(CPACK_DEBIAN_PACKAGE_CONTROL_EXTRA
		"${CMAKE_CURRENT_BINARY_DIR}/.sf/debian/postinst"
		"${CMAKE_CURRENT_BINARY_DIR}/.sf/debian/postrm"
	)
endif ()

# Share all output path to look dependencies in the CPack script.
set(SF_OUTPUT_PATHS)
# Files from these path are ignored to be copied since Qt is packaged itself.
set(SF_DEPENDENCY_PATHS_IGNORED "${QT_DIR}/../../..")
# Pass also the cmake binary build directory using en variable with an 'SF_' prefix.
set(SF_BINARY_DIR "${CMAKE_BINARY_DIR}")

# Create a launcher for each executable.
foreach (_ExecTarget IN LISTS _ExecTargets)
	Sf_GetTargetOutputPath("${_ExecTarget}" _OutputPath)
	list(APPEND SF_OUTPUT_PATHS "${_OutputPath}")
	get_target_property(_OutputName "${_ExecTarget}" OUTPUT_NAME)
	if (NOT _OutputName)
		continue()
	endif ()
	get_target_property(_OutputSuffix "${_ExecTarget}" SUFFIX)
	# Only for Linux targeted OSes.
	if (NOT WIN32)
		# Create a launcher script in the build directory.
		file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/.sf/debian/${_OutputName}" "#!/bin/sh

exec '${CPACK_PACKAGING_INSTALL_PREFIX}/${_OutputName}${_OutputSuffix}' \"$@\"
")
		# Install it directly to '/usr/bin'.
		install(PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/.sf/debian/${_OutputName}"
			DESTINATION "/\${SF_ROOT_PREFIX}/usr/bin"
			COMPONENT "runtime"
		)
	else ()
		# TODO: The shortcut name should be retrieved from a target property like 'SHORTCUT_NAME'.
		# Each entry is is a combination of 2 items in the list executable first and then the shortcut name.
		set(CPACK_PACKAGE_EXECUTABLES "${CPACK_PACKAGE_INSTALL_DIRECTORY}\\\\${_OutputName}" "${_OutputName}")
	endif ()
endforeach ()

# Clear out any existing file from a previous configuration run with a header.
file(WRITE "${CPACK_SF_INCLUDE_VARS_FILE}" "# Generated by CMake. Do not edit.\n")
# Retrieve all variables defined in the current CMake context
get_cmake_property(_variable_names VARIABLES)
# Somehow there are names double in the list.
list(REMOVE_DUPLICATES _variable_names)
# Loop through and write any CMAKE_PROJECT_ and SF_ prefixed variables directly to the file.
foreach (_var IN LISTS _variable_names)
	if (_var MATCHES "^(SF_|CMAKE_PROJECT_)")
		# Properly escape backslashes and quotes to handle paths and strings safely
		string(REPLACE "\\" "\\\\" _escaped_val "${${_var}}")
		string(REPLACE "\"" "\\\"" _escaped_val "${_escaped_val}")
		# Append the explicit set() command into the file
		file(APPEND "${CPACK_SF_INCLUDE_VARS_FILE}" "set(${_var} \"${_escaped_val}\")\n")
	endif ()
endforeach ()

# Set the cmake script cpack is going to run.
set(CPACK_PROJECT_CONFIG_FILE "${CMAKE_CURRENT_LIST_DIR}/project.cmake")
include(CPack)
# Report the available install components.
message(STATUS "CPack All Components: ${CPACK_COMPONENTS_ALL}")
