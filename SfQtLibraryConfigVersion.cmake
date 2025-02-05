# Define the version of the package and as of writing this is the latest.
set(PACKAGE_VERSION 6.8.1)

# Split the the package version string.
string(REPLACE "." ";" _Parts "${PACKAGE_VERSION}")
list(GET _Parts 0 PACKAGE_MAJOR)
list(GET _Parts 1 PACKAGE_MINOR)
list(GET _Parts 2 PACKAGE_PATCH)

# Split the the package find version string.
string(REPLACE "." ";" _Parts "${PACKAGE_FIND_VERSION}")
list(GET _Parts 0 REQUIRED_MAJOR)
list(GET _Parts 1 REQUIRED_MINOR)
list(GET _Parts 2 REQUIRED_PATCH)

##
## Define the compatibility logic.
##

# The same version is always compatible.
if ("${PACKAGE_VERSION}" VERSION_EQUAL "${PACKAGE_FIND_VERSION}")
	set(PACKAGE_VERSION_COMPATIBLE TRUE)
	set(PACKAGE_VERSION_EXACT TRUE)
	# Major version needs to be the same to be compatible.
elseif (NOT "${REQUIRED_MAJOR}" EQUAL "${PACKAGE_MAJOR}")
	set(PACKAGE_VERSION_COMPATIBLE FALSE)
	# Required minor version greater than the package minor version is not compatible.
elseif ("${REQUIRED_MINOR}" GREATER "${PACKAGE_MINOR}")
	set(PACKAGE_VERSION_COMPATIBLE FALSE)
	# Required patch version greater than the package patch version is not compatible.
elseif ("${REQUIRED_PATCH}" GREATER "${PACKAGE_PATCH}")
	set(PACKAGE_VERSION_COMPATIBLE FALSE)
	# All others are compatible.
else ()
	set(PACKAGE_VERSION_COMPATIBLE TRUE)
endif ()

# Optionally, provide detailed information about the version match.
if (PACKAGE_VERSION_COMPATIBLE)
	message(STATUS "Package '${PACKAGE_FIND_NAME}' version ${PACKAGE_VERSION}")
else ()
	set(PACKAGE_VERSION_UNSUITABLE TRUE)
	message(STATUS "Package '${PACKAGE_FIND_NAME}' version ${PACKAGE_VERSION} is not compatible with the requested version ${PACKAGE_FIND_VERSION}")
endif ()
