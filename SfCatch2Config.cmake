# FetchContent added in CMake 3.11, downloads during the configure step
include(FetchContent)
# Import Catch2 library for testing.
FetchContent_Declare(
	"Catch2-${SfCatch2_VERSION}"
	GIT_REPOSITORY https://github.com/catchorg/Catch2.git
	GIT_TAG "v${SfCatch2_VERSION}"
)
# Adds Catch2::Catch2
FetchContent_MakeAvailable("Catch2-${SfCatch2_VERSION}")

### Lines to add to a project using this library.
#[[

# Make the library available.
find_package(SfCatch2 CONFIG REQUIRED)

# Make a specific version 3.1.1) of the library available.
find_package(SfCatch2 3.1.1 CONFIG REQUIRED)

# Link the library to the target.
target_link_libraries(MyTargetName PRIVATE Catch2::Catch2)

]]
