#!/bin/bash
# vim:set ts=4 sw=4 tw=80 et ai si cindent cino=L0,b1,(1s,U1,m1,j1,J1,)50,*90 cinkeys=0{,0},0),0],\:,0#,!^F,o,O,e,0=break:
#
#/**********************************************************************
#    forkq
#    Copyright (C)2010-2023 Todd Harbour (krayon)
#
#    This program is free software; you can redistribute it and/or
#    modify it under the terms of the GNU General Public License
#    version 2 ONLY, as published by the Free Software Foundation.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program, in the file COPYING or COPYING.txt; if
#    not, see http://www.gnu.org/licenses/ , or write to:
#      The Free Software Foundation, Inc.,
#      51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# **********************************************************************/

# forkq
# -----
# forkq is a background queuing service for Linux shell jobs.
#
# Required:
#     -
# Recommended:
#     -

# Config paths
_APP_NAME="forkq"
_CONF_FILENAME="${_APP_NAME}.conf"



############### STOP ###############
#
# Do NOT edit the CONFIGURATION below. Instead generate the default
# configuration file in your XDG_CONFIG directory thusly:
#
#     ./forkq.bash -C >"$XDG_CONFIG_HOME/forkq.conf"
#
# or perhaps:
#     ./forkq.bash -C >~/.config/forkq.conf
#
# or even in your home directory (deprecated):
#     ./forkq.bash -C >~/.forkq.conf
#
# Consult --help for more complete information.
#
####################################

# [ CONFIG_START

# forkq - Default Configuration
# =============================

# DEBUG
#   This defines debug mode which will output verbose info to stderr or, if
#   configured, the debug file ( ERROR_LOG ).
DEBUG=0

# ERROR_LOG
#   The file to output errors and debug statements (when DEBUG != 0) instead of
#   stderr.
#ERROR_LOG="${HOME}/forkq.log"

# DEFAULT_QUEUE
#   The default queue to add jobs to.
DEFAULT_QUEUE='default'

# BOSS_START
#   If this is set to non-zero, a boss (job controller) will be started when a
#   new job is added to the queue.
BOSS_START=1

# ] CONFIG_END



####################################{
###
# Config loading
###

# A list of configs - user provided prioritised over system
# (built backwards to save fiddling with CONFIG_DIRS order)
_CONFS=""

# XDG Base (v0.8) - User level
# ( https://specifications.freedesktop.org/basedir-spec/0.8/ )
# ( xdg_base_spec.0.8.txt )
_XDG_CONF_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}"
# As per spec, non-absolute paths are invalid and must be ignored
[ "${_XDG_CONF_DIR:0:1}" == "/" ] && {
        for conf in\
            "${_XDG_CONF_DIR}/${_APP_NAME}/${_CONF_FILENAME}"\
            "${_XDG_CONF_DIR}/${_CONF_FILENAME}"\
        ; do #{
            [ -r "${conf}" ] && _CONFS="${conf}:${_CONFS}"
        done #}
}

# OLD standard for HOME
[ -r "${HOME}/.${_CONF_FILENAME}" ] && _CONFS="${HOME}/.${_CONF_FILENAME}:${_CONFS}"

# XDG Base (v0.8) - System level
# ( https://specifications.freedesktop.org/basedir-spec/0.8/ )
# ( xdg_base_spec.0.8.txt )
_XDG_CONF_DIRS="${XDG_CONFIG_DIRS:-/etc/xdg}"
# NOTE: Appending colon as read's '-d' sets the TERMINATOR (not delimiter)
[ "${_XDG_CONF_DIRS: -1:1}" != ":" ] && _XDG_CONF_DIRS="${_XDG_CONF_DIRS}:"
while read -r -d: _XDG_CONF_DIR; do #{
    # As per spec, non-absolute paths are invalid and must be ignored
    [ "${_XDG_CONF_DIR:0:1}" == "/" ] && {
        for conf in\
            "${_XDG_CONF_DIR}/${_APP_NAME}/${_CONF_FILENAME}"\
            "${_XDG_CONF_DIR}/${_CONF_FILENAME}"\
        ; do #{
            [ -r "${conf}" ] && _CONFS="${conf}:${_CONFS}"
        done #}
    }
