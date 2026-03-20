#!/usr/bin/env bash

# Get the script directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Include WriteLog function.
source "${script_dir}/inc/Miscellaneous.sh"

# Prints the help.
#
function show_help {
	echo "Usage: $(basename "${0}") <options> [--] <file(s)>
  Lists the dependent dynamic libraries of the passed file(1).
  Options:
     -c|--check   : Check if the DLL can be found in the path.
     -r|--recurse : Do a recursive check on libraries.
     -a|--app     : Application or library which provides Windows executable directory (Windows targets only).
"
}

# Check if the needed commands are installed.
commands=(
	"objdump"
	"grep"
	"sed"
	"find"
	"exiftool"
)
for command in "${commands[@]}"; do
	if ! command -v "${command}" >/dev/null; then
		echo "Missing command '${command}' for this script"
		exit 1
	fi
done

# Flag which determines if Windows is targeted.
flag_win=false
# Flag for checking if dynamic libraries are found.
flag_check=false
# Flag for checking if DLL's are found in the PATH.
flag_recurse=false
# Application or library for acquiring the RUNPATH.
app_bin=""

# Parse options.
temp=$(getopt -o 'hca:r' --long 'help,check,app:,recurse' -n "$(basename "${0}")" -- "$@")
# shellcheck disable=SC2181
if [[ $? -ne 0 || $# -eq 0 ]]; then
	show_help
	exit 1
fi
eval set -- "$temp"
unset temp
while true; do
	case "$1" in

		-h | --help)
			ShowHelp
			exit 0
			;;

		-c | --check)
			flag_check=true
			shift 1
			;;

		-r | --recurse)
			flag_recurse=true
			shift 1
			;;

		-a | --app)
			app_bin="${2}"
			shift 2
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

# Determine if Windows or Linux is targeted.
if [[ "$(uname -o)" == "Cygwin" ]]; then
	flag_win=true
# Check if the binary file is a windows file.
elif [[ "$#" -ne 0 ]] && objdump -a "$1" | grep "file format pei-x86-64$" >/dev/null; then
	flag_win=true
else
	flag_win=false
fi

if $flag_recurse; then
	# Temporary file for storing dl full paths.
	dl_name_file="$(mktemp)"
fi

# When running Windows by checking for Cygwin.
if $flag_win; then
	# Initialize application directory variable.
	app_dir=""
	sys_dirs=()
	# When an application is passed get its executable directory.
	if [[ -n "${app_bin}" ]]; then
		app_dir="$(dirname "$(realpath "${app_bin}")")"
		WriteLog "# Executable path app: ${app_bin}"
		WriteLog "- ${app_dir}"
	fi
	# When using Linux Wine.
	if $flag_win && [[ "$(uname -o)" != "Cygwin" ]]; then
		# Get the default system path.
		IFS=';' read -r -a dirs <<<"$(wine cmd /c 'echo %PATH%')"
		for dir in "${dirs[@]}"; do
			# Skip empty ones.
			if [[ -n "${dir}" ]]; then
				dir="$(winepath -u "${dir}")"
				sys_dirs+=("${dir}")
			fi
		done
		# Get the defined Wine path.
		IFS=';' read -r -a dirs <<<"${WINEPATH}"
		for dir in "${dirs[@]}"; do
			# Skip empty ones.
			if [[ -n "${dir}" ]]; then
				dir="$(winepath -u "${dir}")"
				path_dirs+=("${dir}")
			fi
		done
	else
		# Get the PATH as an array of directories.
		IFS=':' read -r -a path_dirs <<<"${PATH}"
	fi
	if $flag_check; then
		WriteLog "# Paths:"
		for dir in "${path_dirs[@]}"; do
			WriteLog "- ${dir}"
		done
	fi
	{
		for dl_name in "${@}"; do
			WriteLog "# Checking: ${dl_name}"
			# Extract the DLL list and iterate.
			objdump --private-headers "$dl_name" | grep --ignore-case "DLL Name:" | sed --regexp-extended "s/^\s*DLL Name:\s*//" | while read -r dep; do
				if $flag_check; then
					found=0
					if [[ -n "${app_dir}" ]]; then
						if [[ -f "${app_dir}/${dep}" ]]; then
							echo "${dep}→EXE_DIR→${app_dir}"
							found=1
							$flag_recurse && echo "${candidate}" >> "${dl_name_file}"
						fi
					fi
					# When not found continue...
					if [[ "${found}" -eq 0 ]]; then
						for dir in "${path_dirs[@]}"; do
							candidate="${dir}/${dep}"
							if [[ -f "${candidate}" ]]; then
								echo "${dep}→PATH→${dir}"
								found=2
								$flag_recurse && echo "${candidate}" >> "${dl_name_file}"
								break
							fi
						done
					fi
					# When not found continue...
					if [[ "${found}" -eq 0 ]]; then
						for dir in "${sys_dirs[@]}"; do
							if [[ -f "${dir}/${dep}" ]]; then
								echo "${dep}→SYS_PATH→${dir}"
								found=3
								#$flag_recurse && echo "${candidate}" >> "${dl_name_file}"
								break
							fi
						done
					fi
					# When not found continue...
					if [[ "${found}" -eq 0 ]]; then
						for dir in "${sys_dirs[@]}"; do
							result="$(find "${dir}" -maxdepth 1 -iname "${dep}")"
							# When found.
							if [[ -n "${result}" ]]; then
								echo "${dep}→SYS_PATH→${dir} [${col_fg[yellow]}$(basename "${result}")${col_fg[reset]}]"
								found=4
								break
							fi
						done
					fi
					if [[ "${found}" -eq 0 ]]; then
						echo "${dep}→${col_fg[red]}Missing${col_fg[reset]}"
					fi
				else
					echo "$dep"
				fi
			done
		done
	} | column --table --separator '→' --table-columns 'Library,Via,Directory'
