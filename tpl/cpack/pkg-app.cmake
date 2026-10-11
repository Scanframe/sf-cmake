# Lowercase of the provider name for naming the package.
string(TOLOWER "${SF_PROVIDER_NAME}" _ProviderName)

# Get the number of the components.
list(LENGTH CPACK_COMPONENTS_ALL _ComponentCount)

# TODO: RPM package is not tested.
if (CPACK_GENERATOR STREQUAL "RPM")
	# Set the RPM variables for each component.
	foreach (_Component IN LISTS CPACK_COMPONENTS_ALL)
		string(TOUPPER "${_Component}" _ComponentUpper)
		set(_ComponentOutputPathsVariable "SF_OUTPUT_PATHS_${_Component}")
		set(_ComponentOutputPaths "${${_ComponentOutputPathsVariable}}")
		if (_ComponentCount EQUAL 1)
			set("CPACK_RPM_${_ComponentUpper}_PACKAGE_NAME" "${CPACK_PACKAGE_NAME}")
		else ()
			set("CPACK_RPM_${_ComponentUpper}_PACKAGE_NAME" "${CPACK_PACKAGE_NAME}-${_Component}")
		endif ()
		set("CPACK_RPM_${_ComponentUpper}_PACKAGE_GROUP" "Applications/System")
		set("CPACK_RPM_${_ComponentUpper}_PACKAGE_RELEASE" "${SF_PACKAGE_RELEASE}")
		set("CPACK_RPM_${_ComponentUpper}_PACKAGE_SUMMARY" "Executables and shared libraries for the application.")
		if (SF_BUILD_QT AND _ComponentOutputPaths)
			set("CPACK_RPM_${_ComponentUpper}_PACKAGE_REQUIRES"
				"${SF_QT_PACKAGE_FILENAME_PREFIX}rt-${SF_TOOLCHAIN_STRING} = ${SF_QT_VERSION}")
		endif ()
		message(STATUS "RPM (${_Component}) Package name: ${CPACK_RPM_${_ComponentUpper}_PACKAGE_NAME}")
	endforeach ()
endif ()