done <<<"${_XDG_CONF_DIRS}" #}

# OLD standard for SYSTEM
[ -r "/etc/${_CONF_FILENAME}" ] && _CONFS="/etc/${_CONF_FILENAME}:${_CONFS}"

# _CONFS now contains a list of config files, in reverse importance order. We
# can therefore source each in turn, allowing the more important to override the
# earlier ones.

# NOTE: Appending colon as read's '-d' sets the TERMINATOR (not delimiter)
[ "${_CONF: -1:1}" != ":" ] && _CONF="${_CONF}:"
while read -r -d: conf; do #{
    . "${conf}"
done <<<"${_CONFS}" #}
####################################}

# Version
APP_NAME="forkq"
APP_VER="0.0.1"
APP_COPY="(C)2010-2023 Todd Harbour (krayon)"
APP_URL="https://github.com/krayon/forkq"

# Program name
_binname="${_APP_NAME}"
_binname="${0##*/}"
_binnam_="${_binname//?/ }"

# exit condition constants
ERR_NONE=0
ERR_UNKNOWN=1
# START /usr/include/sysexits.h {
ERR_USAGE=64       # command line usage error
ERR_DATAERR=65     # data format error
ERR_NOINPUT=66     # cannot open input
ERR_NOUSER=67      # addressee unknown
ERR_NOHOST=68      # host name unknown
ERR_UNAVAILABLE=69 # service unavailable
ERR_SOFTWARE=70    # internal software error
ERR_OSERR=71       # system error (e.g., can't fork)
ERR_OSFILE=72      # critical OS file missing
ERR_CANTCREAT=73   # can't create (user) output file
ERR_IOERR=74       # input/output error
ERR_TEMPFAIL=75    # temp failure; user is invited to retry
ERR_PROTOCOL=76    # remote error in protocol
ERR_NOPERM=77      # permission denied
ERR_CONFIG=78      # configuration error
# END   /usr/include/sysexits.h }
ERR_MISSINGDEP=90

# Defaults not in config

queue="${DEFAULT_QUEUE}"
boss_mode=0
boss_start="${BOSS_START}"

_lockfile=''
_pidfile=''
tmpdir=''
tmpfile=''
pwd="$(pwd)"



# Params:
#   NONE
show_version() {
    echo -e "\n\
${APP_NAME} v${APP_VER}\n\
${APP_COPY}\n\
${APP_URL}${APP_URL:+\n}\
"
} # show_version()

# Params:
#   NONE
show_usage() {
    show_version

cat <<EOF

${APP_NAME} is a background queuing service for Linux shell jobs.

Usage: ${_binname} [-v|--verbose] -h|--help
       ${_binname} [-v|--verbose] -V|--version
       ${_binname} [-v|--verbose] -C|--configuration

       ${_binname} [-v|--verbose] [-q|--queue <QUEUE>]
       ${_binnam_} [-b|--boss] [-n|--noboss] 
       ${_binnam_} [--] <JOB> [<JOB PARAMETERS> [...]]

       ${_binname} [-v|--verbose] [-q|--queue <QUEUE>]
       ${_binnam_} -b|--boss [--]

-h|--help           - Displays this help
-V|--version        - Displays the program version
-C|--configuration  - Outputs the default configuration that can be placed in a
                      config file in XDG_CONFIG or one of the XDG_CONFIG_DIRS
                      (in order of decreasing precedence):
                          ${XDG_CONFIG_HOME:-${HOME}/.config}/${_APP_NAME}/${_CONF_FILENAME}
                          ${XDG_CONFIG_HOME:-${HOME}/.config}/${_CONF_FILENAME}
                          ${HOME}/.${_CONF_FILENAME}
EOF
    while read -r -d: _XDG_CONF_DIR; do #{
        # As per spec, non-absolute paths are invalid and must be ignored
        [ "${_XDG_CONF_DIR:0:1}" != "/" ] && continue
cat <<EOF
                          ${_XDG_CONF_DIR}/${_APP_NAME}/${_CONF_FILENAME}
                          ${_XDG_CONF_DIR}/${_CONF_FILENAME}
EOF
    done <<<"${_XDG_CONF_DIRS:-/etc/xdg}:" #}
cat <<EOF
                          /etc/${_CONF_FILENAME}
                      for editing.
-v|--verbose        - Displays extra debugging information.  This is the same
                      as setting DEBUG=1 in your config.
-q|--queue          - Specifies the queue (<QUEUE>) to add the job to
                      (DEFAULT: ${DEFAULT_QUEUE}).
-b|--boss           - Tries to start a queue boss for the queue$( \
    [ "${BOSS_START}" != '0' ] && { \
echo; \
echo "                      (DEFAULT)"; \
    } || echo '.'; \
)
-n|--noboss         - Does not try to start a new boss for the queue if one is
                      not already running$( \
    [ "${BOSS_START}" != '0' ] && { \
        echo '.'; \
    } || { \
echo; \
echo "                      (DEFAULT)"; \
    }; \
)

NOTE: If <JOB> has parameters, you should use '--' so ${_binname} can
differentiate between its own parameters and that of <JOB>.

Example: ${_binname}
EOF

} # show_usage()

