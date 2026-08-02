#!/usr/bin/env bash
{
	command -v lsb_release >/dev/null && echo -e "$(lsb_release --id --short):$(lsb_release --release --short)"
	command -v git >/dev/null && echo -e "Git:$(git --version | head -n 1 | grep -o '[^ ]*$')"
	command -v gcc >/dev/null && echo -e "GCC:$(gcc --version | head -n 1 | grep -o '[^ ]*$')"
	command -v g++ >/dev/null && echo -e "C++:$(g++ --version | head -n 1 | grep -o '[^ ]*$')"
	command -v gcc-12 >/dev/null && echo -e "GCC-12:$(gcc-12 --version | head -n 1 | grep -o '[^ ]*$')"
	command -v g++-12 >/dev/null && echo -e "C++-12:$(g++-12 --version | head -n 1 | grep -o '[^ ]*$')"
	command -v gcc-13 >/dev/null && echo -e "GCC-13:$(gcc-13 --version | head -n 1 | grep -o '[^ ]*$')"
	command -v g++-13 >/dev/null && echo -e "C++-13:$(g++-13 --version | head -n 1 | grep -o '[^ ]*$')"
	command -v aarch64-linux-gnu-gcc >/dev/null && echo -e "Aarch64 GCC:$(aarch64-linux-gnu-gcc --version | head -n 1 | grep -o '[^ ]*$')"
	command -v aarch64-linux-gnu-g++ >/dev/null && echo -e "Aarch64 G++:$(aarch64-linux-gnu-g++ --version | head -n 1 | grep -o '[^ ]*$')"
	command -v x86_64-w64-mingw32-gcc-posix >/dev/null && echo -e "MinGW GCC:$(x86_64-w64-mingw32-gcc-posix --version | head -n 1 | cut -d' ' -f3)"
	command -v x86_64-w64-mingw32-c++-posix >/dev/null && echo -e "MinGW C++:$(x86_64-w64-mingw32-c++-posix --version | head -n 1 | cut -d' ' -f3)"
	command -v cmake >/dev/null && echo -e "CMake:$(cmake --version -q | head -n 1 | grep -o '[^ ]*$')"
	command -v make >/dev/null && echo -e "GNU-Make:$(make --version | head -n 1 | grep -o '[^ ]*$')"
	command -v patch >/dev/null && echo -e "GNU-Patch:$(patch --version | head -n 1 | grep -o '[^ ]*$')"
	command -v ninja >/dev/null && echo -e "Ninja-Build:$(ninja --version)"
	command -v clang-format >/dev/null && echo -e "CLang-Format:$(clang-format --version | cut -d' ' -f4)"
	command -v gdb >/dev/null && echo -e "Gdb:$(gdb --version | head -n 1 | grep -o '[^ ]*$')"
	command -v ld >/dev/null && echo -e "GNU-Linker:$(ld -version | head -n 1 | grep -o '[^ ]*$')"
	[[ -d ~/lib/qt ]] && find ~/lib/qt -maxdepth 2 -type d -name "*.*.*" -printf "Qt Library:%P\n"
	command -v doxygen >/dev/null && echo -e "DoxyGen:$(doxygen --version)"
	command -v dot >/dev/null && echo -e "Graphviz:$(dot -V 2>&1 | cut -d' ' -f5)"
	command -v exiftool >/dev/null && echo -e "Exif-Tool:$(exiftool -ver)"
	command -v dpkg >/dev/null && echo -e "Dpkg:$(dpkg --version | head -n 1 | cut -d' ' -f7)"
	command -v rpm >/dev/null && echo -e "RPM:$(rpm --version | grep -o '[^ ]*$')"
	command -v java >/dev/null && echo -e "OpenJDK:$(java --version | head -n 1 | cut -d' ' -f2)"
	command -v bindfs >/dev/null && echo -e "BindFS:$(bindfs --version | grep -o '[^ ]*$')"
	command -v fuse-zip >/dev/null && echo -e "Fuse-zip:$(fuse-zip --version 2>&1 | head -n 1 | cut -d' ' -f3)"
	command -v 7z >/dev/null && echo -e "7-zip:$( "7z" 2>/dev/null | head -n 2 | tail -n 1  | cut -d' ' -f2)"
	command -v jq >/dev/null && echo -e "JQ:$(jq --version | cut -d'-' -f2)"
	command -v gcovr >/dev/null && echo -e "Gcovr:$(gcovr --version | head -n 1 | grep -o '[^ ]*$')"
	command -v python3 >/dev/null && echo -e "Python3:$(python3 --version | cut -d' ' -f2)"
	# Wine only for x86_64 platforms.
	if [[ "$(uname -m)" == "x86_64" ]] && command -v wine >/dev/null; then
		export WINEDEBUG=fixme-all
		echo -e "Wine:$(wine --version | sed 's/^wine-\(\S*\).*$/\1/')"
		winver="$(DISPLAY='' wine cmd /c ver 2>/dev/null)"
		echo "Wine > Windows:$(echo "${winver:4}" | cut -d' ' -f3)"
		if [[ -f "${HOME}/.wine/drive_c/python/python.exe" ]]; then
			echo "Wine > Python:$(wine cmd /c 'python' --version 2>/dev/null)"
		fi
		for dir in "${PWD}/lib/toolchain" "${HOME}/toolchain"; do
			[[ ! -d "${dir}" ]] && continue
			while IFS= read -r exe_path; do
				echo -n "Wine > MinGW:"
				wine "${exe_path}" --version | head -n 1 | grep -o '[^ ]*$'
				# Your logic here
			done < <(find "${dir}/w64-x86_64-mingw"* -name "gcc.exe")
			while IFS= read -r exe_path; do
				echo -n "Wine > MSVC:"
				wine "${exe_path}" 2>&1 | head -n 1 | cut -d' ' -f7
				# Your logic here
			done < <(find "${dir}/w64-x86_64-msvc"* -name "cl.exe" 2>/dev/null)
		done
		for dir in "${PWD}/lib/toolchain/win-x86_64-"*-combi "${HOME}/tools"; do
			[[ ! -d "${dir}" ]] && continue
			version="$(wine "${dir}/bin/patch.exe" --version 2>/dev/null | head -n 1 | tr -d '\r' | grep -o '[^ ]*$')" && echo -e "Wine > GNU-Patch:${version}"
			version="$(wine "${dir}/bin/7z.exe" | head -n 2 | tail -n 1  | cut -d' ' -f3)" && echo -e "Wine > Z-zip:${version}"
			version="$(wine "${dir}/bin/ninja.exe" --version 2>/dev/null)" && echo -e "Wine > Ninja:${version}"
		done
	fi
} | column --table --separator ':' --table-columns 'Application,Version' -o " | " | sed '1a----------------------------'
