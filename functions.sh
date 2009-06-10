# This file is basically snippets from the gentoo script found at /etc/init.d/functions.sh
# and additions pertinent to backupscripts
#
# Amiel martin <amiel.martin@gmail.com> -- 2009-06-03
# 
# Copyright 1999-2007 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
#

# use the following preable to use this and load configuration for backupscripts
# 	FUNCTIONS="$(if [[ -f "$f" ]];then echo "$f"; else echo "/etc/backupscripts/$f";fi)"
# 	source functions.sh
# 	source $(conf_file)




#
# Internal variables
#

# Dont output to stdout?
RC_QUIET_STDOUT="${RC_QUIET_STDOUT:-no}"
RC_VERBOSE="${RC_VERBOSE:-no}"

# Should we use color?
RC_NOCOLOR="${RC_NOCOLOR:-no}"
# Can the terminal handle endcols?
RC_ENDCOL="yes"

include_file() {
	if [[ -f "$1" ]]; then
		echo "$1"
	else
		echo "$BACKUPSCRIPTS_DIR/$1"
	fi	
}

# void esyslog(char* priority, char* tag, char* message)
#
#    use the system logger to log a message
#
esyslog() {
	local pri=
	local tag=

	if [[ -x /usr/bin/logger ]] ; then
		pri="$1"
		tag="$2"

		shift 2
		[[ -z "$*" ]] && return 0

		/usr/bin/logger -p "${pri}" -t "${tag}" -- "$*"
	fi

	return 0
}

