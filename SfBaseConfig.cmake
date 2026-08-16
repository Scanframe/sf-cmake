# Required first entry checking the cmake version.
cmake_minimum_required(VERSION 3.29...4.4)
##!
# Declare some cmake flags for decisions on building targets.
#
set(SF_COMPILER "gnu" CACHE STRING "Selected compiler for the build which default to 'gnu' and could be 'ga', 'gw', 'mingw'.")
set(SF_BUILD_TESTING "OFF" CACHE BOOL "Enable test targets to be build.")
set(SF_BUILD_QT "OFF" CACHE BOOL "Enable QT targets to be build.")
set(SF_BUILD_GUI_TESTING "OFF" CACHE BOOL "Enable testing of tests using the GUI.")
set(SF_TEST_NAME_PREFIX "t_" CACHE STRING "Prefix for test applications to allow skipping when packaging.")
set(SF_COVERAGE_ONLY_TARGETS "" CACHE STRING "Only targets for coverage when developing locally to speed up.")
# Internal used variables.
set(SF_ARCHITECTURE "x86_64" CACHE INTERNAL "Determines the architecture of the build and is determined by the tool chain selection for the set compiler.")
set(SF_COMMON_LIB_DIR "${CMAKE_SOURCE_DIR}/lib" CACHE INTERNAL "Location of common binary libraries to be unpacked into.")
set(SF_NEXUS_SHARED_LIBS "https://nexus.scanframe.com/repository/shared/library" CACHE INTERNAL "Nexus repository server for downloads of libraries.")
set(SF_EXAMPLE_DIR "${CMAKE_BINARY_DIR}/.examples" CACHE INTERNAL "Directory to copy or symlink files in for examples in documentation.")
set(SF_DOCKER "FALSE" CACHE INTERNAL "Flag set when in running in Docker or Wine in Docker.")
set(SF_CPACK_PREPARE_FILE "${CMAKE_CURRENT_LIST_DIR}/tpl/cpack/prepare.cmake" CACHE STRING "Preparation script for running CPack project script.")
set(CMAKE_INSTALL_DEFAULT_COMPONENT_NAME "runtime")

##!
# FetchContent_MakeAvailable was not added until CMake 3.14; use our shim
#
if (${CMAKE_VERSION} VERSION_LESS 3.14)
	macro(FetchContent_MakeAvailable NAME)
		FetchContent_GetProperties(${NAME})
		if (NOT ${NAME}_POPULATED)
			FetchContent_Populate(${NAME})
			add_subdirectory(${${NAME}_SOURCE_DIR} ${${NAME}_BINARY_DIR})
		endif ()
	endmacro()
endif ()

##!
# Prints the current callstack.
#
function(Sf_PrintStack)
	message(STATUS "--- Current Call Stack ---")
	# Loop through the function names in the stack
	foreach (_func IN LISTS CMAKE_CURRENT_FUNCTION_STACK)
		message(STATUS "  ++Called: ${_func}")
	endforeach ()
endfunction()

##!
# Fix for an optional argument in a nested function where a variable ARGV4 when not passed
# as an argument has the value of the parent function.
#  @param _OutVar Name of the output variable returning the value which is not defined in the parent scope when
#     the index is out of range. Use 'if (DEFINED _MyArg)' to check it.
#  @param _Index Index value into the list of additional arguments.
#  @param _Argn List of additional arguments of set with "${ARGN}" by the calling function.
#
function(Sf_GetOptionalArgument _VarOut _Index _Argn)
	list(LENGTH _Argn _Length)
	if (_Index LESS _Length)
		list(GET _Argn ${_Index} _Value)
		set(${_VarOut} "${_Value}" PARENT_SCOPE)
	endif ()
endfunction()

##!
# Gets all sub directories which optionally match the passed regex.
# @param _VarOut Output variable.
# @param _Directory Directory to search in.
# @param _MatchStr Optional: Regular expression.
#
function(Sf_GetSubDirectories _VarOut _Directory)
	Sf_GetOptionalArgument(_MatchStr 0 "${ARGN}")
	file(GLOB _children RELATIVE "${_Directory}" "${_Directory}/*")
	set(_List "")
	foreach (_child ${_children})
		if (IS_DIRECTORY "${_Directory}/${_child}")
			if (NOT DEFINED _MatchStr OR "${_child}" MATCHES "${_MatchStr}")
				list(APPEND _list "${_child}")
			endif ()
		endif ()
	endforeach ()
	set(${_VarOut} ${_list} PARENT_SCOPE)
endfunction()

##!
# Maps the passed UNC path to a mounted drive share when it exists.
# It uses an external PowerShell script to perform it.
#
function(Sf_Unc2DrivePath _InPath _OutVar)
	# Only Windows can use this function.
	if (NOT "${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows")
		# For Linux passthrough the in to out variable..
		set(_result "${_InPath}")
	else ()
		# Check if the environment var exists telling us that cmake is running on Windows.
		if (EXISTS "$ENV{ComSpec}")
			set(_Command "PowerShell.exe")
			string(REPLACE "/" "\\" _script "${SfMacros_DIR}/bin/Unc2DrivePath.ps1")
			execute_process(COMMAND "${_Command}" -ExecutionPolicy Bypass "${_script}" "${_InPath}" OUTPUT_VARIABLE _result RESULT_VARIABLE _ExitCode)
		endif ()
		# Validate the exit code.
		if (_ExitCode GREATER "0")
			message(SEND_ERROR "Failed execution of script: ${_Script}")
		endif ()
	endif ()
	set("${_OutVar}" "${_result}" PARENT_SCOPE)
endfunction()

##!
# Compatible replacement of function 'get_filename_component()'.
# Resolves problem with Windows getting a UNC path from a drive mapped share
# when requesting 'REALPATH' component.
#
function(Sf_GetFilenameComponent _out_var _file_path _component)
	# Optional ARGS
	set(_options)
	set(_oneValueArgs)
	set(_multiValueArgs)
	cmake_parse_arguments(GFC "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})
	# Call the original.
	if (GFC_CACHE)
		get_filename_component(_result "${_file_path}" ${_component} CACHE)
	else ()
		get_filename_component(_result "${_file_path}" ${_component})
	endif ()
	# When the component is 'REALPATH' cmake 4.x returns the UNC path instead of the passed drive.
	if (
		# Issue only is in CMake v4.0.0.
		CMAKE_VERSION VERSION_GREATER_EQUAL "4.0.0" AND
		_component STREQUAL "REALPATH" AND
		# This can only happen in Windows.
		_result MATCHES "^//" AND _file_path MATCHES "^[A-Z]:"
	)
		Sf_Unc2DrivePath("${_result}" _result)
	endif ()
	# Set the output variable in the parent scope.
	set(${_out_var} "${_result}" PARENT_SCOPE)
endfunction()

##!
# Checks if the required passed file exists.
# When not a useful fatal message is produced.
#
function(Sf_CheckFileExists _File)
	if (NOT EXISTS "${_File}")
		message(SEND_ERROR "The file \"${_File}\" does not exist. Check order of dependent add_subdirectory(...).")
	endif ()
endfunction()

##!
# Appends the passed relative directory to the CMAKE_PREFIX_PATH.
# When the directory does not exist it bails out with a fatal error.
#
function(Sf_AppendCmakePrefixPath _Dir)
	Sf_GetFilenameComponent(_RealDir "${CMAKE_CURRENT_LIST_DIR}/${_Dir}" REALPATH)
	if (EXISTS "${_RealDir}")
		set(_path "${CMAKE_PREFIX_PATH}")
		list(APPEND _path "${_RealDir}")
		set(CMAKE_PREFIX_PATH "${_path}" PARENT_SCOPE)
	else ()
		message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}(): Directory '${_Dir}' not found! ")
	endif ()