# Clean up
cleanup() {
    decho "Clean Up"

    decho "Lock file: ${_lockfile}"
    [ -n "${_lockfile}" ] && rm -Rf "${_lockfile}" &>/dev/null
    _lockfile=''
    decho "PID file: ${_pidfile}"
    [ -n "${_pidfile}"  ] && rm -Rf "${_pidfile}"  &>/dev/null
    _pidfile=''
    decho "Temp dir: ${tmpdir}"
    [ -n "${tmpdir}"    ] && rm -Rf "${tmpdir}"    &>/dev/null
    tmpdir=''
    decho "Temp file: ${tmpfile}"
    [ -n "${tmpfile}"   ] && rm -Rf "${tmpfile}"   &>/dev/null
    tmpfile=''
    decho "PWD: ${pwd}"
    [ -n "${pwd}"       ] && cd "${pwd}"           &>/dev/null
    pwd=''
} # cleanup()

trapint() {
    >&2 echo "WARNING: Signal received: ${1}"

    exit ${1}
} # trapint()

trapexit() {
    cleanup
}

# Creates a file (atomically) if it can with optional contents
atomic_file_create() {
    filepath="${1}"; shift 1

    # Create file
    { set -C; cat 2>/dev/null >"${filepath}" <<<"${@}"; } && {
        echo "${filepath}"
        return ${ERR_NONE}
    }

    return ${ERR_UNAVAILABLE}
}

# Takes PID, and a position - outputs the commandline parameter at that position
cmdline_param() {
    # Can we read it?
    [ -r "/proc/${1}/cmdline" ] || return 1

    # cmdline is NULL seperated
    cut -d $'\0' -f "${2}" <"/proc/${1}/cmdline"
}

# Takes lockfile path (1) and queue name (2)
lockfile_create_for_queue() {
    local filepath="${1}"; shift 1
    local q="${1}"; shift 1
    local n_timeout=60

    while [ ${n_timeout} -gt 0 ]; do #{
        _lockfile="$(atomic_file_create "${filepath}")" && break

        n_timeout=$((n_timeout - 1))
        sleep 1
        continue
    done #}

    [ -z "${_lockfile}" ] && {
        >&2 echo "ERROR: Timeout waiting for queue lock for queue ${q}"
        return ${ERR_UNAVAILABLE}
    }

    return ${ERR_NONE}
}