# void eindent(int num)
#
#    increase the indent used for e-commands.
#
eindent() {
	local i="$1"
	(( i > 0 )) || (( i = RC_DEFAULT_INDENT ))
	esetdent $(( ${#RC_INDENTATION} + i ))
}

# void eoutdent(int num)
#
#    decrease the indent used for e-commands.
#
eoutdent() {
	local i="$1"
	(( i > 0 )) || (( i = RC_DEFAULT_INDENT ))
	esetdent $(( ${#RC_INDENTATION} - i ))
}

# void esetdent(int num)
#
#    hard set the indent used for e-commands.
#    num defaults to 0
#
esetdent() {
	local i="$1"
	(( i < 0 )) && (( i = 0 ))
	RC_INDENTATION=$(printf "%${i}s" '')
}

# void einfo(char* message)
#
#    show an informative message (with a newline)
#
einfo() {
	einfon "$*\n"
	LAST_E_CMD="einfo"
	return 0
}

# void einfon(char* message)
#
#    show an informative message (without a newline)
#
einfon() {
	[[ ${RC_QUIET_STDOUT} == "yes" ]] && return 0
	[[ ${RC_ENDCOL} != "yes" && ${LAST_E_CMD} == "ebegin" ]] && echo
	echo -ne " ${GOOD}*${NORMAL} ${RC_INDENTATION}$*"
	LAST_E_CMD="einfon"
	return 0
}

# void ewarn(char* message)
#
#    show a warning message + log it
#
ewarn() {
	if [[ ${RC_QUIET_STDOUT} == "yes" ]] ; then
		echo " $*"
	else
		[[ ${RC_ENDCOL} != "yes" && ${LAST_E_CMD} == "ebegin" ]] && echo
		echo -e " ${WARN}*${NORMAL} ${RC_INDENTATION}$*"
	fi

	local name="rc-scripts"
	# Log warnings to system log
	esyslog "daemon.warning" "${name}" "$*"

	LAST_E_CMD="ewarn"
	return 0
}

# void eerror(char* message)
#
#    show an error message + log it
#
eerror() {
	if [[ ${RC_QUIET_STDOUT} == "yes" ]] ; then
		echo " $*" >/dev/stderr
	else
		[[ ${RC_ENDCOL} != "yes" && ${LAST_E_CMD} == "ebegin" ]] && echo
		echo -e " ${BAD}*${NORMAL} ${RC_INDENTATION}$*"
	fi

	local name="rc-scripts"
	[[ $0 != "/sbin/runscript.sh" ]] && name="${0##*/}"
	# Log errors to system log
	esyslog "daemon.err" "rc-scripts" "$*"

	LAST_E_CMD="eerror"
	return 0
}

# void ebegin(char* message)
#
#    show a message indicating the start of a process
#
ebegin() {
	local msg="$*" dots spaces="${RC_DOT_PATTERN//?/ }"
	[[ ${RC_QUIET_STDOUT} == "yes" ]] && return 0

	if [[ -n ${RC_DOT_PATTERN} ]] ; then
		dots="$(printf "%$((COLS - 3 - ${#RC_INDENTATION} - ${#msg} - 7))s" '')"
		dots="${dots//${spaces}/${RC_DOT_PATTERN}}"
		msg="${msg}${dots}"
	else
		msg="${msg} ..."
	fi
	einfon "${msg}"
	[[ ${RC_ENDCOL} == "yes" ]] && echo

	LAST_E_LEN="$(( 3 + ${#RC_INDENTATION} + ${#msg} ))"
	LAST_E_CMD="ebegin"
	return 0
}

# void _eend(int error, char *efunc, char* errstr)
#
#    indicate the completion of process, called from eend/ewend
#    if error, show errstr via efunc
#
#    This function is private to functions.sh.  Do not call it from a
#    script.
#
_eend() {
	local retval="${1:-0}" efunc="${2:-eerror}" msg
	shift 2

	if [[ ${retval} == "0" ]] ; then
		[[ ${RC_QUIET_STDOUT} == "yes" ]] && return 0
		msg="${BRACKET}[ ${GOOD}ok${BRACKET} ]${NORMAL}"
	else
		if [[ -c /dev/null ]] ; then
			rc_splash "stop" &>/dev/null &
		else
			rc_splash "stop" &
		fi
		if [[ -n $* ]] ; then
			${efunc} "$*"
		fi
		msg="${BRACKET}[ ${BAD}!!${BRACKET} ]${NORMAL}"
	fi

	if [[ ${RC_ENDCOL} == "yes" ]] ; then
		echo -e "${ENDCOL}  ${msg}"
	else
		[[ ${LAST_E_CMD} == ebegin ]] || LAST_E_LEN=0
		printf "%$(( COLS - LAST_E_LEN - 6 ))s%b\n" '' "${msg}"
	fi

	return ${retval}
}

# void eend(int error, char* errstr)
#
#    indicate the completion of process
#    if error, show errstr via eerror
#
eend() {
	local retval="${1:-0}"
	shift

	_eend "${retval}" eerror "$*"

	LAST_E_CMD="eend"
	return ${retval}
}

# void ewend(int error, char* errstr)
#
#    indicate the completion of process
#    if error, show errstr via ewarn
#
ewend() {
	local retval="${1:-0}"
	shift

	_eend "${retval}" ewarn "$*"

	LAST_E_CMD="ewend"
	return ${retval}
}

# v-e-commands honor RC_VERBOSE which defaults to no.
# The condition is negated so the return value will be zero.
veinfo() { [[ ${RC_VERBOSE} != "yes" ]] || einfo "$@"; }
veinfon() { [[ ${RC_VERBOSE} != "yes" ]] || einfon "$@"; }
vewarn() { [[ ${RC_VERBOSE} != "yes" ]] || ewarn "$@"; }
veerror() { [[ ${RC_VERBOSE} != "yes" ]] || eerror "$@"; }
vebegin() { [[ ${RC_VERBOSE} != "yes" ]] || ebegin "$@"; }
veend() {
	[[ ${RC_VERBOSE} == "yes" ]] && { eend "$@"; return $?; }
	return ${1:-0}
}
vewend() {
	[[ ${RC_VERBOSE} == "yes" ]] && { ewend "$@"; return $?; }
	return ${1:-0}
}


##############################################################################
#                                                                            #
# This should be the last code in here, please add all functions above!!     #
#                                                                            #
# *** START LAST CODE ***                                                    #
#                                                                            #
##############################################################################

if [[ ! -z ${VERBOSE} ]] && [[ ${VERBOSE} == "yes" ]] || [[ ${VERBOSE} == "true" ]];then
	RC_VERBOSE=yes
fi


	# Setup a basic $PATH.  Just add system default to existing.
	# This should solve both /sbin and /usr/sbin not present when
	# doing 'su -c foo', or for something like:  PATH= rcscript start
	PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:${PATH}"

	# Cache the CONSOLETYPE - this is important as backgrounded shells don't
	# have a TTY. rc unsets it at the end of running so it shouldn't hang
	# around
	if [[ -z ${CONSOLETYPE} ]] ; then
		export CONSOLETYPE="$( /sbin/consoletype 2>/dev/null )"
	fi
	if [[ ${CONSOLETYPE} == "serial" ]] ; then
		RC_NOCOLOR="yes"
		RC_ENDCOL="no"
	fi

	for arg in "$@" ; do
		case "${arg}" in
			# Lastly check if the user disabled it with --nocolor argument
			--nocolor|-nc)
				RC_NOCOLOR="yes"
				;;
			-v|--verbose)
				RC_VERBOSE="yes"
				;;
		esac
	done




	# Setup COLS and ENDCOL so eend can line up the [ ok ]
	COLS="${COLUMNS:-0}"		# bash's internal COLUMNS variable
	(( COLS == 0 )) && COLS="$(set -- `stty size 2>/dev/null` ; echo "$2")"
	(( COLS > 0 )) || (( COLS = 80 ))	# width of [ ok ] == 7


if [[ ${RC_ENDCOL} == "yes" ]] ; then
	ENDCOL=$'\e[A\e['$(( COLS - 8 ))'C'
else
	ENDCOL=''
fi

# Setup the colors so our messages all look pretty
if [[ ${RC_NOCOLOR} == "yes" ]] ; then
	unset GOOD WARN BAD NORMAL HILITE BRACKET
else
	GOOD=$'\e[32;01m'
	WARN=$'\e[33;01m'
	BAD=$'\e[31;01m'
	HILITE=$'\e[36;01m'
	BRACKET=$'\e[34;01m'
	NORMAL=$'\e[0m'
fi


##############################################################################
#                                                                            #
# *** END LAST CODE ***                                                      #
#                                                                            #
# This should be the last code in here, please add all functions above!!     #
#                                                                            #
##############################################################################


# vim:ts=4
