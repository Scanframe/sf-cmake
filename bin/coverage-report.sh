#!/bin/bash

# Exit at first error.
set -e
# Get the script directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Include WriteLog function.
source "${SCRIPT_DIR}/inc/Miscellaneous.sh"

## Trap script exit with function.
trap 'ScriptExit "${BASH_SOURCE}" "${BASH_LINENO}" "${BASH_COMMAND}"' EXIT

# Prints the help.
#
function ShowHelp {
	echo "Usage: ${0} [options] <directories>

  Needs to be executed in the project directory where the main CMakeLists.txt resides.

  Options:
    -h, --help    : Show this help.
    -s, --source  : Source directory for gcda-files. Defaults to current working directory.
    -t, --target  : Target directory for report.
    -w, --working : Work directory defaults to current working.
    -n, --name    : Report basename which defaults to 'report'.
    --gcov        : Location of the 'gcov' when a different toolchain has been used.
    --cleanup     : Remove the gcda files after the report was generated successfully.
    --verbose     : Inform what is done.
"
}

# Variables used.
gcovr_bin="$(which gcovr)"
gcov_bin=""
filename="report"
source_dir=""
target_dir=""
working_dir="${PWD}"
flag_cleanup=false
flag_verbose=false
flag_search_path=true
flag_report_json=true
flag_report_html=true
## When CI-pipline is involved do not generate html or json files.
#if [[ "${CI}" == "true" ]]; then
#	flag_report_json=false
#	flag_report_html=false
#fi

# Parse options.
temp=$(getopt -o 'hs:t:n:w:' \
	--long 'help,source:,target:,working:,name:,cleanup,verbose,gcov:' \
	-n "$(basename "${0}")" -- "$@")
# No arguments, show help and bailout.
if [[ "${#}" -eq 0 ]]; then
	ShowHelp
	exit 1
fi
eval set -- "${temp}"
unset temp
while true; do
	case $1 in

		-h | --help)
			ShowHelp
			exit 0
			;;

		-t | --target)
			target_dir="${2}"
			shift 2
			continue
			;;

		-s | --source)
			source_dir="${2}"
			shift 2
			continue
			;;

		-w | --working)
			working_dir="${2}"
			shift 2
			continue
			;;

		-n | --name)
			filename="${2}"
			shift 2
			continue
			;;

		--gcov)
			gcov_bin="${2}"
			shift 2
			continue
			;;

		--verbose)
			flag_verbose=true
			shift 1
			continue
			;;

		--cleanup)
			flag_cleanup=true
			shift 1
			continue
			;;

		'--')
			shift
			break
			;;

		*)
			WriteLog "Internal error on argument (${1}) !"
			exit 1
			;;
	esac
done

# Harvest the arguments in an array.
argument=()
while [ "${#}" -gt 0 ] && ! [[ "${1}" =~ ^- ]]; do
	argument+=("${1}")
	shift
done

#if ${flag_verbose}; then
WriteLog "- Command gcovr   : ${gcovr_bin}"
WriteLog "- Command gcov    : ${gcov_bin:-'Default'}"
WriteLog "- Source directory: ${source_dir}"
WriteLog "- Target directory: ${target_dir}"
WriteLog "- Working directory: ${working_dir}"
WriteLog "- Filters(${#argument[@]}): ${argument[*]}"
#fi

# Validate the source directory.
if [[ ! -d "${source_dir}" ]]; then
	WriteLog "Need valid source directory!"
	exit 1
fi

# Validate the target directory.
if [[ ! -d "${target_dir}" ]]; then
	WriteLog "Need valid target directory!"
	exit 1
fi

# Validate the working directory.
if [[ ! -d "${working_dir}" ]]; then
	WriteLog "Need valid working directory!"
	exit 1
fi

# Validate the filename.
regex='^[a-zA-Z\\-\\.+~]+$'
if [[ ! "${filename}" =~ ${regex} ]]; then
	WriteLog "Filename '${filename}' does not match regex '${regex}'!"
	exit 1
fi

# Prepend the filter directories with '--filter '.
filters=()
for dir in "${argument[@]}"; do
	filters+=("--filter" "${dir}")
done

# Create directory when it does not exist.
mkdir --parents "${target_dir}"

if ${flag_verbose}; then
	WriteLog "- Removing all existing files named like '${filename}'."
fi

# Remove existing files named as the given filename.
find "${target_dir}" -type f \( -name "${filename}*.html" -o -name "${filename}*.css" -o -name "${filename}*.json" -o -name "${filename}*.txt" \) -exec rm {} \;

