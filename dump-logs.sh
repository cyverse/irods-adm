#!/bin/bash
#
# Usage: dump-logs.sh [YEAR [MONTH [START_DAY]]]
#
# YEAR is a the four digit year to restrict the dump to. MONTH is the number of the month to
# restrict the dump to. START_DAY is the start day of the log to dump. It is the day number relative
# to the month.
#
# This script dumps all of the errors from rodsLog files on the IES and all of the local resource
# servers. It groups the log by session, and it dumps each session that logs an error message. See
# group-log-by-pid.awk for the details on how a session is logged.
#
# The session error logs are written into the directory $CWD/logs. The session errors are written
# into one file for each server. The file has the name <server>.err. 
# 
# By default, it will process all of the logs. By specifying a year or a year and month number, the
# only the logs for that year or year and month will be processed.
#
# The script shows its progress in the following form:
#
#     dumping logs from <server>
#       dumping /var/log/irods/iRODS/server/log/rodsLog.<year>.<month>.01
#         <failed session count>/<total session count>


readonly LogBase=/var/lib/irods/iRODS/server/log/rodsLog

declare year=*
declare month=*
declare startDay=*

if [ $# -ge 1 ]; then printf -v year '%04d' "$1"; fi
if [ $# -ge 2 ]; then printf -v month '%02d' "$2"; fi
if [ $# -ge 3 ]; then printf -v startDay '%02d' "$3"; fi

readonly LogExt="$year"."$month"."$startDay"

declare -i cnt
declare -i tot

mkdir --parents logs

readonly RS=$(iquest '%s' "SELECT ORDER(RESC_LOC) WHERE RESC_CLASS_NAME = 'archive'")

for svr in data.iplantcollaborative.org $RS
do
  if [ "$svr" != aegis.a2c2.asu.edu ] && \
     [ "$svr" != aegis.cefns.nau.edu ] && \
     [ "$svr" != aegis-ua-1.arl.arizona.edu ] && \
     [ "$svr" != cyverse.corral.tacc.utexas.edu ] && \
     [ "$svr" != wildcat.cshl.edu ]
  then 
    printf '\rdumping logs from %s\n' "$svr"
    out=logs/"$svr".err
    rm -f "$out"

    for log in $(ssh -p 1657 -q root@"$svr" ls "$LogBase"."$LogExt")
    do
      if [[ "$log" =~ $LogBase ]]
      then
        printf '\r  dumping %s\n' "$log"

        cnt=0
        tot=0
        printf '\r    %d/%d' "$cnt" "$tot" >&2

        # The grep removes duplicate key SQL errors
        while IFS= read -r -d§ session
        do
          if [[ "$session" =~ ERROR: ]]
          then
            printf '§%s' "${session:1}"
            (( cnt++ ))
          fi

          (( tot++ ))
          printf '\r    %d/%d' "$cnt" "$tot" >&2
        done \
          < <(ssh -q -p 1657 root@"$svr" "cat '$log' | grep -v 'ERROR:  '" | ./group-log-by-pid.awk) \
          >> "$out"

        printf '\r' >&2
        printf '    %d/%d\n' "$cnt" "$tot"
      fi
    done
  else
    printf '\rskipping %s\n' "$svr"
  fi
done
