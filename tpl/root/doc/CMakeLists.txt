# Required first entry checking the cmake version.
cmake_minimum_required(VERSION 3.25...4.4)

# Set the global project name.
project("document")

# Add doxygen project when SfDoxygen was found.
find_package(SfDoxygen QUIET)
if (SfDoxygen_FOUND)
	set(_src_list)
	# Get the markdown files in this directory and the cmake library.
	file(GLOB _Sources RELATIVE "${CMAKE_CURRENT_BINARY_DIR}" "*.md" "${CMAKE_SOURCE_DIR}/cmake/lib/doc/*.md")
	list(APPEND _src_list ${_Sources})
	# Get all 'doc' named subdirectories in the source tree relative to the binary directory
	# where Doxygen is running from where images are possibly accessed.
	Sf_GetNamedSubdirectories("${CMAKE_SOURCE_DIR}/src" "${CMAKE_CURRENT_BINARY_DIR}" "doc" _image_dirs)
	foreach (_image_dir ${_image_dirs})
		file(GLOB _Sources RELATIVE "${CMAKE_CURRENT_BINARY_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/${_image_dir}/*.md")
		list(APPEND _src_list ${_Sources})
	endforeach ()
	# Retrieve all non-test targets from the global project.
	Sf_GetAllTargets(_targets "${CMAKE_SOURCE_DIR}" TRUE)
	set(_doc_targets)
	# Iterate through all targets and skip all non 'doc' flagged targets.
	foreach (_target IN LISTS _targets)
		Sf_HasTargetFlag(_is_doc "${_target}" doc)
		if (NOT _is_doc)
			continue()
		endif ()
		# Exclude fetched targets.
		get_target_property(_source_dir "${_target}" SOURCE_DIR)
		string(FIND "${_source_dir}" "${FETCHCONTENT_BASE_DIR}" _Pos)
		if(_Pos EQUAL 0)
			message(VERBOSE "Document Target Skipped: ${_target}")
			continue()
		endif ()
		get_target_property(_type "${_target}" TYPE)
		# Only use executables and shared or static libraries.
		if (_type STREQUAL "EXECUTABLE" OR _type STREQUAL "SHARED_LIBRARY" OR _type STREQUAL "STATIC_LIBRARY")
			message(VERBOSE "Document Target (${_type}): ${_target}")
			list(APPEND _doc_targets "${_target}")
		endif ()
	endforeach ()
	# Get the source files from the the passed document targets.
	Sf_GetSourceFiles(_sources "${_doc_targets}" "${CMAKE_CURRENT_BINARY_DIR}")
	# Only add files with the '.h' extension.
	list(FILTER _sources INCLUDE REGEX ".*\\.h$")
	# Remove unwanted header file(s) ending on 'Private.h'.
	list(FILTER _sources EXCLUDE REGEX ".*Private\\.h$")
	# Remove unwanted header file(s) ending on '_p.h'.
	list(FILTER _sources EXCLUDE REGEX ".*_p\\.h$")
	# Add the target found sources to the list.
	list(APPEND _src_list ${_sources})
	# Output a list of sources.
	list(JOIN _src_list "\n\t" _files)
	message(VERBOSE "Target Files:\n\t${_files}")
	# Adds the actual manual target and the last 2 optional arguments are awesome theming flag and plantuml version.
	Sf_AddDoxygenDocumentation("${PROJECT_NAME}" "${PROJECT_SOURCE_DIR}" "${_image_dirs}" "${PROJECT_SOURCE_DIR}/../bin/man" "${_src_list}" TRUE)
endif ()
