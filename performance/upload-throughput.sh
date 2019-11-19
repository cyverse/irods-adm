#!/bin/bash

show_help()
{
  cat <<EOF

$ExecName version $Version

Usage:
 $ExecName SRC_FILE DEST_COLL

This script measures upload throughput from the client running this script to
the CyVerse Data Store. It uploads a 10 GiB file twenty times in a row, with
each upload being to a new data object. It generates the same output as
\`iput -v\` would. The test results are written to stdout, while errors and
status messages are written to stderr.

Caution should be taken when choosing the name of the test file and the
collection where the objects are uploaded. To ensure that the file to upload is
10 GiB, it generates the file. If the file already exists, it overwrites the
file. Likewise, to ensure that no overwrites occur in iRODS, the script deletes
any files that would be overwritten before it performs the test.

It does its best to clean up after itself. It attempts to delete anything it
creates with one caveat. If a parent collection has to be created during the
creation of the destination collection, the parent collection is not deleted.

Parameters:
 SRC_FILE   The name to use for the 10 GiB test file
 DEST_COLL  The name of the collection where the test file will be uploaded

Example:
The following example uses a local file \`testFile\` that is temporarily stored
in the user's home folder. It uploads the file into the collection
\`UploadPerf\` under the client user's home collection. To keep track of the
upload progress, it splits stdout so that it is written both to stderr and a
file named \`upload-results\` stored in the user's home folder.

 iinit
 icd
 $ExecName "\$HOME"/testFile UploadPerf \\
   | tee /dev/stderr > "\$HOME"/upload-results
EOF
}


set -o nounset

readonly ExecAbsPath=$(readlink --canonicalize "$0")
readonly ExecName=$(basename "$ExecAbsPath")
readonly Version=1

readonly ObjBase=upload
readonly NumRuns=20


main()
{
  if [[ "$#" -lt 2 ]]
  then
    # shellcheck disable=SC2016
    show_help >&2
    return 1
  fi

  local testFile="$1"
  local coll="$2"

  printf 'Ensuring 10 GiB test file %s exists\n' "$testFile" >&2
  if ! truncate --size 10GiB "$testFile"
  then
    printf 'Failed to create 10 GiB file %s\n' "$testFile" >&2
    printf 'Cannot continue test\n' >&2
    return 1
  fi

  # shellcheck disable=SC2064
  trap "rm --force '$testFile'" EXIT

  printf 'Ensuring destination collection %s exists\n' "$coll" >&2
  local createdColl
  if ! createdColl=$(mk_dest_coll "$coll")
  then
    printf 'Failed to create destination collection %s\n' "$coll" >&2
    printf 'Cannont continue test\n' >&2
    return 1
  fi

  if [[ "$createdColl" -ne 0 ]]
  then
    printf 'Ensuring any previously uploaded test data objects have been removed\n' >&2

    if ! ensure_clean "$coll"
    then
      printf 'Failed to remove previously uploaded data objects\n' >&2
      printf 'Cannot continue test\n' >&2
      return 1
    fi
  fi

  printf 'Beginning test\n' >&2
  do_test "$testFile" "$coll"

  printf 'Removing uploaded test data objects\n' >&2
  ensure_clean "$coll" >&2

  if [[ "$createdColl" -ne 0 ]]
  then
    printf 'Removing destination collection %s\n' "$coll" >&2
    irm -f -r "$coll" >&2
  fi

  return 0
}


do_test()
{
  local testFile="$1"
  local coll="$2"

  local attempt
  for attempt in $(seq "$NumRuns")
  do
    local obj
    obj=$(mk_obj_path "$coll" "$attempt")

    iput -v "$testFile" "$obj"
  done
}


ensure_clean()
{
  local coll="$1"

  local status=0

  local attempt
  for attempt in $(seq "$NumRuns")
  do
    local obj
    obj=$(mk_obj_path "$coll" "$attempt")

    local errMsg
    if ! errMsg=$(irm -f "$obj" 2>&1)
    then
      if ! [[ "$errMsg" =~ ^ERROR:\ rmUtil:\ srcPath\ .*\ does\ not\ exist$ ]]
      then
        printf '%s\n' "$errMsg" >&2
        status=1
      fi
    fi
  done

  return "$status"
}


mk_dest_coll()
{
  local createdColl=0
  if ! ils "$coll" &> /dev/null
  then
    if ! imkdir -p "$coll"
    then
      return 1
    fi

    createdColl=1
  fi

  printf '%s' "$createdColl"
}


mk_obj_path()
{
  local coll="$1"
  local attempt="$2"

  printf '%s/%s-%02d' "$coll" "$ObjBase" "$attempt"
}


main "$@"
