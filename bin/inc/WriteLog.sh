# Define and use some foreground colors values when not running CI-jobs.
if [[ ${CI} ]] ; then
	col_fg_black=""
	col_fg_red=""
	col_fg_green=""
	col_fg_yellow=""
	col_fg_blue=""
	col_fg_magenta=""
	col_fg_cyan=""
	col_fg_white=""
	col_fg_reset=""
else
	# shellcheck disable=SC2034
	col_fg_black="$(tput setaf 0)"
	col_fg_red="$(tput setaf 1)"
	# shellcheck disable=SC2034
	col_fg_green="$(tput setaf 2)"
	col_fg_yellow="$(tput setaf 3 bold)"
	# shellcheck disable=SC2034
	col_fg_blue="$(tput setaf 4 bold)"
	col_fg_magenta="$(tput setaf 5 bold)"
	col_fg_cyan="$(tput setaf 6)"
	# shellcheck disable=SC2034
	col_fg_white="$(tput setaf 7 bold)"
	col_fg_reset="$(tput sgr0)"
fi

# Writes to stderr.
#
function WriteLog()
{
	# shellcheck disable=SC2124
	local LAST_ARG="${@: -1}"
	local LAST_CH="${LAST_ARG:0-1}"
	local FIRST_CH="${LAST_ARG:0:1}"
	local COLOR
	# Set color based on first character of the string.
	case "${FIRST_CH}" in
		"-")
			COLOR="${col_fg_magenta}"
			;;
		"~")
			COLOR="${col_fg_yellow}"
			;;
		"#")
			COLOR="${col_fg_blue}"
			;;
		"=")
			COLOR="${col_fg_green}"
			;;
		*)
			COLOR=""
			;;
	esac
	case "${LAST_CH}" in
		"!")
			COLOR="${col_fg_red}"
			;;
		".")
			if [[ -z "${COLOR}" ]]; then
				COLOR="${col_fg_cyan}"
			fi
			;;
	esac
	echo -n "${COLOR}" 1>&2
	echo "${@}" 1>&2
	echo -n "${col_fg_reset}" 1>&2
}
