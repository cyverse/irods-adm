# Data Corruption Resolution

When data corruption or loss occurs that CyVerse cannot resolve, we need to ask the people impacted
for help. We do this by sending each person an email notifying them of the problem and what they
need to fix. We give them 90 days to fix the issues before we take actions to restore the integrity
of the Data Store.

Here are the steps of the data loss resolution process.

1. Prepare the information for reporting to users.
1. Send the notification emails.
1. Wait at least 90 days to allow the users time to fix the corrupted data objects.
1. Apply appropriate actions on remaining corrupted data objects.
1. Archive information prepared for reporting.

## Preparing Information for Reporting

All of the information needed to notify the people impacted by a single data corruption event goes
into a subdirectory of the `reports/` directory. This subdirectory should be named after the date
when the users are notified of the corruption. Its name should have the form `YYYY-MM-DD/` where
_YYYY_ is the four-digit year, _MM_ is the two-digit month number, and _DD_ is the two-digit day of
the month.

### Organizing the Information for Reporting

A single data corruption event can affect multiple projects and users. The relevant information for
each project or user goes into its own subdirectory under `YYYY-MM-DD/`. A project subdirectory
should be given the same name as the project's top-level iRODS collection, and a user subdirectory
should be named after the user's CyVerse account. For example, if a user's CyVerse account is
_tedgin_, the corruption event information relevant to this user would go in a subdirectory named
`tedgin`, and for a project whose top-level collection is `/iplant/home/shared/CyVerse_DSStats`, the
information relevant to this project would go in a subdirectory named `CyVerse_DSStats`.

A project or user information subdirectory should be organized as follows. The corrupted data
objects need to be grouped into files by type of corruption. Those with an incorrect checksum or
size in the catalog should be placed in one file, and those missing physical files should be placed
in another. These files should hold the absolute paths to their data objects, one per line. If only
one type of problem exists for this project or user, only a file for that problem type should be
created. Also, a YAML file named `contact.yml` should be provided. Here's an example `contact.yml`
file that has been annontated to describe what information the file needs to provide.

```yaml
---
# This is an annotated example of a contact.yml.

# (OPTIONAL) If the data are owned by a project, this field should be included
# and set to the name of the project as recorded by Project Operations.
project: CyVerse_DSStats

# (REQUIRED) This field should hold the LDAP information for the primary person
# to contact about the data issue. For a project, this should be the project PI
# indicated in the records kept by the Project Operations team.
contact:

  # (OPTIONAL) This is the `uid` field from LDAP. This should be their CyVerse
  # account.
  uid: tedgin

  # (REQUIRED) This is the user's common name or `cn` field from LDAP. The email
  # will refer to the user by this name.
  cn: Tony Edgin

  # (REQUIRED) This is the user's email address or `mail` field from LDAP. The
  # email will be sent to this email address.
  mail: tedgin@cyverse.org

# (OPTIONAL) If there are other users who should be notified or if the primary
# person has more than one email address, they can be added here. These contacts
# will be CC'd.
other_contacts:

  - # (OPTIONAL) This is the `uid` field from an additional contact's LDAP
    # entry.
    uid: tedgin

    # (OPTIONAL) This is the `cn` field from an additional contact's LDAP entry.
    cn: Tony Edgin

    # (REQUIRED) This is the `mail` field from an additional contact's LDAP
    # entry. This email address will be CC'd.
    mail: tedgin@arizona.edu

# (OPTIONAL) If there are any data objects that have checksum or size
# discrepencies, this field should hold the name of the file containing these
# data objects. The file should contain the absolute paths to the data objects,
# one path per line.
corrupted_files: checksum-discrepencies.txt

# (OPTIONAL) If there are any data objects that are missing their replicas
# (physical files), this field should hold the name of the file containing these
# data objects. The file should contain the absolute paths to the data objects,
# one path per line.
missing_files: missing-content.txt
```

Here's a representative layout of a report directory after the reporting informataion has been
organized.

```console
reports/
   YYYY-MM-DD/
      project-1/
         checksum-discrepencies.txt
         contact.yml
         missing-content.txt
      project-2/
         checksum-discrepencies.txt
         contact.yml
      user-1/
         contact.yml
         missing-content.txt
      user-2/
         checksum-discrepencies.txt
         contact.yml
```

__The directory `reports/1999-12-31/` contains a working example.__

### Generating the Recipients List

Before the impacted people can be notified, the report information for the event needs to be
aggregated into a single file named `reports/YYYY-MM-DD/recipients.yml`. This is accomplished by
executing the `mk-recipients` script from this directory on the event directory `YYYY-MM-DD`.

```console
prompt> ./mk-recipients YYYY-MM-DD
```

## Sending the Notification Emails

To send the data corruption notification emails, the ansible playbook `email_notifications.yml` in
this directory is performed. This playbook requires two variables to be passed to it on the command
line. `audit_date` should be set to the date when the data corruption was detected. `recipient_file`
should be set to the relative path to the event report's `recipients.yml` file. A third variable,
`notifier` can be passed to the playbook. This variable is used in the email signature to identify
the CyVerse employee sending the email.

```console
prompt> ansible-playbook \
>   --extra-vars audit_date=yyyy/mm/dd \
>   --extra-vars recipient_file=reports/YYYY-MM-DD/recipients.yml \
>   --extra-vars 'notifier="Tony Edgin"' \
>   email_notifications.yml
```

## 90 Day Wait Period

After sending the notification emails, a wait period of at least 90 days should be taken to allow
the users to fix the corrupted data object.

## Actions for Remaining Corrupted Data Objects

After waiting, the following actions should be taken to restore the integrity of the Data Store.

- Any unfixed data object whose replica has an invalid file path should be deleted.
- Any unfixed data object whose replica has an incorrect size in the catalog should have its catalog
  size and checksum entries set to the size and MD5 checksum of the physical file, respectively.
- Any unfixed data object whose replica has a correct size but incorrect checksum in the catalog
  should have its catalog checksum entry set to the the MD5 checksum of the physical file.

`iadmin` can be used To fix the catalog size entry for a data object's replica, and `ichksum` can be
used to fix its checksum entry. For example, to fix the catalog entries for the data object
`/iplant/home/shared/CyVerse_DSStats/bad-checksum-1`, do something like the following as the iRODS
admin user.

```console
prompt> iquest \
>   "select RESC_LOC, DATA_PATH, DATA_REPL_NUM where COLL_NAME = '/iplant/home/shared/CyVerse_DSStats' and DATA_NAME = 'bad-checksum-1'"
RESC_LOC = ds04.cyverse.org
DATA_PATH = /irods_vault/ds04/home/shared/CyVerse_DSStats/bad-checksum-1
DATA_REPL_NUM = 0
------------------------------------------------------------
prompt> ssh -q ds04.cyverse.org \
>   sudo --user=irods stat --format=%s /irods_vault/ds04/home/shared/CyVerse_DSStats/bad-checksum-1
3165
prompt> iadmin modrepl \
>   logical_path /iplant/home/shared/CyVerse_DSStats/bad-checksum-1 replica_number 0 DATA_SIZE 3165
prompt> ichksum -f -M -n 0 /iplant/home/shared/CyVerse_DSStats/bad-checksum-1
```

## Archiving Report information

Once all of the requested fixes in a report have been made, the subdirectory should be tar-zipped to
indicate that all of the requests have been addressed.

```console
prompt> tar --create --gzip --directory=reports --file=reports/YYYY-MM-DD.tgz YYYY-MM-DD
prompt> rm --recursive reports/YYYY-MM-DD
```