# Takes pidfile path (1) and queue name (2)
pidfile_create_for_boss() {
    local filepath="${1}"; shift 1
    local q="${1}"; shift 1
    local old_pid=''

    # Check for existing boss job
    [ -r "${filepath}" ] && read old_pid <"${filepath}"

    [ -n "${old_pid}" ] && {
        [ -d "/proc/${old_pid}" ] && {
            [ -r "/proc/${old_pid}/cmdline" ] || {
                >&2 echo "ERROR: Unable to read command line for boss of queue ${q} (PID: ${old_pid})"
                return ${ERR_NOPERM}
            }

            local oldparam1="$(cmdline_param "${old_pid}" 1)"
            oldparam1="${oldparam1##*/}"
            local oldparam2="$(cmdline_param "${old_pid}" 2)"
            oldparam2="${oldparam2##*/}"

            # Check for us
            [ "${oldparam1}" == "${_binname}" ] \
            || ( \
                [ "${oldparam1}" == "bash" ] \
                && [ "${oldparam2}" == "${_binname}" ] \
            ) && {
                # It's us
                >&2 echo "INFO: Boss already running for queue ${q} (PID: ${old_pid})"
                return ${ERR_NONE}
            }
        }

        # Stale pid file
        >&2 echo "ERROR: (Stale?) PID file exists: ${filepath}"
        return ${ERR_NOPERM}
    }

    # Create boss pid file
    _pidfile="$(atomic_file_create "${filepath}" "$$")" || {
        >&2 echo "ERROR: Unable to create new pid file for boss of queue ${q}"
        return ${ERR_UNAVAILABLE}
    }

    return $?
}

# Takes PID, outputs the original commandline
cmdline() {
    # Read the original commandline

    # Can we read it?
    [ -r "/proc/${1}/cmdline" ] || return 1

    # cmdline is NULL seperated
    tr '\0' ' '<"/proc/${1}/cmdline"
}

start_boss() {
    #global _pidfile
    local waiting_pid=0
    local n_queue_depth=0
    local n_queue_depth_last=1

    # pidfile_create_for_boss reports any errors
    pidfile_create_for_boss "${pid_file}" "${queue}" || {
        exit $?
    }

    # Existing boss for queue already running?
    [ -z "${_pidfile}" ] && exit ${ERR_NONE}

    # Create temp file
    tmpfile="$(mktemp --tmpdir "${_binname}.${USER}.tmp.XXXXX")" || {
        >&2 echo "ERROR: Failed to create temporary file"
        exit ${ERR_CANTCREAT}
    }
    
    echo "Starting boss for queue "'"'"${queue}"'"'" (PID: $(<"${_pidfile}"))"

    while :; do #{
        sleep 1

        read -r n_queue_depth < <(wc -l <"${queue_file}")
        [ ${n_queue_depth} -le 0 ] && {
            [ ${n_queue_depth_last} -gt 0 ] && {
                echo "Queue empty"
                n_queue_depth_last='0'
            }
            continue
        }
        n_queue_depth_last="${n_queue_depth}"

        # lockfile_create_for_queue reports any errors
        lockfile_create_for_queue "/tmp/${_binname}.${USER}.${queue}.queue.lock" "${queue}" || {
            continue
        }

        # Failed to create lock file?
        [ -z "${_lockfile}" ] && continue



        # Queue is ours
        cmd="$(head -1 "${queue_file}")"
        tail -n +2 <"${queue_file}" >"${tmpfile}"
        cat "${tmpfile}" >"${queue_file}"

        # Unlock the queue lock
        rm "${_lockfile}" && _lockfile=''

        decho "Executing queued item: ${cmd}"
        # TODO: Capture stderr for error display?
        eval "${cmd}" || {
            >&2 echo "ERROR: Failed to execute: ${cmd}"
        }
        decho "Completed queued item: ${cmd}"

    done #}

    return ${ERR_NONE}
}



# Output configuration file
output_config() {
    sed -n '/^# \[ CONFIG_START/,/^# \] CONFIG_END/p' <"${0}"
} # output_config()

