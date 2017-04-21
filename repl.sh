#! /bin/bash


show_help()
{
  printf 'Usage: repl.sh [OPTIONS...] LOG_FILE\n'
  printf '  -h             show help and exit\n'
  printf '  -c COLLECTION  only replicate the data objects in this collection\n'
  printf '  -r RESOURCE    only replicate the data objects with a file on this resource\n'
  printf '  -x MULTIPLIER  a multiplier on the number of processes to run at once\n'
}


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

  while read -r
  do
    ((subCnt++))
    ((cnt++))
    printf 'cohort: %d/%d, all: %d/%d\r' "$subCnt" "$subTot" "$cnt" "$tot" >&2 
  done

  printf 'cohort: %d/%d, all: %d/%d\n' "$subCnt" "$subTot" "$cnt" "$tot" >&2
  printf '%s' "$cnt"
}


select_cohort()
{
  local cnt="$1"
  local tot="$2"
  local log="$3"
  local maxProcs="$4"
  local minThreads="$5"

  if [ "$#" -ge 6 ]
  then
    local maxThreads="$6"
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
  fi >"$cohortList"

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
    xargs --null --max-args $((2 * ((maxProcs ** 2)))) --max-procs $((maxProcs * mult)) \
        irepl -B -M -v -R taccCorralRes \
      <"$cohortList" \
      2>>"$log" \
      | tee --append "$log" \
      | track_prog "$cnt" "$tot" "$subTotal"
  else
    printf '%s\n' "$cnt"
  fi

  rm "$cohortList"  
}

mult=1

while getopts 'c:hr:x:' opt
do
  case "$opt" in
    c)
      readonly BaseColl="$OPTARG"
      ;;
    h)
      show_help
      exit 0
      ;;
    r)
      readonly SrcRes="$OPTARG"
      ;;
    x)
      readonly mult="$OPTARG"
      ;;
    \?)
      printf 'Invalid option: -%s\n' "$OPTARG"
      printf '\n'
      show_help
      exit 1
      ;;
    :)
      printf 'Option -%s requires an argument.\n' "$OPTARG"
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1))

readonly Log="$1"

truncate --size 0 "$Log"

readonly ObjectList=$(tempfile)

printf 'Retrieving data objects to replicate...\n'

if [ -n "$SrcRes" ]
then
  srcCond="d.resc_name = '$SrcRes'"
else
  srcCond=TRUE
fi

if [ -n "$BaseColl" ]
then
  baseCond="c.coll_name = '$BaseColl' OR c.coll_name LIKE '$BaseColl/%'"
else
  baseCond=TRUE
fi

psql --no-align --tuples-only --record-separator-zero --field-separator ' ' --host irods-db3 \
     ICAT icat_reader \
<<EOSQL > "$ObjectList"
SELECT d.data_size, c.coll_name || '/' || d.data_name
  FROM r_data_main AS d JOIN r_coll_main AS c ON c.coll_id = d.coll_id
  WHERE d.data_id = ANY(ARRAY(SELECT data_id FROM r_data_main GROUP BY data_id HAVING COUNT(*) = 1))
    AND NOT (d.data_repl_num = 0 AND d.resc_name = 'cshlWildcatRes')
    AND c.coll_name != '/iplant/home/shared/aegis' 
    AND c.coll_name NOT LIKE '/iplant/home/shared/aegis/%'
    AND ($baseCond)
    AND ($srcCond)
EOSQL

tot=$(count <"$ObjectList")
printf '%d data objects to replicate\n' "$tot"

if [ "$tot" -gt 0 ]
then
  cnt=0
  cnt=$(select_cohort "$cnt" "$tot" "$Log" 16   0  0 <"$ObjectList")  # 16 0 byte transfers 
  cnt=$(select_cohort "$cnt" "$tot" "$Log" 16   0  1 <"$ObjectList")  # 16 1-threaded transfers 
  cnt=$(select_cohort "$cnt" "$tot" "$Log"  8   1  2 <"$ObjectList")  # 8 2-threaded
  cnt=$(select_cohort "$cnt" "$tot" "$Log"  6   2  3 <"$ObjectList")  # 6 3-threaded
  cnt=$(select_cohort "$cnt" "$tot" "$Log"  4   3  5 <"$ObjectList")  # 4 4--5-threaded
  cnt=$(select_cohort "$cnt" "$tot" "$Log"  3   5  7 <"$ObjectList")  # 3 6--7-threaded
  cnt=$(select_cohort "$cnt" "$tot" "$Log"  2   7 15 <"$ObjectList")  # 2 8--15-threaded
  cnt=$(select_cohort "$cnt" "$tot" "$Log"  1  15    <"$ObjectList")  # 1 16-threaded
fi 2>&1

rm "$ObjectList"
