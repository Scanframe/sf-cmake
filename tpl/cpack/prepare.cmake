##
## This file is included in the cmake project configuration.
## It prepares stuff for CPack to run its project.
## File '.sf/SfInstallInclude.cmake' is created by 'project.cmake' when CPack is called.
## When this repository is used as an external project the cmake install si normally called
## to copy them to the staging directory.
##
install(CODE [[
## Hack for allowing ZIP/ARCHIVE generator to avoid absolute file to be created.
set(SF_ROOT_PREFIX ".")
include("${CMAKE_CURRENT_LIST_DIR}/.sf/SfInstallInclude.cmake" OPTIONAL)
]]
	COMPONENT "${SF_DEFAULT_COMPONENT_NAME}"
)

# Set some variables required by this script and CPack as well.
# The provider name for using as an install prefix (directory like: /opt/<provider-name>/my-app).
set(SF_PROVIDER_NAME "Scanframe")
set(SF_PROVIDER_EMAIL "info@scanframe.nl")
# Pass the cmake binary build directory using a variable with an 'SF_' prefix which is exported.
set(SF_BINARY_DIR "${CMAKE_BINARY_DIR}")
# Pass the WIN32 flag using a variable with an 'SF_' prefix which is exported.
if (WIN32)
	set(SF_WIN32 TRUE)
else ()
	set(SF_WIN32 FALSE)
endif ()

if (WIN32)
	# Requires a Windows launcher application for WinGet portable manifest.
	find_package(SfWinLaunch 0.0.4 CONFIG REQUIRED)
	# FIXME: Somehow the you cannot specify a sub-folder since it mixes slashes.
	set(CPACK_PACKAGE_INSTALL_DIRECTORY "${SF_PROVIDER_NAME}")
	set(CPACK_PACKAGING_INSTALL_PREFIX "/${SF_PROVIDER_NAME}/${CMAKE_PROJECT_NAME}")
else ()
	set(CPACK_PACKAGE_INSTALL_DIRECTORY "${SF_PROVIDER_NAME}/${CMAKE_PROJECT_NAME}")
	set(CPACK_PACKAGING_INSTALL_PREFIX "/opt/${SF_PROVIDER_NAME}/${CMAKE_PROJECT_NAME}")
endif ()

# Assemble the basename for the packages of this project.
set(SF_PACKAGE_BASE_NAME "${CMAKE_PROJECT_NAME}")
# Add toolchain information to package name
if (CMAKE_CXX_COMPILER_ID)
	string(TOLOWER "${CMAKE_CXX_COMPILER_ID}" SF_TOOLCHAIN_ID)
	set(SF_TOOLCHAIN_STRING "${SF_TOOLCHAIN_ID}")
	if (CMAKE_CXX_COMPILER_VERSION)
		string(REGEX REPLACE "([0-9]+\\.[0-9]+).*" "\\1" SF_TOOLCHAIN_VERSION "${CMAKE_CXX_COMPILER_VERSION}")
		string(APPEND SF_TOOLCHAIN_STRING "-${SF_TOOLCHAIN_VERSION}")
	endif ()
	Sf_GetSafeArchitectureName(SF_ARCHITECTURE_SAFE "${SF_ARCHITECTURE}")
	# Set custom package filename including toolchain
	set(SF_PACKAGE_NAME "${SF_PACKAGE_BASE_NAME}-${SF_TOOLCHAIN_STRING}-${SF_ARCHITECTURE_SAFE}")
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
	get_filename_component(_filename "${CMAKE_CURRENT_LIST_FILE}" NAME)
	file(WRITE
		"${CMAKE_CURRENT_BINARY_DIR}/.sf/debian/${CMAKE_PROJECT_NAME}-libs.conf"
		"# Enable from project in file: ${_filename}\n#${CPACK_PACKAGING_INSTALL_PREFIX}/lib\n"
	)
	# Install the '.conf' file to the system directory.
	install(FILES "${CMAKE_CURRENT_BINARY_DIR}/.sf/debian/${CMAKE_PROJECT_NAME}-libs.conf"
		DESTINATION "/\${SF_ROOT_PREFIX}/etc/ld.so.conf.d"
		COMPONENT "${SF_DEFAULT_COMPONENT_NAME}"
	)
	# Create the 'postinst' script (runs ldconfig after installation).
	file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/.sf/debian/postinst" [[
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
	ldconfig
	# This could be superfluous to do.
	if command -v update-desktop-database >/dev/null 2>&1; then
		update-desktop-database /usr/share/applications
	fi
fi
exit 0
]])
	# Create the 'postrm' script (runs ldconfig after removal).
	file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/.sf/debian/postrm" [[
#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
	ldconfig
	# This could be superfluous to do.
	if command -v update-desktop-database >/dev/null 2>&1; then
		update-desktop-database /usr/share/applications
	fi