# Debug echo
decho() {
    # global $DEBUG
    local line

    # Not debugging, get out of here then
    [ -z "${DEBUG}" ] || [ "${DEBUG}" -le 0 ] && return 0

    # If message is "-" or isn't specified, use stdin ("" is valid input)
    msg="${@}"
    [ ${#} -lt 1 ] || [ "${msg}" == "-" ] && msg="$(</dev/stdin)"

    while IFS="" read -r line; do #{
        >&2 echo "[$(date +'%Y-%m-%d %H:%M')] DEBUG: ${line}"
    done< <(echo "${msg}") #}
} # decho()



# START #

# Clear DEBUG if it's 0
[ -n "${DEBUG}" ] && [ "${DEBUG}" == "0" ] && DEBUG=

ret=${ERR_NONE}

# If debug file, redirect stderr out to it
[ -n "${ERROR_LOG}" ] && exec 2>>"${ERROR_LOG}"

# SIGEXIT =  0
trap "trapexit" EXIT

# SIGINT  =  2 # (CTRL-c etc)
# SIGKILL =  9
# SIGUSR1 = 10
# SIGUSR2 = 12
for sig in 2 9 10 12; do #{
    trap "trapint ${sig}" ${sig}
done #}



#----------------------------------------------------------

# Process command line parameters
opts=$(\
    getopt\
        --options v,h,V,C,b,n,q:\
        --long verbose,help,version,configuration,boss,noboss,queue:\
        --name "${_binname}"\
        --\
        "$@"\
) || {
    >&2 echo "ERROR: Syntax error"
    >&2 show_usage
    exit ${ERR_USAGE}
}

eval set -- "${opts}"
unset opts

while :; do #{
    case "${1}" in #{
        # Verbose mode # [-v|--verbose]
        -v|--verbose)
            decho "Verbose mode specified"
            DEBUG=1
        ;;

        # Help # -h|--help
        -h|--help)
            decho "Help"

            show_usage
            exit ${ERR_NONE}
        ;;

        # Version # -V|--version
        -V|--version)
            decho "Version"

            show_version
            exit ${ERR_NONE}
        ;;

        # Configuration output # -C|--configuration
        -C|--configuration)
            decho "Configuration"

            output_config
            exit ${ERR_NONE}
        ;;

        # Boss # -b|--boss
        -b|--boss)
            decho "Boss"

            boss_mode=1
            boss_start=1
        ;;

        # No boss # -n|--noboss
        -n|--noboss)
            decho "No boss"

            boss_mode=0
            boss_start=0
        ;;

        # Queue # -q|--queue <QUEUE>
        -q|--queue)
            decho "Queue: ${2}"

            queue="${2}"
            shift 1
        ;;

        --)
            shift
            break
        ;;

        -)
            # Read stdin
            #set -- "/dev/stdin"
            # FALL THROUGH TO FILE HANDLER BELOW
        ;;

        *)
            >&2 echo "ERROR: Unrecognised parameter ${1}..."
            exit ${ERR_USAGE}
        ;;
    esac #}

    shift

done #}

# Check for non-optional parameters

[ ${#} -lt 1 ] && {
    [ "${boss_mode}" -ne 1 ] && {
        >&2 echo "ERROR: Job command or boss parameter required but not specified"
        exit ${ERR_USAGE}
    }
}



decho "START"

pid_file="/tmp/${_binname}.${USER}.${queue}.pid"
queue_file="/tmp/${_binname}.${USER}.${queue}.queue"

# Ensure queue file exists
touch "${queue_file}" || {
    >&2 echo "ERROR: No write access to queue "'"'"${queue}"'"'" file: ${queue_file}"
    exit ${ERR_NOPERM}
}

# Something to add to the queue?
[ "${#@}" -gt 0 ] && {
    read -r n_queue_depth < <(wc -l <"${queue_file}")

    # lockfile_create_for_queue reports any errors
    lockfile_create_for_queue "/tmp/${_binname}.${USER}.${queue}.queue.lock" "${queue}" || {
        exit $?
    }

    # Failed to create lock file?
    [ -z "${_lockfile}" ] && exit ${ERR_NONE}

    # Write new command to queue
    echo "${@@Q}" >>"${queue_file}"

    # Unlock the queue lock
    rm "${_lockfile}" && _lockfile=''

    echo "Added to queue "'"'"${queue}"'"'" (pos ${n_queue_depth}): ${@@Q}"
}

[ "${boss_start}" == '0' ] && exit ${ERR_NONE}



# Start boss

# start_boss reports any errors
start_boss
ret=$?

decho "DONE"

# Clean up is called on exit

exit ${ret}