endfunction()

##!
# Gets the safe filename version of the current or passed architecture.
# @param _OutVar Resulting architecture name.
# @param _Arch  Optional architecture string.
#
function(Sf_GetSafeArchitectureName _OutVar)
	# Default to the host system processor if no argument is passed
	Sf_GetOptionalArgument(_Arch 0 "${ARGN}")
	if (NOT DEFINED _Arch)
		set(_Arch "${CMAKE_SYSTEM_PROCESSOR}")
	endif ()
	# Normalize to lowercase.
	string(TOLOWER "${_Arch}" _arch_lower)
	# Map the architecture to a file-safe naming convention.
	if (_arch_lower STREQUAL "x86_64" OR _arch_lower STREQUAL "amd64")
		set(_arch_safe "amd64")
	elseif (_arch_lower STREQUAL "aarch64" OR _arch_lower STREQUAL "arm64")
		set(_arch_safe "arm64")
	elseif (_arch_lower STREQUAL "armv7l" OR _arch_lower STREQUAL "armv8l")
		set(_arch_safe "armv7")
	elseif (_arch_lower STREQUAL "armv6l")
		set(_arch_safe "armv6")
	elseif (_arch_lower MATCHES "i.86" OR _arch_lower STREQUAL "x86" OR _arch_lower STREQUAL "386")
		set(_arch_safe "i386")
	elseif (_arch_lower STREQUAL "ppc64le" OR _arch_lower STREQUAL "ppc64el")
		set(_arch_safe "ppc64le")
	elseif (_arch_lower STREQUAL "s390x")
		set(_arch_safe "s390x")
	elseif (_arch_lower STREQUAL "riscv64")
		set(_arch_safe "riscv64")
	else ()
		# Fallback safety: Replace any underscores or slashes with hyphens.
		string(REPLACE "_" "-" _arch_lower "${_arch_lower}")
		string(REPLACE "/" "-" _arch_safe "${_arch_lower}")
	endif ()
	# Pass the value back up to the parent scope
	set(${_OutVar} "${_arch_safe}" PARENT_SCOPE)
endfunction()

##!
# Gets the version from the Git repository using 'PROJECT_SOURCE_DIR' variable.
# Always returns a versions list where per index:
# 1: Actual version
# 2: Release-candidate number
# 3: Diverted commits since the tag was created.
# 3: A hash ???
# When no tag is set it simulates finding 'v0.0.0-rc.0' as the version tag.
#
function(Sf_GetGitTagVersion _VarOut _SrcDir)
	# Initialize return value.
	set(${_VarOut} "" PARENT_SCOPE)
	# Get git binary location for execution.
	find_program(_GitExe "git" PATHS "$ENV{SYSTEMDRIVE}/cygwin64/bin")
	if (NOT _GitExe)
		message(SEND_ERROR "Git program not found!")
	endif ()
	if ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows")
		# Get the toplevel directory of this repository or submodule.
		# This is faster then the other call and cache the version result to speed configuration up.
		execute_process(COMMAND
			"${_GitExe}" rev-parse --show-toplevel
			# Use the current project directory to find.
			WORKING_DIRECTORY "${_SrcDir}"
			OUTPUT_VARIABLE _FilePath
			RESULT_VARIABLE _ExitCode
			ERROR_VARIABLE _ErrorText
			ECHO_ERROR_VARIABLE
			OUTPUT_STRIP_TRAILING_WHITESPACE
		)
		# Replace the directory separators from the filepath.
		string(REPLACE "/" "-" _FilePath "${_FilePath}")
		# Prefix the file with the path.
		set(_FilePath "${CMAKE_BINARY_DIR}/git-cache/ver${_FilePath}")
		# Check if the cache file exists.
		if (NOT EXISTS "${_FilePath}")
			# Only annotated tags so no '--tags' option.
			execute_process(COMMAND
				#"${_GitExe}" rev-parse --show-toplevel
				"${_GitExe}" describe --dirty --match "v*.*.*"
				# Use the current project directory to find.
				WORKING_DIRECTORY "${_SrcDir}"
				OUTPUT_VARIABLE _Version
				RESULT_VARIABLE _ExitCode
				ERROR_VARIABLE _ErrorText
				OUTPUT_STRIP_TRAILING_WHITESPACE
				ERROR_STRIP_TRAILING_WHITESPACE
			)
			# Do not cache an empty version to file.
			if (NOT _Version STREQUAL "")
				# Write the cache file.
				file(WRITE "${_FilePath}" "${_Version}")
				# Notify the that a cache version is used.
				message(STATUS "${CMAKE_CURRENT_FUNCTION}(): Creating cache version (${_Version})")
			endif ()
		else ()
			# Read the cache file.
			file(READ "${_FilePath}" _Version)
		endif ()
	else ()
		# Only annotated tags so no '--tags' option.
		execute_process(COMMAND "${_GitExe}" -C "${_SrcDir}" describe --dirty --match "v*.*.*"
			# Use the current project directory to find.
			WORKING_DIRECTORY "${_SrcDir}"
			OUTPUT_VARIABLE _Version
			RESULT_VARIABLE _ExitCode
			ERROR_VARIABLE _ErrorText
			OUTPUT_STRIP_TRAILING_WHITESPACE
			ERROR_STRIP_TRAILING_WHITESPACE
		)
	endif ()
	# Check the exist code for an error.
	if (_ExitCode GREATER 0)
		message(VERBOSE "Repository '${_SrcDir}' not having a version tag like 'v1.2.3' or 'v1.2.3-rc.4 ?!")
		message(VERBOSE "${_GitExe} describe --dirty --match v* ... Exited with (${_ExitCode}). '${_ErrorText}'")
		# Set an initial version to allow continuing.
		set(_Version "v0.0.0-rc.0-dirty")
	endif ()
	# Regular expression getting all elements.
	set(_RegEx "^v([0-9]+\\.[0-9]+\\.[0-9]+)(-rc\\.?([0-9]+))?(-([0-9]+)?(-([a-z0-9]+))?)?(-dirty)?$")
	#[[
	Matching possible different results to match.
	v1.2.3-rc.4-56-78abcdef-dirty
	v0.0.1-42-g914edbb-dirty
	v0.1.1-rc.9-dirty
	v0.1.1-rc.9-12
	v0.1.2-dirty
	v0.1.1
	Group 1 > Version          : 1.2.3
	Group 3 > Release Candidate: 4f4d0976ac5eb0a07889f1913f38d66127f3b9abe
	Group 5 > Commits since tag: 56
	Group 7 > Hash of some sort: 78abcdef
	]]
	string(REGEX MATCH "${_RegEx}" _Dummy_ "${_Version}")
	if ("${CMAKE_MATCH_1}" STREQUAL "")
		message(WARNING "Git returned tag '${_Version}' from '${_SrcDir}' does not match regex '${_RegEx}' !")
		set(${_VarOut} "0;0;0;0" PARENT_SCOPE)
	else ()
		# Make a list of the versions.
		set(${_VarOut} "${CMAKE_MATCH_1}" "${CMAKE_MATCH_3}" "${CMAKE_MATCH_5}" "${CMAKE_MATCH_7}" PARENT_SCOPE)
	endif ()
