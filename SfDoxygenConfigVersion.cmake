# Find the executable.
if (WIN32)
	find_program(DOXYGEN_EXECUTABLE
		NAMES doxygen
		DOC "Doxygen executable"
	)
else ()
	find_program(DOXYGEN_EXECUTABLE
		NAMES doxygen
		PATHS "/opt/doxygen/bin"
		DOC "Doxygen executable"
	)
endif ()

if (NOT DOXYGEN_EXECUTABLE)
	set(PACKAGE_VERSION_COMPATIBLE FALSE)
	set(PACKAGE_VERSION_UNSUITABLE TRUE)
	message(STATUS "Package '${PACKAGE_FIND_NAME}': doxygen executable not found")
	return ()
endif ()

# Get the version string; the first word is the actual version.
execute_process(
	COMMAND ${DOXYGEN_EXECUTABLE} --version
	COMMAND_ERROR_IS_FATAL ANY
	OUTPUT_STRIP_TRAILING_WHITESPACE
	OUTPUT_VARIABLE _Version
)
string(REPLACE " " ";" _Version "${_Version}")
list(GET _Version 0 PACKAGE_VERSION)

# When no version was requested accept whatever was found.
if (NOT PACKAGE_FIND_VERSION)
	set(PACKAGE_FIND_VERSION "${PACKAGE_VERSION}")
endif ()

string(REGEX MATCH "^([0-9]+)" _ "${PACKAGE_VERSION}")
set(PACKAGE_MAJOR "${CMAKE_MATCH_1}")
string(REGEX MATCH "^([0-9]+)" _ "${PACKAGE_FIND_VERSION}")
set(REQUIRED_MAJOR "${CMAKE_MATCH_1}")

# Compatibility logic.
if (PACKAGE_VERSION VERSION_EQUAL PACKAGE_FIND_VERSION)
	set(PACKAGE_VERSION_COMPATIBLE TRUE)
	set(PACKAGE_VERSION_EXACT TRUE)
elseif (NOT REQUIRED_MAJOR EQUAL PACKAGE_MAJOR)
	set(PACKAGE_VERSION_COMPATIBLE FALSE)
elseif (PACKAGE_VERSION VERSION_LESS PACKAGE_FIND_VERSION)
	set(PACKAGE_VERSION_COMPATIBLE FALSE)
else ()
	set(PACKAGE_VERSION_COMPATIBLE TRUE)
endif ()

if (PACKAGE_VERSION_COMPATIBLE)
	message(STATUS "Package '${PACKAGE_FIND_NAME}' version ${PACKAGE_VERSION}")
else ()
	set(PACKAGE_VERSION_UNSUITABLE TRUE)
	message(STATUS "Package '${PACKAGE_FIND_NAME}' version ${PACKAGE_VERSION} is not compatible with the requested version ${PACKAGE_FIND_VERSION}")
	if (SF_DOCKER)
		message(STATUS "Maybe you are running the wrong Docker image or started it with the wrong options.")
	endif ()
endif ()