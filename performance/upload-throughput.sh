#!/bin/bash

show_help()
{
  cat <<EOF

$ExecName version $Version

Usage:
 $ExecName [options]

This script measures upload throughput from the client running this script to
the CyVerse Data Store. It uploads a 10 GiB file twenty times in a row, with
each upload being to a new data object. The test results are written to stdout,
while errors and status messages are written to stderr.

Options:
 -D, --dest-coll DEST-COLL  the name of the temporary collection where the test
                            file will be repeatedly uploaded. Defaults to
                            \`ipwd\`/upload-throughput-\`date -u -Iseconds\`.
 -S, --src-dir SRC-DIR      the directory where the 10 GiB temporary test file
                            will be generated. Defaults to the system default
                            temporary directory.

 -h, --help     show help and exit
 -v, --version  show version and exit

Output:
It generates a TSV style output where each line has the following form.

<run>\t10 GiB\t<duration> s\t<throughput> MiB/s

Here "<run>" is the upload ordinal, "<duration>" is how the upload took in
seconds, and "<throughput>" is the transfer rate in mebibytes per second.

Example:
The following example uses a local file \`testFile\` that is temporarily stored
in the user's home folder. It uploads the file into the collection
\`UploadPerf\` under the client user's home collection. To keep track of the
upload progress, it splits stdout so that it is written both to stderr and a
file named \`upload-results\` stored in the user's home folder.

 iinit
 icd
 $ExecName > "\$HOME"/upload-results
EOF
}


set -o nounset -o pipefail

readonly ExecAbsPath=$(readlink --canonicalize "$0")
readonly ExecName=$(basename "$ExecAbsPath")
readonly Version=2

readonly NumRuns=3


main()
{
  local opts
  if ! opts=$(fmt_opts "$@")
  then
    show_help >&2
    return 1
  fi

  eval set -- "$opts"

  local destColl=
  local srcDir="${TMPDIR:-}"
  local versionReq=0
  while true
  do
    case "$1" in
      -h|--help)
        show_help
        return 0
        ;;
      -v|--version)
        versionReq=1
        shift
        ;;
      -D|--dest-coll)
        destColl="$2"
        shift 2
        ;;
      -S|--src-dir)
        srcDir="$2"
        shift 2
        ;;
      --)
        shift
        break
        ;;
      *)
        show_help >&2
        return 1
        ;;
    esac
  done

  if [[ "$versionReq" -eq 1 ]]
  then
    printf '%s\n' "$Version"
    return 0
  fi

  do_test "$srcDir" "$destColl" | tee /dev/stderr | gen_report
}


fmt_opts()
{
  getopt --name "$ExecName" --longoptions help,version,dest-coll:,src-dir: --options hvD:S: -- "$@"
}


do_test()
{
  local srcDir="$1"
  local destColl="$2"

  if ! ensure_irods_sess
  then
    printf 'iRODS session not initialized\n' >&2
    return 1
  fi

  if [[ -z "$destColl" ]]
  then
    destColl="$(ipwd)/upload-throughput-$(date --utc --iso-8601=seconds)"
  fi

  local srcFile
  if ! srcFile=$(TMPDIR="$srcDir" mktemp)
  then
    printf 'Cannot reserve temporary file\n' >&2
    return 1
  fi

  # shellcheck disable=SC2064
  trap "clean_up '$srcFile' '$destColl'" EXIT

  printf 'Creating 10 GiB test file %s\n' "$srcFile" >&2
  if ! truncate --size 10GiB "$srcFile"
  then
    printf 'Failed to create file\n' >&2
    return 1
  fi

  printf 'Creating destination collection %s\n' "$destColl" >&2
  if ! imkdir "$destColl"
  then
    printf 'Failed to create destination collection\n' >&2
    return 1
  fi

  printf 'Beginning test\n' >&2

  local attempt
  for attempt in $(seq "$NumRuns")
  do
    printf 'Uploading %s\n' "$attempt" >&2

    local obj
    printf -v obj '%s/upload-%02d' "$destColl" "$attempt"
    iput -v "$srcFile" "$obj"
  done

  printf 'Finished test\n' >&2
}


clean_up()
{
  local testFile="$1"
  local destColl="$2"

  if ils "$destColl" &> /dev/null
  then
    printf 'Deleting destination collection %s\n' "$destColl" >&2
    irm -f -r "$destColl"
  fi

  printf 'Deleting test file %s\n' "$testFile" >&2
  rm --force "$testFile"

  printf 'Finished\n' >&2
  return 0
}


ensure_irods_sess()
{
  local authFile="$(ienv | sed --quiet 's/.*irods_authentication_file - //p')"

  if [[ -z "$authFile" ]] || [[ ! -e "$authFile" ]]
  then
    if ! iinit
    then
      iexit full
      return 1
    fi
  fi
}


gen_report()
{
  local report=
  local run=0
  local max min

  local size duration rate
  while IFS=' |' read -r _ _ _ duration _ _ _ rate _
  do
    (( run++ ))
    printf -v report '%s%d\t10 GiB\t%s s\t%s MiB/s\n' "$report" "$run" "$duration" "$rate"

    if [[ "$run" -eq 1 ]]
    then
      min="$rate"
      max="$rate"
    else
      if [[ $(bc <<<"$rate < $min") -eq 1 ]]; then min="$rate"; fi
      if [[ $(bc <<<"$rate > $max") -eq 1 ]]; then max="$rate"; fi
    fi
  done

  printf -v report '%s\nrange: [%s, %s] MiB/s\n' "$report" "$min" "$max"

  printf '%s' "$report"
}



main "$@"
