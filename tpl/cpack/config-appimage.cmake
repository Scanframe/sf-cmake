# Define path to 'appimagetool'.
# Original download locations for different CPU architectures:
# - https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-aarch64.AppImage
# - https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
find_program(APPIMAGETOOL_EXECUTABLE "appimagetool" REQUIRED)
if (APPIMAGETOOL_EXECUTABLE)
	set(CPACK_APPIMAGE_TOOL_EXECUTABLE "${APPIMAGETOOL_EXECUTABLE}")
endif ()
# Original download locations for different CPU architectures:
# - https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64
# - https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-aarch64
find_program(APPIMAGETOOL_RUNTIME "runtime-${SF_ARCHITECTURE}" PATHS "${CMAKE_CURRENT_SOURCE_DIR}/lib/toolchain/lnx-${SF_HOST_ARCHITECTURE}-combi/bin" REQUIRED)
if (APPIMAGETOOL_RUNTIME)
	set(CPACK_APPIMAGE_RUNTIME_FILE "${APPIMAGETOOL_RUNTIME}")
endif ()
# Define path to 'patchelf'.
find_program(PATCHELF_EXECUTABLE "patchelf" REQUIRED)
if (PATCHELF_EXECUTABLE)
	set(CPACK_APPIMAGE_PATCHELF_EXECUTABLE "${PATCHELF_EXECUTABLE}")
endif ()
# Set the environment variable 'ARCH' to the architecture being build.
set(CPACK_CUSTOM_INSTALL_VARIABLES "ARCH=${SF_ARCHITECTURE}")

# MAke the install script the required '/usr' install prefix inside the AppDir.
set(CPACK_PACKAGING_INSTALL_PREFIX "/usr")
