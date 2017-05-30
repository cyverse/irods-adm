# irods-adm
A collection of scripts for administering an iRODS grid

## iRODS Sessions

A session is a group of log messages that occured during a single connection.

### Grouping a log by session

The awk script `group-log-by-pid.awk` can be used to group a sequence of log messages by the
connection that generated them.

### Dumping all of the errors on the IES and CyVerse resource servers

The bash script `dump-logs.sh` can be used to dump all of the sessions with errors from the CyVerse portion of the CyVerse grid.

### Filtering a sequence of sessions for a given user

The awk script `filter-session-by-cuser.awk` can be combined with `group-log-by-pid.awk` to find all of the sessions for a given user.

### Extracting the length of each session from a sequence of sessions

The awk script `session-intervals.awk` can be combined with `group-log-by-pid.awk` to find all of the time intervals for each session from a log file.

### Generating a report on the number of concurrent sessions over time

The bash script `count-sessions.sh` can be combined with `sessions-intervals.awk` to generate a report on the number of concurrent sessions during each second for the time period covered by a log file.

## Check access to iRODS resources

The program `check-irods` generates a report on the accessibility of the IES and resources from various locations.

## Synchronizing data object and file sizes

The bash script `fix-file-size.sh` can be used to set the sizes of a group of data objects with the sizes of their respective files.

## Generating a histogram of an SQL query for files size

The bash script `histgram.sh` can be used to generate a histogram of file sizes.

## Generating a report on data objects that need to be replicated

The bash script `repl-report` can be used to generate a report on the number and volume of data objects that need to be replicated.
