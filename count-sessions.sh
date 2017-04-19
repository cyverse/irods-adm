#! /bin/bash
#
# Generates a report on the number of concurrent sessions during each second.
# It reads an interval report with the following format.
#
# START_TIME STOP_TIME ...
#
# START_TIME is the time when a session started in seconds since the POSIX 
# epoch. STOP_TIME is the time when the same session ended in seconds since the
# POSIX epoch.  The rest if the line is ignored.

readonly IntervalsFile="$1"

readonly LB=$(cut --delimiter ' ' --fields 1 "$IntervalsFile" \
              | sort --numeric-sort \
              | head --lines 1)

declare -a counts
max=0

while read -r start stop junk
do
  start=$((start - LB))
  stop=$((stop - LB))

  for t in $(seq "$start" "$stop")
  do
    counts["$t"]=$((counts[t] + 1))
  done
  
  if [ "$stop" -gt "$max" ]
  then
    max="$stop"
  fi
done < "$IntervalsFile"

for t in $(seq 0 "$max")
do
  printf '%d %d\n' $((LB + t)) $((counts[t] + 0))
done
