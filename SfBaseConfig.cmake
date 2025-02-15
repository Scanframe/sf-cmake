##!
# Declare some cmake flags for decisions on building targets.
#
set(SF_COMPILER "gnu" CACHE STRING "Selected compiler for the build which default to 'gnu' and could be 'ga', 'gw', 'mingw'.")
set(SF_ARCHITECTURE "x86_64" CACHE INTERNAL "Determines the architecture of the build and is determined by the tool chain selection for the set compiler.")
set(SF_COMMON_LIB_DIR "${CMAKE_SOURCE_DIR}/lib" CACHE INTERNAL "Location of common binary libraries to be unpacked into.")
set(SF_NEXUS_SHARED_LIBS "https://nexus.scanframe.com/repository/shared/library" CACHE INTERNAL "Nexus repository server for downloads of libraries.")
set(SF_BUILD_TESTING "OFF" CACHE BOOL "Enable test targets to be build.")
set(SF_BUILD_QT "OFF" CACHE BOOL "Enable QT targets to be build.")
set(SF_BUILD_GUI_TESTING "OFF" CACHE BOOL "Enable testing of tests using the GUI.")
set(SF_TEST_NAME_PREFIX "t_" CACHE STRING "Prefix for test applications to allow skipping when packaging.")
set(SF_COVERAGE_ONLY_TARGETS "" CACHE STRING "Only targets for coverage when developing locally to speed up.")
set(SF_OUTPUT_DIR_SUFFIX "" CACHE STRING "Output directory suffix only used by e.g. user presets to separate builds.")

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
# Checks if the required passed file exists.
# When not a useful fatal message is produced.
#
function(Sf_CheckFileExists _File)
	if (NOT EXISTS "${_File}")
		message(SEND_ERROR "The file \"${_File}\" does not exist. Check order of dependent add_subdirectory(...).")
	endif ()
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
			)
			# Report solution for specific Windows issue when using a share file system.
			if (_ExitCode EQUAL 128)
				message(SEND_ERROR "Solve this Windows only issue: git config --global --add safe.directory '*'")
			endif ()
			# Write the cache file.
			file(WRITE "${_FilePath}" "${_Version}")
		else ()
			# Read the cache file.
			file(READ "${_FilePath}" _Version)
			# Notify the that a cache version is used.
			message(STATUS "${CMAKE_CURRENT_FUNCTION}(): Using cached version (${_Version})")
		endif ()
	else ()
		# Only annotated tags so no '--tags' option.
		execute_process(COMMAND "${_GitExe}" describe --dirty --match "v*.*.*"
			# Use the current project directory to find.
			WORKING_DIRECTORY "${_SrcDir}"
			OUTPUT_VARIABLE _Version
			RESULT_VARIABLE _ExitCode
			ERROR_VARIABLE _ErrorText
			OUTPUT_STRIP_TRAILING_WHITESPACE
		)
	endif ()
	# Check the exist code for an error.
	if (_ExitCode GREATER 0)
		message(NOTICE "Repository '${_SrcDir}' not having a version tag like 'v1.2.3' or 'v1.2.3-rc.4 ?!")
		message(VERBOSE "${_GitExe} describe --dirty --match v* ... Exited with (${_ExitCode}).")
		message(VERBOSE "${_ErrorText}")
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
		message(SEND_ERROR "Git returned tag '${_Version}' does not match regex '${_RegEx}' !")
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
			target_compile_options("${_Target}" PRIVATE "-O3 -DNDEBUG")
		elseif (CMAKE_BUILD_TYPE STREQUAL "Debug")
			# Nothing specific yet.
		elseif (CMAKE_BUILD_TYPE STREQUAL "Coverage")
			# Targets get compile options assigned when added using Sf_AddTargetForCoverage() function.
		else ()
			message(AUTHOR_WARNING "The current build type '${CMAKE_BUILD_TYPE}' is not covered!")
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
		target_compile_options("${_Target}" PRIVATE "-Zc:__cplusplus")
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
				# Set the target version properties for Linux.
				set_target_properties("${_Target}" PROPERTIES VERSION "${_Version}" SOVERSION "${_Version}")
			endif ()
		else ()
			# Set the target version properties for Windows.
			set_target_properties("${_Target}" PROPERTIES SOVERSION "${_Version}")
		endif ()
	endif ()
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
		set_target_properties("${PROJECT_NAME}" PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
	endif ()
endfunction()

##!
# Adds an exif custom target for reporting the resource stored versions.
#
function(Sf_AddExifTarget _Target)
	# Try finding the bash.exe from cygwin.
	find_program(_BashExe "bash" PATHS "$ENV{SYSTEMDRIVE}/cygwin64/bin" REQUIRED)
	# Add "exif-<target>" custom target when main 'exif' target exist.
	if (TARGET "exif")
		if ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows")
			add_custom_target("exif-${_Target}" ALL
				COMMAND "${_BashExe}" -lc "exiftool '$<TARGET_FILE:${_Target}>' | egrep -i '(File Name|Product Version|File Version|File Type|CPU Type)\\s*:' | sed 's/\\s*:/:/g'"
				WORKING_DIRECTORY "$<TARGET_FILE_DIR:${_Target}>"
				DEPENDS "$<TARGET_FILE:${_Target}>"
				COMMENT "Reading resource information from '$<TARGET_FILE:${_Target}>'."
				VERBATIM
			)
		else ()
			if (WIN32)
				add_custom_target("exif-${_Target}" ALL
					COMMAND exiftool "$<TARGET_FILE:${_Target}>" | egrep -i "^(File Name|Product Version|File Version|File Type|CPU Type)\\s*:" | sed "s/\\s*:/:/g"
					# Report the linked shared libraries.
					COMMAND "objdump" -p "$<TARGET_FILE:${_Target}>" | grep -i "DLL Name: " | sed --regexp-extended "s/\\s*DLL Name: /Shared Library: /"
					WORKING_DIRECTORY "$<TARGET_FILE_DIR:${_Target}>"
					DEPENDS "$<TARGET_FILE:${_Target}>"
					COMMENT "Reading resource information from '$<TARGET_FILE:${_Target}>'."
					VERBATIM
				)
			else ()
				add_custom_target("exif-${_Target}" ALL
					COMMAND exiftool "$<TARGET_FILE:${_Target}>" | egrep -i "^(File Name|Product Version|File Version|File Type|CPU Type)\\s*:" | sed "s/\\s*:/:/g"
					# Report the runpath and the linked shared libraries.
					COMMAND "${CMAKE_READELF}" -d "$<TARGET_FILE:${_Target}>" | egrep -i "\\((NEEDED|RUNPATH)\\)" | sed --regexp-extended "s/.*(Shared library: |Library runpath: )\\[(.*)\\]/\\1\\2/"
					WORKING_DIRECTORY "$<TARGET_FILE_DIR:${_Target}>"
					DEPENDS "$<TARGET_FILE:${_Target}>"
					COMMENT "Reading resource information from '$<TARGET_FILE:${_Target}>'."
					VERBATIM
				)
			endif ()
		endif ()
		add_dependencies("exif" "exif-${_Target}")
	endif ()
	#endif ()
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
	# Generate the configure the file for doxygen.
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
# Gets the include directories from all targets in the list.
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
			get_filename_component(_dir "${_incdir}" REALPATH)
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
# Calls native add_test() function using start scripts to set the library paths for Windows/Wine and Linux.
# @param _Target Name of the target.
# @param _RunTimeDir Runtime directory which also contains the shell scripts win-exec.sh, win-exec.cmd and lnx-exec.sh.
#
function(Sf_AddTest _Target _RunTimeDir)
	# When target is a Windows build.
	if (WIN32)
		# When the host is Windows use a command script.
		if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
			set(_Script "win-exec.cmd")
		# When the host is Linux use a shell script executing Wine.
		else()
			set(_Script "win-exec.sh")
		endif ()
	else ()
		# When NOT compiling Windows assume Linux build and use a shell script.
		set(_Script "lnx-exec.sh")
	endif ()
	# Check if the needed script exists.
	if (NOT EXISTS "${_RunTimeDir}/${_Script}")
		# Notify copying the script.
		message(NOTICE "Copying required script: ${_RunTimeDir}/${_Script}")
		# Copy the file when it does not exist and do not use 'file(INSTALL ... DESTINATION ...)' since this does not copy the execute mod of the file.
		execute_process(
			COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/tpl/bin/${_Script}" "${_RunTimeDir}/${_Script}"
			COMMAND_ERROR_IS_FATAL ANY
		)
	endif ()

	# Add the test using the script.
	add_test(NAME "${_Target}"
		COMMAND "${_Script}" "$<TARGET_FILE_NAME:${_Target}>"
		WORKING_DIRECTORY "${_RunTimeDir}"
	)
	# Set the environment variable for the shell script to pickup up to target the correct output directory.
	set_property(TEST "${_Target}" PROPERTY ENVIRONMENT "SF_OUTPUT_DIR_SUFFIX=${SF_OUTPUT_DIR_SUFFIX}")
endfunction()

##!
# Adds the passed target for coverage only when the build type is 'Coverage'.
#
function(Sf_AddTargetForCoverage _Target)
	# Set options only when the build type is coverage and the SF_COVERAGE_ONLY_TARGET is empty.
	if (CMAKE_BUILD_TYPE STREQUAL "Coverage" AND
	(
		SF_COVERAGE_ONLY_TARGETS STREQUAL "" OR _Target IN_LIST SF_COVERAGE_ONLY_TARGETS
	))
		# Get the type of the target.
		get_target_property(_Type "${_Target}" TYPE)
		# When the GNU compiler is involved.
		if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
			message(STATUS "Target '${_Target}' added for coverage.")
			# No optimization when compiling for coverage.
			target_compile_options("${_Target}" BEFORE PRIVATE -g -O0 -coverage -fprofile-arcs -ftest-coverage)
			# Only add linking options for target types that are linked.
			if (_Type STREQUAL "EXECUTABLE" OR _Type STREQUAL "SHARED_LIBRARY")
				target_link_options("${_Target}" BEFORE PRIVATE -coverage)
				# Probably superfluous since it is probably linked already using the option.
				target_link_libraries("${_Target}" PRIVATE gcov)
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
	get_filename_component(_OutDir "${_OutDir}" REALPATH)
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
