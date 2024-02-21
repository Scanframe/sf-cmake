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
macro(Sf_CheckFileExists _File)
	if (NOT EXISTS "${_File}")
		message(FATAL_ERROR "The file \"${_File}\" does not exist. Check order of dependent add_subdirectory(...).")
	endif ()
endmacro()

##!
# Works around for Catch2 which does not allow us to set the compiler switch (-fvisibility=hidden)
#
function(Sf_SetTargetDefaultCompileOptions _Target)
	#message(STATUS "Setting target '${_Target}' compiler option -fvisibility=hidden")
	target_compile_options("${_Target}" PRIVATE "-fvisibility=hidden")
endfunction()

##!
# Gets the version from the Git repository using 'PROJECT_SOURCE_DIR' variable.
# When not found it returns "${_VarOut}-NOTFOUND"
#
function(Sf_GetGitTagVersion _VarOut _SrcDir)
	# Initialize return value.
	set(${_VarOut} "${_VarOut}-NOTFOUND" PARENT_SCOPE)
	# Get git binary location for execution.
	find_program(_GitExe "git")
	if (_Compiler STREQUAL "_GitExe-NOTFOUND")
		message(FATAL_ERROR "Git program not found!")
	endif ()
	if ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows")
		execute_process(COMMAND bash -c "\"${_GitExe}\" describe --tags --dirty --match \"v*\""
			# Use the current project directory to find.
			WORKING_DIRECTORY "${_SrcDir}"
			OUTPUT_VARIABLE _Version
			RESULT_VARIABLE _ExitCode
			ERROR_VARIABLE _ErrorText
			OUTPUT_STRIP_TRAILING_WHITESPACE
			ERROR_QUIET
		)
	else ()
		execute_process(COMMAND "${_GitExe}" describe --tags --dirty --match "v*"
			# Use the current project directory to find.
			WORKING_DIRECTORY "${_SrcDir}"
			OUTPUT_VARIABLE _Version
			RESULT_VARIABLE _ExitCode
			ERROR_VARIABLE _ErrorText
			OUTPUT_STRIP_TRAILING_WHITESPACE
			ERROR_QUIET
		)
	endif ()
	# Check the exist code for an error.
	if (_ExitCode GREATER 0)
		message(STATUS "Repository '${_SrcDir}' not having a version tag like 'v0.0.0' ?!")
		message(VERBOSE "${_GitExe} describe --tags --dirty --match v* ... Exited with (${_ExitCode}).")
		message(VERBOSE "${_ErrorText}")
		# Set an initial version to allow continuing.
		set(_Version "v0.0.0")
	endif ()
	set(_RegEx "^v([0-9]+\\.[0-9]+\\.[0-9]+)")
	string(REGEX MATCH "${_RegEx}" _Dummy_ "${_Version}")
	if ("${CMAKE_MATCH_1}" STREQUAL "")
		message(FATAL_ERROR "Git returned tag '${_Version}' does not match regex '${_RegEx}' !")
	else ()
		set(${_VarOut} "${CMAKE_MATCH_1}" PARENT_SCOPE)
	endif ()
endfunction()

##!
# Sets the passed target version properties according the version of the sub project
# or by default use the tag in vN.N.N format
#
function(Sf_SetTargetVersion _Target)
	# Get the type of the target.
	get_target_property(_Type ${_Target} TYPE)
	# Get version. from Git when possible.
	Sf_GetGitTagVersion(_Version "${CMAKE_CURRENT_SOURCE_DIR}")
	# Check if the git version was found.
	if (NOT "${_Version}" STREQUAL "_Version-NOTFOUND")
		message(VERBOSE "${CMAKE_CURRENT_FUNCTION}(${_Target}) using Git version (${_Version})")
		# Check the target version is set.
	elseif (NOT "${CMAKE_PROJECT_VERSION}" STREQUAL "")
		set(_Version "${${_Target}_VERSION}")
		message(VERBOSE "${CMAKE_CURRENT_FUNCTION}(${_Target}) using Sub-Project(${_Target}) version (${_Version})")
		# Check the project version is set.
	elseif (NOT "${CMAKE_PROJECT_VERSION}" STREQUAL "")
		# Try using the main project version
		set(_Version "${CMAKE_PROJECT_VERSION}")
		message(VERBOSE "${CMAKE_CURRENT_FUNCTION}(${_Target}) using Main-Project version (${_Version})")
	else ()
		# Clear the version variable.
		set(_Version "")
	endif ()
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
macro(Sf_AddExecutable _Target)
	# Add the executable.
	add_executable("${_Target}")
	# Set the default compiler options for our own code only.
	Sf_SetTargetDefaultCompileOptions("${_Target}")
	# Set the version of this target.
	Sf_SetTargetVersion("${_Target}")
endmacro()

