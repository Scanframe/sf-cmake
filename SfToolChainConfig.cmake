##!
# Finds the GNU toolchain applications using the given prefix for Linux only.
# @param _CmakeFile Toolchain cmake file to append to.
# @param _Prefix Prefix consisting out subdirectory and part of the filename of the application.
#
function(Sf_FindLinuxToolChainApps _CmakeFile _Prefix)
	set(_GccMaxVer 18)
	foreach (_Version RANGE ${_GccMaxVer} 8 -1)
		# Check if non distribution gcc is installed available.
		set(_Dir "/opt/gcc-${_Version}/bin")
		if (EXISTS "${_Dir}")
			message(STATUS "C compiler: ${_Dir}/gcc")
			file(APPEND "${_CmakeFile}"
				"set(CMAKE_C_COMPILER \"${_Dir}/gcc\")\n"
				"set(CMAKE_CXX_COMPILER \"${_Dir}/g++\")\n"
			)
			return()
		endif ()
	endforeach ()
	# Find the highest install GCC compiler of this distribution.
	foreach (_Version RANGE ${_GccMaxVer} 8 -1)
		unset(_App CACHE)
		find_program(_App "${_Prefix}gcc-${_Version}")
		if (_App)
			message(STATUS "C compiler: ${_App}")
			file(APPEND "${_CmakeFile}"
				"set(CMAKE_C_COMPILER \"${_App}\")\n"
			)
			break()
		endif ()
	endforeach ()
	foreach (_Version RANGE ${_GccMaxVer} 8 -1)
		unset(_App CACHE)
		find_program(_App "${_Prefix}g++-${_Version}")
		if (_App)
			message(STATUS "C++ compiler: ${_App}")
			file(APPEND "${_CmakeFile}"
				"set(CMAKE_CXX_COMPILER \"${_App}\")\n"
			)
			break()
		endif ()
	endforeach ()
	foreach (_Version RANGE 16 8 -1)
		unset(_App CACHE)
		find_program(_App "${_Prefix}gcov-${_Version}")
		if (_App)
			message(STATUS "Coverage: ${_App}")
			# Deliberate not setting the gcov command here like this.
			#file(APPEND "${_CmakeFile}" "set(COVERAGE_COMMAND \"${_App}\")\n")
			# Manually set the coverage command
			set(COVERAGE_COMMAND "${_App}" CACHE STRING "Coverage command found by ${CMAKE_CURRENT_FUNCTION}().")
			break()
		endif ()
	endforeach ()
endfunction()

