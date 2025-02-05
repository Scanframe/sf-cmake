# Define the version of the package and as of writing this is the latest.
set(PACKAGE_VERSION 1.15.2)

# Define the compatibility logic
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
	message(STATUS "Package '${PACKAGE_FIND_NAME}' version ${PACKAGE_VERSION}")
else ()
	set(PACKAGE_VERSION_UNSUITABLE TRUE)
	message(STATUS "Package '${PACKAGE_FIND_NAME}' version ${PACKAGE_VERSION} is not compatible with the requested version ${PACKAGE_FIND_VERSION}")
endif ()
