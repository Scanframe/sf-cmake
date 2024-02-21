include(FetchContent)

##!
# Adds doxygen manual target to the project.
# _SourceList info is obtained using a GLOB function like:
#  file(GLOB_RECURSE _SourceListTmp RELATIVE "${CMAKE_CURRENT_BINARY_DIR}" "../*.h" "../*.md")
#
function(Sf_AddManual _Target _BaseDir _OutDir _SourceList)
	# Get the actual output directory.
	get_filename_component(_OutDir "${_OutDir}" REALPATH)
	# Check if the resulting directory exists.
	if (NOT EXISTS "${_OutDir}" OR NOT IS_DIRECTORY "${_OutDir}")
		message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Output directory '${_OutDir}' does not exist and needs to be created!")
	endif ()
	# Initialize plantuml version with empty string.
	set(_PlantUmlVer "")
	# Check if argument 4 which is the plantuml version is passed
	if (DEFINED ARGV4)
		if ("${ARGV4}" STREQUAL "")
			# Set default plantuml version.
			set(_PlantUmlVer "v1.2023.1")
		else ()
			set(_PlantUmlVer "${ARGV4}")
		endif ()
		message(STATUS "DoxyGen > PlantUML version to download: '${_PlantUmlVer}'")
		# Check GitHub for latest releases at 'https://github.com/plantuml/plantuml/releases'.
		FetchContent_Declare(PlantUmlJar
			URL "https://github.com/plantuml/plantuml/releases/download/${_PlantUmlVer}/plantuml.jar"
			DOWNLOAD_NO_EXTRACT true
			TLS_VERIFY true
		)
		# Download it.
		FetchContent_MakeAvailable(PlantUmlJar)
		# Set the variable used in the configuration template.
		set(DG_PlantUmlJar "${plantumljar_SOURCE_DIR}")
	else ()
		message(STATUS "PlantUML version not set and is not downloaded.")
	endif ()
	# Add doxygen project when doxygen was found
	find_package(Doxygen QUIET)
	if (NOT Doxygen_FOUND)
		message(NOTICE "${CMAKE_CURRENT_FUNCTION}(): Cannot Doxygen package is missing!")
		return()
	endif ()
	# For cygwin only relative path are working.
	file(RELATIVE_PATH DG_LogoFile "${CMAKE_CURRENT_BINARY_DIR}" "${_BaseDir}/logo.png")
	# Path to images adding the passed base directory. ()
	file(RELATIVE_PATH _Temp "${CMAKE_CURRENT_BINARY_DIR}" "${_BaseDir}")
	set(DG_ImagePath "${_Temp}")
	# Add the top project source dir so images in the code can be referenced from the root of the project.
	file(RELATIVE_PATH _Temp "${CMAKE_CURRENT_BINARY_DIR}" "${CMAKE_SOURCE_DIR}")
	set(DG_ImagePath "${DG_ImagePath} ${_Temp}")
	# Enable when to change the output directory.
	file(RELATIVE_PATH DG_OutputDir "${CMAKE_CURRENT_BINARY_DIR}" "${_OutDir}")
	# Set the MarkDown main page for the manual.
	file(RELATIVE_PATH DG_MainPage "${CMAKE_CURRENT_BINARY_DIR}" "${_BaseDir}/mainpage.md")
	# Replace the list separator ';' with a space and a double quotes in the list to allow names with spaces in it.
	list(JOIN _SourceList "\" \"" DG_Source)
	set(DG_Source "\"${DG_Source}\"")
	# Enable when generating Zen styling output.
	if (FALSE)
		set(DG_HtmlHeader "${SfDoxyGen_DIR}/theme/zen/header.html")
		set(DG_HtmlFooter "${SfDoxyGen_DIR}/theme/zen/footer.html")
		set(DG_HtmlExtra "${SfDoxyGen_DIR}/theme/zen/stylesheet.css")
		set(DG_HtmlExtraStyleSheet "")
	else ()
		# Fixes source file viewing.
		file(RELATIVE_PATH DG_HtmlExtraStyleSheet "${CMAKE_CURRENT_BINARY_DIR}" "${SfDoxyGen_DIR}/tpl/doxygen/custom.css")
	endif ()
	# Set the example path to this parent directory.
	file(RELATIVE_PATH DG_ExamplePath "${CMAKE_CURRENT_BINARY_DIR}" "${PROJECT_SOURCE_DIR}")
	# Set PlantUML the include path.
	set(DG_PlantUmlIncPath "${_BaseDir}")
	# Set input and output files for the generation of the actual config file.
	set(_FileIn "${SfDoxyGen_DIR}/tpl/doxygen/doxyfile.conf")
	set(_FileOut "${CMAKE_CURRENT_BINARY_DIR}/doxyfile.conf")
	# Generate the configure the file for doxygen.
	configure_file("${_FileIn}" "${_FileOut}" @ONLY)
	# Note the option ALL which allows to build the docs together with the application.
	add_custom_target("${_Target}"
		# Remove previous resulting 'html' directory.
		COMMAND ${CMAKE_COMMAND} -E rm -rf "${_OutDir}/html/"
		# Execute DoxyGen and generate the document.
		COMMAND ${DOXYGEN_EXECUTABLE} "${_FileOut}"
		WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
		COMMENT "Generating documentation with Doxygen"
		VERBATIM
	)
	# Only applicable when plantuml is available.
	if (NOT "${DG_PlantUmlJar}" STREQUAL "")
		# Remove plantuml cache file which prevent changes in the include file to propagate.
		add_custom_command(
			TARGET ${_Target}
			PRE_BUILD
			COMMAND ${CMAKE_COMMAND} -E rm -f "${_OutDir}/inline_*.pu"
			COMMENT "Cleanup plantuml files for next build."
		)
	endif ()
endfunction()

##!
# Gets the include directories from all targets in the list.
# When not found it returns "${_VarOut}-NOTFOUND"
# _var: Variable receiving resulting list of include directories.
# _targets: Build targets to get the include directories from.
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
