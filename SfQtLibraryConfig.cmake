include("${CMAKE_CURRENT_LIST_DIR}/SfQtLibraryCommon.cmake")

Sf_QtLibraryDownload("${SfQtLibrary_VERSION}")

# When the Qt version directory was found/installed set the cmake prefix path.
if (NOT "$ENV{QT_VER_DIR}" STREQUAL "")
	Sf_GetQtCompilerSubdirectory(_QtCompileName)
	if (_QtCompileName STREQUAL "")
		message(FATAL_ERROR "SF_COMPILER '${SF_COMPILER}' has no solution for the 'CMAKE_PREFIX_PATH' path!")
	endif ()
	set(_QtVerCompiler "$ENV{QT_VER_DIR}/${_QtCompileName}")
	if (EXISTS "${_QtVerCompiler}/lib/cmake")
		# Add the cmake directory to the cmake search path.
		list(PREPEND CMAKE_PREFIX_PATH "${_QtVerCompiler}/lib/cmake")
		# Set the Qt include directory.
		set(SF_QT_INCLUDE_DIRECTORY "${_QtVerCompiler}/include")
	else ()
		message(FATAL_ERROR "Compiler '${SF_COMPILER}' QT cmake library prefix directory '${_QtVerCompiler}/lib/cmake' does not exist!")
	endif ()
	# When the Windows cross compiler is selected, the QT_HOST_PATH is required.
	if (SF_COMPILER STREQUAL "gw" AND NOT DEFINED QT_HOST_PATH AND NOT DEFINED ENV{QT_HOST_PATH})
		string(REPLACE "/win-x86_64/" "/lnx-x86_64/" QT_HOST_PATH "$ENV{QT_VER_DIR}/gcc_64")
		if (NOT EXISTS "${QT_HOST_PATH}")
			message(FATAL_ERROR "Required QT_HOST_PATH '${QT_HOST_PATH}' was not found!")
		endif ()
	endif ()
	unset(_QtCompileName)
endif ()
