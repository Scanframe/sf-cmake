# FetchContent added in CMake 3.11, downloads during the configure step
include(FetchContent)
# Import Json library.
FetchContent_Declare(
	json
	GIT_REPOSITORY https://github.com/nlohmann/json
	GIT_TAG v3.11.2
	)
# Adds nlohmann_json::nlohmann_json
FetchContent_MakeAvailable(json)

### Lines to add to a project using this library.
#[[

# Make nlohmann_json::nlohmann_json library available.
find_package(SfJson CONFIG REQUIRED)

# Link the library to the target.
target_link_libraries(MyTargetName PRIVATE nlohmann_json::nlohmann_json)

]]


