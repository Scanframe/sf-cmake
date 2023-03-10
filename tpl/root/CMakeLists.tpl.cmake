# Required first entry checking the cmake version.
cmake_minimum_required(VERSION 3.18)

# Make it so our own packages are found and also the ones in the sub-module library.
list(APPEND CMAKE_PREFIX_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake" "${CMAKE_CURRENT_LIST_DIR}/cmake/lib")

# Enable the tests added with add_test.
enable_testing()

# Package needed for Sf_GetGitTagVersion().
find_package(SfBase CONFIG REQUIRED)
# Package needed for adding function Sf_SetToolChain().
find_package(SfToolChain CONFIG REQUIRED)
# Install tool chain for Linux or Windows.
Sf_SetToolChain()

# Get the Git version number from the repository of this files directory.
Sf_GetGitTagVersion(SF_VERSION "${CMAKE_CURRENT_LIST_DIR}")

# Set the global project name.
project("My-Project"
	VERSION "${SF_VERSION}"
	DESCRIPTION "My Project Description"
	HOMEPAGE_URL "https://git.scanframe.com/example/my-project.git"
	LANGUAGES C CXX
	)

# Add top target for displaying info on the compiled target where Sf_AddExifTarget() is called on.
add_custom_target("exif" ALL)

# Enables including Qt libraries when building (libraries).
set(SF_BUILD_QT ON)
#set(SF_BUILD_QT OFF)

# Use faster linker for Windows maybe?
if (WIN32)
	# Adding option '-mwindows' as a linker flag will remove the console.
	# When using the CLion's MinGW compiler it gives an error.
	#set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fuse-ld=bfd")
	# Needed to be able to set debug breaks using MSVC
	SET(CMAKE_C_FLAGS_DEBUG "-D_DEBUG")
endif ()

# Make sure builds do not wind up in the source directory.
find_package(SfMacros CONFIG REQUIRED)
# Makes sure no out of project builds are performed. Meaning that sub projects will not build
find_package(SfBuildCheck CONFIG REQUIRED)
find_package(SfCompiler CONFIG REQUIRED)

# Set the 3 CMAKE_?????_OUTPUT_DIRECTORY variables to '<project-root>/bin/lnx64' '<project-root>/bin/win64' instead of the default ones.
Sf_SetOutputDirs()

# Add Sub Projects in the right order of dependency.
add_subdirectory(src)
# Add DoxyGen document project.
add_subdirectory(doc)