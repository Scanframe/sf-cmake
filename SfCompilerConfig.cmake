if ("${CMAKE_PROJECT_NAME}" STREQUAL "${PROJECT_NAME}")
	list(APPEND CMAKE_MESSAGE_INDENT "CMake ")
	message(STATUS "Version: ${CMAKE_VERSION}")
	message(STATUS "Generator: ${CMAKE_MAKE_PROGRAM}")
	message(STATUS "System : ${CMAKE_SYSTEM}")
	message(STATUS "Host System: ${CMAKE_HOST_SYSTEM}")
	message(STATUS "System Info File: ${CMAKE_SYSTEM_INFO_FILE}")
	message(STATUS "System Processor: ${CMAKE_SYSTEM_PROCESSOR}")
	list(POP_BACK CMAKE_MESSAGE_INDENT)
	# Make the target property 'CXX_STANDARD' a requirement.
	set(CMAKE_CXX_STANDARD_REQUIRED ON)
	# Report when the global C++ standard has not been set.
	if ("${CMAKE_CXX_STANDARD}" STREQUAL "")
		message(SEND_ERROR "Global C++ standard using 'CMAKE_CXX_STANDARD' has not been set!")
	endif ()
	# Do not export all by default in Linux.
	if (NOT WIN32)
		# Catch2 cannot handle compiler switch below when flag 'BUILD_SHARED_LIBS' is enabled presumably.
		add_definitions("-fvisibility=hidden")
	endif ()
	if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
		# Generate an error on undefined (imported) symbols on dynamic libraries
		# because the error appears only at load-time otherwise.
		add_link_options(-Wl,--no-undefined -Wl,--no-allow-shlib-undefined)
	endif ()
	# When MSVC compiler is used set some options.
	if (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
		add_compile_options("-Zc:__cplusplus")
	endif ()
	# When GNU compiler is used set some options.
	if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
		message(STATUS "C++ Compiler: ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
		if (WIN32)
			# Needed for Windows since Catch2 is creating a huge obj file.
			add_compile_options(-m64 -Wa,-mbig-obj)
		else ()
			# For detecting memory errors.
			add_compile_options(--pedantic-errors #[[-fsanitize=address]])
		endif ()
	endif ()
	# Workaround for using a network drive on Windows.
	Sf_WorkAroundSmbShare()
endif ()

#TODO: This QT stuff should probably be in its own cmake package file so it can be omitted in non Qt builds.
# Set the Qt Library location variable.
if (NOT DEFINED QT_DIRECTORY)
	Sf_GetQtVersionDirectory(QT_DIRECTORY)
	if (QT_DIRECTORY STREQUAL "")
		# When not found define it as empty.
		set(QT_DIRECTORY "")
	else()
		message(STATUS "Qt Version Directory: ${QT_DIRECTORY}")
		# When changing this CMAKE_PREFIX_PATH remove the 'cmake-build-xxxx' directory
		# since it weirdly keeps the previous selected CMAKE_PREFIX_PATH
		if (WIN32)
			if (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
				set(QT_LIBS_SUBDIRECTORY "msvc2019_64")
			else ()
				set(QT_LIBS_SUBDIRECTORY "mingw_64")
			endif ()
			message(STATUS "Qt Libraries: ${QT_LIBS_SUBDIRECTORY}")
			list(PREPEND CMAKE_PREFIX_PATH "${QT_DIRECTORY}/${QT_LIBS_SUBDIRECTORY}")
			set(QT_INCLUDE_DIRECTORY "${QT_DIRECTORY}/${QT_LIBS_SUBDIRECTORY}/include")
		else ()
			list(PREPEND CMAKE_PREFIX_PATH "${QT_DIRECTORY}/gcc_64")
			set(QT_INCLUDE_DIRECTORY "${QT_DIRECTORY}/gcc_64/include")
		endif ()
	endif()
endif ()

# Set the Qt plugins directory variable.
if (NOT DEFINED QT_PLUGINS_DIR)
	if (NOT QT_DIRECTORY STREQUAL "")
		if (WIN32)
			set(QT_PLUGINS_DIR "${QT_DIRECTORY}/mingw_64/plugins")
		else ()
			set(QT_PLUGINS_DIR "${QT_DIRECTORY}/gcc_64/plugins")
		endif ()
		message(STATUS "Designer Plugins Dir: ${QT_PLUGINS_DIR}")
	endif ()
endif ()
