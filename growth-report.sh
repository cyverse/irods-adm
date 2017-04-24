#! /bin/bash

set -e

readonly DEFAULT_HOST=localhost
readonly DEFAULT_PORT=5432

readonly ExecName=$(basename $0)


print_help()
{
  cat << EOF
Usage:
 $ExecName [options]

Generates a report showing how the data store has grown each month. For each
month, it displays the total number of data objects first created in that month
and the total volume of data contained in those files. Only data objects that
still exist in the data store are counted, i.e., if a data object where added
and then removed from the data store, it would not be counted. The report is 
written to stdout in CSV format.

Options:
 -f, --first-year <first_year>  the first year in the report
 -H, --host <host>              connect to the ICAT's DBMS on the host <host>, 
                                default '$DEFAULT_HOST'
 -l, --last-year  <last_year>   the last year in the report
 -p, --port <port>              connect to the ICAT's DBMS listening on TCP port
                                <port>, default '$DEFAULT_PORT'

 -h, --help  display help text and exit
EOF
}


readonly Opts=$(getopt --name "$ExecName" \
                       --options f:hH:l:p: \
                       --longoptions first-year:,help,host:,last-year:,port: \
                       -- \
                       "$@")

if [ "$?" -ne 0 ]
then
  printf '\n' >&2
  print_help >&2
  exit 1
fi

eval set -- "$Opts"

while true
do
  case "$1" in
    -f|--first-year)
      readonly FirstDay="$2"-1-1
      shift 2
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    -H|--host)
      readonly Host="$2"
      shift 2
      ;;
    -l|--last-year)
      readonly LastDay="$2"-12-31
      shift 2
      ;;
    -p|--port)
      readonly Port="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      printf '\n' >&2
      print_help >&2
      exit 1
      ;;
  esac
done

if [ -z "$Host" ]
then
  readonly Host="$DEFAULT_HOST"
fi

if [ -z "$Port" ]
then
  readonly Port="$DEFAULT_PORT"
fi

if [ -n "$FirstDay" -a -n "$LastDay" ]
then
  readonly CreateFilter="create_month BETWEEN TIMESTAMP '$FirstDay' AND TIMESTAMP '$LastDay'"
elif [ -n "$FirstDay" ]
then
  readonly CreateFilter="create_month >= TIMESTAMP '$FirstDay'"
elif [ -n "$LastDay" ]
then
  readonly CreateFilter="create_month <= TIMESTAMP '$LastDay'"
else
  readonly CreateFilter=TRUE
fi

psql --no-align --tuples-only --field-separator , --host "$Host" --port "$Port" ICAT icat_reader \
<< SQL
SELECT SUBSTRING(CAST(d.create_month AS TEXT) FROM 1 FOR 7), COUNT(*), CAST(SUM(d.size) AS BIGINT)
  FROM (
      SELECT 
          DATE_TRUNC('month', TO_TIMESTAMP(MIN(CAST(create_ts AS INTEGER))))  AS create_month, 
          AVG(data_size)                                                      AS size 
        FROM r_data_main 
        GROUP BY data_id
     ) AS d
  WHERE ($CreateFilter)
  GROUP BY d.create_month
  ORDER BY d.create_month
SQL
