#!/usr/bin/awk -f
#
# This script groups the entries in a log file by the PID of the iRODS agent handling the 
# connection. Each grouping is referred to as a "session".
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
    entries[pid, entryCounts[pid]] = entry;
  }
}


function format_entry(entry) {
  gsub("\n", "\n   … ", entry);
  return entry;
}


function print_section_start(entry) {
  print "§• " format_entry(entry);
}


function dump(entries, entryCounts, pid) {
  if (pid in entryCounts) {
    for (i = 0; i <= entryCounts[pid]; i++) {
      print_section_start(entries[pid, i]);
      delete entries[pid, i];
    }

    delete entryCounts[pid];
  }
}
 

function dump_agent (entries, entryCounts, pid) {
  print_section_start(entries[pid, 0]);
  delete entries[pid, 0];

  for (i = 1; i <= entryCounts[pid]; i++) {
    print " • " format_entry(entries[pid, i]);
    delete entries[pid, i];
  }

  delete entryCounts[pid];  
}


function extract_start (entries, entryCounts, pid, fromAddr, user, entry) {
  if (pid in entryCounts) {
    dump_agent(entries, entryCounts, pid);
  }
 
  if ((FROM == "" || FROM == fromAddr) && (USER == "" || USER == user)) {
    entryCounts[pid] = -1;
    assign_entry(entries, entryCounts, pid, entry);
  }
}


function extract_stop (entries, entryCounts, pid, entry) {
  assign_entry(entries, entryCounts, pid, entry);

  if (pid in entryCounts) {
    dump_agent(entries, entryCounts, pid);
  }
}


function process_entry (entries, entryCounts, entry) {
  if (entry != "") {
    split(entry, fields);
    pid = substr(fields[4], 5);
    
    if (fields[6] " " fields[7] == "Agent process") {
      dump(entries, entryCounts, pid);
      aPid = fields[8];
 
      if (fields[9] == "started") {
        user = substr(fields[13], 7);
        fromAddr = fields[15];
        extract_start(entries, entryCounts, aPid, fromAddr, user, entry);
      } else if (fields[9] == "exited") {
        extract_stop(entries, entryCounts, aPid, entry);
      } else {
        print_section_start(entry);
      }
    } else {
      assign_entry(entries, entryCounts, pid, entry);
    }
  }
}


/^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [ 1-3][0-9] [0-2][0-9]:[0-5][0-9]:[0-5][0-9] / {
  process_entry(entries, entryCounts, currentEntry);
  currentEntry = "";
}


NF > 0 {
  if (currentEntry == "") {
    currentEntry = $0;
  } else {
    currentEntry = currentEntry "\n" $0;
  }
}


END {
  process_entry(entries, entryCounts, currentEntry);

  for (pid in entryCounts) {
    dump_agent(entries, entryCounts, pid);
  }
}
