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
 -h, --help  show help and exit

Summary:
It reads a list of data object paths, one per line, from standard in. For each
replica, it updates the ICAT size information based on the size of the 
corresponding file in storage.  No object name may have a carriage return in its
path. The user must be initialized with iRODS as an admin user. Finally, the 
user must have passwordless access to the root account on the relevant storage 
resources. It writes the path of the data object currently being processed to
standard out.
EOF
}


show_version()
{
  printf '%s\n' "$VERSION"
}


if ! opts=$(getopt --name "$EXEC_NAME" --options hv --longoptions help,version -- "$@")
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

while IFS= read -r objPath
do
  printf '%s\n' "$objPath"

  while read -r rescHier storeHost filePath
  do
    coordResc="${rescHier%%;*}"
    tmp="$filePath".tmp

    ssh -q "$storeHost" \
        su --command \'mv --no-clobber \"$filePath\" \"$tmp\" \&\& \
                       touch \"$filePath\" \&\& \
                       \(irsync -K -s -v -R \"$coordResc\" \"$tmp\" \"i:$objPath\"\; \
                         mv \"$tmp\" \"$filePath\"\)\' \
           --login irods \
      < /dev/null
  done < <(cd "$EXEC_DIR" && ./get-replicas "$objPath")
done
