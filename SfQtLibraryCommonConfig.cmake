# Required first entry checking the cmake version.
cmake_minimum_required(VERSION 3.29...4.4)

set(SF_QT_COMPONENT_PREFIX "sf_qt_" CACHE INTERNAL "The install component prefix used to identify them (NSIS does not handle '-' hyphens).")
set(SF_QT_PACKAGE_FILENAME_PREFIX "sf-qt-" CACHE INTERNAL "The package filename prefix used for creating Qt packages.")

##!
# Downloads a QT-library zip files and unzips it the directory specified by variable 'SF_COMMON_LIB_DIR'.
# @param _Version Version to download Qt version and an empty string  when not found.
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
		if ("${SF_ARCHITECTURE}" STREQUAL "aarch64" AND "${CMAKE_HOST_SYSTEM_PROCESSOR}" STREQUAL "x86_64")
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
	else ()
		message(SEND_ERROR "${CMAKE_CURRENT_FUNCTION}(): Combination of host OS '${CMAKE_HOST_SYSTEM_NAME}' and target OS '${CMAKE_SYSTEM_NAME}' is not possible!")
	endif ()
	# When SF_COMMON_LIB_DIR is not provided bailout.
	if (NOT SF_COMMON_LIB_DIR)
		message(SEND_ERROR "Cache variable SF_COMMON_LIB_DIR has not been set!")
	endif ()
	# Form the Qt version possible directories for the project.
	set(_QtDirs "")
	list(APPEND _QtDirs "${SF_COMMON_LIB_DIR}/${_QtSubDir}/${_Version}")
	if (DEFINED ENV{HOME})
		list(APPEND _QtDirs "$ENV{HOME}/lib/${_QtSubDir}/${_Version}")
	endif ()
	if (DEFINED ENV{WINE_HOST_HOME})
		list(APPEND _QtDirs "Z:$ENV{WINE_HOST_HOME}/lib/${_QtSubDir}/${_Version}")
	endif ()
	# Initialize the variable.
	set(_QtVerDir "_QtVerDir-NOTFOUND")
	# Do some conversion to be sure.
	foreach (_Dir IN LISTS _QtDirs)
		message(VERBOSE "Looking for Qt library at: ${_Dir}")
		if (EXISTS "${_Dir}")
			set(_QtVerDir "${_Dir}")
			message(VERBOSE "Found Qt Library at: ${_QtVerDir}")
			break()
		endif ()
	endforeach ()
	if (SF_DOCKER AND NOT _QtVerDir)
		message(FATAL_ERROR "Docker container '${SF_ARCHITECTURE}' is missing required Qt version '${_Version}'!")
	elseif (NOT _QtVerDir)
		# Check if the depend directory exists and when not bailout.
		if (DEFINED _DependQtSubDir AND NOT EXISTS "${SF_COMMON_LIB_DIR}/${_DependQtSubDir}/${_Version}")
			message(FATAL_ERROR "Dependent directory '${_DependQtSubDir}' is not present.")
		endif ()
		# Sanity check if the qt subdirectory is not a symbolic link.
		Sf_IsSymlink("${SF_COMMON_LIB_DIR}/qt" _IsSymLink)
		if (_IsSymLink)
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
		find_program(_7zExe
			NAMES 7z 7z.exe 7za.exe
			PATHS "$ENV{ProgramFiles}/7-Zip" "$ENV{ProgramFiles\(x86\)}/7-Zip"
			DOC "Path a 7-Zip executable")
		file(MAKE_DIRECTORY "${SF_COMMON_LIB_DIR}/${_QtSubDir}")
		execute_process(
			COMMAND "${_7zExe}" x "${_ZipFile}" "-o${SF_COMMON_LIB_DIR}/${_QtSubDir}"
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
# Finds all the Qt versions located in defined positions for Linux or Windows.
# @param _VarOut Out: List of all found Qt versions.
#
function(Sf_FindQtVersions _VarOut)
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
			message(STATUS "A Qt library root found in '${_Location}'!")
			Sf_GetSubDirectories(_SubDirs "${_Location}" "^[0-9]+\\.[0-9]+\\.[0-9]+$")
			list(LENGTH _SubDirs _Len)
			if (NOT ${_Len})
				message(STATUS "${CMAKE_CURRENT_FUNCTION}(): Qt versioned library not found in '${_Location}'!")
				return()
			endif ()
		endif ()
	endforeach ()
	list(SORT _SubDirs COMPARE NATURAL ORDER DESCENDING)
	set(${_VarOut} "${_SubDirs}" PARENT_SCOPE)
endfunction()

##!
# Finds the Qt directory located a defined position for Linux and Windows.
# @param _VarOut Out: Highest of the found Qt version directories and "${_OutVar}-NOTFOUND" when not found.
#
function(Sf_FindQtVersionDirectory _VarOut)
	Sf_GetOptionalArgument(_Version 0 "${ARGN}")
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
			message(STATUS "Qt Root Library: ${_QtDir}")
			break()
		endif ()
	endforeach ()
	if (_QtDir STREQUAL "")
		message(STATUS "${CMAKE_CURRENT_FUNCTION}(): Qt library for architecture '${SF_ARCHITECTURE}' not found!")
		set(${_VarOut} "" PARENT_SCOPE)
	else ()
		if (DEFINED _Version)
			Sf_GetSubDirectories(_SubDirs "${_QtDir}" "${_Version}")
		else ()
			Sf_GetSubDirectories(_SubDirs "${_QtDir}" "^[0-9]+\\.[0-9]+\\.[0-9]+$")
		endif ()
		list(LENGTH _SubDirs _Len)
		if (NOT ${_Len})
			message(STATUS "${CMAKE_CURRENT_FUNCTION}(): Qt versioned library not found in '${_QtDir}'!")
			# Set the value to allow boolean evaluation of the value.
			set(${_VarOut} "${_OutVar}-NOTFOUND" PARENT_SCOPE)
			return()
		endif ()
		list(SORT _SubDirs COMPARE NATURAL ORDER DESCENDING)
		list(GET _SubDirs 0 _QtVerDir)
		set(${_VarOut} "${_QtDir}/${_QtVerDir}" PARENT_SCOPE)
	endif ()
endfunction()

##!
# Finds the Qt directory located a defined position for Linux and Windows.
# @param _VarOut Out: Highest of the found Qt version directories and and "${_OutVar}-NOTFOUND" when not found.
#
function(Sf_FindQtVersion _VarOut)
	Sf_GetOptionalArgument(_Version 0 "${ARGN}")
	Sf_FindQtVersionDirectory(_Dir "${_Version}")
	if (_Dir)
		get_filename_component(_Dir "${_Dir}" NAME)
		set(${_VarOut} "${_Dir}" PARENT_SCOPE)
	else ()
		set(${_VarOut} "${_VarOut}-NOTFOUND" PARENT_SCOPE)
	endif ()
endfunction()

##!
# Gets the Qt library directory located a defined position for Linux and Windows.
# @param _VarOut Out: Found Qt version of the library directory.
#
function(Sf_GetQtVersionLibraryDirectory _VarOut)
	Sf_GetQtVersionDirectory(_dir)
	Sf_GetQtCompilerSubdirectory(_compiler_dir)
	if (WIN32)
		set(${_VarOut} "${_dir}/${_compiler_dir}/bin" PARENT_SCOPE)
	else ()
		set(${_VarOut} "${_dir}/${_compiler_dir}/lib" PARENT_SCOPE)
	endif ()
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

##!
# Gets the Qt compiler subdirectory in the QT version directory base on SF_COMPILER.
# @param _VarOut Out: Resolved subdirectory.
#
function(Sf_GetQtCompilerSubdirectory _VarOut)
	set(_QtCompilerName "")
	if (SF_COMPILER STREQUAL "gnu" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
		set(_QtCompilerName "gcc_64")
	elseif (SF_COMPILER STREQUAL "ga" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
		set(_QtCompilerName "gcc_64")
	elseif (SF_COMPILER STREQUAL "mingw" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
		set(_QtCompilerName "mingw_64")
	elseif (SF_COMPILER STREQUAL "gw" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
		set(_QtCompilerName "mingw_64")
	elseif (SF_COMPILER STREQUAL "msvc" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
		set(_QtCompilerName "msvc_64")
	endif ()
	set(${_VarOut} "${_QtCompilerName}" PARENT_SCOPE)
endfunction()

##!
# Gets the Qt architecture subdirectory in the QT version directory.
# @param _VarOut Out: Resolved subdirectory.
#
function(Sf_GetQtArchitectureSubdirectory _VarOut)
	# When the host is Linux and the targeted system is Linux use the linux Qt library.
	if ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Linux" AND "${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")
		set(_QtArchDir "lnx-${SF_ARCHITECTURE}")
		# When the host is Linux and the targeted system is Windows use the cross compiler enabled QtWin library.
	elseif ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Linux" AND "${CMAKE_SYSTEM_NAME}" STREQUAL "Windows")
		set(_QtArchDir "win-${SF_ARCHITECTURE}")
		# When the host is Windows and the targeted system is Windows use the Windows native compiler QtW64 library.
	elseif ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows" AND "${CMAKE_SYSTEM_NAME}" STREQUAL "Windows")
		set(_QtArchDir "w64-${SF_ARCHITECTURE}")
	else ()
		message(SEND_ERROR "${CMAKE_CURRENT_FUNCTION}(): Combination of host OS '${CMAKE_HOST_SYSTEM_NAME}' and target OS '${CMAKE_SYSTEM_NAME}' is not possible!")
	endif ()
	set(${_VarOut} "${_QtArchDir}" PARENT_SCOPE)
endfunction()

##!
# Installs the current Qt
# @param _IncDev Flag to include development.
# @param _QtDir Optional Qt directory default to global 'QT_DIR'.
#
function(Sf_QtLibraryInstall _IncDev)
	Sf_GetOptionalArgument(_QtDir 0 "${ARGN}")
	set(_base "." #[["qt"]])
	if (NOT DEFINED _QtDir)
		set(_QtDir "${QT_DIR}")
	endif ()
	if (NOT EXISTS "${_QtDir}")
		message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Missing QT directory location.")
	endif ()
	# Get the toolchain part of the current selected Qt directory where the QT_DIR is
	# like '.../lib/qt/lnx-x86_64/6.10.1/gcc_64/lib/cmake/Qt6'.
	cmake_path(GET _QtDir PARENT_PATH _ParentDir)
	cmake_path(GET _ParentDir PARENT_PATH _ParentDir)
	cmake_path(GET _ParentDir PARENT_PATH _QtSourceDir)
	if (WIN32)
		# Runtime dirs.
		set(_rt_dirs bin plugins qml translations)
		# Install runtime assets.
		foreach (_dir IN LISTS _rt_dirs)
			if (EXISTS "${_QtSourceDir}/${_dir}")
				if (_dir STREQUAL "bin")
					file(GLOB _qt_libs LIST_DIRECTORIES FALSE "${_QtSourceDir}/${_dir}/*.dll")
					install(FILES ${_qt_libs} DESTINATION "${_base}/${_dir}" COMPONENT "${SF_QT_COMPONENT_PREFIX}rt")
				else ()
					install(DIRECTORY "${_QtSourceDir}/${_dir}" DESTINATION "${_base}" COMPONENT "${SF_QT_COMPONENT_PREFIX}rt")
				endif ()
			endif ()
			if (_IncDev)
				message(NOTICE "Develop package for Windows not implemented!")
			endif ()
		endforeach ()
	else ()
		# Runtime dirs.
		set(_rt_dirs lib plugins qml translations)
		# Install runtime assets.
		foreach (_dir IN LISTS _rt_dirs)
			if (EXISTS "${_QtSourceDir}/${_dir}")
				if (_dir STREQUAL "lib")
					file(GLOB _qt_libs LIST_DIRECTORIES FALSE "${_QtSourceDir}/${_dir}/*.so" "${_QtSourceDir}/${_dir}/*.so.[0-9]*")
					install(FILES ${_qt_libs} DESTINATION "${_base}/${_dir}" COMPONENT "${SF_QT_COMPONENT_PREFIX}rt")
				else ()
					install(DIRECTORY "${_QtSourceDir}/${_dir}" DESTINATION "${_base}" COMPONENT "${SF_QT_COMPONENT_PREFIX}rt")
				endif ()
			endif ()
		endforeach ()
		# Install development assets.
		if (_IncDev)
			Sf_GetSubDirectories(_dev_dirs "${_QtSourceDir}")
			list(REMOVE_ITEM _dev_dirs ${_rt_dirs})
			# The lib directory also contains development elements.
			list(APPEND _dev_dirs lib)
			foreach (_dir IN LISTS _dev_dirs)
				if (_dir STREQUAL "lib")
					# Get all items (files and folders) in the root directory
					file(GLOB _all_items "${_QtSourceDir}/${_dir}/*")
					set(_subdirs "")
					set(_non_so_files "")
					foreach (_item IN LISTS _all_items)
						if (IS_DIRECTORY "${_item}")
							list(APPEND _subdirs "${_item}")
						elseif (NOT _item MATCHES "\\.so(\\.[0-9]+)?(\\.[0-9]+)?(\\.[0-9]+)?$")
							list(APPEND _non_so_files "${_item}")
						endif ()
					endforeach ()
					# Install all subdirectories (including their entire sub-contents).
					if (_subdirs)
						install(DIRECTORY ${_subdirs} DESTINATION "${_base}/${_dir}" COMPONENT "${SF_QT_COMPONENT_PREFIX}dev")
					endif ()
					# Install root files excluding '.so' files.
					if (_non_so_files)
						install(FILES ${_non_so_files} DESTINATION "${_base}/${_dir}" COMPONENT "${SF_QT_COMPONENT_PREFIX}dev")
					endif ()
				else ()
					install(DIRECTORY "${_QtSourceDir}/${_dir}" DESTINATION "${_base}" COMPONENT "${SF_QT_COMPONENT_PREFIX}dev")
				endif ()
			endforeach ()
		endif ()
	endif ()
endfunction()

##!
# Recursively determine whether `target` needs Qt's RUNPATH.
# Walks LINK_LIBRARIES / INTERFACE_LINK_LIBRARIES, descending only
# through STATIC/OBJECT/INTERFACE libraries (see note above).
# @param _target Designated target.
# @param _out_var Output variable receiving TRUE or FALSE.
#
function(Sf_IsQtLinked _target _out_var)
	set(_visited "")
	_sf_links_qt_impl("${_target}" _visited _result)
	set(${_out_var} ${_result} PARENT_SCOPE)
endfunction()

##!
# Helper function for function 'Sf_TargetLinksQt()'.
#
function(_sf_links_qt_impl _target _visited_var _out_var)
	set(${_out_var} FALSE PARENT_SCOPE)
	if (NOT TARGET ${_target})
		return()
	endif ()
	# Check if library is re-visited.
	#if ("${_target}" IN_LIST "${_visited_var}")
	list(FIND ${_visited_var} "${_target}" _idx)
	if (NOT _idx EQUAL -1)
		return()
	endif ()
	list(APPEND ${_visited_var} "${_target}")
	set(${_visited_var} "${${_visited_var}}" PARENT_SCOPE)
	get_target_property(_type ${_target} TYPE)
	# gather both direct and propagated (interface) link items
	set(_libs "")
	foreach (_prop LINK_LIBRARIES INTERFACE_LINK_LIBRARIES)
		get_target_property(_val ${_target} ${_prop})
		if (_val)
			list(APPEND _libs ${_val})
		endif ()
	endforeach ()
	foreach (_item IN LISTS _libs)
		# Strip a single layer of common generator-expression wrappers,
		# e.g. $<LINK_ONLY:Qt6::Core>, $<BUILD_INTERFACE:...>
		string(REGEX REPLACE "^\\$<[A-Za-z_]+:(.*)>$" "\\1" _item "${_item}")
		if (_item MATCHES "^Qt::|^Qt[0-9]+::")
			set(${_out_var} TRUE PARENT_SCOPE)
			return()
		endif ()
		if (TARGET ${_item})
			get_target_property(_item_type ${_item} TYPE)
			if (_item_type STREQUAL "SHARED_LIBRARY")
				# Qt itself is SHARED and caught by the name match above;
				# any other shared dependency stops here - it carries
				# its own RUNPATH, doesn't propagate NEEDED further.
				continue()
			endif ()
			_sf_links_qt_impl("${_item}" ${_visited_var} _sub_result)
			set(${_visited_var} "${${_visited_var}}" PARENT_SCOPE)
			if (_sub_result)
				set(${_out_var} TRUE PARENT_SCOPE)
				return()
			endif ()
		endif ()
	endforeach ()
endfunction()