fi
exit 0
]])
	# Point CPack to the newly generated files in the build directory.
	set(CPACK_DEBIAN_PACKAGE_CONTROL_EXTRA
		"${CMAKE_CURRENT_BINARY_DIR}/.sf/debian/postinst"
		"${CMAKE_CURRENT_BINARY_DIR}/.sf/debian/postrm"
	)
endif ()

if (SF_BUILD_QT)
	# Files from these path are ignored to be copied since Qt is packaged itself.
	list(APPEND SF_DEPENDENCY_PATHS_IGNORED "${QT_DIR}/../../..")
endif ()

# Only for Linux.
if (NOT WIN32)
	list(APPEND SF_DEPENDENCY_PATHS_IGNORED "/lib/${CMAKE_LIBRARY_ARCHITECTURE}" "/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}")
endif ()

Sf_GetQtCompilerSubdirectory(SF_COMPILER_SUBDIR)

set(CPACK_PACKAGE_EXECUTABLES)
# Create a launcher for each executable.
foreach (_ExecTarget IN LISTS _ExecTargets)
	Sf_GetTargetOutputPath("${_ExecTarget}" _OutputPath)
	get_target_property(_OutputName "${_ExecTarget}" OUTPUT_NAME)
	# Skip this file without an output name.
	if (NOT _OutputName)
		message(STATUS "Skipping target: ${_ExecTarget}")
		continue()
	endif ()
	list(APPEND SF_OUTPUT_PATHS_${SF_DEFAULT_COMPONENT_NAME} "${_OutputPath}")
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
			COMPONENT "${SF_DEFAULT_COMPONENT_NAME}"
		)
	else ()
		# TODO: The shortcut name should be retrieved from a target property like 'SHORTCUT_NAME'.
		# For a windows package create a launcher link.
		if (WIN32)
			# Install the Windows launcher executable `cmd-pass.exe` as the current executable prefixed with 'launch-'.
			install(PROGRAMS "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/cmd-pass.exe"
				DESTINATION .
				RENAME "launch-${_OutputName}${_OutputSuffix}"
				COMPONENT "${SF_DEFAULT_COMPONENT_NAME}"
			)
			# Assemble the Windows launcher configuration ini-file path.
			set(_LauncherIniTpl "${CMAKE_CURRENT_SOURCE_DIR}/data/win-launch/launch-${_OutputName}${_OutputSuffix}.ini")
			set(_LauncherIni "${CMAKE_CURRENT_BINARY_DIR}/.sf/winget/launch-${_OutputName}${_OutputSuffix}.ini")
			set(SF_WINGET_SOURCE_IDENTIFIER "NexusWinGet-")
			set(SF_WINGET_GROUP "develop")
			configure_file("${_LauncherIniTpl}" "${_LauncherIni}")
			# Check if it exists.
			if (NOT EXISTS "${_LauncherIni}")
				message(SEND_ERROR "Missing launcher ini-file: ${_LauncherIni}")
			endif ()
			install(FILES "${_LauncherIni}" DESTINATION . RENAME "launch-${_OutputName}${_OutputSuffix}.ini" COMPONENT "${SF_DEFAULT_COMPONENT_NAME}")
			list(APPEND CPACK_PACKAGE_EXECUTABLES "${CPACK_PACKAGE_INSTALL_DIRECTORY}/${CMAKE_PROJECT_NAME}/launch-${_OutputName}${_OutputSuffix}" "${_OutputName}")
		else ()
			# Each entry is is a combination of 2 items in the list executable first and then the shortcut name.
			list(APPEND CPACK_PACKAGE_EXECUTABLES "${CPACK_PACKAGE_INSTALL_DIRECTORY}/${CMAKE_PROJECT_NAME}/${_OutputName}${_OutputSuffix}" "${_OutputName}")
		endif ()
	endif ()
endforeach ()

