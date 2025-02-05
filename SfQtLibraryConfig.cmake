##!
# Downloads a QT-library zip files and unzips it the directory specified by variable 'SF_COMMON_LIB_DIR'.
# @param _Version Version to download Qt version.
#
function(Sf_QtLibraryDownload _Version)
	if (NOT "$ENV{QT_VER_DIR}" STREQUAL "")
		message(STATUS "${CMAKE_CURRENT_FUNCTION}(): Skipping since environment variable 'QT_VER_DIR' is set!")
		return()
	endif ()
	if (SF_ARCHITECTURE STREQUAL "")
		message(FATAL_ERROR "Variable SF_ARCHITECTURE has not been set yet.")
	endif ()
	# When the host is Linux and the targeted system is Linux use the linux Qt library.
	if ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Linux" AND "${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")
		# When cross compiling.
		if ("${SF_ARCHITECTURE}" STREQUAL "aarch64" AND "${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "x86_64")
			if (NOT "$ENV{QT_LNX_VER_DIR_AARCH64}" STREQUAL "")
				set(ENV{QT_VER_DIR} "$ENV{QT_LNX_VER_DIR_AARCH64}")
				message(STATUS "When running Docker 'ENV{QT_LNX_VER_DIR_AARCH64}' ($ENV{QT_LNX_VER_DIR_AARCH64}) is copied to 'ENV{QT_VER_DIR}'.")
				return()
			endif ()
		else ()
			# Let the target dedicated 'QT_LNX_VER_DIR' set 'QT_VER_DIR' when running in Docker.
			if (NOT "$ENV{QT_LNX_VER_DIR}" STREQUAL "")
				set(ENV{QT_VER_DIR} "$ENV{QT_LNX_VER_DIR}")
				message(STATUS "When running Docker 'ENV{QT_LNX_VER_DIR}' ($ENV{QT_LNX_VER_DIR}) is copied to 'ENV{QT_VER_DIR}'.")
				return()
			endif ()
		endif ()
		set(_Url "${SF_NEXUS_SHARED_LIBS}/qt/qt-lnx-${SF_ARCHITECTURE}-${_Version}.zip")
		set(_ZipFile "/tmp/qt-lnx-${_Version}.zip")
		set(_QtSubDir "qt/lnx-${SF_ARCHITECTURE}")
		# When the host is Linux and the targeted system is Windows use the cross compiler enabled QtWin library.
	elseif ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Linux" AND "${CMAKE_SYSTEM_NAME}" STREQUAL "Windows")
		# Let the target dedicated 'QT_WIN_VER_DIR' set 'QT_VER_DIR' when running in Docker.
		if (NOT "$ENV{QT_WIN_VER_DIR}" STREQUAL "")
			message(STATUS "When running Docker 'ENV{QT_WIN_VER_DIR}' ($ENV{QT_WIN_VER_DIR}) is copied to 'ENV{QT_VER_DIR}'.")
			set(ENV{QT_VER_DIR} "$ENV{QT_WIN_VER_DIR}")
			return()
		endif ()
		set(_Url "${SF_NEXUS_SHARED_LIBS}/qt/qt-win-${SF_ARCHITECTURE}-${_Version}.zip")
		set(_ZipFile "/tmp/qt-win-${SF_ARCHITECTURE}-${_Version}.zip")
		set(_QtSubDir "qt/win-${SF_ARCHITECTURE}")
		# When it depends on this directory since symlinks are referring to it.
		set(_DependQtSubDir "qt/lnx-${SF_ARCHITECTURE}")
		# When the host is Windows and the targeted system is Windows use the Windows native compiler QtW64 library.
	elseif ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows" AND "${CMAKE_SYSTEM_NAME}" STREQUAL "Windows")
		set(_Url "${SF_NEXUS_SHARED_LIBS}/qt/qt-w64-${SF_ARCHITECTURE}-${_Version}.zip")
		string(REPLACE "\\" "/" _Temp "$ENV{TEMP}")
		set(_ZipFile "${_Temp}/qt-w64-${SF_ARCHITECTURE}-${_Version}.zip")
		set(_QtSubDir "qt/w64-${SF_ARCHITECTURE}")
		# Try finding the bash.exe from cygwin.
		find_program(_BashExe "bash" PATHS "$ENV{SYSTEMDRIVE}/cygwin64/bin")
		if (NOT _BashExe)
			message(SEND_ERROR "Bash program not found!")
		endif ()
	else ()
		message(SEND_ERROR "${CMAKE_CURRENT_FUNCTION}(): Combination of host OS '${CMAKE_HOST_SYSTEM_NAME}' and target OS '${CMAKE_SYSTEM_NAME}' is not possible!")
	endif ()
	# When SF_COMMON_LIB_DIR is not provided bailout.
	if (NOT SF_COMMON_LIB_DIR)
		message(SEND_ERROR "Cache variable SF_COMMON_LIB_DIR has not been set!")
	endif ()
	# Check if the required library exists locally and otherwise unpack it.
	# Form the Qt version directory for the project.
	if (EXISTS "${SF_COMMON_LIB_DIR}/${_QtSubDir}/${_Version}")
		# Form the Qt version project directory.
		set(_QtVerDir "${SF_COMMON_LIB_DIR}/${_QtSubDir}/${_Version}")
		message(VERBOSE "Found Qt Library at: ${_QtVerDir}")
		# Check the users library path for a docker container.
	elseif (EXISTS "$ENV{HOME}/lib/${_QtSubDir}/${_Version}")
		# Form the Qt version local directory.
		set(_QtVerDir "$ENV{HOME}/lib/${_QtSubDir}/${_Version}")
		message(VERBOSE "Found Qt Library at: ${_QtVerDir}")
	else ()
		# Check if the depend directory exists and when not bailout.
		if (DEFINED _DependQtSubDir AND NOT EXISTS "${SF_COMMON_LIB_DIR}/${_DependQtSubDir}/${_Version}")
			message(FATAL_ERROR "Dependent directory '${_DependQtSubDir}' is not present.")
		endif ()
		# Sanity check if the qt subdirectory is not a symbolic link.
		Sf_IsSymlink("${SF_COMMON_LIB_DIR}/qt" _IsSymLink)
		if (EXISTS "/.dockerenv")
			message(FATAL_ERROR "Docker container '${SF_ARCHITECTURE}' is missing required Qt version '${_Version}'!")
		elseif (_IsSymLink)
			# Check if required 'yad' app exists.
			find_program(_YadApp "yad")
			if (_YadApp)
				execute_process(
					COMMAND "${_YadApp}"
					--center --on-top --no-markup
					--width=250
					--title="Confirmation"
					--text "Download Qt framework v${_Version},\neven when 'lib/qt' is a symlink ?"
					--button="Yes":0
					--button="No":1
					RESULT_VARIABLE _ExitCode
				)
				if (_ExitCode GREATER 0)
					message(FATAL_ERROR "Bailed out on installing Qt targeted library version!")
				endif ()
			else ()
				message(FATAL_ERROR "Cannot install Qt targeted library version directory!")
			endif ()
		endif ()
		if (EXISTS "${_ZipFile}")
			message(VERBOSE "Downloaded file exists: ${_ZipFile}")
		else ()
			message(VERBOSE "Downloading: ${_ZipFile} from ${_Url}")
			# Download the ZIP file using the internal command.
			file(DOWNLOAD "${_Url}" "${_ZipFile}" STATUS _Result)
			# First element of this list result list is the exitcode.
			list(GET _Result 0 _ExitCode)
		endif ()
		# Check the exit code.
		if (_ExitCode GREATER 0 OR NOT EXISTS "${_ZipFile}")
			# Seems there is still a file created which is empty and should be deleted.
			file(REMOVE "${_ZipFile}")
			message(FATAL_ERROR "Downloading of '${_ZipFile}' failed (${_Result})!")
			return()
		endif ()
		# Extract the ZIP file using external command unzip.
		message(VERBOSE "Unzipping to: ${SF_COMMON_LIB_DIR}/${_QtSubDir}")
		find_program(_ZipExe "unzip" REQUIRED)
		file(MAKE_DIRECTORY "${SF_COMMON_LIB_DIR}/${_QtSubDir}")
		execute_process(
			COMMAND "${_ZipExe}" -qd "${SF_COMMON_LIB_DIR}/${_QtSubDir}" "${_ZipFile}"
			RESULT_VARIABLE _ExitCode
			ECHO_OUTPUT_VARIABLE
			ECHO_ERROR_VARIABLE
		)
		# Check the exit code.
		if (NOT _ExitCode EQUAL 0)
			message(FATAL_ERROR "Unzipping failed (${_ExitCode})!")
			return()
		else ()
			message(STATUS "Unzipping succeeded deleting:  ${_ZipFile}")
			# Remove the zip file after unzipping successfully.
			file(REMOVE "${_ZipFile}")
		endif ()
		# Check if the directory exists after unpacking.
		if (NOT EXISTS "${SF_COMMON_LIB_DIR}/${_QtSubDir}/${_Version}")
			message(SEND_ERROR "Unzipped version directory '${_Version}' not exists!")
			return()
		endif ()
		set(_QtVerDir "${SF_COMMON_LIB_DIR}/${_QtSubDir}/${_Version}")
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
		set(_Locations "${SF_COMMON_LIB_DIR}/qt/lnx-${SF_ARCHITECTURE}")
	elseif (CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux" AND CMAKE_SYSTEM_NAME STREQUAL "Windows")
		set(_Locations "${SF_COMMON_LIB_DIR}/qt/win-${SF_ARCHITECTURE}")
	elseif (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows" AND CMAKE_SYSTEM_NAME STREQUAL "Windows")
		# Iterate through all the specified locations.
		set(_Locations
			"${SF_COMMON_LIB_DIR}/qt/w64-${SF_ARCHITECTURE}"
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
		message(STATUS "${CMAKE_CURRENT_FUNCTION}(): Qt library for architecture '${SF_ARCHITECTURE}' not found!")
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
			set(${_VarOut} "${_VarOut}-NOTFOUND" PARENT_SCOPE)
			message(SEND_ERROR "Environment QT_VER_DIR set to non existing directory: $ENV{QT_VER_DIR} !")
		endif ()
	endif ()
endfunction()

Sf_QtLibraryDownload("${SfQtLibrary_VERSION}")

# When the Qt version directory was found/installed set the cmake prefix path.
if (NOT "$ENV{QT_VER_DIR}" STREQUAL "")
	if (SF_COMPILER STREQUAL "gnu" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
		set(_QtCompileName "gcc_64")
	elseif (SF_COMPILER STREQUAL "ga" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
		set(_QtCompileName "gcc_64")
	elseif (SF_COMPILER STREQUAL "mingw" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
		set(_QtCompileName "mingw_64")
	elseif (SF_COMPILER STREQUAL "gw" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
		set(_QtCompileName "mingw_64")
	elseif (SF_COMPILER STREQUAL "msvc" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
		set(_QtCompileName "msvc2019_64")
	else ()
		message(FATAL_ERROR "SF_COMPILER '${SF_COMPILER}' has no solution for the 'CMAKE_PREFIX_PATH' path!")
	endif ()
	if (EXISTS "$ENV{QT_VER_DIR}/${_QtCompileName}/lib/cmake")
		# Add the cmake directory to the cmake search path.
		list(PREPEND CMAKE_PREFIX_PATH "$ENV{QT_VER_DIR}/${_QtCompileName}/lib/cmake")
		# Set the Qt include directory.
		set(SF_QT_INCLUDE_DIRECTORY "$ENV{QT_VER_DIR}/${_QtCompileName}/include")
	else ()
		message(FATAL_ERROR "Compiler '${SF_COMPILER}' QT cmake library prefix directory '$ENV{QT_VER_DIR}/${_QtCompileName}/lib/cmake' does not exist!")
	endif ()
	unset(_QtCompileName)
endif ()
