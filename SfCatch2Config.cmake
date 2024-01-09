# FetchContent added in CMake 3.11, downloads during the configure step
include(FetchContent)
# Check if the version has been given for this repo otherwise use a default.
if (NOT DEFINED Catch2_VERSION)
	set(Catch2_VERSION "v3.1.1")
endif ()
# Import Catch2 library for testing.
FetchContent_Declare(
	"Catch2-${Catch2_VERSION}"
	GIT_REPOSITORY https://github.com/catchorg/Catch2.git
	GIT_TAG "${Catch2_VERSION}"
)
# Adds Catch2::Catch2
FetchContent_MakeAvailable("Catch2-${Catch2_VERSION}")

### Lines to add to a project using this library.
#[[

# Make the library available.
find_package(SfCatch2 CONFIG REQUIRED)

# Link the library to the target.
target_link_libraries(MyTargetName PRIVATE Catch2::Catch2)

]]
