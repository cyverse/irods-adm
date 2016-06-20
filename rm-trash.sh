#! /bin/bash
#
# Since irmtrash fails often, this is a simple script that iterates over 
# the users and deletes their trasn one user at a time.
#

readonly Zone=$(imiscsvrinfo | sed -n 's/^rodsZone=//p')

for user in $(iadmin lu | sort)
do
  user=${user%#$Zone}   

  if [ "$user" != "anonymous" -a "$user" != "rodsBoot" ]
  then        
    printf 'removing trash for %s\n' "$user"
    irmtrash -M -u "$user"
  fi
done
