include(FetchContent)

##!
# Adds Doxygen documentation manual target to the project.
# _SourceList info is obtained using a GLOB function like:
# @param _Target Name of the build target.
# @param _DocBaseDir Document base directory for general documentation.
# @param _ImageDirs Document directories for searching images.
# @param _OutDir Directory for the HTML output.
# @param _SourceList List of files to process which could be markdown, html and C++ header files.
# @param [_FlagTheme] Flag for using Awesome theming plugin.
# @param [_PlantUmlVer] Version to use for PlantUML like '1.2025.10'.
#
function(Sf_AddDoxygenDocumentation _Target _DocBaseDir _ImageDirs _OutDir _SourceList)
	# Get the first optional argument which is the version.
	Sf_GetOptionalArgument(_FlagTheme 0 "${ARGN}")
	Sf_GetOptionalArgument(_PlantUmlVer 1 "${ARGN}")
	# Get the actual output directory.
	Sf_GetFilenameComponent(_OutDir "${_OutDir}" REALPATH)
	# Check if the resulting directory exists.
	if (NOT EXISTS "${_OutDir}" OR NOT IS_DIRECTORY "${_OutDir}")
		message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Output directory '${_OutDir}' does not exist and needs to be created!")
	endif ()
	if ("${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows")
		set(_TlsCheck FALSE)
	else ()
		set(_TlsCheck TRUE)
	endif ()
	# Add doxygen project when doxygen was found
	find_package(Doxygen QUIET)
	if (NOT Doxygen_FOUND)
		message(STATUS "${CMAKE_CURRENT_FUNCTION}(): Doxygen package has not been found!")
		return()
	endif ()
	# Check if the version was passed in the optional argument.
	if (NOT DEFINED _PlantUmlVer)
		# Get the latest release version number from 'https://github.com/plantuml/plantuml/tags' through the API.
		Sf_GetGitHubVersion(_Version "plantuml" "plantuml")
		# When found override the default.
		if (_Version)
			set(_PlantUmlVer "${_Version}")
		endif ()
	endif ()
	# Check if the version still isn't defined.
	if (NOT DEFINED _PlantUmlVer)
		# Set default plantuml version to the known latest.
		set(_PlantUmlVer "1.2025.10")
	endif ()
	# Download only when a version was set.
	if (NOT _PlantUmlVer STREQUAL "")
		message(STATUS "Doxygen > PlantUML version to download: '${_PlantUmlVer}'")
		# Check GitHub for latest releases at 'https://github.com/plantuml/plantuml/releases'.
		FetchContent_Declare(PlantUmlJar
			URL "https://github.com/plantuml/plantuml/releases/download/v${_PlantUmlVer}/plantuml.jar"
			DOWNLOAD_NO_EXTRACT TRUE
			TLS_VERIFY ${_TlsCheck}
		)
		# Download it.
		FetchContent_MakeAvailable(PlantUmlJar)
		# Set the variable used in the configuration template.
		set(DG_PlantUmlJar "${plantumljar_SOURCE_DIR}")
	endif ()
	# Just a copy of the current project version and description.
	set(DG_ProjectVersion "${CMAKE_PROJECT_VERSION}")
	set(DG_ProjectDescription "${CMAKE_PROJECT_DESCRIPTION}")
	if (WIN32)
		find_program(_DotExe
			NAMES dot
			PATHS
				"C:/Program Files/Graphviz/bin"
				"C:/Program Files (x86)/Graphviz/bin"
				"$ENV{ProgramFiles}/Graphviz/bin"
				"$ENV{ProgramFiles\(x86\)}/Graphviz/bin"
			DOC "Graphviz dot executable"
			REQUIRED
		)
	else ()
		find_program(_DotExe
			NAMES dot
			DOC "Graphviz dot executable"
			REQUIRED
		)
	endif ()
	set(DG_GraphizDotPath "${_DotExe}")
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
	unset(_SourceList)
	set(DG_Source "\"${DG_Source}\"")
	# Enable when generating Awesome styling output.
	if (DEFINED _FlagTheme AND _FlagTheme)
		#[[
		Required for this theme to work
		GENERATE_TREEVIEW      = YES # optional. Also works without treeview
		DISABLE_INDEX = NO
		FULL_SIDEBAR = NO
		HTML_EXTRA_STYLESHEET  = doxygen-awesome-css/doxygen-awesome.css
		HTML_COLORSTYLE        = LIGHT # required with Doxygen >= 1.9.5
		]]
		FetchContent_Declare(doxygen_awesome
			GIT_REPOSITORY "https://github.com/jothepro/doxygen-awesome-css.git"
			GIT_TAG "v2.4.1"
			GIT_SHALLOW 1
			TLS_VERIFY ${_TlsCheck}
		)
		# Download it.
		FetchContent_MakeAvailable(doxygen_awesome)
		# Header
		#file(RELATIVE_PATH DG_HtmlHeader "${CMAKE_CURRENT_BINARY_DIR}" "${doxygen_awesome_SOURCE_DIR}/doxygen-custom/header.html")
		# CSS files.
		file(RELATIVE_PATH DG_HtmlExtraStyleSheet "${CMAKE_CURRENT_BINARY_DIR}" "${doxygen_awesome_SOURCE_DIR}/doxygen-awesome.css")
		# Javascript files.
		file(GLOB _JsFiles LIST_DIRECTORIES FALSE RELATIVE "${CMAKE_CURRENT_BINARY_DIR}" "${doxygen_awesome_SOURCE_DIR}/*.js")
		list(JOIN _JsFiles "\" \"" DG_HtmlExtraFiles)
		unset(_JsFiles)
		set(DG_HtmlExtraFiles "\"${DG_HtmlExtraFiles}\"")
	else ()
		# Fixes source file viewing.
		file(RELATIVE_PATH DG_HtmlExtraStyleSheet "${CMAKE_CURRENT_BINARY_DIR}" "${SfDoxygen_DIR}/tpl/doxygen/custom.css")
		file(RELATIVE_PATH DG_HtmlExtraFiles "${CMAKE_CURRENT_BINARY_DIR}" "${_DocBaseDir}/favicon.ico")
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