if (WIN32)
	# Get date in YYYY-MM-DD format (e.g., 2026-08-23)
	string(TIMESTAMP _current_date "%Y-%m-%d")
	# Create a partial manifest to merge with the Nexus WinGet service.
	set(SF_ZIP_MANIFEST_FILE "${CMAKE_CURRENT_BINARY_DIR}/.sf/winget/zip-manifest.yml")
	# Duplicate quotes to escape them.
	string(REPLACE "'" "''" _description "${CMAKE_PROJECT_DESCRIPTION}")
	file(WRITE "${SF_ZIP_MANIFEST_FILE}" "# yaml-language-server: $schema=https://aka.ms/winget-manifest.singleton.1.12.0.schema.json
ManifestVersion: 1.12.0
Publisher: '${SF_PROVIDER_NAME}'
Author: '${SF_PROVIDER_NAME}'
PackageName: '${SF_PACKAGE_BASE_NAME}'
License: GPL
ShortDescription: '${_description}'
Description: '${_description}'
ReleaseDate: '${_current_date}'
InstallerType: zip
NestedInstallerType: portable
Moniker: '${SF_PACKAGE_BASE_NAME}'
Tags:
  - hello
# Declared globally
ArchiveBinariesDependOnPath: false
NestedInstallerFiles:
")
	list(LENGTH CPACK_PACKAGE_EXECUTABLES _list_len)
	if (_list_len GREATER 0)
		# Subtract 2 from length to get the last valid starting index of a pair
		math(EXPR _max_index "${_list_len} - 2")
		# Loop from 0 to max_index, stepping by 2 each time
		foreach (_index RANGE 0 ${_max_index} 2)
			list(GET CPACK_PACKAGE_EXECUTABLES ${_index} _exe_file)
			# Get the next item (index + 1)
			math(EXPR _val_index "${_index} + 1")
			list(GET CPACK_PACKAGE_EXECUTABLES ${_val_index} _shortcut_name)
			string(REPLACE "'" "''" _shortcut_name "${_shortcut_name}")
			string(REPLACE "/" "\\" _exe_file "${_exe_file}")
			file(APPEND "${SF_ZIP_MANIFEST_FILE}" "  - RelativeFilePath: '${_exe_file}'
    PortableCommandAlias: '${_shortcut_name}'
")
		endforeach ()
	endif ()
	if (SF_BUILD_QT)
		# When building also Qt add the dependency to the Qt library package.
		file(APPEND "${SF_ZIP_MANIFEST_FILE}" "# Add dependent packages
Dependencies:
  PackageDependencies:
  - PackageIdentifier: '${SF_PROVIDER_NAME}.sf-qt-rt-${SF_QT_VERSION}'
    MinimumVersion: ${SF_QT_VERSION}-0
")
		# File for the QT
		set(SF_ZIP_QT_MANIFEST_FILE "${CMAKE_CURRENT_BINARY_DIR}/.sf/winget/zip-qt-manifest.yml")
		set(_rel_file "${SF_PROVIDER_NAME}/qt/${SF_QT_VERSION}/${SF_COMPILER_SUBDIR}/bin/Qt6Core.dll")
		string(REPLACE "/" "\\" _rel_file "${_rel_file}")
		file(WRITE "${SF_ZIP_QT_MANIFEST_FILE}" "# yaml-language-server: $schema=https://aka.ms/winget-manifest.singleton.1.12.0.schema.json
ManifestVersion: 1.12.0
Publisher: '${SF_PROVIDER_NAME}'
Author: '${SF_PROVIDER_NAME}'
PackageName: 'sf-qt-rt-${SF_QT_VERSION}'
License: GPL
ShortDescription: 'Qt v${SF_QT_VERSION} runtime library'
Description: 'Custom from source partial build Qt v${SF_QT_VERSION} library files'
ReleaseDate: '${_current_date}'
InstallerType: zip
NestedInstallerType: portable
Moniker: 'sf-qt-${SF_QT_VERSION}'
Tags:
  - qt
# Declared globally
ArchiveBinariesDependOnPath: false
# Is a required field and need at least one and no executable to link to it, using a DLL instead.
NestedInstallerFiles:
  - RelativeFilePath: '${_rel_file}'
    PortableCommandAlias: '___sf-qt-rt-${SF_QT_VERSION}'")
	endif ()
endif ()

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

# Check for a data application directory.
set(_ApplicationDir "${CMAKE_CURRENT_SOURCE_DIR}/data/application")
if (EXISTS "${_ApplicationDir}")
	if (WIN32)
	else ()
		# Install the desktop menu files.
		install(DIRECTORY
			"${CMAKE_CURRENT_SOURCE_DIR}/data/application/"
			DESTINATION "/\${SF_ROOT_PREFIX}/usr/share/applications"
			COMPONENT "${SF_DEFAULT_COMPONENT_NAME}"
			FILES_MATCHING
			PATTERN "*.desktop"
		)
		# Install the icon files.
		install(DIRECTORY
			"${CMAKE_CURRENT_SOURCE_DIR}/data/application/"
			DESTINATION "/\${SF_ROOT_PREFIX}/usr/share/icons/hicolor/scalable/apps"
			COMPONENT "${SF_DEFAULT_COMPONENT_NAME}"
			FILES_MATCHING
			PATTERN "*.svg"
		)
	endif ()
endif ()

# Set the cmake script cpack is going to run.
set(CPACK_PROJECT_CONFIG_FILE "${CMAKE_CURRENT_LIST_DIR}/project.cmake")

# Force 'CPACK_COMPONENTS_ALL' before 'include(CPack)' generates 'CPackConfig.cmake' otherwise 'CPACK_COMPONENTS_ALL' is empty.
if (NOT CPACK_COMPONENTS_ALL)
	get_cmake_property(CPACK_COMPONENTS_ALL COMPONENTS)
endif ()
include(CPack)

# Report the available install components.
message(STATUS "CPack All Components: ${CPACK_COMPONENTS_ALL}")
