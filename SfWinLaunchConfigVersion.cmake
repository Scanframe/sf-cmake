#[[

# Only one version can be used per top level project.
# The first call to find_package() pins the version in SF_LIB_WIN_LAUNCH_VERSION, resolved from GitHub.
# An unversioned call pins the latest GitHub tag, a versioned call pins the requested version when it is a GitHub tag.
# Later calls only compare their requested version against the pinned version.
# A failed GitHub lookup stops configure, and a requested version that is not a GitHub tag is a fatal error.

]]

# Pin the version once when nothing is cached yet, for versioned and unversioned calls.
if ("${SF_LIB_WIN_LAUNCH_VERSION}" STREQUAL "")
	if ("${PACKAGE_FIND_VERSION}" STREQUAL "")
		# Unversioned call, pin the latest version from GitHub.
		Sf_GetGitHubVersion(_Version "Scanframe" "win-launch")
		if (NOT _Version)
			message(FATAL_ERROR "Project '${PACKAGE_FIND_NAME}' latest version is not available on GitHub.")
		endif ()
	else ()
		# Versioned call, the requested version must be a tag on GitHub and is pinned.
		Sf_GetGitHubVersions(_Versions "Scanframe" "win-launch")
		list(FIND _Versions "${PACKAGE_FIND_VERSION}" _Result)
		if (NOT _Result EQUAL -1)
			set(_Version "${PACKAGE_FIND_VERSION}")
		else ()
			message(FATAL_ERROR "Project '${PACKAGE_FIND_NAME}' version '${PACKAGE_FIND_VERSION}' is not available on GitHub.")
		endif ()
	endif ()
	# Write the SfWinLaunch pinned version.
	set(SF_LIB_WIN_LAUNCH_VERSION "${_Version}" CACHE INTERNAL "Version of the framework from GitHub.")
elseif (NOT "${PACKAGE_FIND_VERSION}" STREQUAL "")
	message(STATUS "Project '${PACKAGE_FIND_NAME}' packages using earlier set version ${SF_LIB_WIN_LAUNCH_VERSION}")
endif ()

# Use the pinned version as the package version.
set(PACKAGE_VERSION "${SF_LIB_WIN_LAUNCH_VERSION}")

# Define the compatibility logic.
if ("${PACKAGE_FIND_VERSION}" STREQUAL "")
	set(PACKAGE_VERSION_COMPATIBLE TRUE)
elseif ("${PACKAGE_VERSION}" VERSION_EQUAL "${PACKAGE_FIND_VERSION}")
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
