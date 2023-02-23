# FetchContent added in CMake 3.11, downloads during the configure step
include(FetchContent)
# Import Catch2 library for testing.
FetchContent_Declare(
	Catch2
	GIT_REPOSITORY https://github.com/catchorg/Catch2.git
	GIT_TAG v3.1.1
)
# Adds Catch2::Catch2
FetchContent_MakeAvailable(Catch2)

### Lines to add to a project using this library.
#[[

# Make nlohmann_json::nlohmann_json library available.
find_package(SfCatch2 CONFIG REQUIRED)

# Link the library to the target.
target_link_libraries(MyTargetName PRIVATE Catch2::Catch2)

]]
