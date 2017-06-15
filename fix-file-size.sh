#! /bin/bash

readonly EXEC_NAME=$(basename "$0")
readonly VERSION=1


show_help()
{
  cat <<EOF

$EXEC_NAME version $VERSION

Usage:
 $EXEC_NAME [options]

Updates the ICAT size information for the replicas of a set of data objects

Options:
 -j, --jobs  the number of fixes to perform simultaneously

 -h, --help     show help and exit
 -v, --version  show version and exit

Summary:
It reads a list of data object paths, one per line, from standard in. For each
replica, it updates the ICAT size information based on the size of the
corresponding file in storage.  No object name may have a carriage return in its
path. The user must be initialized with iRODS as an admin user. Finally, the
user must have passwordless access to the root account on the relevant storage
resources.
EOF
}


show_version()
{
  printf '%s\n' "$VERSION"
}


if ! opts=$(getopt --name "$EXEC_NAME" --options hj:v --longoptions help,jobs:,version -- "$@")
then
  printf '\n' >&2
  show_help >&2
  exit 1
fi

eval set -- "$opts"

while true
do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -j|--jobs)
      readonly JOBS="$2"
      shift 2
      ;;
    -v|--version)
      show_version
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      show_help >&2
      exit 1
      ;;
  esac
done

readonly EXEC_DIR=$(dirname "$0")


fix()
{
  local objPath="$1"

  printf '%s\n' "$objPath"

  while read -r rescHier storeHost filePath
  do
    local coordResc="${rescHier%%;*}"
    local tmp="$filePath".tmp

    ssh -q "$storeHost" \
        mv --no-clobber \"$filePath\" \"$tmp\" \&\& \
        touch \"$filePath\" \&\& \
        \(irsync -K -s -v -R \"$coordResc\" \"$tmp\" \"i:$objPath\"\; mv \"$tmp\" \"$filePath\"\) \
      < /dev/null
  done < <(cd "$EXEC_DIR" && ./get-replicas "$objPath")
}
export -f fix


if [ -n "$JOBS" ]
then
  readonly JobsOpt="-j$JOBS"
else
  readonly JobsOpt=
fi


parallel --eta --no-notice --delimiter '\n' --max-args 1 "$JobsOpt" fix > /dev/null
