add_subdirectory("cli")
add_subdirectory("hwl")

# When Qt libraries are linked.
if (SF_BUILD_QT)
	add_subdirectory(qt)
endif ()