if (CPACK_GENERATOR STREQUAL "DEB")
	# Set the Debian variables for each component.
	foreach (_Component IN LISTS CPACK_COMPONENTS_ALL)
		string(TOUPPER "${_Component}" _ComponentUpper)
		if (_ComponentCount EQUAL 1)
			set("CPACK_DEBIAN_${_ComponentUpper}_PACKAGE_NAME" "${CPACK_PACKAGE_NAME}")
		else ()
			set("CPACK_DEBIAN_${_ComponentUpper}_PACKAGE_NAME" "${CPACK_PACKAGE_NAME}-${_Component}")
		endif ()
		set("CPACK_DEBIAN_${_ComponentUpper}_PACKAGE_SECTION" "misc")
		set("CPACK_DEBIAN_${_ComponentUpper}_DESCRIPTION" "Executables and shared libraries for the application.")
		message(STATUS "Debian (${_Component}) Package name: ${CPACK_DEBIAN_${_ComponentUpper}_PACKAGE_NAME}")
		set(_ComponentOutputPathsVariable "SF_OUTPUT_PATHS_${_Component}")
		set(_ComponentOutputPaths "${${_ComponentOutputPathsVariable}}")
		# Create an empty list variable for package dependencies.
		set(_Dependencies)
		# Initialize the flag for Qt dependency.
		set(_HasQtDependency FALSE)
		# Create dummy debian/control file to allow dpkg-shlibdeps to run at all.
		file(WRITE "${SF_BINARY_DIR}/.sf/debian/control" "Source: dummy\nPackage: dummy\n")
		# Process each output file.
		foreach (_path IN LISTS _ComponentOutputPaths)
			# Run dpkg-shlibdeps
			execute_process(
				COMMAND dpkg-shlibdeps --ignore-missing-info -O "${_path}"
				WORKING_DIRECTORY "${SF_BINARY_DIR}/.sf"
				OUTPUT_VARIABLE _ShLibs
				ERROR_VARIABLE _IgnoreThis
				COMMAND_ERROR_IS_FATAL ANY
			)
			get_filename_component(_filename "${_path}" NAME)
			# Extract dependency string.
			string(REGEX MATCH "shlibs:Depends=(.*)" _ "${_ShLibs}")
			set(_ShLibs "${CMAKE_MATCH_1}")
			# Remove trailing newline.
			string(REGEX REPLACE "\n" "" _ShLibs "${_ShLibs}")
			# Report the findings of the file processed.
			message(STATUS "Dependencies(${_filename}): ${_ShLibs}")
			# Convert comma-separated string to a CMake list.
			string(REPLACE ", " ";" _DebList "${_ShLibs}")
			# Check if Qt is linked.
			string(REGEX MATCH "(^|;)libqt[^;]*(;|$)" _QtDependency "${_DebList}")
			if (_QtDependency)
				set(_HasQtDependency TRUE)
			endif ()
			# Remove QT related items.
			list(FILTER _DebList EXCLUDE REGEX "^libqt")
			# Add these items to the total list.
			list(APPEND _Dependencies "${_DebList}")
			# Secondary check on Qt library linkage.
			Sf_GetDependencyFilenames(_Names "${_path}")
			string(REGEX MATCH "(^|;)lib[qQ]t[^;]*(;|$)" _QtDependency "${_Names}")
			if (_QtDependency)
				set(_HasQtDependency TRUE)
			endif ()
		endforeach ()
		# When the component uses the Qt runtime add the custom package dependency.
		if (_HasQtDependency)
			set(_QtPackage "${SF_QT_PACKAGE_FILENAME_PREFIX}rt-${SF_TOOLCHAIN_STRING}")
			# To create a range the next patch version is calculated.
			Sf_IncrementPatchVersion("${SF_QT_VERSION}" _QtPatchVerNext)
			# This prevent updating a dependent Qt package like v6.10.1 to v6.10.3.
			list(APPEND _Dependencies "${_QtPackage} (>= ${SF_QT_VERSION})" "${_QtPackage} (<< ${_QtPatchVerNext})")
			# Check if this is the main/default component.
			if (_Component STREQUAL "${SF_DEFAULT_COMPONENT_NAME}")
				# Add the dependency to desktop files utilities without a version constraint.
				list(APPEND _Dependencies "desktop-file-utils")
			endif ()
		endif ()
		# Remove any duplicates.
		list(REMOVE_DUPLICATES _Dependencies)
		# Convert back to a comma-separated string.
		string(JOIN ", " _Dependencies ${_Dependencies})
		# Output results.
		message(STATUS "Resulting Dependencies: ${_Dependencies}")
		# The application uses the separately packaged Qt runtime when Qt support is enabled.
		set("CPACK_DEBIAN_${_ComponentUpper}_PACKAGE_DEPENDS" "${_Dependencies}")
	endforeach ()
endif ()

