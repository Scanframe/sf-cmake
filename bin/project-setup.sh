#!/usr/bin/env bash

# Bailout on first error.
set -e
# Make sure the 'tee pipes' fail correctly. Don't hide errors within pipes.
set -o pipefail

# Get this script's directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

## Trap script exit with function.
trap 'ScriptExit "${BASH_SOURCE}" "${BASH_LINENO}" "${BASH_COMMAND}"' EXIT

# Include miscellaneous functions.
source "${script_dir}/inc/Miscellaneous.sh"

# Get this script's working directory as the project directory.
prj_dir="$(pwd)"

# Template base dir.
tpl_dir="$(realpath "${script_dir}/../tpl")"

# GitLab CI config files directory.
gitlab_ci_dir="${prj_dir}/.gitlab-ci"

WriteLog "# Setup the project..."
WriteLog "- Template directory: ${tpl_dir}"
WriteLog "- Project directory: ${prj_dir}"
WriteLog "- GitLab-CI directory: ${gitlab_ci_dir}"

if AskConfirmation "Copy sample project source?"; then
	if [[ -d "${prj_dir}/src" ]]; then
		WriteLog "Source directory '<root>/src' already exists!"
	else
		cp --recursive --interactive "${tpl_dir}/root/src" "${prj_dir}/src"
	fi
fi

if AskConfirmation "Copy sample project documentation?"; then
	if [[ -d "${prj_dir}/doc" ]]; then
		WriteLog "Document directory '<root>/doc' already exists!"
	else
		cp --recursive --interactive "${tpl_dir}/root/doc" "${prj_dir}/doc"
	fi
fi

if AskConfirmation "Create project directories?"; then
	subdirs=("lib" "bin/config" "bin/man" "bin/gcov" "bin/lnx64/lib" "bin/win64/lib")
	for dir in "${subdirs[@]}"; do
		WriteLog "- Directory: ${dir}"
		mkdir -p "${prj_dir}/${dir}"
		WriteLog "- Adding: ${dir}/.gitkeep"
		touch "${prj_dir}/${dir}/.gitkeep"
		git add --force "${prj_dir}/${dir}/.gitkeep"
	done
	cat <<'EOD' >"${prj_dir}/bin/man/open.sh"
#!/usr/bin/env bash

# shellcheck disable=SC2034
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$(uname -o)" == "Cygwin" ]]; then
	"$(ls -f /cygdrive/*/Program\ Files*/Google/Chrome/Application/chrome.exe | head -n 1)" --app="file://$(cygpath --mixed "${script_dir}/html/index.html")"
else
	google-chrome --app="file://${script_dir}/html/index.html"
fi
EOD
	# Make the script executable.
	chmod +x "${prj_dir}/bin/man/open.sh"
	cat <<'EOD' >"${prj_dir}/bin/__output__"
Place holder for finding the directory to for binary output for the projects.
Used by cmake function "Sf_LocateOutputDir()" for locating it.
EOD
	git add "${prj_dir}/bin/__output__"
	# Create the config symlinks.
	cfg_dirs=("bin/lnx64" "bin/win64")
	for dir in "${cfg_dirs[@]}"; do
		WriteLog "- Symlinking config directory: ${dir}/config"
		ln --relative --symbolic --force "${prj_dir}/bin/config" "${prj_dir}/${dir}"
		git add "${prj_dir}/${dir}/config"
	done
	# Also copied from the cmake project when a needed script does not exist.
	bin_files=("lnx-exec.sh" "win-exec.cmd" "win-exec.sh")
	for fn in "${bin_files[@]}"; do
		WriteLog "- Copying shell script: bin/${fn}"
		cp "${tpl_dir}/bin/${fn}" "${prj_dir}/bin/"
		git add "${prj_dir}/bin/${fn}"
	done
	# When the Qt library directory exists.
	qt_lib_dir="/mnt/server/userdata/applications/library/qt"
	if [[ -d "${qt_lib_dir}" && ! -d "${prj_dir}/lib/qt" ]]; then
		WriteLog "- Symlinking Qt library: ${prj_dir}/lib/qt"
		ln --symbolic --relative --force "${qt_lib_dir}" "${prj_dir}/lib/qt"
	fi
fi

if AskConfirmation "Copy project files from template?"; then
	declare -A root_files
	root_files["CMakeLists.cmake"]="CMakeLists.txt"
	root_files["CMakePresets.json"]="CMakePresets.json"
	root_files["CMakeUserPresets.json"]="CMakeUserPresets.json"
	root_files["user.cmake"]="user.cmake"
	root_files["default.gitignore"]=".gitignore"
	root_files["default.clang-format"]=".clang-format"
	for fn in "${!root_files[@]}"; do
		WriteLog "- File: ${root_files["${fn}"]}"
		cp --interactive "${tpl_dir}/root/${fn}" "${prj_dir}/${root_files["${fn}"]}"
		git add "${prj_dir}/${root_files["${fn}"]}" || true
	done
fi

if AskConfirmation "Symlink shell scripts?"; then
	script_files=("build.sh" "docker-build.sh" "check-format.sh" "version-bump.sh")
	# Iterate through the array.
	for fn in "${script_files[@]}"; do
		WriteLog "- File: ${fn}"
		ln --force --relative --symbolic "${script_dir}/${fn}" "${prj_dir}/${fn}" || true
		git add "${prj_dir}/${fn}"
	done
	if AskConfirmation "Install git pre-commit hook?"; then
		cp "${tpl_dir}/root/git-pre-commit-hook.sh" "${prj_dir}/.git/hooks/pre-commit"
	fi
fi

if AskConfirmation "GitLab-CI configuration?"; then
	gitlab_ci_files=("build-single.gitlab-ci.yml" "coverage.gitlab-ci.yml" "main.gitlab-ci.yml" "test.gitlab-ci.yml")
	for fn in "${gitlab_ci_files[@]}"; do
		WriteLog "- File: ${fn}}"
		mkdir -p "${gitlab_ci_dir}"
		cp --interactive "${tpl_dir}/root/gitlab-ci/${fn}" "${gitlab_ci_dir}/${fn}" || true
		git add "${gitlab_ci_dir}/${fn}"
	done
fi
