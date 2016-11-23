#! /bin/bash

if [ "$#" -ne 3 ]
then
  printf 'Wrong number of parameters\n' >&2
  exit 1
fi

readonly DBMS_HOST="$1"
readonly DBMS_PORT="$2"
readonly DB_USER="$3"

query() 
{
  psql --host "$DBMS_HOST" --port "$DBMS_PORT" ICAT "$DB_USER"   
}


query <<SQL
  CREATE TEMPORARY TABLE resc_summary (resc_hier, volume) AS 
    SELECT resc_hier, SUM(data_size) FROM r_data_main GROUP BY resc_hier;

  SELECT resc_hier                                       AS "Resource", 
         CAST(volume / 1000000000000.0 AS NUMERIC(8, 3)) AS "Data Volume (TB)" 
    FROM resc_summary 
    ORDER BY resc_hier;

  SELECT CAST(SUM(volume) / 1000000000000.0 AS NUMERIC(8, 3)) AS "Total Data Volume (TB)" 
    FROM resc_summary;
SQL
