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

The program `gather-logs` can be used to retrieve all of the log messages from
selected log files on a given server.

The program `session-intervals` can be used to extract session time intervals
from a sequence of sessions.


## Monitoring

The program `check_irods` checks to see if an iRODS service is online. It is
intended for use with Nagios.


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

The program `cyverse-throughput` reports throughput between the client running
the script and the CyVerse Data Store.

The program `daily-transfer-report` generates a report summarizing the amount of
data uploaded and downloaded each day.

The program `growth-report` generates a report showing the monthly growth of the
Data Store.

The program `histogram` can be used to generate a histogram of sizes from an
arbitrary SQL query for byte-based sizes.

The program `ips-proxy` can be used to generate a report similar to `ips`, but
when the IES behind a proxy.

The program `list-rods-logs` can be used to list the iRODS log files on a given
server.

The program `resource-report` generates a report on the size of the root
resources.

The program `sharing-report` generates a report on the amount of user data that
has been shared.

The program `trash-report` can be used to generate a report on how much trash
there is.

The program `transfer-report` generates a report summarizing the amount of data
uploaded and downloaded over a time period.


## Resources

The program `resc-create-times` lists all of the root resources sorted by
creation time.

The program `rm-resc` can be used to remove all of the files from a given
resource.


## Synchronizing data object and file sizes

The program `fsck-batch` can be used to find data objects that are out of sync
with their files.

The program `fix-file-size` can be used to set the sizes of a group of data
objects with the sizes of their respective files.