endfunction()

##!
# Reports the version retrieved with Sf_GetGitTagVersion().
#
function(Sf_ReportGitTagVersion _Versions)
	# Split the list into separate values.
	list(GET _Versions 0 _Version)
	list(GET _Versions 1 _ReleaseCandidate)
	list(GET _Versions 2 _CommitOffset)
	set(_List "Git Tag;Version: ${_Version}")
	if (NOT _ReleaseCandidate STREQUAL "")
		list(APPEND _List "Release-Candidate: ${_ReleaseCandidate}")
	endif ()
	if (NOT _CommitOffset STREQUAL "")
		list(APPEND _List "Commit-Offset: ${_CommitOffset}")
	endif ()
	list(JOIN _List "\n\t" _List)
	message(STATUS "${_List}")
endfunction()

##!
# Set the target linker and compile options depending on the compiler ID and 'CMAKE_BUILD_TYPE' variable.
#
function(Sf_SetTargetDefaultOptions _Target)
	# Get the target's type.
	get_target_property(_Type "${_Target}" TYPE)
	# When the GNU compiler is involved.
	if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
		# Workaround for Catch2 which does not allow us to set the compiler switch (-fvisibility=hidden) globally.
		target_compile_options("${_Target}" PRIVATE "-fvisibility=hidden")
		# Generate an error on undefined (imported) symbols on dynamic libraries
		# because the error appears only at load-time otherwise.
		target_link_options("${_Target}" PRIVATE -Wl,--no-undefined -Wl,--no-allow-shlib-undefined)
		# Set options depending on the build type.
		if (CMAKE_BUILD_TYPE STREQUAL "Release")
			# This bellow could also be the default already.
			target_compile_options("${_Target}" PRIVATE -O3 -DNDEBUG)
		elseif (CMAKE_BUILD_TYPE STREQUAL "Debug")
			# Nothing specific yet.
		elseif (CMAKE_BUILD_TYPE STREQUAL "Coverage")
			# Targets get compile options assigned when added using Sf_AddTargetForCoverage() function.
		else ()
			message(AUTHOR_WARNING "The current build type '${CMAKE_BUILD_TYPE}' is not covered yet for compiler '${CMAKE_CXX_COMPILER_ID}'!")
		endif ()
		# When compiling a Windows target.
		if (WIN32)
			# Needed for Windows since Catch2 is creating a huge obj file.
			target_compile_options("${_Target}" PRIVATE -m64 -Wa,-mbig-obj)
			# Needed to suppress warnings since MinGW seems to need inline in class methods later redeclared as inline.
			target_compile_options("${_Target}" PRIVATE -Wno-attributes -Wignored-attributes)
		else ()
			# For detecting memory errors.
			target_compile_options("${_Target}" PRIVATE --pedantic-errors #[[-fsanitize=address]])
		endif ()
		# When MSVC compiler is used set some options.
	elseif (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
		# Set options depending on the build type.
		if (CMAKE_BUILD_TYPE STREQUAL "Release")
			# This bellow could also be the default already.
			#target_compile_options("${_Target}" PRIVATE "-O3 -DNDEBUG")
		elseif (CMAKE_BUILD_TYPE STREQUAL "Debug")
			#[[
						# When compiling with MSVC in Wine and the target is a dynamic library.
						if (DEFINED ENV{WINE_HOST_HOME})
							message(STATUS "Forces MSVC to link standard Release runtimes on target: ${_Target}")
							# Use the multithread-specific and DLL-specific version of the runtime library.
							# Defines _MT and _DLL. The linker uses the MSVCRT.lib import library to resolve runtime symbols.
							if (_Type STREQUAL "SHARED_LIBRARY")
								set_target_properties("${_Target}" PROPERTIES MSVC_RUNTIME_LIBRARY "MultiThreadedDLL")
							elseif (_Type STREQUAL "EXECUTABLE")
								set_target_properties("${_Target}" PROPERTIES MSVC_RUNTIME_LIBRARY "MultiThreaded")
							endif ()
						endif ()
			]]
			#target_compile_options("${_Target}" PRIVATE "-Zc:__cplusplus")
		elseif (CMAKE_BUILD_TYPE STREQUAL "Coverage")
			# Targets get compile options assigned when added using Sf_AddTargetForCoverage() function.
		else ()
			message(AUTHOR_WARNING "The current build type '${CMAKE_BUILD_TYPE}' is not covered yet for compiler '${CMAKE_CXX_COMPILER_ID}'!")
		endif ()
	endif ()
endfunction()

##!
# Sets the passed target version property when not set already.
# The order in which the version is retrieved:
# * Git version tag from source
# * Sub-Project
# * Main-Project
# * Skipped when none of the above were set.
#
function(Sf_SetTargetVersion _Target)
	# Get the type of the target.
	get_target_property(_Type ${_Target} TYPE)
	# Only in Linux SOVERSION makes sense.
	if ("${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")
		# Do not want symlink like SO-file.
		if (_Type STREQUAL "EXECUTABLE")
			get_target_property(_Version "${_Target}" SOVERSION)
		else ()
			get_target_property(_Version "${_Target}" VERSION)
		endif ()
	else ()
		# Set the target version properties for Windows.
		get_target_property(_Version "${_Target}" SOVERSION)
	endif ()
	if (_Version)
		message(VERBOSE "Target '${_Target}' skipping, version already set to (${_Version})")
		return()
	endif ()
	# Get versions from Git when possible.
	Sf_GetGitTagVersion(_Versions "${CMAKE_CURRENT_SOURCE_DIR}")
	list(GET _Versions 0 _Version)
	# Prepend a text to message function.
	list(APPEND CMAKE_MESSAGE_INDENT "Target '${_Target}' version set from ")
	# Check if the git version was found.
	if (NOT "${_Version}" STREQUAL "0.0.0")
		# Get only the sub directory to report where Git got its version from.
		string(LENGTH "${CMAKE_SOURCE_DIR}/" _Length)
		string(SUBSTRING "${CMAKE_CURRENT_SOURCE_DIR}" "${_Length}" -1 _SubDir)
		message(VERBOSE "Git tag at '${_SubDir}' (${_Version})")
		# Check the sub-project version has been set.
	elseif (DEFINED PROJECT_VERSION AND NOT PROJECT_VERSION STREQUAL "")
		set(_Version "${PROJECT_VERSION}")
		message(VERBOSE "Sub-Project '${PROJECT_NAME}' (${_Version})")
		# Check the main-project version is set.
	elseif (DEFINED CMAKE_PROJECT_VERSION AND NOT "${CMAKE_PROJECT_VERSION}" STREQUAL "")
		set(_Version "${CMAKE_PROJECT_VERSION}")
		message(VERBOSE "Main-Project '${CMAKE_PROJECT_NAME}' (${_Version})")
	else ()
		# Clear the version variable.
		set(_Version "")
		message(VERBOSE "None")
	endif ()
	list(POP_BACK CMAKE_MESSAGE_INDENT)
	# When the version string was resolved apply the properties.
	if (NOT "${_Version}" STREQUAL "")
		# Only in Linux SOVERSION makes sense.
		if ("${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")
			# Do not want symlink like SO-file.
			if (_Type STREQUAL "EXECUTABLE")
				set_target_properties("${_Target}" PROPERTIES SOVERSION "${_Version}")
			else ()
				# Get the major version
				string(REGEX REPLACE "^([0-9]+)\\..*" "\\1" _MajorVersion "${_Version}")
				# Set the target version properties for Linux.
				set_target_properties("${_Target}" PROPERTIES VERSION "${_Version}" SOVERSION "${_MajorVersion}")
			endif ()
		else ()
			# Set the target version properties for Windows.
			set_target_properties("${_Target}" PROPERTIES SOVERSION "${_Version}")
		endif ()
	endif ()