else
	if $flag_check; then
		## Create array variables.
		ld_path_dirs=()
		run_path_dirs=()
		# Check if the environment variable `LD_LIBRARY_PATH' was set.
		if [[ -n "${LD_LIBRARY_PATH}" ]]; then
			IFS=':' read -r -a dirs <<<"${LD_LIBRARY_PATH}"
			WriteLog "# Loader Paths:"
			for dir in "${dirs[@]}"; do
				# Check if the path directory is absolute.
				if [[ "${dir}" =~ ^/ ]]; then
					WriteLog "- ${dir}"
					ld_path_dirs+=("${dir}")
				else
					# Prepend the working directory.
					WriteLog "- ${dir} => $(pwd)/${dir}"
					ld_path_dirs+=("$(pwd)/${dir}")
				fi
			done
		fi
	fi
	for dl_name in "${@}"; do
		# Check if an application or other dynamic library has been passed.
		WriteLog "# File RUNPATH: ${dl_name}"
		dl_fullname="$(realpath "${dl_name}")"
		origin="$(dirname "${dl_fullname}")"
		IFS=':' read -r -a path_dirs <<<"$(readelf -d "${dl_fullname}" | egrep -i "\\(RUNPATH\\)" | sed --regexp-extended "s/.*Library runpath: \\[(.*)\\]/\\1/")"
		for dir in "${path_dirs[@]}"; do
			rdir="${dir/$\{ORIGIN\}/${origin}}"
			rdir="${rdir/$ORIGIN/${origin}}"
			if [[ "${rdir}" == "${dir}" ]]; then
				WriteLog "- ${dir}"
			else
				WriteLog "- ${dir} => ${rdir}"
			fi
			run_path_dirs+=("${rdir}")
		done
		WriteLog "# Paths:"
		for dir in "${ld_path_dirs[@]}" "${run_path_dirs[@]}"; do
			WriteLog "- ${dir}"
		done
		# Report which file is checked.
		WriteLog "# Checking: ${dl_name}"
		#
		{
			# Extract the SO list and iterate.
			while read -r dep; do
				if $flag_check; then
					found=0
					for dir in "${ld_path_dirs[@]}"; do
						candidate="${dir}/${dep}"
						if [[ -f "${candidate}" ]]; then
							echo "${dep}→LD_PATH→$(dirname "${candidate}")"
							found=1
							$flag_recurse && echo "${candidate}" >> "${dl_name_file}"
							break
						fi
					done
					# When not found continue...
					if [[ "$found" -eq 0 ]]; then
						for dir in "${run_path_dirs[@]}"; do
							candidate="${dir}/${dep}"
							if [[ -f "${candidate}" ]]; then
								echo "${dep}→RUNPATH→$(dirname "${candidate}")"
								found=2
								$flag_recurse && echo "${candidate}" >> "${dl_name_file}"
								break
							fi
						done
					fi
					# When not found continue...
					if [[ "${found}" -eq 0 ]]; then
						if ldconfig -p | grep -q "^\s*$(EscapeRegularExpression "${dep}")\s"; then
							echo "${dep}→LD_CONF→..."
							found=3
							#$flag_recurse && echo "${candidate}" >> "${dl_name_file}"
						fi
					fi
					if [[ "${found}" -eq 0 ]]; then
						echo "${dep}→${col_fg[red]}Missing${col_fg[reset]}"
					fi
				else
					echo "${dep}"
				fi
			done <<<"$(objdump --private-headers "${dl_name}" | grep --ignore-case "NEEDED" | sed --regexp-extended "s/^\s*NEEDED\s*//")"
			for dep in "${dep_list[@]}"; do
				WriteLog "# Dependency: ${dep}"
			done
		} | column --table --separator '→' --table-columns 'Library,Via,Directory'
	done
fi

# When recursing is requested.
if $flag_recurse; then
	while read -r dep; do
		# The body of your loop uses the 'dep' variable
		WriteLog "# Recursing through: ${dep}"
		"${0}" $($flag_check && echo "-c") "${dep}"
		#ls -la "${dep}"
	done < "${dl_name_file}"
fi
