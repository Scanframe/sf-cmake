##
## This package cannot be used with find_package() before the first project is set.
##
find_package(SfBase CONFIG REQUIRED)

##!
# Used as a sub-macro to macro 'Sf_AddImportLibrary'.
#
macro(Sf_PopulateTargetProperties TargetName _Configuration _LibLocation _ImplibLocation)
	# Seems a relative directory is not working using REALPATH.
	get_filename_component(_imported_location "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${_LibLocation}" REALPATH)
	# When this fails on a library which is part of the project the order of add_subdirectory(...) is incorrect.
	Sf_CheckFileExists(${_imported_location})
	set_target_properties(${TargetName} PROPERTIES "IMPORTED_LOCATION_${_Configuration}" ${_imported_location})
	if (NOT _ImplibLocation STREQUAL "")
		set(_imported_implib "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${_ImplibLocation}")
		Sf_CheckFileExists(${_imported_implib})
		set_target_properties(${TargetName} PROPERTIES "IMPORTED_IMPLIB_${_Configuration}" ${_imported_implib})
	endif ()
endmacro()

##!
# Adds a named target as import library to the current project when the current
# top project does not have this target configured and when is does it is ignored.
#
macro(Sf_AddImportLibrary TargetName)
	# When the target exists ignore it.
	if (TARGET ${TargetName})
		message(VERBOSE "Not adding (${PROJECT_NAME}) library ${TargetName} already part of build and ignored.")
	else ()
		message(VERBOSE "Adding (${PROJECT_NAME}) library: ${TargetName}")
		add_library(${TargetName} SHARED IMPORTED)
		if (WIN32)
			Sf_PopulateTargetProperties(${TargetName} DEBUG "lib${TargetName}.dll" "lib${TargetName}.dll.a")
		else ()
			Sf_PopulateTargetProperties(${TargetName} DEBUG "lib${TargetName}.so" "")
		endif ()
	endif ()
endmacro()

##!
# Locates a top '_DirName' directory containing the file named '__output__'.
# Sets the '_OutputDir' variable when found.
#
function(Sf_LocateOutputDir _DirName _OutputDir)
	# InitializeBase return value variable.
	set(${_OutputDir} "" PARENT_SCOPE)
	# Loop from 9 to 4 with step 1.
	foreach (_Counter RANGE 0 4 1)
		# Form the string to the parent directory.
		string(REPEAT "/.." ${_Counter} _Sub)
		# Get the real filepath which is looked for.
		get_filename_component(_Dir "${CMAKE_CURRENT_LIST_DIR}${_Sub}/${_DirName}" REALPATH)
		# When the file inside is found Set the output directories and break the loop.
		if (EXISTS "${_Dir}/__output__")
			set(_Sep "/")
			# Make a distinction based on targeted system.
			if (WIN32)
				set(${_OutputDir} "${_Dir}${_Sep}win64" PARENT_SCOPE)
			else ()
				set(${_OutputDir} "${_Dir}${_Sep}lnx64" PARENT_SCOPE)
			endif ()
			# Stop here the directory has been found.
			break()
		endif ()
	endforeach ()
endfunction()

##!
# Sets the 3 CMAKE_??????_OUTPUT_DIRECTORY variables when an output directory has been found.
# Only when the top project is the current project.
# Fatal error when not able to do so.
#
function(Sf_SetOutputDirs _DirName)
	if (CMAKE_PROJECT_NAME STREQUAL "${PROJECT_NAME}")
		Sf_LocateOutputDir("${_DirName}" _OutputDir)
		# Check if the directory was found.
		if (_OutputDir STREQUAL "")
			message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}() (${PROJECT_NAME}): Output directory could not be located")
		else ()
			# Set the directories accordingly in the parents scope.
			#if (CMAKE_RUNTIME_OUTPUT_DIRECTORY STREQUAL "")
				set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${_OutputDir}" PARENT_SCOPE)
			#endif ()
			#if (CMAKE_LIBRARY_OUTPUT_DIRECTORY STREQUAL "")
				set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${_OutputDir}/lib" PARENT_SCOPE)
			#endif ()
			#set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${_OutputDir}" PARENT_SCOPE)
		endif ()
	endif ()
