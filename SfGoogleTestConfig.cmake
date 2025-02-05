# FetchContent added in CMake 3.11, downloads during the configure step
include(FetchContent)
# Import GoogleTest library for testing.
FetchContent_Declare(
	"GoogleTest-${SfGoogleTest_VERSION}"
	GIT_REPOSITORY https://github.com/google/googletest.git
	GIT_TAG "v${SfGoogleTest_VERSION}"
)
# Prevent GoogleTest from overriding options like BUILD_SHARED_LIBS
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
# Disable build the googlemock subproject by default.
set(BUILD_GMOCK OFF)
# Disable installation of googletest by default.
set(INSTALL_GTEST OFF)
# Adds 'gtest' library and 'gmock' library when it is enabled.
FetchContent_MakeAvailable("GoogleTest-${SfGoogleTest_VERSION}")

### Lines to add to a project using this library.
#[[

# Make the library available.
find_package(SfGoogleTest CONFIG REQUIRED)

# Make a specific version 1.15.2) of the library available.
find_package(SfGoogleTest 1.15.2 CONFIG REQUIRED)

# Link the library to the target.
target_link_libraries(MyTargetName PRIVATE gtest)

]]