##!
# Adds a dynamic library target and sets the version number.
# For Windows builds the library output directory is set the
# same as when build for Linux.
#
macro(Sf_AddSharedLibrary _Target)
	# Add the library to create.
	add_library("${_Target}" SHARED)
	# Set the default compiler options for our own code only.
	Sf_SetTargetDefaultCompileOptions("${_Target}")
	# Set the version of this target.
	Sf_SetTargetVersion("${_Target}")
	# In Windows builds the output directory for libraries is ignored and the runtime is used and is now corrected.
	if (WIN32)
		set_target_properties("${PROJECT_NAME}" PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
	endif ()
endmacro()

##!
# Adds an exif custom target for reporting the resource stored versions.
#
macro(Sf_AddExifTarget _Target)
	# Only possible when compiling in Linux.
	#if ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Linux")
	# Add "exif-<target>" custom target when main 'exif' target exist.
	if (TARGET "exif")
		if ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows")
			add_custom_target("exif-${_Target}" ALL
				COMMAND bash -c "exiftool '$<TARGET_FILE:${_Target}>' | egrep -i '(File Name|Product Version|File Version|File Type|CPU Type)\\s*:' | sed 's/\\s*:/:/g'"
				WORKING_DIRECTORY "$<TARGET_FILE_DIR:${_Target}>"
				DEPENDS "$<TARGET_FILE:${_Target}>"
				COMMENT "Reading resource information from '$<TARGET_FILE:${_Target}>'."
				VERBATIM
			)
		else ()
			add_custom_target("exif-${_Target}" ALL
				COMMAND exiftool "$<TARGET_FILE:${_Target}>" | egrep -i "^(File Name|Product Version|File Version|File Type|CPU Type)\\s*:" | sed "s/\\s*:/:/g"
				WORKING_DIRECTORY "$<TARGET_FILE_DIR:${_Target}>"
				DEPENDS "$<TARGET_FILE:${_Target}>"
				COMMENT "Reading resource information from '$<TARGET_FILE:${_Target}>'."
				VERBATIM
			)
		endif ()
		add_dependencies("exif" "exif-${_Target}")
	endif ()
	#endif ()
endmacro()

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
	get_target_property(_OutputSuffix "${_Target}" SUFFIX)
	string(REPLACE "." "," RC_WindowsFileVersion "${_Version},0")
	set(RC_WindowsProductVersion "${RC_WindowsFileVersion}")
	set(RC_FileVersion "${_Version}")
	set(RC_ProductVersion "${RC_FileVersion}")
	set(RC_FileDescription "${CMAKE_PROJECT_DESCRIPTION}")
	set(RC_ProductName "${CMAKE_PROJECT_DESCRIPTION}")
	set(RC_OriginalFilename "${_OutputName}${_OutputSuffix}")
	set(RC_InternalName "${_OutputName}${_OutputSuffix}")
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
#
function(Sf_GetAllTargets _result _dir)
	# Get the length of the name to skip.
	string(LENGTH "${FETCHCONTENT_BASE_DIR}" _length)
	get_property(_subdirs DIRECTORY "${_dir}" PROPERTY SUBDIRECTORIES)
	foreach (_subdir IN LISTS _subdirs)
		string(SUBSTRING "${_subdir}" 0 ${_length} _tmp)
		if (_tmp STREQUAL FETCHCONTENT_BASE_DIR)
			#message(NOTICE "Skipping: ${_tmp}")
			continue()
		endif ()
		Sf_GetAllTargets(${_result} "${_subdir}")
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
	foreach (_target IN LISTS ${_targets})
		# Get the source directory from the target.
		#get_target_property(_srcdir "${_target}" SOURCE_DIR)
		# Get all the include directories from the target.
		get_target_property(_incdirs "${_target}" INCLUDE_DIRECTORIES)
		# Check if there are include directories for this target.
		if ("${_incdirs}" STREQUAL "_incdirs-NOTFOUND")
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
				message(FATAL_ERROR "[${_Loops}] Populating '${_DepName}' took more then the given '${_Timeout}s'!")
			endif ()
		endif ()
	endwhile ()
endfunction()

##!
# Sets or appends the rpath for all compiled targets.
# @param _Path A path string like "\${ORIGIN}:\${ORIGIN}/lib".
#
function (Sf_SetRPath _Path)
	# Is a Linux only thing.
	if (WIN32)
		# When building for Windows using GNU report warnings on MSVC incompatibilities.
		#add_definitions(-D__MINGW_MSVC_COMPAT_WARNINGS)
		# Suppressing the warning that out-of-line inline functions are redeclared.
		#add_link_options(-Wno-inconsistent-dllimport)
	else ()
		# Using Cmake's way of RPATH.
		set(CMAKE_SKIP_BUILD_RPATH FALSE)
		set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)
		#set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
		# Linker option -rpath is not working due to doubling of the '$' sign by CMAKE.
		#    add_link_options(-Wl,-rpath-link "\${ORIGIN\}")
		if (CMAKE_INSTALL_RPATH STREQUAL "")
			set(CMAKE_INSTALL_RPATH "${_Path}")
		else ()
			set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_RPATH}:${_Path}")
		endif ()
		# Set the parent scope version.
		set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_RPATH}" PARENT_SCOPE)
		# Report the resulting RPath.
		message(STATUS "Install RPATH: ${CMAKE_INSTALL_RPATH}")
	endif ()
endfunction()