##!
# Find the toolchain and creates a cmake toolchain file in the build directory.
# A Function is used to have a scopen for temporary variables.
#
function(Sf_SetToolChain)
	# Assemble path to tool chain file.
	set(_CmakeFile "${CMAKE_CURRENT_BINARY_DIR}/.sf/SfToolChain.cmake")
	file(WRITE "${_CmakeFile}" "##\n## Created by function '${CMAKE_CURRENT_FUNCTION}()'\n##\n")
	# Assign the CMAKE_HOST_SYSTEM_PROCESSOR when not defined.
	if (NOT DEFINED CMAKE_HOST_SYSTEM_PROCESSOR)
		# When Linux find the it with the uname command.
		if ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Linux")
			execute_process(COMMAND uname -m
				OUTPUT_VARIABLE _HostArch
				OUTPUT_STRIP_TRAILING_WHITESPACE
				COMMAND_ERROR_IS_FATAL ANY
			)
		elseif ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows")
			set(_HostArch "x86_64")
		else ()
			message(FATAL_ERROR "Cannot determine the host process.")
		endif ()
	else ()
		set(_HostArch "${CMAKE_HOST_SYSTEM_PROCESSOR}")
	endif ()
	# When the ccache package and executable is installed use it in the tool-chain file.
	# The configuration file is at '~/.config/ccache/ccache.conf' and command 'ccache -p' shows it.
	find_program(_CcacheExe "ccache")
	if (_CcacheExe)
		file(APPEND "${_CmakeFile}" "set(CMAKE_C_COMPILER_LAUNCHER \"${_CcacheExe}\")\n")
		file(APPEND "${_CmakeFile}" "set(CMAKE_CXX_COMPILER_LAUNCHER \"${_CcacheExe}\")\n")
	endif ()
	# Check if this is a cross compile for windows and set the default compiler when n ot set.
	if (NOT DEFINED SF_COMPILER OR SF_COMPILER STREQUAL "")
		message(FATAL_ERROR "Cache variable SF_COMPILER not set.")
	endif ()
	# By default the toolset for Linux is native GNU
	if (SF_COMPILER STREQUAL "gnu" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
		set(_SystemName "Linux")
		set(_Arch "${_HostArch}")
		Sf_FindLinuxToolChainApps("${_CmakeFile}" "/usr/bin/${_Arch}-linux-gnu-")
		# When set to 'ag' try to find the latest aarch64 cross compiler.
	elseif (SF_COMPILER STREQUAL "ga" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
		set(_SystemName "Linux")
		set(_Arch "aarch64")
		Sf_FindLinuxToolChainApps("${_CmakeFile}" "/usr/bin/${_Arch}-linux-gnu-")
		# Set the architecture of the targets being build also requires 'CMAKE_SYSTEM_NAME' to be set since this also
		# sets 'CMAKE_CROSSCOMPILING' and makes a project not reset 'CMAKE_SYSTEM_PROCESSOR' for each created project.
		file(APPEND "${_CmakeFile}" "##
set(CMAKE_SYSTEM_NAME \"Linux\")
set(CMAKE_SYSTEM_PROCESSOR \"aarch64\")
		")
		# When building Windows targets using GNU compiler on Windows.
	elseif (SF_COMPILER STREQUAL "mingw" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
		set(_SystemName "Windows")
		set(_Arch "${_HostArch}")
		find_program(_App "gcc.exe")
		if (NOT _App)
			message(SEND_ERROR "GNU Windows compiler for ${_HostArch} not found!\nPATH=$ENV{PATH}")
			return()
		else ()
			find_program(_GccExe x86_64-w64-mingw32-gcc.exe REQUIRED)
			get_filename_component(_BinDir "${_GccExe}" DIRECTORY)
			get_filename_component(_SysRootDir "${_BinDir}" DIRECTORY)
			# Do not set the CMAKE_SYSTEM_NAME since it will set the CMAKE_CROSSCOMPILING flag.
			file(APPEND "${_CmakeFile}" "##
# Use mingw 64-bit compilers on Windows.
# Commented out now to have CMake find each of them.
#set(CMAKE_C_COMPILER \"${_BinDir}/x86_64-w64-mingw32-gcc.exe\")
#set(CMAKE_CXX_COMPILER \"${_BinDir}/x86_64-w64-mingw32-g++.exe\")
#set(CMAKE_RC_COMPILER \"${_BinDir}/windres.exe\")
#set(CMAKE_AR \"${_BinDir}/x86_64-w64-mingw32-gcc-ar.exe\")
#set(CMAKE_RANLIB \"${_BinDir}/x86_64-w64-mingw32-gcc-ranlib.exe\")
#set(CMAKE_NM \"${_BinDir}/x86_64-w64-mingw32-gcc-nm.exe\")
#set(CMAKE_LINKER \"${_BinDir}/ld.exe\")
## Adjust the default behavior of the find commands:
## search headers and libraries in the target environment
#set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
#set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
## Search programs in the host environment
#set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
")
		endif ()
		# When building Windows targets using GNU compiler on Linux.
	elseif (SF_COMPILER STREQUAL "gw" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
		set(_SystemName "Windows")
		set(_Arch "${_HostArch}")
		# Find the Windows cross compiler.
		find_program(_App "${_Arch}-w64-mingw32-c++-posix")
		if (NOT _App)
			message(SEND_ERROR "Windows cross compiler not found. Missing package 'mingw-w64' ?")
			return()
		endif ()
		get_filename_component(_BinDir "${_App}" DIRECTORY)
		# Important to set CMAKE_CROSSCOMPILING to TRUE together with CMAKE_SYSTEM_NAME and CMAKE_SYSTEM_PROCESSOR
		# When not it is not CMAKE_SYSTEM_PROCESSOR is reset by CMake itself and only for MinGW on a Linux host.
		file(APPEND "${_CmakeFile}" "
set(CMAKE_CROSSCOMPILING TRUE)
set(CMAKE_SYSTEM_NAME \"${_SystemName}\")
set(CMAKE_SYSTEM_PROCESSOR \"${_HostArch}\")
# Prevent CLion IDE from reconfiguring the project thinking it has changed and the cache file is deleted.
# Use mingw 64-bit compilers.
if (NOT CMAKE_C_COMPILER STREQUAL \"${_BinDir}/x86_64-w64-mingw32-gcc-posix\")
  set(CMAKE_C_COMPILER \"${_BinDir}/x86_64-w64-mingw32-gcc-posix\")
endif ()
if (NOT CMAKE_CXX_COMPILER STREQUAL \"${_BinDir}/x86_64-w64-mingw32-g++-posix\")
  set(CMAKE_CXX_COMPILER \"${_BinDir}/x86_64-w64-mingw32-g++-posix\")
endif ()
set(CMAKE_RC_COMPILER \"${_BinDir}/x86_64-w64-mingw32-windres\")
set(CMAKE_RANLIB \"${_BinDir}/x86_64-w64-mingw32-ranlib\")
set(CMAKE_AR \"${_BinDir}/x86_64-w64-mingw32-gcc-ar\")
set(CMAKE_NM \"${_BinDir}/x86_64-w64-mingw32-gcc-nm\")
set(CMAKE_LINKER \"${_BinDir}/x86_64-w64-mingw32-gcc-ld\")
set(CMAKE_STRIP \"${_BinDir}/x86_64-w64-mingw32-gcc-strip\")
set(CMAKE_FIND_ROOT_PATH \"/usr/x86_64-w64-mingw32\")
# Adjust the default behavior of the find commands:
# search headers and libraries in the target environment
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
# Search programs in the host environment
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
")
		# TODO: Cygwin compilers?
		if (False)
			set(_SystemName "Windows")
			file(APPEND "${_CmakeFile}" "
# Use mingw 64-bit compilers on Cygwin.
set(CMAKE_C_COMPILER \"i686-w64-mingw32-gcc\")
set(CMAKE_CXX_COMPILER \"i686-w64-mingw32-c++\")
set(CMAKE_RC_COMPILER \"i686-w64-mingw32-windres\")
set(CMAKE_RANLIB \"i686-w64-mingw32-ranlib\")
set(CMAKE_STRIP \"i686-w64-mingw32-strip\")
set(CMAKE_FIND_ROOT_PATH \"/usr/bin\")
# Adjust the default behavior of the find commands:
# search headers and libraries in the target environment
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
# Search programs in the host environment
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
")
		endif ()
		# When building Windows targets using MSVC compiler on Windows.
	elseif (SF_COMPILER STREQUAL "msvc" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
		set(_SystemName "Windows")
		set(_Arch "${_HostArch}")
		find_program(_App "cl.exe")
		if (NOT _App)
			message(SEND_ERROR "MSVC Windows compiler for ${_HostArch} not found!\nPATH=$ENV{PATH}")
			return()
		else ()
			file(APPEND "${_CmakeFile}" "# CMake uses the environment to find MSVC.
# Make `__cplusplus` have the same value as in other compilers.
add_compile_options(/Zc:__cplusplus)")
		endif ()
		# Report that a toolset was given but not
	else ()
		message(SEND_ERROR "Toolset '${SF_COMPILER}' is unknown for host system '${CMAKE_HOST_SYSTEM_NAME}'!")
	endif ()
	# Set the SF_ARCHITECTURE global variable.
	set(SF_ARCHITECTURE "${_Arch}" PARENT_SCOPE)
	# Set the SF_HOST_ARCHITECTURE global variable.
	set(SF_HOST_ARCHITECTURE "${_HostArch}" PARENT_SCOPE)
	# Determine the flag for cross compiling.
	if (_Arch STREQUAL _HostArch AND _SystemName STREQUAL CMAKE_HOST_SYSTEM_NAME)
		set(SF_CROSSCOMPILING FALSE PARENT_SCOPE)
	else ()
		set(SF_CROSSCOMPILING TRUE PARENT_SCOPE)
	endif ()
	# Set the Docker flag when the file exists.
	if (EXISTS "Z:/.dockerenv" OR EXISTS "/.dockerenv")
		set(SF_DOCKER TRUE PARENT_SCOPE)
	else ()
		set(SF_DOCKER FALSE PARENT_SCOPE)
	endif ()
	# Assign the tool chain.
	if (CMAKE_TOOLCHAIN_FILE AND NOT CMAKE_TOOLCHAIN_FILE STREQUAL "${_CmakeFile}")
		message(NOTICE "Toolchain file was externally set: ${CMAKE_TOOLCHAIN_FILE}")
	else ()
		set(CMAKE_TOOLCHAIN_FILE "${_CmakeFile}" PARENT_SCOPE)
	endif ()
endfunction()

# Make it happen.
Sf_SetToolChain()
