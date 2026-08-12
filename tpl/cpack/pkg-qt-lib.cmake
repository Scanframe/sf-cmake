##
## Create a package from the current selected Qt library for the application project.
##
cmake_minimum_required(VERSION 3.29)

# Error: invalid characters in variable name "sf-qt-rt_selected", use only characters [a-z][A-Z][0-9], '.' and '_'

# Lowercase of the provider name for naming the package.
string(TOLOWER "${SF_PROVIDER_NAME}" _ProviderName)

# This setting is already set using 'CPACK_PACKAGE_VERSION'.
#set(CPACK_DEBIAN_PACKAGE_VERSION "${SF_QT_VERSION}-${QT_TWEAK_VERSION}")

# Set a different install directory for the Qt packages.
if (WIN32)
	set(CPACK_PACKAGE_INSTALL_DIRECTORY "${SF_PROVIDER_NAME}/qt/${SF_QT_VERSION}")
	set(CPACK_PACKAGING_INSTALL_PREFIX "/${SF_PROVIDER_NAME}/qt/${SF_QT_VERSION}")
else ()
	set(CPACK_PACKAGE_INSTALL_DIRECTORY "${SF_PROVIDER_NAME}/qt/${SF_QT_VERSION}")
	set(CPACK_PACKAGING_INSTALL_PREFIX "/opt/${SF_PROVIDER_NAME}/qt/${SF_QT_VERSION}")
endif ()

if (CPACK_GENERATOR STREQUAL "DEB")
	# Set the Debian variables for each component.
	foreach (_Component IN LISTS CPACK_COMPONENTS_ALL)
		string(TOUPPER "${_Component}" _ComponentUpper)
		string(REGEX MATCH "^${SF_QT_COMPONENT_PREFIX}(.*)$" _ "${_Component}")
		set(_SubComponent "${CMAKE_MATCH_1}")
		# Check for the Qt development component 'dev'.
		if (_SubComponent STREQUAL "dev")
			set("CPACK_DEBIAN_${_ComponentUpper}_PACKAGE_SECTION" "libdevel")
			set("CPACK_DEBIAN_${_ComponentUpper}_DESCRIPTION" "Development files required to build applications against the Qt libraries.")
			set("CPACK_DEBIAN_${_ComponentUpper}_PACKAGE_DEPENDS" "${_Component}-${SF_TOOLCHAIN_STRING} (= ${SF_QT_VERSION}.${QT_TWEAK_VERSION})")
		else ()
			set("CPACK_DEBIAN_${_ComponentUpper}_PACKAGE_SECTION" "libs")
			set("CPACK_DEBIAN_${_ComponentUpper}_DESCRIPTION" "Runtime libraries and plugins required by Qt applications.")
		endif ()
		set("CPACK_DEBIAN_${_ComponentUpper}_PACKAGE_NAME" "${_Component}-${SF_TOOLCHAIN_STRING}")
		set("CPACK_DEBIAN_${_ComponentUpper}_PACKAGE_VERSION" "${SF_QT_VERSION}-${QT_TWEAK_VERSION}")
	endforeach ()
endif ()

if (CPACK_GENERATOR IN_LIST SF_SUPPORTED_ARCHIVE_GENERATORS)
	# Set the Archive variables for each component.
	foreach (_Component IN LISTS CPACK_COMPONENTS_ALL)
		string(TOUPPER "${_Component}" _ComponentUpper)
		string(REGEX MATCH "^${SF_QT_COMPONENT_PREFIX}(.*)$" _ "${_Component}")
		set(_SubComponent "${CMAKE_MATCH_1}")
		# Check for the development component 'sf-qt-devel'.
		if (_SubComponent STREQUAL "dev")
		else ()
		endif ()
		string(REPLACE "_" "-" _Architecture "${SF_ARCHITECTURE}")
		set("CPACK_ARCHIVE_${_ComponentUpper}_FILE_NAME" "${_Component}-${SF_TOOLCHAIN_STRING}_${SF_QT_VERSION}-${QT_TWEAK_VERSION}_${_Architecture}")
	endforeach ()
endif ()

if (CPACK_GENERATOR STREQUAL "NSIS64")
	# Set the Debian variables for each component.
	foreach (_Component IN LISTS CPACK_COMPONENTS_ALL)
		string(TOUPPER "${_Component}" _ComponentUpper)
		string(REGEX MATCH "^${SF_QT_COMPONENT_PREFIX}(.*)$" _ "${_Component}")
		set(_SubComponent "${CMAKE_MATCH_1}")
		# Check for the Qt development component 'dev'.
		if (_SubComponent STREQUAL "dev")
			# Add description (and optional display name) to the component.
			cpack_add_component("${_Component}"
				DESCRIPTION "Development files required to build applications against the Qt libraries."
				DEPENDS "${SF_QT_COMPONENT_PREFIX}rt"
			)
		else ()
			# Add description (and optional display name) to the component.
			cpack_add_component("${_Component}"
				DESCRIPTION "Runtime libraries and plugins required by Qt applications."
			)
		endif ()
	endforeach ()
	#
	set(CPACK_NSIS_WELCOME_TITLE "${SF_PROVIDER_NAME} installer for Qt Libraries ${SF_PACKAGE_BASE_NAME}")
	set(CPACK_NSIS_PACKAGE_NAME "${SF_QT_COMPONENT_PREFIX}${SF_TOOLCHAIN_STRING}_${SF_QT_VERSION}-${QT_TWEAK_VERSION}-${SF_ARCHITECTURE}")
	set(CPACK_NSIS_DISPLAY_NAME "${SF_QT_COMPONENT_PREFIX}${SF_TOOLCHAIN_STRING}_${SF_QT_VERSION}-${QT_TWEAK_VERSION}-${SF_ARCHITECTURE}")
	set(CPACK_PACKAGE_FILE_NAME "${SF_QT_COMPONENT_PREFIX}${SF_TOOLCHAIN_STRING}_${SF_QT_VERSION}-${QT_TWEAK_VERSION}_${SF_ARCHITECTURE_SAFE}")
	# No applications for the QT library.
	unset(CPACK_PACKAGE_EXECUTABLES)
endif ()