# Assemble the call to gcovr.
gcovr_mcd=("${gcovr_bin}")
# Needed to process windows cross compiled test results coming from wine.
gcovr_mcd+=(--gcov-ignore-errors=no_working_dir_found)
# Add when a other then default gcov binary is given.
if [[ -n "${gcov_bin}" ]]; then
	gcovr_mcd+=(--gcov-executable "${gcov_bin}")
fi
# General options.
gcovr_mcd+=(--exclude-unreachable-branches --print-summary)
# Generate the HTML report.
if ${flag_report_html}; then
	gcovr_mcd+=(--json-summary-pretty --json-summary "${target_dir}/${filename}.json")
fi
# Generate summary json-file,
if ${flag_report_json}; then
	gcovr_mcd+=(--html-tab-size 2)
	# Select the theme for HTML output to be green,blue,github.blue,github.green,github.dark-green,github.dark-blue.
	gcovr_mcd+=(--html-theme github.green)
	#gcovr_mcd+=(--html-self-contained)
	gcovr_mcd+=(--html-nested "${target_dir}/${filename}.html")
	#gcovr_mcd+=(--html-details "${target_dir}/${filename}.html")
fi
# Generate Cobertura coverage report which GitLab can handle/process.
gcovr_mcd+=(--xml-pretty --output "${target_dir}/${filename}.xml")
# Sort on: filename,uncovered-number,uncovered-percent
gcovr_mcd+=(--sort uncovered-percent)

# Output also additional values/columns.
#gcovr_mcd+=(--decisions --calls)
# Remove lines containing only an accolade.
#gcovr_mcd+=( --exclude-lines-by-pattern '^\s*\}\s*$')

# Add the gcda-files using file or search path(s).
if ${flag_search_path}; then
	gcovr_mcd+=("${source_dir}")
else
	# Collect all the "*.gcda" files from the passed source directory.
	while IFS='' read -r -d $'\n'; do
		#[[ "${REPLY}" =~ \.dir/test- ]] && continue
		if ${flag_verbose}; then
			WriteLog "- File: ${REPLY}"
		fi
		files+=("${source_dir}/${REPLY}")
	done < <(find "${source_dir}" -type f -name "*.gcda" -printf "%P\n")
	# Alternative to search paths, add the gcda-files ourself.
	gcovr_mcd+=("${files[@]}")
fi

# Add the directory filters on the found files.
gcovr_mcd+=("${filters[@]}")

# Try speeding up the report generation when the filter arguments are passed remove all files '*.gc??' files not intended for the report.
if [[ "${#argument[@]}" -ne 0 ]]; then
	echo "Remove files not in: " "${argument[@]}"
	while IFS='' read -r -d $'\n'; do
		# Remove the sub directory '/CMakeFiles/*/' from the path.
		dir="$(dirname "${REPLY}" | sed --regexp-extended "s/^(.*)\/CMakeFiles\/[^\/]*(.*)$/\\1\\2/")"
		# Now check the resulting path if it is part of the including filter paths.
		if ! InArray "${dir}" "${argument[@]}"; then
			# When not remove the file.
			rm "${source_dir}/${REPLY}"
		fi
	done < <(find "${source_dir}" -type f -name "*.gc??" -printf "%P\n")
fi

# Move to the working directory before executing the command.
pushd "${working_dir}" >/dev/null

# Make the call to generate.
if "${gcovr_mcd[@]}" | tee "${target_dir}/${filename}.txt"; then
	#xdg-open "${target_dir}/index.html"
	# Create in the log a clickable entry to open in the browser.
	WriteLog "Report at: file://${target_dir}/${filename}.html"
	WriteLog "Summary at: ${target_dir}/${filename}.json"
	# It seems '--html-tab-size 2' is not working, so add it to the stylesheet.
	echo ".w {tab-size: 4;}" >> "${target_dir}/${filename}.css"
	# Delete all arc files when successful.
	if ${flag_cleanup}; then
		# Remove all the "*.gcda" files after.
		while IFS='' read -r -d $'\n'; do
			#[[ "${REPLY}" =~ \.dir/test- ]] && continue
			if ${flag_verbose}; then
				WriteLog "- Removing: ${REPLY}"
			fi
			rm "${REPLY}"
		done < <(find "${source_dir}" -type f -name "*.gcda")
	fi
fi

# Restore the directory.
popd >/dev/null