endfunction()

##!
# Sets the extension of the created shared library or executable.
#
function(Sf_SetTargetSuffix)
	foreach (_Target IN LISTS ARGN)
		get_target_property(_Type "${_Target}" TYPE)
		if (_Type STREQUAL "EXECUTABLE")
			if (WIN32)
				set_target_properties(${_Target} PROPERTIES OUTPUT_NAME "${_Target}" SUFFIX ".exe")
			else ()
				set_target_properties(${_Target} PROPERTIES OUTPUT_NAME "${_Target}" SUFFIX ".bin")
			endif ()
		elseif (_Type STREQUAL "SHARED_LIBRARY")
			if (WIN32)
				set_target_properties(${_Target} PROPERTIES LIBRARY_OUTPUT_NAME "${_Target}" SUFFIX ".dll")
			else ()
				set_target_properties(${_Target} PROPERTIES LIBRARY_OUTPUT_NAME "${_Target}" SUFFIX ".so")
			endif ()
		endif ()
	endforeach ()
endfunction()

##!
# Gets all sub directories which match the passed regex.
#
function(Sf_GetSubDirectories VarOut Directory MatchStr)
	file(GLOB _Children RELATIVE "${Directory}" "${Directory}/*")
	set(_List "")
	foreach (_Child ${_Children})
		if (IS_DIRECTORY "${Directory}/${_Child}")
			if ("${_Child}" MATCHES "${MatchStr}")
				list(APPEND _List "${_Child}")
			endif ()
		endif ()
	endforeach ()
	set(${VarOut} ${_List} PARENT_SCOPE)
endfunction()

##!
# Works around the cmake bug with sources and binary directory on a shared drive.
#
function(Sf_WorkAroundSmbShare)
	#[[
		# Check if the environment var exists telling us that cmake is running on Windows.
		if (EXISTS "$ENV{ComSpec}")
			set(_Command "PowerShell.exe")
			string(REPLACE "/" "\\" _Script "${SfMacros_DIR}/bin/SmbShareWorkAround.ps1")
			execute_process(COMMAND "${_Command}" "${_Script}" "${CMAKE_BINARY_DIR}" OUTPUT_VARIABLE _Result RESULT_VARIABLE _ExitCode)
		endif ()
		#message(STATUS ${_Result})
		# Validate the exit code.
		if (_ExitCode GREATER "0")
			message(FATAL_ERROR "Failed execution of script: ${_Script}")
		endif ()
	]]
endfunction()

##!
# Get all source files from the passed targets.
#  @param _Targets  The list containing all found targets
#  @param _OutVar Output variable returning a list variable.
#
function(Sf_GetTargetSource _Targets _OutVar)
	# Create or recreate empty variable since this is global namespace.
	set(_ActiveSources)
	# Iterate through the targets.
	foreach (_target IN LISTS _Targets)
		# Get the source list from the target.
		get_target_property(_Sources ${_target} SOURCES)
		# Append the target source list to the collection.
		list(APPEND _ActiveSources ${_Sources})
	endforeach ()
	# For convenience sort the list.
	list(SORT _ActiveSources)
	# Since some targets have the same sources remove duplicates.
	list(REMOVE_DUPLICATES _ActiveSources)
	# Assign the passed variable.
	set("${_OutVar}" "${_ActiveSources}" PARENT_SCOPE)
endfunction()

