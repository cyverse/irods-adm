#! /bin/bash

set -e

readonly EXEC_NAME=$(basename "$0")


show_help()
{
  cat << EOF
Usage: 
 $EXEC_NAME [options] LOG_FILE

Replicates data objects to taccCorralRes. It only replicates objects that only 
have one replica. The replica cannot be in the /iplant/home/shared/aegis 
collection or be on cshlWildcatRes.

Options:
 -c, --collection <collection>  only replicate the data objects in this 
                                collection
 -m, --multiplier <multiplier>  a multiplier on the number of processes to run 
                                at once, default: 1
 -r, --resource <resource>      only replicate the data objects with a file on 
                                this resource
 -u, --until <stop_time>        the time to stop replication in seconds since 
                                the POSIX epoch

 -h, --help  show help and exit
EOF
} 


exit_with_help()
{
  show_help >&2
  exit 1
}


readonly Opts=$(getopt --name "$EXEC_NAME" \
                       --options c:hm:r:u: \
                       --longoptions collection:,help,multiplier:,resource:until: \
                       -- \
                       "$@")

if [ "$?" -ne 0 ]
then
  printf '\n' >&2
  exit_with_help
fi

eval set -- "$Opts"

while true
do
  case "$1" in
    -c|--collection)
      readonly BASE_COLL="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    -m|--multiplier)
      readonly PROC_MULT="$2"
      shift 2
      ;;
    -r|--resource)
      readonly SRC_RES="$2"
      shift 2
      ;;
    -u|--until)
      export UNTIL="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      exit_with_help
      ;;
  esac
done

if [ "$#" -lt 1 ]
then
  exit_with_help
fi

readonly LOG="$1"

if [ -z "$PROC_MULT" ]
then
  readonly PROC_MULT=1
fi


check_time()
{
  if [ -n "$UNTIL" ] && [ $(date '+%s') -ge "$UNTIL" ]
  then
    return 1
  fi
}
export -f check_time


finish()
{
  local objList="$1"

  if ! check_time
  then
    printf 'out of time\n'
  fi

  rm --force "$objList"
}


repl()
{
  if ! check_time
  then
    exit 1
  fi

  irepl -B -M -v -R taccCorralRes "$@"
}
export -f repl


count()
{
  awk 'BEGIN { 
         RS = "\0"
         tot = 0
       } 
       
       { tot = tot + 1 } 
       
       END { print tot }'
}


partition()
{
  local minSizeB="$1"

  if [ "$#" -ge 2 ]
  then
    local maxSizeB="$2"

    if [ "$maxSizeB" -eq 0 ]
    then
      maxSizeB=1
    elif [ "$minSizeB" -eq 0 ]
    then
      minSizeB=1
    fi
  fi

  if [ -n "$maxSizeB" ]
  then
    awk --assign min="$minSizeB" --assign max="$maxSizeB" \
        'BEGIN {
           RS = "\0" 
           FS = " " 
           ORS = "\0"
         }

         {
           if ($1 >= min && $1 < max) { print substr($0, length($1) + 2) }
         }'
  else
    awk --assign min="$minSizeB" \
        'BEGIN {
           RS = "\0" 
           FS = " " 
           ORS = "\0"
         } 
         
         {
           if ($1 >= min) { print substr($0, length($1) + 2) }
         }' 
  fi 
}


track_prog() 
{
  local cnt="$1"
  local tot="$2"  
  local subTot="$3"

  local subCnt=0
  local msg=

  while read -r
  do
    ((++subCnt))
    ((++cnt))
    printf '\r%*s\r' "${#msg}" '' >&2
    printf -v msg \
           'cohort: %0*d/%d, all: %0*d/%d' \
           "${#subTot}" "$subCnt" "$subTot" "${#tot}" "$cnt" "$tot" 
    printf '%s' "$msg" >&2
  done

  printf '\r%*s\rcohort: %0*d/%d, all: %0*d/%d\n' \
         "${#msg}" '' "${#subTot}" "$subCnt" "$subTot" "${#tot}" "$cnt" "$tot" \
      >&2

  printf '%s' "$cnt"
}


