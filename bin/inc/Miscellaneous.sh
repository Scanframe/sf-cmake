# Include WriteLog.sh when it is not.
[[ "$(type -t WriteLog)" != "function" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/WriteLog.sh"

##
# Function reporting stack.
function StackTrace {
	# Start at 1 to skip this function itself.
	local i=0 line file func
	while read -r line func file < <(caller $i); do
		WriteLog "[$i] $file:$line $func(): $(sed -n "${line}"p "$file")"
		((i += 1))
	done
}

##
# Function to trap script exit.
# Arg1: ${BASH_SOURCE}
# Arg2: ${BASH_LINENO}
# Arg3: ${BASH_COMMAND}
#
function ScriptExit {
	local exitcode="${?}" idx line file func
	# Show the stack in case of an error.
	if [[ "${exitcode}" -ne 0 ]]; then
		# Perform a stack trace.
		idx=0
		while read -r line func file < <(caller $idx); do
			# When the line number is 1 clear the line number and use the passed failed command.
			[[ "${line}" -eq 1 ]] && line=""
			WriteLog "[$idx] $file:$line $func(): $([[ -n "${line}" ]] && sed -n "${line}"p "$file" || echo "$3")"
			((idx += 1))
		done
		WriteLog "! Exitcode: ${exitcode}"
	fi
	# Report execution time.
	WriteLog "- $(basename "${0}"), executed in ${SECONDS}s."
	# Propagate the exit code.
	exit "${exitcode}"
}

### Usage...
### Trap script exit with function.
#trap 'ScriptExit "${BASH_SOURCE}" "${BASH_LINENO}" "${BASH_COMMAND}"' EXIT

##
# Returns the version number of the git version tag.
# Expected tag format is
#  'vM.N.P'
#  'vM.N.P~C'
#  'vM.N.P-rc.R'
#  'vM.N.P-rc.R~C'
#  where:
#  M: Major version number.
#  N: Minor version number.
#  P: Patch version number.
#  C: Commit amount since the tag was created.
#  R: Release candidate number.
#
function GetGitTagVersion {
	local tag
	# Only annotated tags so no '--tags' option.
	tag="$(git describe --dirty --match 'v*.*.*' 2>/dev/null)"
	# Match on vx.x.x version tag.
	if [[ $? && ! "${tag}" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)(-rc\.?([0-9]+))?(-([0-9]+)?(-([a-z0-9]+))?)?(-dirty)?$ ]]; then
		echo "0.0.0"
		return 1
	else
		echo "${BASH_REMATCH[1]};${BASH_REMATCH[3]};${BASH_REMATCH[5]};${BASH_REMATCH[7]}"
	fi
	return 0
}

##
# Returns the version string from the information returned by GetGitTagVersion().
# @arg1 Version string "ver;rc;commit"
#
function GitTagVersionString {
	local IFS=';'
	read -r -a versions <<<"${1}"
	echo -n "${versions[0]}"
	# Append when this version is a release candidate.
	[[ -z "${versions[1]}" ]] || echo -n "-rc.${versions[1]}"
	# Append when this version is has commits since tag creation.
	[[ -z "${versions[2]}" ]] || echo -n "~${versions[2]}"
}

##
# Joins an array with glue.
# Arg1: The glue which can be a multi character string.
# Arg2+n: The array as separate arguments like "${myarray[@]}"
#
function JoinBy {
	local d=${1-} f=${2-}
	if shift 2; then
		printf %s "$f" "${@/#/$d}"
	fi
}

##
# Usage: ${0} [options] <name>
# Find directory or file equal to the passed name.
# Options
#   -t|--type <d|f>: File or directory
#
function FindUp {
	local type temp path name argument
	# Type 'd' for directory
	type=""
	# Parse options.
	temp=$(getopt -o 'ht:' --long 'help,type:' -n "$(basename "${0}")" -- "$@")
	# shellcheck disable=SC2181
	if [[ $? -ne 0 ]]; then
		return 1
	fi
	eval set -- "$temp"
	unset temp
	while true; do
		case "$1" in

			-t | --type)
				type="${2:0:1}"
				shift 2
				continue
				;;

			'--')
				shift
				break
				;;

			*)
				WriteLog "Internal error on argument (${1}) !" >&2
				return 1
				;;
		esac
	done
	# Get the arguments in an array.
	argument=()
	while [[ $# -gt 0 ]] && ! [[ "$1" =~ ^- ]]; do
		argument+=("$1")
		shift
	done
	# Check if a filename or dirname was passed.
	if [[ "${#argument[@]}" -eq 0 ]]; then
		WriteLog "Function '${FUNCNAME[0]}': argument(s) missing!"
		return 1
	fi
	# Iterate through the passed names.
	for name in "${argument[@]}"; do
		# Get the current working directory.
		path="${PWD}"
		# Iterate up the tree.
		while [[ "${path}" != "" ]]; do
			# Per type check if it exist and so, then break the loop.
			case "${type}" in
				d)
					if [[ -d "${path}/${name}" ]]; then
						break
					fi
					;;
				f)
					if [[ -f "${path}/${name}" ]]; then
						break
					fi
					;;
				*)
					if [[ -e "${path}/${name}" ]]; then
						break
					fi
					;;
			esac
			# One directory up.
			path="${path%/*}"
		done
	done
	# When the path is empty the file was not found.
	if [[ -z "${path}" ]]; then
		# Print error on not finding to stderr.
		case "${type}" in
			d) WriteLog "Directory '${name}' not found." ;;
			f) WriteLog "File '${name}' not found." ;;
			*) WriteLog "File or directory '${name}' not found." ;;
		esac
		return 1
	fi
	# Output the found.
	echo "${path}/${name}"
	return 0
}

