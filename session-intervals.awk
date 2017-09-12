#!/usr/bin/awk -f
#
# This script extracts the begin and end times for each session from a stream of iRODS sessions.
# It writes one interval per line with the follwoing format.
#
# <start time> <end time> <client user>
#
# The times are in seconds since the POSIX epoch.



function read_time(month, day, time) {
  switch (month) {
  case "Jan":
    monNum = "01";
    break;
  case "Feb":
    monNum = "02";
    break;
  case "Mar":
    monNum = "03";
    break;
  case "Apr":
    monNum = "04";
    break;
  case "May":
    monNum = "05";
    break;
  case "Jun":
    monNum = "06";
    break;
  case "Jul":
    monNum = "07";
    break;
  case "Aug":
    monNum = "08";
    break;
  case "Sep":
    monNum = "09";
    break;
  case "Oct":
    monNum = "10";
    break;
  case "Nov":
    monNum = "11";
    break;
  case "Dec":
    monNum = "12";
    break;
  default:
    break;
  }

  gsub(":", " ", time)
  return mktime("2017 " monNum " " day " " time " MST")
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

  startTime = read_time($2, $3, $4)
  endTime = startTime
  user = substr($14, 7)
}


$1 ~ "•" {
  endTime = read_time($2, $3, $4)
}


END {
  print_interval(startTime, endTime, user)
}
