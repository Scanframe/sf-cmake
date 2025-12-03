include(FetchContent)

##!
# Adds Doxygen documentation manual target to the project.
# _SourceList info is obtained using a GLOB function like:
# @param _Target Name of the build target.
# @param _DocBaseDir Document base directory for general documentation.
# @param _ImageDirs Document directories for searching images.
# @param _OutDir Directory for the HTML output.
# @param _SourceList List of files to process which could be markdown, html and C++ header files.
#
function(Sf_AddDoxygenDocumentation _Target _DocBaseDir _ImageDirs _OutDir _SourceList)
	# Get the actual output directory.
	Sf_GetFilenameComponent(_OutDir "${_OutDir}" REALPATH)
	# Check if the resulting directory exists.
	if (NOT EXISTS "${_OutDir}" OR NOT IS_DIRECTORY "${_OutDir}")
		message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Output directory '${_OutDir}' does not exist and needs to be created!")
	endif ()
	# Initialize plantuml version with empty string.
	set(_PlantUmlVer "")
	# Check if argument 4 which is the plantuml version is passed
	if (DEFINED ARGV5)
		if (ARGV5 STREQUAL "")
			# Set default plantuml version.
			set(_PlantUmlVer "v1.2023.1")
		else ()
			set(_PlantUmlVer "${ARGV5}")
		endif ()
		message(STATUS "Doxygen > PlantUML version to download: '${_PlantUmlVer}'")
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
	# Just a copy of the current project version and description.
	set(DG_ProjectVersion "${CMAKE_PROJECT_VERSION}")
	set(DG_ProjectDescription "${CMAKE_PROJECT_DESCRIPTION}")
	# For cygwin only relative path are working.
	file(RELATIVE_PATH DG_LogoFile "${CMAKE_CURRENT_BINARY_DIR}" "${_DocBaseDir}/logo.png")
	# Path to images of the document base directory.
	file(RELATIVE_PATH DG_ImagePath "${CMAKE_CURRENT_BINARY_DIR}" "${_DocBaseDir}")
	# Add the image directories (assumed they are relative!).
	list(APPEND DG_ImagePath ${_ImageDirs})
	# Multiple paths need to be SPACE separated!
	list(JOIN DG_ImagePath " " DG_ImagePath)
	# Enable when to change the output directory.
	file(RELATIVE_PATH DG_OutputDir "${CMAKE_CURRENT_BINARY_DIR}" "${_OutDir}")
	# Set the MarkDown main page for the manual.
	file(RELATIVE_PATH DG_MainPage "${CMAKE_CURRENT_BINARY_DIR}" "${_DocBaseDir}/mainpage.md")
	# Replace the list separator ';' with a space and a double quotes in the list to allow names with spaces in it.
	list(JOIN _SourceList "\" \"" DG_Source)
	set(DG_Source "\"${DG_Source}\"")
	# Enable when generating Zen styling output.
	if (FALSE)
		set(DG_HtmlHeader "${SfDoxygen_DIR}/theme/zen/header.html")
		set(DG_HtmlFooter "${SfDoxygen_DIR}/theme/zen/footer.html")
		set(DG_HtmlExtra "${SfDoxygen_DIR}/theme/zen/stylesheet.css")
		set(DG_HtmlExtraStyleSheet "")
	else ()
		# Fixes source file viewing.
		file(RELATIVE_PATH DG_HtmlExtraStyleSheet "${CMAKE_CURRENT_BINARY_DIR}" "${SfDoxygen_DIR}/tpl/doxygen/custom.css")
	endif ()
	# Set the example path for this project it currently only accepts a single directory.
	file(RELATIVE_PATH DG_ExamplePath "${CMAKE_CURRENT_BINARY_DIR}" "${SF_EXAMPLE_DIR}")
	# Set PlantUML the include path.
	set(DG_PlantUmlIncPath "${_DocBaseDir}")
	# Set input and output files for the generation of the actual config file.
	set(_FileIn "${SfDoxygen_DIR}/tpl/doxygen/doxyfile.conf")
	set(_FileOut "${CMAKE_CURRENT_BINARY_DIR}/doxyfile.conf")
	# Generate the configure the file for doxygen.
	configure_file("${_FileIn}" "${_FileOut}" @ONLY)
	# Note the option ALL which allows to build the docs together with the application.
	add_custom_target("${_Target}"
		# Remove previous resulting 'html' directory.
		COMMAND ${CMAKE_COMMAND} -E rm -rf "${_OutDir}/html/"
		# Execute Doxygen and generate the document.
		COMMAND ${DOXYGEN_EXECUTABLE} "${_FileOut}"
		WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
		COMMENT "Generating documentation with Doxygen"
		VERBATIM
		USES_TERMINAL
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
