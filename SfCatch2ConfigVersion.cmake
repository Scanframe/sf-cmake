#[[

# Only one version can be specified per top level project.
# The first call to find_package() with a version sets it for all others sub projects.
#
# To set the Catch2 library version used for all sub projects add the following
in the top level CMakeLists.txt file.

find_package(SfCatch2 3.9.1 CONFIG)

]]

# Default version of the package and as of writing this is the latest.
set(PACKAGE_VERSION 3.8.1)

# Check if a certain version is requested.
if (NOT "${PACKAGE_FIND_VERSION}" STREQUAL "")
	# Check if a version has been requested.
	if ("${SF_CATCH2_VERSION}" STREQUAL "")
		# Get versions from GitHub through its API.
		Sf_GetGitHubVersions(_Versions "catchorg" "Catch2")
		# Check a version list was retrieved.
		if (NOT "${_Versions}" STREQUAL "")
			# Try finding the requested version in the list of versions.
			list(FIND _Versions "${PACKAGE_FIND_VERSION}" _Result)
			# Check if the version was found.
			if (NOT _Result EQUAL -1)
				# Update the current package version.
				set(PACKAGE_VERSION "${PACKAGE_FIND_VERSION}")
				message(STATUS "Project '${PACKAGE_FIND_NAME}' packages set to version ${PACKAGE_FIND_VERSION}")
			else ()
				message(WARNING "Project '${PACKAGE_FIND_NAME}' failed on version '${PACKAGE_FIND_VERSION}' using now default '${PACKAGE_VERSION}'.")
			endif ()
			# Write the SfCatch2 cached version.
			set(SF_CATCH2_VERSION "${PACKAGE_VERSION}" CACHE INTERNAL "Version of the catch framework from GitHub.")
		endif ()
	else ()
	endif ()
endif ()

# When a version is cached use it to set the package version from there.
if (NOT "${SF_CATCH2_VERSION}" STREQUAL "")
	set(PACKAGE_VERSION "${SF_CATCH2_VERSION}")
endif ()

# Define the compatibility logic.
if ("${PACKAGE_VERSION}" VERSION_EQUAL "${PACKAGE_FIND_VERSION}")
	set(PACKAGE_VERSION_COMPATIBLE TRUE)
	set(PACKAGE_VERSION_EXACT TRUE)
elseif ("${PACKAGE_VERSION}" VERSION_GREATER "${PACKAGE_FIND_VERSION}")
	set(PACKAGE_VERSION_COMPATIBLE TRUE)
else ()
	set(PACKAGE_VERSION_COMPATIBLE FALSE)
endif ()
# Optionally, provide detailed information about the version match

if (PACKAGE_VERSION_COMPATIBLE)
	message(STATUS "Project '${PROJECT_NAME}' using '${PACKAGE_FIND_NAME}' version '${PACKAGE_VERSION}'")
else ()
	set(PACKAGE_VERSION_UNSUITABLE TRUE)
	message(WARNING "Project '${PROJECT_NAME}' package '${PACKAGE_FIND_NAME}' version '${PACKAGE_VERSION}' is incompatible with the requested version '${PACKAGE_FIND_VERSION}'")
endif ()
