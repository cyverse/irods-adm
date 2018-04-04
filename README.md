# irods-adm

A collection of scripts for administering an iRODS grid


## iRODS Sessions

A session is a group of log messages that occurred during a single connection.

The program `format-log-entries` can be used to generate a sequence of formatted
log file messages from an iRODS log file.

The program `group-log-by-pid` can be combined with `format-log-entries` to
group log messages by the connection that generated them. This group of messages
is called a session.

The program `filter-sessions-by-origin` can be combined with `group-log-by-pid`
to find all of the sessions originating from a certain host.

The program `filter-sessions-by-time` can be combined with `group-log-by-pid` to
find all of the open sessions during a given time interval.

The program `order-sessions` can be combined with `group-log-by-pid` to list
sessions by the order of their start times.

The program `dump-logs` can be used to dump all of the sessions from the CyVerse
grid.

The program `filter-failed-sessions` can be used to filter a sequence of
sessions for those containing errors.

The program `filter-sessions-by-user` can be used to filter a sequence of
sessions for a given client user.

The program `session-intervals` can be used to extract session time intervals
from a sequence of sessions.


## Moving files to another resource

The program `phymv` can be used to move groups of files from one resource to
another more efficiently that `iphymv`.


## Repair

The program `data-store-fix` can be used to detect and repair issues with the
Data Store.


## Replication

The program `repl-report` can be used to generate a report on the number and
volume of data objects that need to be replicated.

The program `repl` can be used to replicate data objects to the taccCorralRes
resource.

The program `classify-repl-errors` takes the output of `repl` and group the
errors by type.

The program `get-replicas` looks up information on the replicas of a data
object.


## Report generation

The program `count-sessions` can be combined with `sessions-intervals` to
generate a report on the number of concurrent sessions during each second for
the time period covered by a sequence of sessions.

The program `daily-transfer-report` generates a report summarizing the amount of
data uploaded and downloaded each day.

The program `growth-report` generates a report showing the monthly growth of the
Data Store.

The program `histogram` can be used to generate a histogram of sizes from an
arbitrary SQL query for byte-based sizes.

The program `resource-report` generates a report on the size of the root
resources.

The program `trash-report` can be used to generate a report on how much trash
there is.


## Resources

The program `resc-create-times` lists all of the root resources sorted by
creation time.

The program `check-irods` generates a report on the accessibility of the IES and
resources from various locations.

The program `rm-resc` can be used to remove all of the files from a given
resource.


## Synchronizing data object and file sizes

The program `fsck-batch` can be used to find data objects that are out of sync
with their files.

The program `fix-file-size` can be used to set the sizes of a group of data
objects with the sizes of their respective files.


## Trash

The program `rm-trash` can be used to empty trash older than one month.