endfunction()

##!
# Gets the output path of the given target at configure time.
#
function(Sf_GetTargetOutputPath _target _result)
	get_target_property(_out_name ${_target} OUTPUT_NAME)
	get_target_property(_out_suffix "${_target}" SUFFIX)
	get_target_property(_out_dir ${_target} RUNTIME_OUTPUT_DIRECTORY)
	if (NOT _out_dir)
		set(_out_dir "${CMAKE_CURRENT_BINARY_DIR}")
	endif ()
	if (NOT _out_name)
		set(_out_name "${_target}")
	endif ()
	set(${_result} "${_out_dir}/${_out_name}${_out_suffix}" PARENT_SCOPE)
endfunction()

##!
# Adds an executable application target and also sets the default compile options.
#
function(Sf_AddExecutable _Target)
	# Add the executable.
	add_executable("${_Target}")
	# Set the default compiler options for our own code only.
	Sf_SetTargetDefaultOptions("${_Target}")
	# Set the version of this target.
	Sf_SetTargetVersion("${_Target}")
endfunction()

##!
# Adds a dynamic library target and sets the version number.
# For Windows builds the library output directory is set the
# same as when build for Linux.
#
function(Sf_AddSharedLibrary _Target)
	# Add the library to create.
	add_library("${_Target}" SHARED)
	# Set the default compiler options for our own code only.
	Sf_SetTargetDefaultOptions("${_Target}")
	# Set the version of this target.
	Sf_SetTargetVersion("${_Target}")
	# In Windows builds the output directory for libraries is ignored and the runtime is used and is now corrected.
	if (WIN32)
		set_target_properties("${_Target}" PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
	endif ()
endfunction()

##!
# Adds an exif custom target for reporting the resource stored versions.
#
function(Sf_AddExifTarget _Target)
	# Windows only knows the 'python' command.
	find_program(_PythonExe "python3" "python" REQUIRED)
	if (_PythonExe)
		add_custom_target("exif-${_Target}" ALL
			COMMAND "${_PythonExe}" "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/bin/exiftool.py" $<SHELL_PATH:$<TARGET_FILE:${_Target}>>
			WORKING_DIRECTORY "$<TARGET_FILE_DIR:${_Target}>"
			DEPENDS "$<TARGET_FILE:${_Target}>"
			COMMENT "Resource information: $<TARGET_FILE:${_Target}>"
			VERBATIM
		)
		add_dependencies("exif" "exif-${_Target}")
	endif ()
endfunction()

##!
# Add version resource 'resource.rc' to be compiled by passed target.
#
function(Sf_AddVersionResource _Target)
	get_target_property(_Version "${_Target}" SOVERSION)
	get_target_property(_Type "${_Target}" TYPE)
	if (_Type STREQUAL "EXECUTABLE")
		get_target_property(_OutputName "${_Target}" OUTPUT_NAME)
	elseif (_Type STREQUAL "SHARED_LIBRARY")
		get_target_property(_OutputName "${_Target}" LIBRARY_OUTPUT_NAME)
	endif ()
	# Check if _OutputName was set.
	if (NOT _OutputName)
		message(SEND_ERROR "For target '${_Target}', a call to Sf_SetTargetSuffix() must preceded ${CMAKE_CURRENT_FUNCTION}()!")
	endif ()
	get_target_property(_OutputSuffix "${_Target}" SUFFIX)
	string(REPLACE "." "," RC_WindowsFileVersion "${_Version},0")
	set(RC_WindowsProductVersion "${RC_WindowsFileVersion}")
	set(RC_FileVersion "${_Version}")
	set(RC_ProductVersion "${RC_FileVersion}")
	set(RC_FileDescription "${CMAKE_PROJECT_DESCRIPTION}")
	set(RC_ProductName "${CMAKE_PROJECT_DESCRIPTION}")
	set(RC_OriginalFilename "${_OutputName}${_OutputSuffix}")
	set(RC_InternalName "${_OutputName}${_OutputSuffix}")
	set(RC_Compiler "${CMAKE_HOST_SYSTEM} ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
	string(TIMESTAMP RC_BuildDateTime "%Y-%m-%dT%H:%M:%SZ" UTC)
	if (NOT DEFINED SF_COMPANY_NAME)
		set(RC_CompanyName "Unknown")
	else ()
		set(RC_CompanyName "${SF_COMPANY_NAME}")
	endif ()
	set(_HomepageUrl "${HOMEPAGE_URL}")
	set(RC_Comments "Build on '${CMAKE_HOST_SYSTEM_NAME} ${CMAKE_HOST_SYSTEM_PROCESSOR} ${CMAKE_HOST_SYSTEM_VERSION}' (${CMAKE_PROJECT_HOMEPAGE_URL})")
	# Set input and output files for the generation of the actual config file.
	set(_FileIn "${SfBase_DIR}/tpl/res/version.rc")
	# MAke sure the file exists.
	Sf_CheckFileExists("${_FileIn}")
	# Assemble the file out.
	set(_FileOut "${CMAKE_CURRENT_BINARY_DIR}/version.rc")
	# Generate the configure the file for the resource.
	configure_file("${_FileIn}" "${_FileOut}" @ONLY NEWLINE_STYLE LF)
	#
	target_sources("${_Target}" PRIVATE "${_FileOut}")
endfunction()

##!
# Get all added targets in all subdirectories.
#  @param _result The list containing all found targets
#  @param _dir Root directory to start looking from
#  @param _inc_deps Include dependencies TRUE or FALSE.
#
function(Sf_GetAllTargets _result _dir _inc_deps)
	# Get the length of the name to skip.
	string(LENGTH "${FETCHCONTENT_BASE_DIR}" _length)
	get_property(_subdirs DIRECTORY "${_dir}" PROPERTY SUBDIRECTORIES)
	foreach (_subdir IN LISTS _subdirs)
		string(SUBSTRING "${_subdir}" 0 ${_length} _tmp)
		if (NOT _inc_deps AND _tmp STREQUAL FETCHCONTENT_BASE_DIR)
			#message(NOTICE "Skipping: ${_subdir}")
			continue()
		endif ()
		Sf_GetAllTargets(${_result} "${_subdir}" ${_inc_deps})
	endforeach ()
	get_directory_property(_sub_targets DIRECTORY "${_dir}" BUILDSYSTEM_TARGETS)
	set(${_result} ${${_result}} ${_sub_targets} PARENT_SCOPE)
endfunction()

##!
# Gets the include directories from the given targets.
# When not found it returns "${_VarOut}-NOTFOUND"
# @param _var Variable receiving resulting list of include directories.
# @param _targets Build targets to get the include directories from.
#
function(Sf_GetIncludeDirectories _var _targets)
	set(_list "")
	# Iterate through the passed list of build targets.
	foreach (_target IN LISTS _targets)
		# Get the source directory from the target.
		#get_target_property(_srcdir "${_target}" SOURCE_DIR)
		# Get all the include directories from the target.
		get_target_property(_incdirs "${_target}" INCLUDE_DIRECTORIES)
		# Check if there are include directories for this target.
		if (NOT _incdirs)
			#message("The '${_target}' has no includes...")
			continue()
		endif ()
		# Get for each include directory...
		foreach (_incdir IN LISTS _incdirs)
			# The real path by combining the source dir and in dir.
			Sf_GetFilenameComponent(_dir "${_incdir}" REALPATH)
			# Append the real directory to the resulting list.
			list(APPEND _list "${_dir}/")
		endforeach ()
	endforeach ()
	# Remove any duplicates directories from the list but sorting is needed first before removing duplicates.
	list(SORT _list)
	list(REMOVE_DUPLICATES _list)
	# Assign the list to the passed resulting variable.
	set(${_var} ${_list} PARENT_SCOPE)
endfunction()

##!
# Gets the header files the given targets.
# When not found it returns "${_VarOut}-NOTFOUND"
# @param _var Variable receiving resulting list of include directories.
# @param _targets Build targets to get the include directories from.
# @param _targets Build targets to get the include directories from.
# @param _rel_to_dir Build targets to get the include directories from.
#
function(Sf_GetSourceFiles _var _targets #[[_rel_to_dir]])
	set(_list)
	# Iterate through the passed list of build targets.
	foreach (_target IN LISTS _targets)
		# Get the source directory from the target.
		#get_target_property(_srcdir "${_target}" SOURCE_DIR)
		# Get all the include directories from the target.
		get_target_property(_sources "${_target}" SOURCES)
		get_target_property(_source_dir "${_target}" SOURCE_DIR)
		# Check if there are sources for this target '_sources-NOTFOUND'.
		if (NOT _sources)
			continue()
		endif ()
		# Fix for nexted problem of ARGVn variables.
		Sf_GetOptionalArgument(_arg2 0 "${ARGN}")
		# Prepend source directory for each source file.
		foreach (_file IN LISTS _sources)
			if (DEFINED _arg2)
				if (IS_ABSOLUTE "${_file}")
					file(RELATIVE_PATH _file "${_arg2}" "${_file}")
				else ()
					file(RELATIVE_PATH _file "${_arg2}" "${_source_dir}/${_file}")
				endif ()
			else ()
				set(_file "${_source_dir}/${_file}")
			endif ()
			list(APPEND _list "${_file}")
		endforeach ()
	endforeach ()
	# Remove any duplicates from the list but sorting is needed first before removing duplicates.
	list(SORT _list)
	list(REMOVE_DUPLICATES _list)
	# Assign the list to the passed resulting variable.
	set(${_var} "${_list}" PARENT_SCOPE)
endfunction()

##!
# Waits until the files are actually available.
# @param _DepName Dependency name passed to FetchContent_Declare().
# @param _Timeout Amount of seconds to wait until timeout failure.
#
function(Sf_FetchContent_MakeAvailable _DepName _Timeout)
	# Initialize the flag
	set(_Populated False)
	set(_DepDir "")
	set(_SleepTime 0.2)
	set(_LoopsPerSec 5)
	# Calculate the max amount of loops allowed. Some ho
	math(EXPR _Loops "${_Timeout} * ${_LoopsPerSec}")
	# Populate the library and wait for it.
	FetchContent_Populate("${_DepName}")
	while (NOT ${_Populated})
		# Notify waiting for population of content.
		message(STATUS "[${_Loops}] Waiting for '${_DepName}' to populate...")
		# Generic sleep command of CMake itself.
		execute_process(COMMAND ${CMAKE_COMMAND} -E sleep ${_SleepTime})
		# Get the population flag of the content.
		FetchContent_GetProperties("${_DepName}" POPULATED _Populated)
		# Check if populated and continue to check if actually true.
		if (${_Populated})
			# Get the unpacked location of the content.
			FetchContent_GetProperties("${_DepName}" SOURCE_DIR _DepDir)
			# When the directory is not yet available the content is not either.
			if (NOT EXISTS "${_DepDir}")
				# Wait some longer to unpack fully.
				execute_process(COMMAND ${CMAKE_COMMAND} -E sleep ${_SleepTime})
				# Notify waiting for population of content.
				message(STATUS "[${_Loops}] Almost there for '${_DepName}' content to be available in '${_DepDir}'...")
				# Reset the flag. Populating needs more time.
				set(_Populated False)
			endif ()
			# Decrement the loops variable.
			math(EXPR _Loops "${_Loops} - 1")
			if (${_Loops} LESS_EQUAL 0)
				message(SEND_ERROR "[${_Loops}] Populating '${_DepName}' took more then the given '${_Timeout}s'!")
			endif ()
		endif ()
	endwhile ()
endfunction()


##!
# Increments the patch component of a semantic version.
#
# The input version must use the format MAJOR.MINOR.PATCH.
# For example, 6.10.1 becomes 6.10.2.
#
# @param _Version  Name of the variable containing the input version.
# @param _OutVar Name of the variable receiving the incremented version.
#
function(Sf_IncrementPatchVersion _Version _OutVar)
	if (NOT "${_Version}" MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
		message(FATAL_ERROR "Invalid semantic version '${_Version}'.")
	endif ()
	math(EXPR _patch "${CMAKE_MATCH_3} + 1")
	set(${_OutVar} "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${_patch}" PARENT_SCOPE)
endfunction()

##!
# Calls native add_test() function using start scripts to set the library paths for Windows/Wine and Linux.
# @param _Target Name of the target.
# @param _Labels Optional labels for test execution selection.
#
function(Sf_AddTest _Target)
	# Invoke a script when cross-compiling which makes normal test debugging not possible which is the case anyway.
	# Somehow CMAKE_CROSSCOMPILING is not having the correct value at this point so SF_CROSSCOMPILING is used.
	if (SF_CROSSCOMPILING)
		# When target is a Windows build.
		if (WIN32)
			set(_Script "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/bin/WineExec.sh")
		else ()
			# When NOT compiling Windows assume Linux build and use a shell script.
			set(_Script "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/bin/LinuxExec.sh")
		endif ()
		# TODO: Property 'CROSSCOMPILING_EMULATOR' seems not to be working.
		#set_target_properties(my_exe PROPERTIES CROSSCOMPILING_EMULATOR "/usr/bin/qemu-arm;-L;/usr/arm-linux-gnueabihf")
		# Add the test using a script setting correct paths for finding dynamic libraries and executing a different architecture.
		add_test(NAME "${_Target}"
			# Optional script when cross-compiling.
			COMMAND ${_Script} "$<TARGET_FILE_NAME:${_Target}>"
			# Ensure the working directory is its own location.
			WORKING_DIRECTORY "$<TARGET_FILE_DIR:${_Target}>"
			COMMAND_EXPAND_LISTS
		)
	else ()
		# Add the test using a script setting correct paths for finding dynamic libraries and executing a different architecture.
		add_test(NAME "${_Target}"
			# Optional script when cross-compiling.
			COMMAND "$<TARGET_FILE_NAME:${_Target}>"
			# Ensure the working directory is its own location.
			WORKING_DIRECTORY "$<TARGET_FILE_DIR:${_Target}>"
			COMMAND_EXPAND_LISTS
		)
	endif ()
	# Location of dynamic libraries.
	get_target_property(_LibDir "${_Target}" LIBRARY_OUTPUT_DIRECTORY)
	if (NOT _LibDir)
		# Check if global library output directory has been set.
		set(_LibDir "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
	endif ()
	if (_LibDir)
		if (WIN32)
			# For Windows prepend the PATH.
			set_tests_properties("${_Target}" PROPERTIES ENVIRONMENT_MODIFICATION "PATH=path_list_prepend:$<SHELL_PATH:${_LibDir}>")
		elseif (LINUX)
			# For Linux prepend/set the LD_LIBRARY_PATH in case it was build using Docker with a different RUNPATH.
			get_target_property(_LibDir "${_Target}" LIBRARY_OUTPUT_DIRECTORY)
			if (NOT _LibDir)
				set(_LibDir "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
			endif ()
			set_tests_properties("${_Target}" PROPERTIES ENVIRONMENT_MODIFICATION "LD_LIBRARY_PATH=path_list_prepend:$<SHELL_PATH:${_LibDir}>")
		endif ()
	endif ()
	# When the first optional argument is given use it to set labels.
	Sf_GetOptionalArgument(_Labels 0 "${ARGN}")
	# Test if the argument was passed.
	if (DEFINED _Labels)
		set_tests_properties("${_Target}" PROPERTIES LABELS "${_Labels}")
	endif ()
endfunction()

##!
# Adds the passed target for coverage only when the build type is 'Coverage'.
#
function(Sf_AddTargetForCoverage _target)
	# Set options only when the build type is coverage and the variable 'SF_COVERAGE_ONLY_TARGETS' is empty.
	if (CMAKE_BUILD_TYPE STREQUAL "Coverage" AND
	(
		SF_COVERAGE_ONLY_TARGETS STREQUAL "" OR _target IN_LIST SF_COVERAGE_ONLY_TARGETS
	))
		# Get the type of the target.
		get_target_property(_type "${_target}" TYPE)
		# When the GNU compiler is involved.
		if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
			message(STATUS "Target '${_target}' added for coverage.")
			# No optimization when compiling for coverage.
			target_compile_options("${_target}" BEFORE PRIVATE -g -O0 -coverage -fprofile-arcs -ftest-coverage)
			# Only add linking options for target types that are linked.
			if (_type STREQUAL "EXECUTABLE" OR _type STREQUAL "SHARED_LIBRARY")
				target_link_options("${_target}" BEFORE PRIVATE -coverage)
				# Probably superfluous since it is probably linked already using the option.
				target_link_libraries("${_target}" PRIVATE gcov)
			endif ()
		endif ()
	else ()
	endif ()
endfunction()

##!
# Adds a test to the list of tests producing coverage information in order to make
# the added test using 'Sf_AddTestCoverageReport()' be executed last using it as a dependency.
# Uses cache variable with force to store this information between project namespaces.
# _Test: The test name when empty will clear the cache entry.
#
function(Sf_AddAsCoverageTest _Test)
	if (BUILD_TESTING AND CMAKE_BUILD_TYPE STREQUAL "Coverage")
		if (_Test STREQUAL "")
			set(SF_COVERAGE_TESTS "")
		else ()
			list(APPEND SF_COVERAGE_TESTS "${_Test}")
		endif ()
		# Overwrite the cache value using FORCE.
		set(SF_COVERAGE_TESTS "${SF_COVERAGE_TESTS}" CACHE STRING "List of tests producing coverage information." FORCE)
	endif ()
endfunction()

##!
# Adds coverage target to the project when the build type is Coverage.
# _TestName      : The target name for the report.
#                  relative to the 'PROJECT_SOURCE_DIR'.
# _OutDir        : Output directory for the coverage report.
# _Options       : See script 'bin/coverage-report.sh' for options other then already by default used.
# _SourceDirList : List of relative directories to be included in the coverage report
#
function(Sf_AddTestCoverageReport _TestName _OutDir _Options _SourceDirList)
	# Get the actual output directory.
	Sf_GetFilenameComponent(_OutDir "${_OutDir}" REALPATH)
	# Check if the resulting directory exists.
	if (NOT EXISTS "${_OutDir}" OR NOT IS_DIRECTORY "${_OutDir}")
		message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Output directory '${_OutDir}' does not exist and needs to be created!")
	endif ()
	# Make a list from
	string(REPLACE " " ";" _Options "${_Options}")
	if (BUILD_TESTING AND CMAKE_BUILD_TYPE STREQUAL "Coverage")
		# Add a test to generate the report.
		add_test(NAME "${_TestName}"
			COMMAND "${SfBase_DIR}/bin/coverage-report.sh"
			# Set the coverage command of the tool chain.
			--gcov "${COVERAGE_COMMAND}"
			--source "${CMAKE_CURRENT_BINARY_DIR}"
			--target "${_OutDir}"
			${_Options}
			# Show some information while executing te script.
			#--verbose
			${_SourceDirList}
			WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
			COMMAND_EXPAND_LISTS
		)
		# Ensure this test is run after the ones adding coverage information.
		set_property(TEST "${_TestName}" PROPERTY DEPENDS "${SF_COVERAGE_TESTS}")
	endif ()
endfunction()

##!
# Adds a file to be accessible by Doxygen which allows a single directory for examples and no subdirectories.
# In a markdown the file is referenced as '[\@]snippet <prefix>/<file> <visible-name>'.
# _Files  : List of file used as examples.
# _Prefix : Prefix for the destination filename to prevent naming collisions.
#
# Code example for creating a by 'Data' referencable snipped:
#
# //! [Data]
#	int my_example_var = 0;
# //! [Data]
#
function(Sf_AddExamples _Files _Prefix)
	# Create the sample directory if it does not exists yet.
	if (NOT EXISTS "${SF_EXAMPLE_DIR}/${_Prefix}")
		file(MAKE_DIRECTORY "${SF_EXAMPLE_DIR}/${_Prefix}")
	endif ()
	foreach (_file IN LISTS _Files)
		# Extract the file name from the given file.
		Sf_GetFilenameComponent(_filename "${_file}" NAME)
		# Make a flat name of the filename replacing the slashes with a '-' character.
		string(REPLACE "/" "-" _filename "${_filename}")
		# When the file is relative prepend the list dir of the current project.
		if (NOT IS_ABSOLUTE _file)
			set(_file "${CMAKE_CURRENT_LIST_DIR}/${_file}")
		endif ()
		# Copy the file to the destination.
		file(COPY_FILE "${_file}" "${SF_EXAMPLE_DIR}/${_Prefix}/${_filename}")
	endforeach ()
endfunction()

##!
# Sets or appends the rpath property 'INSTALL_RPATH' for all compiled targets.
# @param _Path A path string like "\${ORIGIN}:\${ORIGIN}/lib".
#
function(Sf_SetRPath _Path)
	# Is a Linux only thing.
	if (WIN32)
		# When building for Windows using GNU report warnings on MSVC incompatibilities.
		#add_definitions(-D__MINGW_MSVC_COMPAT_WARNINGS)
		# Suppressing the warning that out-of-line inline functions are redeclared.
		#add_link_options(-Wno-inconsistent-dllimport)
	else ()
		# Using Cmake's way of RPATH.
		set(CMAKE_SKIP_BUILD_RPATH FALSE PARENT_SCOPE)
		set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE PARENT_SCOPE)
		#set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE PARENT_SCOPE)
		# Linker option -rpath is not working due to doubling of the '$' sign by CMAKE.
		#    add_link_options(-Wl,-rpath-link "\${ORIGIN\}")
		if (NOT DEFINED CMAKE_INSTALL_RPATH OR CMAKE_INSTALL_RPATH STREQUAL "")
			set(CMAKE_INSTALL_RPATH "${_Path}")
		else ()
			# When appending the RPATH remove duplicates.
			string(REPLACE ":" ";" _List "${CMAKE_INSTALL_RPATH}:${_Path}")
			list(REMOVE_DUPLICATES _List)
			list(JOIN _List ":" _List)
			set(CMAKE_INSTALL_RPATH "${_List}")
		endif ()
		# Set the parent scope version.
		set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_RPATH}" PARENT_SCOPE)
		# Report the resulting RPath.
		message(STATUS "Resulting RPATH: ${CMAKE_INSTALL_RPATH}")
	endif ()
endfunction()

##!
# Sets $ORIGIN-relative RUNPATH/RPATH properties on the given targets only.
#
# sf_SetRunPath([TARGETS <target1> [<target2> ...]] [REPORT])
#
# @param TARGETS Optional list of targets to process. If omitted, all
#        targets in the current project (via Sf_GetAllTargets) are used.
# @param REPORT  Optional flag. If given, prints the resulting BUILD_RPATH
#        and INSTALL_RPATH for each processed target.
#
function(sf_SetRunPath)
	set(_options REPORT)
	set(_one_value_args)
	set(_multi_value_args TARGETS)
	cmake_parse_arguments(PARSE_ARGV 0 _arg
		"${_options}" "${_one_value_args}" "${_multi_value_args}")
	if (_arg_UNPARSED_ARGUMENTS)
		message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Unknown arguments: ${_arg_UNPARSED_ARGUMENTS}")
	endif ()
	# No effect for Windows targets so bailout here after parsing the arguments.
	if (WIN32)
		return()
	endif ()
	# Fall back to all project targets when TARGETS was not given.
	if (DEFINED _arg_TARGETS)
		set(_targets "${_arg_TARGETS}")
	else ()
		Sf_GetAllTargets(_targets "${PROJECT_SOURCE_DIR}" "TRUE")
	endif ()
	foreach (_target IN LISTS _targets)
		set(_rpath)
		get_target_property(_type ${_target} TYPE)
		if (_type STREQUAL "EXECUTABLE")
			set(_var_name "RUNTIME")
			# Required in any case.
			list(APPEND _rpath "\$ORIGIN/lib")
		elseif (_type STREQUAL "SHARED_LIBRARY" OR _type STREQUAL "MODULE_LIBRARY")
			set(_var_name "LIBRARY")
			# Required in any case.
			list(APPEND _rpath "\$ORIGIN")
		else ()
			# static libs, interfaces: nothing to do
			continue()
		endif ()
		get_target_property(_rpath_build "${_target}" BUILD_RPATH)
		get_target_property(_rpath_install "${_target}" INSTALL_RPATH)
		get_target_property(_output_dir "${_target}" "${_var_name}_OUTPUT_DIRECTORY")
		if (NOT _output_dir)
			if (CMAKE_${_var_name}_OUTPUT_DIRECTORY)
				set(_output_dir "${CMAKE_${_var_name}_OUTPUT_DIRECTORY}")
			else ()
				message(FATAL_ERROR "Cannot continue without an output directory!")
			endif ()
		endif ()
		if (NOT _rpath_build)
			set(_rpath_build "")
		endif ()
		if (NOT _rpath_install)
			set(_rpath_install "")
		endif ()
		if (SF_BUILD_QT)
			Sf_IsQtLinked("${_target}" _qt_linked)
			if (_qt_linked)
				Sf_GetQtVersionLibraryDirectory(_qt_lib_dir)
				cmake_path(RELATIVE_PATH _qt_lib_dir BASE_DIRECTORY "${_output_dir}" OUTPUT_VARIABLE _qt_rel_dir)
				list(APPEND _rpath_build "\$ORIGIN/${_qt_rel_dir}")
				Sf_GetQtCompilerSubdirectory(_qt_compiler)
				if (WIN32)
					list(APPEND _rpath_install "\$ORIGIN/../qt/${SfQtLibrary_VERSION}/${_qt_compiler}/bin")
				else ()
					list(APPEND _rpath_install "\$ORIGIN/../qt/${SfQtLibrary_VERSION}/${_qt_compiler}/lib")
				endif ()
			endif ()
		endif ()
		list(PREPEND _rpath_build ${_rpath})
		list(PREPEND _rpath_install ${_rpath})
		set_target_properties("${_target}" PROPERTIES
			# Set the output directory in case it was not set.
			"${_var_name}_OUTPUT_DIRECTORY" "${_output_dir}"
			BUILD_RPATH "${_rpath_build}"
			INSTALL_RPATH "${_rpath_install}"
			BUILD_WITH_INSTALL_RPATH FALSE
			INSTALL_RPATH_USE_LINK_PATH FALSE
			BUILD_RPATH_USE_ORIGIN TRUE
		)
		if (_arg_REPORT)
			list(APPEND CMAKE_MESSAGE_INDENT "Runpath '${_target}' ")
			get_target_property(_value "${_target}" BUILD_RPATH)
			message(STATUS "Build: ${_value}")
			get_target_property(_value "${_target}" INSTALL_RPATH)
			message(STATUS "Install: ${_value}")
			list(POP_BACK CMAKE_MESSAGE_INDENT)
		endif ()
	endforeach ()
endfunction()

##!
# Lazy way for a project to installs all non-test targets in a project.
# @param _executables Optional: Variable to return the executables in.
#
function(Sf_TargetsInstall)
	Sf_GetOptionalArgument(_executables 0 "${ARGN}")
	set(_execs)
	# Retrieve all targets from this project.
	Sf_GetAllTargets(_all_targets "${PROJECT_SOURCE_DIR}" "TRUE")
	# Iterate through all targets.
	foreach (_target ${_all_targets})
		get_target_property(_type "${_target}" TYPE)
		# Only install executables and shared libraries.
		if (_type STREQUAL "EXECUTABLE")
			# Skip all test targets for packaging.
			if ("${_target}" MATCHES "^${SF_TEST_NAME_PREFIX}.*$")
				message(VERBOSE "Skipping Test Exec: ${_target}")
			else ()
				message(VERBOSE "Installing Executable: ${_target}")
				list(APPEND _targets "${_target}")
				if (DEFINED _executables)
					list(APPEND _execs "${_target}")
				endif ()
			endif ()
		elseif (_type STREQUAL "SHARED_LIBRARY" OR _type STREQUAL "MODULE_LIBRARY")
			list(APPEND _targets "${_target}")
			message(VERBOSE "Installing Dyn Library: ${_target}")
		endif ()
	endforeach ()
	# Install all the targets in the designated relative paths.
	if (WIN32)
		# Do not include the import libraries.
		install(TARGETS ${_targets}
			RUNTIME DESTINATION . COMPONENT "${CMAKE_INSTALL_DEFAULT_COMPONENT_NAME}"
			LIBRARY DESTINATION . COMPONENT "${CMAKE_INSTALL_DEFAULT_COMPONENT_NAME}"
			#CONFIGURATIONS Debug
		)
	else ()
		install(TARGETS ${_targets}
			RUNTIME DESTINATION . COMPONENT "${CMAKE_INSTALL_DEFAULT_COMPONENT_NAME}"
			LIBRARY DESTINATION lib COMPONENT "${CMAKE_INSTALL_DEFAULT_COMPONENT_NAME}"
			ARCHIVE DESTINATION arc COMPONENT "devel"
			#CONFIGURATIONS Debug
		)
	endif ()
	if (DEFINED _executables)
		set("${_executables}" "${_execs}" PARENT_SCOPE)
	endif ()
endfunction()

##!
# Notifies all available tools from CMake.
# Used for debugging.
#
function(Sf_ToolsNotice)
	string(REPLACE ";" "\n" _Path "$ENV{PATH}")
	message(NOTICE "
==================================================
ENV{PATH}=
${_Path}
--------------------------------------------------
CMAKE_C_COMPILER=${CMAKE_C_COMPILER}
CMAKE_C_COMPILER_AR=${CMAKE_C_COMPILER_AR}
CMAKE_C_COMPILER_RANLIB=${CMAKE_C_COMPILER_RANLIB}
CMAKE_RC_COMPILER=${CMAKE_RC_COMPILER}
CMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
CMAKE_CXX_COMPILER_AR=${CMAKE_CXX_COMPILER_AR}
CMAKE_CXX_COMPILER_RANLIB=${CMAKE_CXX_COMPILER_RANLIB}
CMAKE_RANLIB=${CMAKE_RANLIB}
CMAKE_AR=${CMAKE_AR}
CMAKE_NM=${CMAKE_NM}
CMAKE_ADDR2LINE=${CMAKE_ADDR2LINE}
CMAKE_DLLTOOL=${CMAKE_DLLTOOL}
CMAKE_OBJCOPY=${CMAKE_OBJCOPY}
CMAKE_OBJDUMP=${CMAKE_OBJDUMP}
CMAKE_LINKER=${CMAKE_LINKER}
CMAKE_READELF=${CMAKE_READELF}
CMAKE_STRIP=${CMAKE_STRIP}
CMAKE_SYSROOT=${CMAKE_SYSROOT}
--------------------------------------------------
CMAKE_FIND_ROOT_PATH=${CMAKE_FIND_ROOT_PATH}
CMAKE_FIND_ROOT_PATH_MODE_INCLUDE=${CMAKE_FIND_ROOT_PATH_MODE_INCLUDE}
CMAKE_FIND_ROOT_PATH_MODE_LIBRARY=${CMAKE_FIND_ROOT_PATH_MODE_LIBRARY}
CMAKE_FIND_ROOT_PATH_MODE_PROGRAM=${CMAKE_FIND_ROOT_PATH_MODE_PROGRAM}
==================================================
")
endfunction()

##!
# Call message() on each item in the given variable prefixed with an index number.
# Use 'CMAKE_MESSAGE_INDENT' to prefix each message.
#
function(Sf_ListPath _Path)
	Sf_GetOptionalArgument(_Prefix 0 "${ARGN}")
	# Check if the variable is a Linux path one.
	string(FIND "${_Path}" ";" _idx)
	# Check if this is a Linux path.
	if (_idx EQUAL -1)
		string(REPLACE ":" ";" _Path "${_Path}")
	endif ()
	set(_Counter 0)
	foreach (_Dir IN LISTS _Path)
		message(STATUS "${_Prefix}[${_Counter}]: ${_Dir}")
		math(EXPR _Counter "${_Counter} + 1")
	endforeach ()
endfunction()

#[[
Retrieves dynamic library dependencies for a binary file.

  Sf_GetDependencies(<out-var> <bin-file> [IGNORE_PATHS path1 ...])

  <out-var>
  Variable to store the resulting list of dependencies.

  <bin-file>
  Target binary file to analyze.

  IGNORE_PATHS
  Optional list of directory path prefixes to ignore.
]]
function(Sf_GetDependencies _OutVar _BinFile)
	# Parse the function arguments.
	cmake_parse_arguments(PARSE_ARGV 2 ARG "" "" "IGNORE_PATHS")
	# Covert to real path.
	foreach (_ignore IN LISTS ARG_IGNORE_PATHS)
		get_filename_component(_ignore_real "${_ignore}" REALPATH)
		list(APPEND _ignored_paths "${_ignore_real}")
	endforeach ()
	# Windows only knows the 'python' command.
	find_program(_PythonExe NAMES "python3" "python" REQUIRED)
	# Get the dependencies using the special python script.
	execute_process(
		COMMAND "${_PythonExe}" "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/bin/dependencies.py" --recurse --cmake --exclude-system "${_BinFile}"
		OUTPUT_VARIABLE _deps
		OUTPUT_STRIP_TRAILING_WHITESPACE
		ECHO_ERROR_VARIABLE
		COMMAND_ERROR_IS_FATAL ANY
	)
	# Variable to hold the non-ignored dependencies.
	set(_bin_deps)
	# Filter dependencies safely by appending non-ignored items.
	foreach (_dep IN LISTS _deps)
		set(_is_ignored FALSE)
		foreach (_ignore IN LISTS _ignored_paths)
			cmake_path(IS_PREFIX _ignore "${_dep}" NORMALIZE _is_inside)
			if (_is_inside)
				set(_is_ignored TRUE)
				break()
			endif ()
		endforeach ()
		if (NOT _is_ignored)
			list(APPEND _bin_deps "${_dep}")
		endif ()
	endforeach ()
	set("${_OutVar}" "${_bin_deps}" PARENT_SCOPE)
endfunction()

#[[
Retrieves dynamic library dependency filenames for a binary file.

  Sf_GetDependencies(<out-var> <bin-file>

  <out-var>
  Variable to store the resulting list of dependencies.

  <bin-file>
  Target binary file to analyze.

]]
function(Sf_GetDependencyFilenames _OutVar _BinFile)
	# Windows only knows the 'python' command.
	find_program(_PythonExe NAMES "python3" "python" REQUIRED)
	# Get the dependencies using the special python script.
	execute_process(
		COMMAND "${_PythonExe}" "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/bin/dependencies.py" --recurse --no-format "${_BinFile}"
		OUTPUT_VARIABLE _deps
		OUTPUT_STRIP_TRAILING_WHITESPACE
		ECHO_ERROR_VARIABLE
		COMMAND_ERROR_IS_FATAL ANY
	)
	# Create a list of the output.
	string(REPLACE "\n" ";" _deps "${_deps}")
	# Variable to hold the non-ignored dependencies.
	set("${_OutVar}" "${_deps}" PARENT_SCOPE)
endfunction()

if (WIN32)
	# Set the Docker flag when the file exists.
	if (EXISTS "Z:/.dockerenv")
		set(SF_DOCKER TRUE)
	endif ()
	if (MINGW)
		# Adding option '-mwindows' as a linker flag will remove the console.
		set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fuse-ld=bfd")
	endif ()
	if (MSVC)
		# Needed to be able to set debug breaks using MSVC
		#add_compile_definitions($<$<CONFIG:Debug>:_DEBUG>)
		# Warning: This disables some STL bounds checking in Debug builds otherwise the Qt Release library build
		# causes access violations in for example:
		#   QString::fromStdString({"My String."});
		# Release builds from the application has no problem linking or violations.
		add_compile_definitions($<$<CONFIG:Debug>:_ITERATOR_DEBUG_LEVEL=0>)
	endif ()
else ()
	# Set the Docker flag when the file exists.
	if (EXISTS "/.dockerenv")
		set(SF_DOCKER TRUE)
	endif ()
endif ()
