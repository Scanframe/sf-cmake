# Define and use some foreground colors values when not running CI-jobs
# or when terminal is 'dumb' when running ctest from CLion.

declare -A col_fg
if [[ "${TERM}" == "dumb" || -n "${CI}" ]]; then
	col_fg[black]=""
	col_fg[red]=""
	col_fg[green]=""
	col_fg[yellow]=""
	col_fg[blue]=""
	col_fg[magenta]=""
	col_fg[cyan]=""
	col_fg[white]=""
	col_fg[reset]=""
	function WriteLog() {
		echo "${@}" 1>&2
	}
else
	# shellcheck disable=SC2034
	col_fg[black]="$(tput setaf 0)"
	col_fg[red]="$(tput setaf 1)"
	# shellcheck disable=SC2034
	col_fg[green]="$(tput setaf 2)"
	col_fg[yellow]="$(tput setaf 3 bold)"
	# shellcheck disable=SC2034
	col_fg[blue]="$(tput setaf 4 bold)"
	col_fg[magenta]="$(tput setaf 5)"
	col_fg[cyan]="$(tput setaf 6)"
	# shellcheck disable=SC2034
	col_fg[white]="$(tput setaf 7 bold)"
	col_fg[reset]="$(tput sgr0)"
	# Writes to stderr.
	#
	function WriteLog() {
		# shellcheck disable=SC2124
		local FIRST_CH LAST_ARG LAST_CH COLOR
		LAST_ARG="${*: -1}"
		LAST_CH="${LAST_ARG:0-1}"
		# match a single non-whitespace character
		if [[ "$(printf "%b" "${LAST_ARG}")" =~ [^[:space:]] ]]; then
			FIRST_CH="${BASH_REMATCH[0]}"
		else
			FIRST_CH="${LAST_ARG:0:1}"
		fi
		# Set color based on first character of the string.
		case "${FIRST_CH}" in
			"-")
				COLOR="${col_fg[cyan]}"
				;;
			"~")
				COLOR="${col_fg[blue]}"
				;;
			"#")
				COLOR="${col_fg[yellow]}"
				;;
			"=")
				COLOR="${col_fg[green]}"
				;;
			":")
				COLOR="${col_fg[magenta]}"
				;;
			"!")
				COLOR="${col_fg[red]}"
				;;
			*)
				COLOR=""
				;;
		esac
		case "${LAST_CH}" in
			"!")
				COLOR="${col_fg[red]}"
				;;
		esac
		echo -n "${COLOR}" 1>&2
		echo "${@}" 1>&2
		echo -n "${col_fg[reset]}" 1>&2
	}
fi

##
# Prepends each line read from the input.
# Allows a line counter "\${counter}" to be expanded.
#
function PrependAndEscape {
	local counter
	while read -r line; do
		((counter += 1))
		eval "WriteLog -e \"${1}${line}\""
	done
	return 0
}

##
# Prepends each line read from the input.
# Allows a line counter "\${counter}" to be expanded.
#
function PrependAndEcho {
	local counter
	while read -r line; do
		((counter += 1))
		eval "echo -e \"${1}${line}\""
	done
	return 0
}

function PrependAndEcho {
	local counter
	while read -r line; do
		((counter += 1))
		eval "echo -e \"${1}${line}\""
	done
	return 0
}

##
# Pipe function to highlight non skipped lines.
# Arg1: Regex
# Arg2: Color name like 'white' according the 'col_fg' array.
#
function Highlight {
	while read -r line; do
		# Check if string or regex is empty.
		if [ -z "$1" ] || [ -z "$2" ]; then
			# shellcheck disable=SC2128
			WriteLog "Usage: ${FUNCNAME} <regex> <color>"
			return 1
		fi
		# Check if regex matches the string.
		if [[ -v col_fg[$2] && ! "${line}" =~ ^[a-z_\\-]+(\([a-z_\-]+\))?!?: ]]; then
			# No match, return the line.
			echo "${line}"
		else
			# Highlight the matched sequence.
			echo "${line/${BASH_REMATCH[0]}/${col_fg[$2]}${BASH_REMATCH[0]}${col_fg[reset]}}"
		fi
	done
}
