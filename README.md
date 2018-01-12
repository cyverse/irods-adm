# irods-adm

A collection of scripts for administering an iRODS grid


## iRODS Sessions

A session is a group of log messages that occurred during a single connection.

The awk script `group-log-by-pid.awk` can be used to group a sequence of log messages by the connection that generated them.

The bash script `dump-logs.sh` can be used to dump all of the sessions with errors from the CyVerse portion of the CyVerse grid.

The awk script `filter-session-by-cuser.awk` can be combined with `group-log-by-pid.awk` to find all of the sessions for a given user.

The awk script `session-intervals.awk` can be combined with `group-log-by-pid.awk` to find all of the time intervals for each session from a log file.

The program `count-sessions` can be combined with `sessions-intervals.awk` to generate a report on the number of concurrent sessions during each second for the time period covered by a log file.


## Resources

The program `resc-create-times` lists all of the root resources sorted by creation time.

The program `check-irods` generates a report on the accessibility of the IES and resources from various locations.


## Generating a histogram of an SQL query for byte-based sizes

The bash script `histgram.sh` can be used to generate a histogram of file sizes.


## Synchronizing data object and file sizes

The program `fsck-batch` can be used to find data objects that are out of sync with their files.

The program `fix-file-size` can be used to set the sizes of a group of data objects with the sizes of their respective files.


## Moving files to another resource

The program `phymv` can be used to move groups of files from one resource to another more efficiently that `iphymv`.


## Replication

The program `repl-report` can be used to generate a report on the number and volume of data objects that need to be replicated.

The program `repl` can be used to replicate data objects to the taccCorralRes resource.

The program `classify-repl-errors` takes the output of `repl` and group the errors by type.


## Repair

The program `data-store-fix` can be used to detect and repair issues with the Data Store.


## Trash

The program `trash-report` can be used to generate a report on how much trash there is.

The program `rm-trash` can be used to empty trash older than one month.
