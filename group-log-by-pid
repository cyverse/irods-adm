#!/usr/bin/awk -f
#
# This script groups a formatted log file entries by the PID of the iRODS agent
# handling the connection. Each grouping is referred to as a "session".
#
# If the FROM variable is set from the command line, only sessions from the
# provided IP address will be returned. If the USER variable is set from the
# command line, only sessions from the provided client user name will be
# returned.
#
# This script reads from standard input and writes to standard output.
#
# Here's a example grouping:
#
#     §• Sep 11 01:10:01 pid:26632 NOTICE: Agent process 13674 started for puser=ipc_admin and cuser=ipc_admin from 206.207.252.32
#      • Sep 11 01:10:02 pid:13674 NOTICE: readAndProcClientMsg: received disconnect msg from client
#      • Sep 11 01:10:02 pid:13674 NOTICE: Agent exiting with status = 0
#      • Sep 11 01:10:02 pid:26632 NOTICE: Agent process 13674 exited with status 0
#
# Each session begins with a "§". Each log entry is prefixed with a "•". If a log entries has a
# carriage return, the subsequent lines are indented and prefixed with the "…" character.
#
# The sessions get logged in the chronological order of their agents' exit times.


function assign_entry (entries, entryCounts, pid, entry) {
  if (pid in entryCounts) {
    entryCounts[pid]++;
  } else {
    entryCounts[pid] = 0;
  }

  entries[pid, entryCounts[pid]] = entry;
}


function format_entry(entry) {
  gsub(/\\n/, "\n   ", entry);
  return entry;
}


function print_section_start(entry) {
  print "§• " format_entry(entry);
}


function dump_agent (entries, entryCounts, pid) {
  if (pid in entryCounts) {
    print_section_start(entries[pid, 0]);
    delete entries[pid, 0];

    for (i = 1; i <= entryCounts[pid]; i++) {
      print " • " format_entry(entries[pid, i]);
      delete entries[pid, i];
    }

    delete entryCounts[pid];
  }
}


function dump_svr(entries, entryCounts, pid) {
  if (pid in entryCounts) {
    for (i = 0; i <= entryCounts[pid]; i++) {
      print_section_start(entries[pid, i]);
      delete entries[pid, i];
    }

    delete entryCounts[pid];
  }
}


function extract_start (entries, entryCounts, pid, fromAddr, user, entry) {
  dump_agent(entries, entryCounts, pid);

  if ((FROM == "" || FROM == fromAddr) && (USER == "" || USER == user)) {
    assign_entry(entries, entryCounts, pid, entry);
  }
}


function extract_stop (entries, entryCounts, pid, entry) {
  assign_entry(entries, entryCounts, pid, entry);

  if (pid in entryCounts) {
    dump_agent(entries, entryCounts, pid);
  }
}


{
  entry = $0;
  pid = substr($3, 5);

  if ($5 " " $6 == "Agent process") {
    dump_svr(entries, entryCounts, pid);

    aPid = $7;

    if ($8 == "started") {
      user = substr($12, 7);
      fromAddr = $14;
      extract_start(entries, entryCounts, aPid, fromAddr, user, entry);
    } else if ($8 == "exited") {
      extract_stop(entries, entryCounts, aPid, entry);
    } else {
      print_section_start(entry);
    }
  } else {
    assign_entry(entries, entryCounts, pid, entry);
  }
}


END {
  for (pid in entryCounts) {
    dump_agent(entries, entryCounts, pid);
  }
}
