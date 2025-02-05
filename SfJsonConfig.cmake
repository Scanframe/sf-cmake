# FetchContent added in CMake 3.11, downloads during the configure step
include(FetchContent)
# Check if the version has been given for this repo otherwise use a default.
if (NOT DEFINED json_VERSION)
	set(json_VERSION "v3.11.3")
endif ()
# Import Json library.
FetchContent_Declare(
	json
	GIT_REPOSITORY "https://github.com/nlohmann/json"
	GIT_TAG "${json_VERSION}"
	)
# Adds nlohmann_json::nlohmann_json
FetchContent_MakeAvailable(json)

### Lines to add to a project using this library.
#[[

# Make the library available.
find_package(SfJson CONFIG REQUIRED)

# Link the library to the target.
target_link_libraries(MyTargetName PRIVATE nlohmann_json::nlohmann_json)

]]


