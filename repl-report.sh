#! /bin/bash

readonly ExecName=$(basename $0)
readonly DefaultHost=localhost
readonly DefaultPort=5432

set -e


print_help()
{
cat <<EOF
Usage:
 $ExecName [options]

Generates a report on the data objects that need to be replicated. It lists the 
number of unreplicated data objects and their volume broken down by the storage 
resource holding the corresponding files.

Options:
 -H, --host <host>  connect to the ICAT's DBMS on the host <host>, default 
                    '$DefaultHost'
 -p, --port <port>  connect to the ICAT's DBMS listening on TCP port <port>, 
                    default '$DefaultPort'

 -h, --help  display help text and exit
EOF
}
 
 
if ! opts=$(getopt --name "$ExecName" --options hH:p: --longoptions help,host:,port: -- "$@")
then
  printf '\n' >&2
  print_help >&2
  exit 1
fi

eval set -- "$opts"

host="$DefaultHost"
port="$DefaultPort"

while true
do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    -H|--host)
      host="$2"
      shift 2
      ;;
    -p|--port)
      port="$2"
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


psql --host "$host" --port "$port" ICAT icat_reader <<SQL
SELECT resc_name AS resource, COUNT(*) AS count, SUM(data_size) / 1024 ^ 4 AS "volume (TiB)"
  FROM r_data_main
  WHERE data_id = ANY(ARRAY(SELECT data_id FROM r_data_main GROUP BY data_id HAVING COUNT(*) = 1))
    AND NOT (data_repl_num = 0 AND resc_name = 'cshlWildcatRes')
    AND coll_id IN (
        SELECT coll_id FROM r_coll_main WHERE coll_name NOT LIKE '/iplant/home/shared/aegis%')
  GROUP BY resc_name
  ORDER BY resc_name
SQL
