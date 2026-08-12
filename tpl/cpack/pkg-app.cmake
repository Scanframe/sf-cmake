# Lowercase of the provider name for naming the package.
string(TOLOWER "${SF_PROVIDER_NAME}" _ProviderName)

set("${SF_PACKAGE_NAME}_${SF_GIT_TAG_VERSION}~${SF_PACKAGE_RELEASE}" SF_PACKAGE_NAME)
# Get the number of the components.
list(LENGTH CPACK_COMPONENTS_ALL _ComponentCount)

if (CPACK_GENERATOR STREQUAL "RPM")
	# Set the RPM variables for each component.
	foreach (_Component IN LISTS CPACK_COMPONENTS_ALL)
		string(TOUPPER "${_Component}" _ComponentUpper)
		if (_ComponentCount EQUAL 1)
			set("CPACK_RPM_${_ComponentUpper}_PACKAGE_NAME" "${CPACK_PACKAGE_NAME}")
		else ()
			set("CPACK_RPM_${_ComponentUpper}_PACKAGE_NAME" "${CPACK_PACKAGE_NAME}-${_Component}")
		endif ()
		set("CPACK_RPM_${_ComponentUpper}_PACKAGE_GROUP" "Applications/System")
		set("CPACK_RPM_${_ComponentUpper}_PACKAGE_VERSION" "${SF_GIT_TAG_VERSION}")
		set("CPACK_RPM_${_ComponentUpper}_PACKAGE_RELEASE" "${SF_PACKAGE_RELEASE}")
		set("CPACK_RPM_${_ComponentUpper}_PACKAGE_SUMMARY" "Executables and shared libraries for the application.")
		message(STATUS "RPM (${_Component}) Package name: ${CPACK_RPM_${_ComponentUpper}_PACKAGE_NAME}")
	endforeach ()
	# Create list variable for package dependencies.
	set(_Dependencies)
	if (SF_BUILD_QT)
		list(APPEND _Dependencies "${_ProviderName}-qt-${SF_TOOLCHAIN_STRING} = ${SF_QT_VERSION}")
	endif ()
	# Convert back to a comma-separated string for RPM Requires field.
	string(JOIN ", " _Dependencies ${_Dependencies})
	if (_Dependencies)
		set("CPACK_RPM_${_AppComponent}_PACKAGE_REQUIRES" "${_Dependencies}")
	endif ()
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
		set("CPACK_DEBIAN_${_ComponentUpper}_PACKAGE_VERSION" "${SF_GIT_TAG_VERSION}~${SF_PACKAGE_RELEASE}")
		set("CPACK_DEBIAN_${_ComponentUpper}_DESCRIPTION" "Executables and shared libraries for the application.")
		message(STATUS "Debian (${_Component}) Package name: ${CPACK_DEBIAN_${_ComponentUpper}_PACKAGE_NAME}")
	endforeach ()
	# Create an empty list variable for package dependencies.
	set(_Dependencies)
	# The application uses the separately packaged Qt runtime when Qt build is enabled.
	if (SF_BUILD_QT)
		list(APPEND _Dependencies "${_ProviderName}-qt-${SF_TOOLCHAIN_STRING} (= ${SF_QT_VERSION})")
	endif ()
	# Create dummy debian/control file to allow dpkg-shlibdeps to run at all.
	file(WRITE "${SF_BINARY_DIR}/.sf/debian/control" "Source: dummy\nPackage: dummy\n")
	# Process each output file.
	foreach (_path IN LISTS SF_OUTPUT_PATHS)
		# Run dpkg-shlibdeps
		execute_process(
			COMMAND dpkg-shlibdeps --ignore-missing-info -l/mnt/server/userdata/source/c++src/trial-devops/bin/lnx64-gnu/lib -O "${_path}"
			WORKING_DIRECTORY "${SF_BINARY_DIR}/.sf"
			OUTPUT_VARIABLE _ShLibs
			ERROR_VARIABLE _IgnoreThis
			#ERROR_QUIET
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
		# Remove QT related items.
		list(FILTER _DebList EXCLUDE REGEX "^libqt")
		# Add these items to the total list.
		list(APPEND _Dependencies "${_DebList}")
	endforeach ()
	# Remove any duplicates.
	list(REMOVE_DUPLICATES _Dependencies)
	# Convert back to a comma-separated string.
	string(JOIN ", " _Dependencies ${_Dependencies})
	# Output results.
	message(STATUS "Total Dependencies: ${_Dependencies}")
	# The application uses the separately packaged Qt runtime when Qt support is enabled.
	set("CPACK_DEBIAN_${_AppComponent}_PACKAGE_DEPENDS" "${_Dependencies}")
endif ()

if (CPACK_GENERATOR IN_LIST SF_SUPPORTED_ARCHIVE_GENERATORS)
	# Only change the component filename when there is only one.
	string(TOUPPER "${_Component}" _ComponentUpper)
	# Set the Debian variables for each component.
	foreach (_Component IN LISTS CPACK_COMPONENTS_ALL)
		string(TOUPPER "${_Component}" _ComponentUpper)
		if (_ComponentCount EQUAL 1)
			set("CPACK_ARCHIVE_${_ComponentUpper}_FILE_NAME" "${CPACK_ARCHIVE_FILE_NAME}")
		else ()
			set("CPACK_ARCHIVE_${_ComponentUpper}_FILE_NAME" "${SF_PACKAGE_NAME}-${_Component}_${SF_GIT_TAG_VERSION}-${SF_PACKAGE_RELEASE}")
		endif ()
		message(STATUS "Debian (${_Component}) Package name: ${CPACK_DEBIAN_${_ComponentUpper}_PACKAGE_NAME}")
	endforeach ()
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
endif ()

