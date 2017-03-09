# irods-adm
A collection of scripts for administering an iRODS grid

## Grouping a log by session

The awk script `group-log-by-pid.awk` can be used to group a sequence of log messages by the 
connection that generated them.

## Filtering a sequence of sessions for a given user

The awk script `filter-session-by-cuser.awk` can be combined with `group-log-by-pid.awk` to find all of the sessions for a given user.

## Extracting the length of each session from a sequence of sessions

The awk script `session-intervals.awk` can be combined with `group-log-by-pid.awk` to find all of the time intervals for each session from a log file.

## Dumping all of the errors on the IES and CyVerse resource servers

The bash script `dump-logs.sh` can be used to dump all of the errors from the CyVerse portion of
the CyVerse grid.
