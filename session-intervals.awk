#!/usr/bin/awk -f
#
# This script extracts the begin and end times for each session from a stream of iRODS sessions.
# It writes one interval per line with the follwoing format.
#
# <start time> <end time> <client user>
#
# The times are in seconds since the POSIX epoch.

function read_time(day, time) {
  gsub(":", " ", time)
  return mktime("2017 02 " day " " time " MST")
}


function print_interval(startTime, endTime, user) {
  print startTime " " endTime " " user
}


BEGIN {
  startTime=-1
  endTime=0
  user=""
}


$1 ~ "§•" {
  if (startTime > 0) {
    print_interval(startTime, endTime, user)
  }

  startTime = read_time($3, $4)
  endTime = startTime
  user = substr($14, 7)
}


$1 ~ "•" {
  endTime = read_time($3, $4)
}


END {
  print_interval(startTime, endTime, user)
}