if (CPACK_GENERATOR IN_LIST SF_SUPPORTED_ARCHIVE_GENERATORS)
	# Only change the component filename when there is only one.
	string(TOUPPER "${_Component}" _ComponentUpper)
	# Set the Debian variables for each component.
	foreach (_Component IN LISTS CPACK_COMPONENTS_ALL)
		string(TOUPPER "${_Component}" _ComponentUpper)
		set(_filename "${SF_PACKAGE_BASE_NAME}-${_Component}")
		# An archive file is not specific for an OS, so the toolchain is prefixed.
		if (WIN32)
			list(APPEND _filename "win+${SF_TOOLCHAIN_STRING}")
		else ()
			list(APPEND _filename "lnx+${SF_TOOLCHAIN_STRING}")
		endif ()
		list(APPEND _filename "${SF_GIT_TAG_VERSION}")
		if (SF_PACKAGE_RELEASE)
			string(APPEND _filename "-${SF_PACKAGE_RELEASE}")
		endif ()
		if (DEFINED SF_PACKAGE_REVISION)
			string(APPEND _filename ".${SF_PACKAGE_REVISION}")
		endif ()
		list(APPEND _filename "${SF_ARCHITECTURE_SAFE}")
		string(REPLACE ";" "_" _filename "${_filename}")
		set("CPACK_ARCHIVE_${_ComponentUpper}_FILE_NAME" "${_filename}")
		# Add the package revision to the file version part.
		message(STATUS "Archive (${_Component}) filename: ${CPACK_ARCHIVE_${_ComponentUpper}_FILE_NAME}")
	endforeach ()
	if (CPACK_GENERATOR STREQUAL "ZIP" AND EXISTS "${SF_ZIP_MANIFEST_FILE}")
		file(COPY_FILE "${SF_ZIP_MANIFEST_FILE}" "${CPACK_OUTPUT_FILE_PREFIX}/${CPACK_ARCHIVE_${_ComponentUpper}_FILE_NAME}.zip-def")
	endif ()
endif ()


if (CPACK_GENERATOR STREQUAL "NSIS64")
	foreach (_Component IN LISTS CPACK_COMPONENTS_ALL)
		# Add description (and optional display name) to the component.
		cpack_add_component("${_Component}"
			#DISPLAY_NAME "Main Application"
			DESCRIPTION "Installs the main executable binaries and required ${_Component} libraries."
		)
	endforeach ()
	set(CPACK_NSIS_WELCOME_TITLE "Installer from ${SF_PROVIDER_NAME} for ${SF_PACKAGE_BASE_NAME}")
	# Determine the menu folder for shortcuts.
	set(CPACK_NSIS_PACKAGE_NAME "${SF_PROVIDER_NAME}")
	set(CPACK_NSIS_DISPLAY_NAME "${SF_PACKAGE_NAME} ${SF_GIT_TAG_VERSION}-${SF_PACKAGE_RELEASE}")
	# The executable file name.
	set(CPACK_PACKAGE_FILE_NAME "${SF_PACKAGE_NAME}_${SF_GIT_TAG_VERSION}-${SF_PACKAGE_RELEASE}")
	# Add the package revision to the file version part.
	if (SF_PACKAGE_REVISION)
		set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_FILE_NAME}.${SF_PACKAGE_REVISION}")
	endif ()
endif ()

if (CPACK_GENERATOR STREQUAL "AppImage")
	# Set AppImage file naming pattern matching the convention.
	set(_filename "${SF_PACKAGE_BASE_NAME}-lnx+${SF_TOOLCHAIN_STRING}_${SF_GIT_TAG_VERSION}")
	if (SF_PACKAGE_RELEASE)
		string(APPEND _filename "-${SF_PACKAGE_RELEASE}")
	endif ()
	if (DEFINED SF_PACKAGE_REVISION)
		string(APPEND _filename ".${SF_PACKAGE_REVISION}")
	endif ()
	string(APPEND _filename "_${SF_ARCHITECTURE_SAFE}")
	# The executable file name.
	set(CPACK_PACKAGE_FILE_NAME "${_filename}")
	message(STATUS "CPACK_PACKAGE_FILE_NAME: ${CPACK_PACKAGE_FILE_NAME}")
	# Desktop and icon configuration.
	set(_AppDir "${CMAKE_CURRENT_SOURCE_DIR}/data/application")
	if (EXISTS "${_AppDir}")
		file(GLOB _DesktopFiles "${_AppDir}/*.desktop")
		list(GET _DesktopFiles 0 _MainDesktopFilePath)
		if (EXISTS "${_MainDesktopFilePath}")
			get_filename_component(_MainDesktopFile "${_MainDesktopFilePath}" NAME)
			set(CPACK_APPIMAGE_DESKTOP_FILE "${_MainDesktopFile}")
			string(REGEX REPLACE "desktop$" "svg" CPACK_PACKAGE_ICON "${_MainDesktopFile}")
			message(STATUS "CPACK_APPIMAGE_DESKTOP_FILE: ${CPACK_APPIMAGE_DESKTOP_FILE}")
			message(STATUS "CPACK_PACKAGE_ICON: ${CPACK_PACKAGE_ICON}")
		else ()
			message(FATAL_ERROR "Desktop file missing!")
		endif ()
	endif ()