select_cohort()
{
  local cnt="$1"
  local tot="$2"
  local maxProcs="$3"
  local minThreads="$4"

  if [ "$#" -ge 5 ]
  then
    local maxThreads="$5"
  fi

  if ! check_time
  then
    exit 0
  fi

  local minSizeMiB=$((minThreads * 32))
  local minSizeB=$((minSizeMiB * ((1024 ** 2))))
  local cohortList=$(tempfile)

  if [ -n "$maxThreads" ]
  then
    local maxSizeMiB=$((maxThreads * 32))
    local maxSizeB=$((maxSizeMiB * ((1024 ** 2))))

    partition "$minSizeB" "$maxSizeB"
  else
    partition "$minSizeB"
  fi > "$cohortList"

  local subTotal=$(count <"$cohortList")

  if [ -n "$maxSizeMiB" ]
  then
    printf 'Replicating %s files with size in [%s, %s) MiB\n' \
           "$subTotal" "$minSizeMiB" "$maxSizeMiB" \
        >&2
  else
    printf 'Replicating %s files with size >= %s MiB\n' "$subTotal" "$minSizeMiB" >&2
  fi
 
  if [ "$subTotal" -gt 0 ]
  then
    local maxArgs=$((2 * ((maxProcs ** 2))))
    maxProcs=$((maxProcs * PROC_MULT))

    parallel --no-notice --null --halt 2 --max-args "$maxArgs" --max-procs "$maxProcs" repl {} \
        < "$cohortList" \
        2>> "$LOG" \
        | tee --append "$LOG" \
        | track_prog "$cnt" "$tot" "$subTotal"
  else
    printf '%s\n' "$cnt"
  fi

  rm --force "$cohortList"  
}


if ! check_time
then
 printf 'Stop time is in the past\n' >&2
 exit 1
fi

readonly ObjectList=$(tempfile)

trap "finish $ObjectList" EXIT

truncate --size 0 "$LOG"

printf 'Retrieving data objects to replicate...\n'

if [ -n "$SRC_RES" ]
then
  readonly SrcCond="d.resc_name = '$SRC_RES'"
else
  readonly SrcCond=TRUE
fi

if [ -n "$BASE_COLL" ]
then
  readonly BaseCond="c.coll_name = '$BASE_COLL' OR c.coll_name LIKE '$BASE_COLL/%'"
else
  readonly BaseCond=TRUE
fi

psql --no-align --tuples-only --record-separator-zero --field-separator ' ' --host irods-db3 \
     ICAT icat_reader \
<< EOSQL > "$ObjectList"
SELECT d.data_size, c.coll_name || '/' || d.data_name
  FROM r_data_main AS d JOIN r_coll_main AS c ON c.coll_id = d.coll_id
  WHERE d.data_id = ANY(ARRAY(SELECT data_id FROM r_data_main GROUP BY data_id HAVING COUNT(*) = 1))
    AND NOT (d.data_repl_num = 0 AND d.resc_name = 'cshlWildcatRes')
    AND c.coll_name != '/iplant/home/shared/aegis' 
    AND c.coll_name NOT LIKE '/iplant/home/shared/aegis/%'
    AND ($BaseCond)
    AND ($SrcCond)
EOSQL

readonly Tot=$(count <"$ObjectList")
printf '%d data objects to replicate\n' "$Tot"

if [ "$Tot" -gt 0 ]
then
  cnt=0
  cnt=$(select_cohort "$cnt" "$Tot"  16   0  0 < "$ObjectList")  # 16 0 byte transfers 
  cnt=$(select_cohort "$cnt" "$Tot"  16   0  1 < "$ObjectList")  # 16 1-threaded transfers 
  cnt=$(select_cohort "$cnt" "$Tot"   8   1  2 < "$ObjectList")  # 8 2-threaded
  cnt=$(select_cohort "$cnt" "$Tot"   6   2  3 < "$ObjectList")  # 6 3-threaded
  cnt=$(select_cohort "$cnt" "$Tot"   4   3  5 < "$ObjectList")  # 4 4--5-threaded
  cnt=$(select_cohort "$cnt" "$Tot"   3   5  7 < "$ObjectList")  # 3 6--7-threaded
  cnt=$(select_cohort "$cnt" "$Tot"   2   7 15 < "$ObjectList")  # 2 8--15-threaded
  cnt=$(select_cohort "$cnt" "$Tot"   1  15    < "$ObjectList")  # 1 16-threaded
fi 2>&1

