##!
# Reports information about the CMake and sets compiler general
# options depending on the selected compiler.
#
if ("${CMAKE_PROJECT_NAME}" STREQUAL "${PROJECT_NAME}")
	list(APPEND CMAKE_MESSAGE_INDENT "CMake ")
	message(STATUS "Version: ${CMAKE_VERSION}")
	message(STATUS "Generator: ${CMAKE_MAKE_PROGRAM}")
	message(STATUS "System : ${CMAKE_SYSTEM}")
	message(STATUS "Host System: ${CMAKE_HOST_SYSTEM}")
	message(STATUS "System Info File: ${CMAKE_SYSTEM_INFO_FILE}")
	message(STATUS "System Processor: ${CMAKE_SYSTEM_PROCESSOR}")
	# Remove the indentation of the message() function.
	list(POP_BACK CMAKE_MESSAGE_INDENT)
	# Make the target property 'CXX_STANDARD' a requirement.
	set(CMAKE_CXX_STANDARD_REQUIRED ON)
	# Report when the global C++ standard has not been set.
	if ("${CMAKE_CXX_STANDARD}" STREQUAL "")
		message(SEND_ERROR "Global C++ standard using 'CMAKE_CXX_STANDARD' has not been set!")
	endif ()
	message(STATUS "C   Compiler: ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION} ${CMAKE_C_COMPILER}")
	message(STATUS "C++ Compiler: ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION} ${CMAKE_CXX_COMPILER}")
	message(STATUS "RC  Compiler: ${CMAKE_RC_COMPILER}")
	message(STATUS "RanLib : ${CMAKE_RANLIB}")
	message(STATUS "Nm     : ${CMAKE_NM}")
	message(STATUS "Ar     : ${CMAKE_AR}")
	message(STATUS "Linker : ${CMAKE_LINKER}")
	message(STATUS "Strip  : ${CMAKE_STRIP}")
endif ()

