#!/bin/bash

set -e
# Get the script directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Include WriteLog function.
source "${SCRIPT_DIR}/inc/WriteLog.sh"
# Prints the help.
#
function ShowHelp {
	echo "Usage: ${0} [options] <directories>

  Needs to be executed in the project directory where the main CMakeLists.txt resides.

  Options:
    -h, --help   : Show this help.
    -s, --source : Source directory for gcda-files. Defaults to current working directory.
    -t, --target : Target directory for report.
    -n, --name   : Report basename whic defaults to 'report'.
    --gcov       : Location of the 'gcov' when a different toolchain has been used.
    --cleanup    : Remove the gcda files after the report was generated successfully.
    --verbose    : Inform what is done.
"
}

# Variables used.
gcovr_bin="$(which gcovr)"
gcov_bin=""
filename="report"
source_dir=""
target_dir=""
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
temp=$(getopt -o 'hs:t:n:' \
	--long 'help,source:,target:,name:,cleanup,verbose,gcov:' \
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
WriteLog "- Source directory: ${source_dir}"
WriteLog "- Target directory: ${target_dir}"
WriteLog "- Command gcovr   : ${gcovr_bin}"
WriteLog "- Command gcov    : ${gcov_bin:-'Default'}"
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
gcovr_mcd+=(--decisions --calls)
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

# Make the call to generate.
if "${gcovr_mcd[@]}" | tee "${target_dir}/${filename}.txt"; then
	#xdg-open "${target_dir}/index.html"
	# Create in the log a clickable entry to open in the browser.
	WriteLog "Report at: file://${target_dir}/${filename}.html"
	WriteLog "Summary at: ${target_dir}/${filename}.json"
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