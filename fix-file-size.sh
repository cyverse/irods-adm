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

  file=$(ils -L "$obj" | sed -n '/^   /p' | awk '{$1=$2=""; print substr($0,3)}')

  if [ $(wc -l <<< "$file") -ne 1 ]
  then
    printf "skipping: there isn't a unique file for this data object\n"
    continue
  fi

  coordRes=$(ils -L "$obj" | sed -n '/^  [^ ]/p' | awk '{print $3}' | cut -d\; -f 1)
  storeRes=$(ils -L "$obj" | sed -n '/^  [^ ]/p' | awk '{print $3}' | cut -d\; -f 2)
  storeHost=$(ilsresc -l "$storeRes" | sed -n 's/location: //p')
  vault=$(ilsresc -l "$storeRes" | sed -n 's/vault: //p')
  tmp="$vault"/tmp

  ssh -q "$storeHost" \
      su --command \'mv --no-clobber \"$file\" \"$tmp\" \&\& \
                     touch \"$file\" \&\& \
                     \(irsync -K -s -v -R \"$coordRes\" \"$tmp\" \"i:$obj\"\; \
                       mv \"$tmp\" \"$file\"\)\' \
         --login irods \
    < /dev/null
done < "$ObjsToFix"
