#! /bin/bash

readonly Log="$1"

set -e


lsl()
{
  local obj="$1"
  
  while ! size=$(ils -l "$obj" | awk '{ print $4 }')
  do
    sleep 1
  done

  printf '%d %s\n' "$size" "$obj" 
}
export -f lsl


split_out_class()
{
  local errorsFile="$1"
  local classifierRegEx="$2"
  local classFile="$3"

  local errors=$(cat "$errorsFile")
  local classifiedErrors=$(sed --quiet "/$classifierRegEx/p" <<< "$errors")

  if [ -n "$classifiedErrors" ]
  then
    comm -2 -3 <(echo "$errors") <(echo "$classifiedErrors") > "$errorsFile"
    echo "$classifiedErrors" > "$classFile"
    wc --lines <<< "$classifiedErrors"
  else
    printf '0'
  fi
}


rm --force "$Log".*

readonly ErrorsFile=$(mktemp)
readonly ReplErrorsFile=$(mktemp)
readonly ChksumMismatchesFile=$(mktemp)

touch "$ErrorsFile" "$ReplErrorsFile" "$ChksumMismatchesFile"

sed --quiet 's/.*ERROR: \([^\[].*$\)/\1/p' "$Log" | sort > "$ErrorsFile"

readonly ErrCnt=$(cat "$ErrorsFile" | wc --lines)
readonly CntWid=${#ErrCnt}

printf '%*d errors\n' "$CntWid" "$ErrCnt"

readonly ITCnt=$(split_out_class "$ErrorsFile" \
                                 'replUtil: invalid repl objType 0 for ' \
                                 "$Log".invalid_types)
printf '%*d invalid object types\n' "$CntWid" "$ITCnt"

readonly SPECnt=$(split_out_class "$ErrorsFile" 'replUtil: srcPath ' "$Log".src_path_errors)
printf '%*d source path errors\n' "$CntWid" "$SPECnt"

readonly RCnt=$(split_out_class "$ErrorsFile" 'replUtil: repl error for ' "$ReplErrorsFile")
printf '%*d replication errors\n' "$CntWid" "$RCnt"

readonly ReplErrors=$(cat "$ReplErrorsFile")
sed 's/replUtil: repl error for //' <<< "$ReplErrors" | sort > "$ReplErrorsFile"

readonly SCLECnt=$(split_out_class "$ReplErrorsFile" \
                                   ', status = -27000 status = -27000 SYS_COPY_LEN_ERR' \
                                   "$Log".short_file)
printf '%*d short files\n' "$CntWid" "$SCLECnt"

readonly UFOECnt=$(split_out_class \
  "$ReplErrorsFile" \
  ', status = -510002 status = -510002 UNIX_FILE_OPEN_ERR, No such file or directory$' \
  "$Log".missing_file)
printf '%*d file open errors\n' "$CntWid" "$UFOECnt"

readonly UCMCnt=$(split_out_class "$ReplErrorsFile" \
                                  ', status = -314000 status = -314000 USER_CHKSUM_MISMATCH$' \
                                  "$ChksumMismatchesFile")
printf '%*d checksum mismatches\n' "$CntWid" "$UCMCnt"

sed --in-place \
  's/, status = -314000 status = -314000 USER_CHKSUM_MISMATCH$//' "$ChksumMismatchesFile"

ecmCnt=0
ncmCnt=0
cnt=0
msg=

while read -r size obj
do
  ((++cnt))
  printf '\r%*s\r' ${#msg} '' 
  printf -v msg 'checking size: %0*d/%d ...' ${#UCMCnt} "$cnt" "$UCMCnt"
  printf '%s' "$msg"

  if [ "$size" -eq 0 ]
  then
    ((++ecmCnt))
    echo "$obj" >> "$Log".empty_chksum_mismatches
  else
    ((++ncmCnt))
    echo "$obj" >> "$Log".nonempty_chksum_mismatches
  fi
done < <(parallel --no-notice --delimiter '\n' --max-args 1 --max-procs 7 lsl {} \
           < "$ChksumMismatchesFile")

printf '\r%*s\r' ${#msg} '' 

printf '%*d empty checksum mismatches\n' "$CntWid" "$ecmCnt"
printf '%*d nonempty checksum mismatches\n' "$CntWid" "$ncmCnt"

printf '%*d unclassified replication errors\n' "$CntWid" $(cat "$ReplErrorsFile" | wc --lines)

if [ -s "$ReplErrorsFile" ]
then
  mv "$ReplErrorsFile" "$Log".unclassified_repl_errors
fi

printf '%*d unclassified errors\n' "$CntWid" $(cat "$ErrorsFile" | wc --lines)

if [ -s "$ErrorsFile" ]
then
  mv "$ErrorsFile" "$Log".unclassified_errors
fi

rm --force "$ErrorsFile" "$ReplErrorsFile" "$ChksumMismatchesFile"
