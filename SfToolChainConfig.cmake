##!
# Finds the GNU toolchain applications using the given prefix for Linux only.
# @param _CmakeFile Toolchain cmake file to append to.
# @param _Prefix Prefix consisting out subdirectory and part of the filename of the application.
#
function(Sf_FindLinuxToolChainApps _CmakeFile _Prefix)
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
	# Find the highest install gcc comppiler of this distribution.
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
	foreach (_Version RANGE 14 8 -1)
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
#
function(Sf_SetToolChain)
	set(_GccMaxVer 16)
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
		# Cmake does not set this variable all the time.
		#set(CMAKE_SYSTEM_PROCESSOR "${_HostArch}" CACHE STRING "Set by ${CMAKE_CURRENT_FUNCTION}().")
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
		set(_Arch "${_HostArch}")
		Sf_FindLinuxToolChainApps("${_CmakeFile}" "/usr/bin/${_Arch}-linux-gnu-")
		# When set to 'ag' try to find the latest aarch64 cross compiler.
	elseif (SF_COMPILER STREQUAL "ga" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
		set(_Arch "aarch64")
		Sf_FindLinuxToolChainApps("${_CmakeFile}" "/usr/bin/${_Arch}-linux-gnu-")
		# When building Windows targets using GNU compiler on Windows.
	elseif (SF_COMPILER STREQUAL "mingw" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
		set(_Arch "${_HostArch}")
		find_program(_App "gcc.exe")
		if (NOT _App)
			message(SEND_ERROR "GNU Windows compiler for ${_HostArch} not found!")
			return()
		else ()
			# When the PATH has been prefixed in the 'build.sh' script with '.tools-dir-*' file or
			# in the 'CMakePresets.json' setting the PATH not forgetting to use the ';' separator.
			# Cygwin mingw compiler will be found when the PATH is not prefixed.
			file(APPEND "${_CmakeFile}" "set(CMAKE_SYSTEM_NAME \"Windows\")
# Use mingw 64-bit compilers on Windows.
# Commented out now to have CMake find each of them.
#set(CMAKE_C_COMPILER \"x86_64-w64-mingw32-gcc.exe\")
#set(CMAKE_CXX_COMPILER \"x86_64-w64-mingw32-g++.exe\")
#set(CMAKE_RC_COMPILER \"windres.exe\")
#set(CMAKE_AR \"x86_64-w64-mingw32-gcc-ar.exe\")
#set(CMAKE_RANLIB \"x86_64-w64-mingw32-gcc-ranlib.exe\")
#set(CMAKE_NM \"x86_64-w64-mingw32-gcc-nm.exe\")
#set(CMAKE_LINKER \"ld.exe\")
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
		set(_Arch "${_HostArch}")
		# Find the Windows cross compiler.
		find_program(_App "${_Arch}-w64-mingw32-c++-posix")
		if (NOT _App)
			message(SEND_ERROR "Windows cross compiler not found. Missing package 'mingw-w64' ?")
			return()
		endif ()
		file(APPEND "${_CmakeFile}" "set(CMAKE_SYSTEM_NAME \"Windows\")
# Use mingw 64-bit compilers.
set(CMAKE_C_COMPILER \"x86_64-w64-mingw32-gcc-posix\")
set(CMAKE_CXX_COMPILER \"x86_64-w64-mingw32-c++-posix\")
set(CMAKE_RC_COMPILER \"x86_64-w64-mingw32-windres\")
set(CMAKE_RANLIB \"x86_64-w64-mingw32-ranlib\")
set(CMAKE_FIND_ROOT_PATH \"/usr/x86_64-w64-mingw32\")
# Adjust the default behavior of the find commands:
# search headers and libraries in the target environment
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
# Search programs in the host environment
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
")
		# When the ccache package and executable is installed use it in the tool-chain file.
		# The configuration file is at '~/.config/ccache/ccache.conf' and command 'ccache -p' shows it.
		find_program(_CcacheExe "ccache")
		if (_CcacheExe)
			file(APPEND "${_CmakeFile}" "set(CMAKE_C_COMPILER_LAUNCHER \"${_CcacheExe}\")\n")
			file(APPEND "${_CmakeFile}" "set(CMAKE_CXX_COMPILER_LAUNCHER \"${_CcacheExe}\")\n")
		endif ()
		# Cygwin compilers.
		if (False)
			file(APPEND "${_CmakeFile}" "set(CMAKE_SYSTEM_NAME \"Windows\")
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
		# Report that a toolset was given but not
	else ()
		message(SEND_ERROR "Toolset '${SF_COMPILER}' is unknown for host system '${CMAKE_HOST_SYSTEM_NAME}'!")
	endif ()
	# Set the SF_ARCHITECTURE cache variable.
	set(SF_ARCHITECTURE "${_Arch}" PARENT_SCOPE)
	# Assign the tool chain.
	set(CMAKE_TOOLCHAIN_FILE "${_CmakeFile}" PARENT_SCOPE)
endfunction()

# Make it happen.
Sf_SetToolChain()