##
# Increment version a version number.
# Arg1: Version number to increment.
# Arg2: How to increment 'none', 'patch', 'minor' and 'major'.
#
function IncrementVersion {
	# Check if version is provided
	if [ -z "${1}" ]; then
		WriteLog "Usage: ${FUNCNAME[0]} <version> <increment>"
		return 1
	fi

	# Check if increment type is provided
	if [ -z "${2}" ]; then
		WriteLog "Provide increment type: 'none', 'patch', 'minor', or 'major' !"
		return 1
	fi

	# Extract major, minor, and patch numbers
	version=$1
	major=$(echo "${version}" | cut -d. -f1)
	minor=$(echo "${version}" | cut -d. -f2)
	patch=$(echo "${version}" | cut -d. -f3)

	# Increment version based on the specified increment type
	case "$2" in
		none) ;;

		\
			patch)
			patch=$((patch + 1))
			;;

		minor)
			minor=$((minor + 1))
			patch=0
			;;

		major)
			major=$((major + 1))
			minor=0
			patch=0
			;;

		*)
			WriteLog "Invalid increment type: $2. Please use 'patch', 'minor', or 'major'!"
			return 1
			;;
	esac

	# Print the incremented version
	echo "$major.$minor.$patch"
}

##
# Increment version increment names at return the highest.
# Arg1: 'none', 'patch', 'minor' and 'major'.
# Arg2: 'none', 'patch', 'minor' and 'major'.
#
function CompareIncrements {
	# Check if both arguments are provided
	if [[ -z "${1}" ]] || [[ -z "${2}" ]]; then
		echo "Usage: compare_versions <version1> <version2>"
		return 1
	fi
	local increments
	# Define a list of version increments in order of precedence.
	declare -A increments=([none]=0 [patch]=1 [minor]=2 [major]=3)
	# Compare the indexes to determine the higher version increment
	if [[ "${increments[$1]}" -gt "${increments[$2]}" ]]; then
		echo "${1}"
	else
		echo "${2}"
	fi
}

##
# Escapes the markdown passed string.
#
function EscapeMarkdown {
	local escaped_string string
	string="$1"
	# Characters to escape in Markdown: \ ` * _ { } [ ] ( ) # + - . !
	# Escape them using HTML entities
	escaped_string="${string//\\/&#92;}"         # Backslash (\)
	escaped_string="${escaped_string//\`/&#96;}" # Backtick (`)
	escaped_string="${escaped_string//\*/&#42;}" # Asterisk (*)
	escaped_string="${escaped_string//#/&#35;}"  # Hash (#)
	#	escaped_string="${escaped_string//_/&#95;}"   # Underscore (_)
	#	escaped_string="${escaped_string//\{/&#123;}" # Left curly brace ({)
	#	escaped_string="${escaped_string//\}/&#125;}" # Right curly brace (})
	escaped_string="${escaped_string//\[/&#91;}" # Left square bracket ([)
	escaped_string="${escaped_string//\]/&#93;}" # Right square bracket (])
	#	escaped_string="${escaped_string//\(/&#40;}"  # Left parenthesis (()
	#	escaped_string="${escaped_string//\)/&#41;}"  # Right parenthesis ())
	#	escaped_string="${escaped_string//+/&#43;}"   # Plus sign (+)
	#	escaped_string="${escaped_string//-/&#45;}"   # Hyphen (-)
	#	escaped_string="${escaped_string//./&#46;}"   # Period (.)
	#	escaped_string="${escaped_string//!/&#33;}"   # Exclamation mark (!)
	echo "$escaped_string"
}

##
# Decodes the passed URL string.
#
function UrlDecode {
	# urldecode <string>
	local url_encoded="${1//+/ }"
	printf '%b' "${url_encoded//%/\\x}"
}

##
# Encodes the passed URL string.
#
function UrlEncode {
	old_lc_collate=$LC_COLLATE
	LC_COLLATE=C
	local length="${#1}"
	for ((i = 0; i < length; i++)); do
		local c="${1:i:1}"
		case $c in
			[a-zA-Z0-9.~_-]) printf "$c" ;;
			*) printf '%%%02X' "'$c" ;;
		esac
	done
	LC_COLLATE=$old_lc_collate
}

##
# Encodes the passed URL string.
# Arg1: Value to look for.
# ArgN+1: Array values.
#
function InArray {
	# Local scope for the variable
	local value element
	value="${1}"
	# Remove first function argument.
	shift
	# Loop through the array and compare elements directly
	for element in "${@}"; do
		# Element found, return success
		[[ "${element}" == "${value}" ]] && return 0
	done
	# Element not found, return failure
	return 1
}
