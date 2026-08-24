##!
# Ensures that the current build directory is not within the source.
# @param _Message Message to report when build directory is in the source tree.
#
function(Sf_EnsureOutOfSourceBuild _Message)
	string(COMPARE EQUAL "${CMAKE_SOURCE_DIR}" "${CMAKE_BINARY_DIR}" _InSource)
	Sf_GetFilenameComponent(_ParentDir ${CMAKE_SOURCE_DIR} PATH)
	string(COMPARE EQUAL "${CMAKE_SOURCE_DIR}" "${_ParentDir}" _InSourceSubdir)
	if(_InSource OR _InSourceSubdir)
		message(SEND_ERROR "${_Message}")
	endif()
endfunction()

# Ensures that we do an out of source build
Sf_EnsureOutOfSourceBuild("Project '${PROJECT_NAME}' requires an out of source build!")
