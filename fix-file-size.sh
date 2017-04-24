#! /bin/bash

readonly ExecName=$(basename $0)

if [ "$#" -lt 1 ]
then
  cat <<EOF
Usage:
 $ExecName <obj-paths-file>

Updates the ICAT size information for a data object, setting it to the size of 
the corresponding file. No object name may have a carriage return in its path.
Also, no object may have more than one replica. The user must be initialized 
with iRODS as an admin user. Finally, the user must have passwordless access to
the root account on the relavent storage resources.

Parameters:
 obj-paths-file - A file containing the paths of the data objects to fix, one
                  object per line.
EOF

  exit 0
fi

readonly ObjsToFix="$1"

while IFS= read -r obj
do
  printf '%s\n' "$obj"

  info=$(isysmeta ls -l "$obj")

  if grep --quiet '\-\-\-\-' <<< "$info"
  then
    printf "skipping: there isn't a unique file for this data object\n"
    continue
  fi

  file=$(sed --quiet 's/data_path: //p' <<< "$info")
  coordRes=$(sed --quiet 's/resc_name: //p' <<< "$info")
  storeRes=$(ils -L "$obj" \
             | sed --quiet '/^  [^ ]/p' \
             | awk '{print $3}' \
             | cut --delimiter \; --fields 2)
  storeHost=$(ilsresc -l "$storeRes" | sed -n 's/location: //p')
  tmp="$file".tmp

  ssh -q "$storeHost" \
      su --command \'mv --no-clobber \"$file\" \"$tmp\" \&\& \
                     touch \"$file\" \&\& \
                     \(irsync -K -s -v -R \"$coordRes\" \"$tmp\" \"i:$obj\"\; \
                       mv \"$tmp\" \"$file\"\)\' \
         --login irods \
    < /dev/null
done < "$ObjsToFix"