##!
# Downloads a QT-library zip files and unzips it the directory specified by variable 'SF_COMMON_LIB_DIR'.
# @param _Version Version to download Qt version.
#
function(Sf_QtLibraryDownload _Version)
	if (NOT "$ENV{QT_VER_DIR}" STREQUAL "")
		message(STATUS "${CMAKE_CURRENT_FUNCTION}(): Skipping since environment variable 'QT_VER_DIR' is set!")
		return()
	endif ()
	# Fixed URL for now.
	set(SF_NEXUS_SHARED_LIBS "https://nexus.scanframe.com/repository/shared/library")
	# When the host is Linux and the targeted system is Linux use the linux Qt library.
	if ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Linux" AND "${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")
		set(_Url "${SF_NEXUS_SHARED_LIBS}/qt-lnx-${_Version}.zip")
		set(_ZipFile "/tmp/qt-lnx-${_Version}.zip")
		set(_QtSubDir "Qt")
		# When the host is Linux and the targeted system is Windows use the cross compiler enabled QtWin library.
	elseif ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Linux" AND "${CMAKE_SYSTEM_NAME}" STREQUAL "Windows")
		set(_Url "${SF_NEXUS_SHARED_LIBS}/qt-win-${_Version}.zip")
		set(_ZipFile "/tmp/qt-win-${_Version}.zip")
		set(_QtSubDir "QtWin")
		# When the host is Windows and the targeted system is Windows use the Windows native compiler QtW64 library.
	elseif ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows" AND "${CMAKE_SYSTEM_NAME}" STREQUAL "Windows")
		set(_Url "${SF_NEXUS_SHARED_LIBS}/qt-w64-${_Version}.zip")
		string(REPLACE "\\" "/" _Temp "$ENV{TEMP}")
		set(_ZipFile "${_Temp}/qt-w64-${_Version}.zip")
		set(_QtSubDir "QtW64")
		# Try finding the bash.exe from cygwin.
		find_program(_BashExe "bash" PATHS "$ENV{SYSTEMDRIVE}/cygwin64/bin")
		if (_BashExe STREQUAL "_BashExe-NOTFOUND")
			message(SEND_ERROR "Bash program not found!")
		endif ()
	else ()
		message(SEND_ERROR "${CMAKE_CURRENT_FUNCTION}(): Combination of host OS '${CMAKE_HOST_SYSTEM_NAME}' and target OS '${CMAKE_SYSTEM_NAME}' is not possible!")
	endif ()
	# When SF_COMMON_LIB_DIR is not provided bailout.
	if (NOT SF_COMMON_LIB_DIR)
		message(FATAL_ERROR "Cache variable SF_COMMON_LIB_DIR has not been set!")
	endif ()
	# Form the Qt version directory.
	set(_QtVerDir "${SF_COMMON_LIB_DIR}/${_QtSubDir}/${_Version}")
	# Check if the required library exists and unpack it.
	if (EXISTS "${_QtVerDir}")
		message(VERBOSE "Found Qt Library at: ${_QtVerDir}")
	else ()
		if (EXISTS "${_ZipFile}")
			message(VERBOSE "Downloaded file exists: ${_ZipFile}")
		else ()
			message(VERBOSE "Downloading: ${_ZipFile} from ${_Url}")
			# Download the ZIP file using the wget command.
			execute_process(
				COMMAND wget -qcO "${_ZipFile}" "${_Url}"
				RESULT_VARIABLE _ExitCode
				ECHO_OUTPUT_VARIABLE
				ECHO_ERROR_VARIABLE
			)
		endif ()
		# Check the exit code.
		if (_ExitCode GREATER 0 OR NOT EXISTS "${_ZipFile}")
			message(SEND_ERROR "Download failed (${_ExitCode})!")
			return()
		endif ()
		# Extract the ZIP file using unzip
		message(VERBOSE "Unzipping to: ${SF_COMMON_LIB_DIR}/${_QtSubDir}")
		if (FALSE)
			execute_process(
				COMMAND mkdir -p "${_QtVerDir}"
				RESULT_VARIABLE _ExitCode
				ECHO_OUTPUT_VARIABLE
				ECHO_ERROR_VARIABLE
			)
		else ()
			execute_process(
				COMMAND unzip -qd "${SF_COMMON_LIB_DIR}/${_QtSubDir}" "${_ZipFile}"
				RESULT_VARIABLE _ExitCode
				ECHO_OUTPUT_VARIABLE
				ECHO_ERROR_VARIABLE
			)
		endif ()
		# Check the exit code.
		if (NOT _ExitCode EQUAL 0)
			message(SEND_ERROR "Unzipping failed (${_ExitCode})!")
			return()
		endif ()
		# Check if the directory exists after unpacking.
		if (NOT EXISTS "${_QtVerDir}")
			message(SEND_ERROR "Unzipped directory not exists: ${_QtVerDir} !")
			return()
		endif ()
		# Clean up the downloaded file.
		execute_process(COMMAND rm -rf "${_ZipFile}")
	endif ()
	# Set the environment variable which is used in Sf_GetQtVersionDirectory() to set the fixed Qt version directory.
	set(ENV{QT_VER_DIR} "${_QtVerDir}")
endfunction()

##!
# Finds the Qt directory located a defined position for Linux and Windows.
# @param _VarOut Out: Found Qt version of the directory.
#
function(Sf_FindQtVersionDirectory _VarOut)
	set(_QtDir "")
	if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux" AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
		set(_Locations "${SF_COMMON_LIB_DIR}/Qt" _QtDir "$ENV{HOME}/lib/Qt")
	elseif (CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux" AND CMAKE_SYSTEM_NAME STREQUAL "Windows")
		set(_Locations "${SF_COMMON_LIB_DIR}/QtWin" _QtDir "$ENV{HOME}/lib/QtWin")
	elseif (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows" AND CMAKE_SYSTEM_NAME STREQUAL "Windows")
		set(_QtDir "")
		# Iterate through all the specified locations.
		set(_Locations
			"${SF_COMMON_LIB_DIR}/QtW64"
			"C:/Qt" "D:/Qt" "E:/Qt" "F:/Qt" "G:/Qt" "H:/Qt" "I:/Qt" "J:/Qt" "K:/Qt" "L:/Qt" "M:/Qt" "N:/Qt"
			"O:/Qt" "P:/Qt" "Q:/Qt" "R:/Qt" "S:/Qt" "T:/Qt" "U:/Qt" "V:/Qt" "W:/Qt" "X:/Qt" "Y:/Qt" "Z:/Qt"
		)
	endif ()
	# Iterate through the location and use the first one that matches.
	foreach (_Location ${_Locations})
		if (EXISTS "${_Location}")
			set(_QtDir "${_Location}")
			message(STATUS "Qt root library found in '${_QtDir}'!")
			break()
		endif ()
	endforeach ()
	if (_QtDir STREQUAL "")
		message(STATUS "${CMAKE_CURRENT_FUNCTION}(): Qt library not found!")
	endif ()
	Sf_GetSubDirectories(_SubDirs "${_QtDir}" "^[0-9]+\\.[0-9]+\\.[0-9]+$")
	list(LENGTH _SubDirs _Len)
	if (NOT ${_Len})
		message(STATUS "${CMAKE_CURRENT_FUNCTION}():Qt versioned library not found in '${_QtDir}'!")
		set(${_VarOut} "" PARENT_SCOPE)
		return()
	endif ()
	list(SORT _SubDirs COMPARE NATURAL ORDER DESCENDING)
	list(GET _SubDirs 0 _QtVerDir)
	set(${_VarOut} "${_QtDir}/${_QtVerDir}" PARENT_SCOPE)
endfunction()

##!
# Gets the Qt directory located a defined position for Linux and Windows.
# @param _VarOut Out: Found Qt version of the directory.
#
function(Sf_GetQtVersionDirectory _VarOut)
	# Check if the environment variable has been set for a fixed Qt directory.
	if ("$ENV{QT_VER_DIR}" STREQUAL "")
		# Try finding a Qt directory in some possible locations.
		Sf_FindQtVersionDirectory(_QtVerDir)
		set(${_VarOut} "${_QtVerDir}" PARENT_SCOPE)
	else ()
		if (EXISTS "$ENV{QT_VER_DIR}")
			set(${_VarOut} "$ENV{QT_VER_DIR}" PARENT_SCOPE)
		else ()
			set(${_VarOut} "" PARENT_SCOPE)
			message(SEND_ERROR "Environment QT_VER_DIR set to non existing directory: $ENV{QT_VER_DIR} !")
		endif ()
	endif ()
endfunction()
