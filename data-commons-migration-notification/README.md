# Data Commons Migration Notification

The described community collections under `/iplant/home/shared` are being moved out of the legacy
Data Commons and into the CKAN catalogue at [dc.cyverse.org](https://dc.cyverse.org). 20 of the 103
collections carry full descriptive metadata and so qualify, between them 172 folders that would
become datasets. The migration is opt-in: an owner who does not reply is not published, and their
collection stays exactly as it is in the Data Store and the legacy Data Commons.

This directory holds the machinery for asking them. It follows the pattern in
[`user-activity/account-removal-notification`](../user-activity/account-removal-notification):
JSON-SEQ on stdin, a Jinja2 template per message, SMTP with a delay between sends.

Here are the steps of the notification process.

1. Resolve the owner of each collection.
1. Build the recipient list.
1. Read the notices before anything is sent.
1. Send the notices.
1. Send one reminder after 30 days, and close out at 60.

## Resolving the Owners

The legacy Data Commons cannot say who owns a collection. Its `api_stat` endpoint reports
`permission` as a bare `read` and carries no ownership field at all, so the owning account has to
come from the iRODS ACL. `resolve-collection-owners` reads collection names on stdin and writes the
own-access users to stdout as a one-column CSV, which is what
[`extract-ldap-user-info`](../user-activity/extract-ldap-user-info) consumes.

```console
prompt> ./collections | ./resolve-collection-owners | ../user-activity/extract-ldap-user-info
username,create_date,expire_date,cn,mail
...
```

`resolve-collection-owners` needs a rodsadmin session, and `extract-ldap-user-info` needs to reach
`ldap.iplantcollaborative.org`, so both have to run from inside the CyVerse network. Service and
administrative accounts own most of `/iplant/home/shared` by default and are never the person to
write to, so they are filtered out; `--all-permissions` reports every ACL entry instead, which is
useful when a collection turns out to have no owner outside those accounts.

The result has to be joined back to the collections it came from, giving a CSV with the header
`collection,username,cn,mail`. One row per collection whose owner is known; a collection with no row
gets a notice with no address, which `notify-owners` skips and lists rather than sending.

Keep that file out of this repository. It is the one artifact of this process that holds people's
contact information.

## Building the Recipient List

`build-recipients` turns the survey of the collections and the contacts file into JSON-SEQ, one
document per outreach thread. Seven of the 20 collections name the same CyVerse steward, so they
travel as a single thread, which is why 20 collections make 14 threads rather than 20.

```console
prompt> ./build-recipients \
>   --metadata metadata.json \
>   --publishable publishable.json \
>   --contacts contacts.csv \
>   --send-date 2026-10-01 \
>   > recipients.jsonseq
No contact yet for 12 collections: ...
```

Every figure that appears in a notice is read from the survey rather than typed, so a notice cannot
claim a count that was not measured. See [measurements/README.md](measurements/README.md) for the
shape of the two survey files, and `measurements/example/` for a runnable pair.

`--send-date` is day 1 of the window. The reminder date and the deadline are derived from it, 30 and
60 days out, and travel in each record so that every message quotes the same two dates.

## Reading the Notices First

These go to principal investigators outside CyVerse and cannot be unsent. `render-preview` writes
each message to a file and nothing else: it imports no `smtplib` and opens no socket.

```console
prompt> ./build-recipients ... | ./render-preview --out ./preview
prompt> ./build-recipients ... | ./render-preview --stage reminder --out ./preview
```

Each thread produces a `.html` file and a `.txt` file. The `.txt` is not a summary; it is the exact
plain-text alternative `notify-owners` attaches beside the HTML, produced by the same code, so
reviewing it reviews what gets sent.

`notify-owners --dry-run --out ./preview` writes the assembled `.eml` instead, headers included,
which is the thing to check when the question is about the envelope rather than the wording.

## Sending the Notices

```console
prompt> ./build-recipients ... \
>   | ./notify-owners --sender-name 'Your Name' --sender-title 'Your Title'
```

The signature is required: `notify-owners` refuses to send while it is still a placeholder, because
an unsigned notice asking someone to make a decision about their own data is worse than no notice.
`--thread N` and `--template-filter NAME` restrict a run to part of the campaign, which is how to
send the internal thread first and read it in a real mail client before the external ones go out.

Every send appends a line to `sent.jsonseq` recording the addresses, the collections and the two
dates. The dates have to be counted from when a message was actually written, not from when the
campaign was planned, so the log is what the reminder run is driven from.

`SMTP_SERVER` and `SMTP_PORT` select the mail server, defaulting to `localhost:25`.

## Reminding and Closing Out

One reminder goes out on the date in the record, to the threads that have not replied. It is the
same pipeline with `--stage reminder` at the rendering step and the unanswered threads filtered out
of the recipient list. At 60 days the collections that never replied drop out of scope: nothing is
published, and nothing about them changes.

## The Messages

The template `internal-msg.html.j2` is for the CyVerse steward named on seven of the collections. It
is the only one carrying the staff asks, the lookups and metadata cleanups that are nobody else's
business.

The template `external-named-msg.html.j2` is for a collection whose creator is a person, and
`external-institution-msg.html.j2` for one whose creator is an organization, where there is nobody
to greet by name.

The template `reminder-msg.html.j2` is the day-30 reminder, and `acceptance-msg.html.j2` goes back
to an owner who has said yes, covering what happens next and what they have to do first.

The template `_layout.html.j2` is the wrapper, and `_parts.html.j2` holds the macros shared between
messages. All styling is inline, because mail clients strip `<style>` blocks.

## Where This Departs From notify-users

Each message carries its own subject. That campaign sent one subject to thousands of inactive users;
this one sends 14 subjects to 14 named threads.

There is a `--dry-run`, and a separate send-free `render-preview`. These go to external PIs and
cannot be unsent, so previewing the exact bytes is not optional.

The body is `multipart/alternative` with a text part beside the HTML. The original sets
`Content-Type: text/html` on a `multipart/mixed` container, which adds a second Content-Type header
rather than describing the body.

A record with no `mail` is skipped and listed. Most owners are unknown until the ACL lookups land,
so a partial run is the normal case rather than malformed input.

Each send is logged, because every recipient carries a reminder date and a deadline that have to be
counted from when they were actually written to.

The envelope sender and the `From` header are both configurable. The original sends
`MAIL FROM: support@cyverse.org` while `From:` is `$USER@$(hostname --fqdn)`. That is harmless at
their volume, but two domains not agreeing is what lands a small campaign in a spam folder.

There is no `List-Unsubscribe` header. This is not a mailing list. Each message asks one owner for a
decision about their own data, and there is nothing to unsubscribe from.

## What Has Not Been Exercised

`resolve-collection-owners` has not been run against the grid, and `notify-owners` has not opened an
SMTP connection. Every notice reviewed so far came from `render-preview`. The rendering, the
flattening and the recipient list are exercised; the ACL query and the send path are not.

The `--split-string` shebang is a GNU coreutils feature, so on macOS these have to be invoked as
`uv run --script ./build-recipients`.