endif ()

if (NOT WIN32)
	# Prevent copying by removing the files for generators not needing them.
	set(_dir_out "${CMAKE_CURRENT_BINARY_DIR}/.sf/debian/etc/ld.so.conf.d")
	Sf_RemoveFiles("${_dir_out}")
	# Disabled since it is not needed.
	if (FALSE)
		# Create the ld.so configuration file content.
		file(WRITE "${_dir_out}/${CMAKE_PROJECT_NAME}-libs.conf" "
# Enable from project file.\n
# ${CPACK_PACKAGING_INSTALL_PREFIX}/lib\n"
		)
	endif ()
	# Prevent copying by removing the files for generators not needing them.
	set(_dir_out "${CMAKE_CURRENT_BINARY_DIR}/.sf/debian/bin")
	Sf_RemoveFiles("${_dir_out}")
	if (CPACK_GENERATOR STREQUAL "DEB" OR CPACK_GENERATOR STREQUAL "AppImage")
		# Create launcher scripts for each executable.
		foreach (_bin_file IN LISTS SF_OUTPUT_PATHS_${SF_DEFAULT_COMPONENT_NAME})
			get_filename_component(_OutputName "${_bin_file}" NAME_WLE)
			get_filename_component(_OutputSuffix "${_bin_file}" LAST_EXT)
			# Create a launcher script in the build directory.
			set(_FilePath "${_dir_out}/${_OutputName}")
			message(STATUS "Creating launcher '${_OutputName}': ${CPACK_PACKAGING_INSTALL_PREFIX}/${_OutputName}${_OutputSuffix}")
			file(WRITE "${_FilePath}" [[#!/bin/env bash

# Get the script's directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
]])
			file(APPEND "${_FilePath}" "
exec \"\${script_dir}/../..${CPACK_PACKAGING_INSTALL_PREFIX}/${_OutputName}${_OutputSuffix}\" \"$@\"
	")
		endforeach ()
	endif ()
	# Prevent copying by removing the files for generators not needing them.
	set(_dir_out "${CMAKE_CURRENT_BINARY_DIR}/.sf/appimage")
	Sf_RemoveFiles("${_dir_out}")
	if (CPACK_GENERATOR STREQUAL "AppImage")
		# Generate custom AppRun launcher script for AppImage payload.
		set(_filepath "${_dir_out}/AppRun")
		file(WRITE "${_filepath}" [[#!/bin/env bash
# Determine how the application was called externally.
invocation_name=$(basename "${ARGV0:-$0}")
script_dir="$(dirname "$(readlink -f "$0")")"
if [ -f "${script_dir}/usr/bin/${invocation_name}" ]; then
	exec "${script_dir}/usr/bin/${invocation_name}" "$@"
else
	shopt -s nullglob
	for file in "${script_dir}/usr/bin/"*; do
		exec "${file}" "$@"
		break
	done
fi
]])
		file(APPEND "${_filepath}" [[
return $?
]])
	Sf_GetGitCommitDateTime(_DateTime "${CMAKE_CURRENT_LIST_DIR}")
	list(GET _DateTime 0 SF_GIT_DATE)
		list(GET _DateTime 1 SF_GIT_TIME)
		# Get all template files.
	file(GLOB _files "${CMAKE_CURRENT_SOURCE_DIR}/data/application/*.appdata.xml.xtpl")
	foreach (_file_in IN LISTS _files)
		# Generate the configure the file for doxygen.
		get_filename_component(_filename "${_file_in}" NAME_WLE)
		configure_file("${_file_in}" "${_dir_out}/${_filename}" @ONLY)
	endforeach ()
	endif ()
endif ()
