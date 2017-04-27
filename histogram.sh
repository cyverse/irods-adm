#! /bin/bash

set -e 

readonly ExecName=$(basename $0)
readonly SizeQuery="$*"

readonly HIST_WID=60


print_help()
{
  cat <<EOF
Usage:
 $ExecName <size_query>

Generates a histogram of the results of the SQL query, <size_query>. The query 
should return a single column of sizes in bytes. The generated histogram will be 
base-2 logarithmically binned.
EOF
}


if [ -z "$SizeQuery" ]
then
  print_help >&2
  exit 1
fi

psql --host irods-db3 ICAT icat_reader <<EOF
WITH 
  units(unit, lb, ub) AS (
          SELECT '  B', 0,      2 ^ 10 
    UNION SELECT 'kiB', 2 ^ 10, 2 ^ 20 
    UNION SELECT 'MiB', 2 ^ 20, 2 ^ 30 
    UNION SELECT 'GiB', 2 ^ 30, 2 ^ 40
    UNION SELECT 'TiB', 2 ^ 40, 2 ^ 50
    UNION SELECT 'PiB', 2 ^ 50, 2 ^ 60
    UNION SELECT 'EiB', 2 ^ 60, NULL  ), -- BIGINT DOESN'T SUPPORT LARGER than 2 ^ 62.
  data(val) AS ($SizeQuery),
  log_bounds(lb, ub) AS (
    SELECT
        CASE 
          WHEN COUNT(*) = 0 THEN NULL 
          ELSE CAST(LEAST(FLOOR(LOG(2, GREATEST(MIN(val), 1))), 62) AS INT) 
        END,
        CASE 
          WHEN COUNT(*) = 0 THEN NULL 
          ELSE CAST(LEAST(CEIL(LOG(2, MAX(val) + 1)), 62) AS INT) 
        END 
      FROM data),  
  log_seq(el) AS (SELECT GENERATE_SERIES(lb, ub) FROM log_bounds),
  bins(lb, ub) AS (
    SELECT 0, 2 ^ MIN(el) FROM log_seq
    UNION SELECT 
        2 ^ el, 
        CASE WHEN el < (SELECT MAX(el) FROM log_seq) THEN 2 ^ (el + 1) ELSE NULL END 
      FROM log_seq),
  binned_data(lb, ub, cnt) AS (
    SELECT b.lb, b.ub, COUNT(d.*) 
      FROM bins AS b 
        LEFT JOIN data AS d ON d.val BETWEEN b.lb AND b.ub - 1 OR (d.val >= b.lb AND b.ub IS NULL) 
      GROUP BY b.lb, b.ub) 
SELECT
    CASE
      WHEN b.lb = 0 AND b.ub IS NULL THEN u.unit || ' [0, ∞)'
      WHEN b.lb = 0 
        THEN (
          SELECT unit || ' [0, ' || b.ub / GREATEST(lb, 1) || ')'  
            FROM units 
            WHERE b.ub BETWEEN lb AND ub - 1)
      WHEN b.lb = (SELECT MAX(lb) FROM bins) 
        THEN u.unit || ' [' || b.lb / GREATEST(u.lb, 1) || ', ∞)'
      ELSE u.unit || ' [' || b.lb / GREATEST(u.lb, 1) || ', ' || b.ub / GREATEST(u.lb, 1) || ')'
    END AS "Range",
    b.cnt AS "Count", 
    CASE 
      WHEN b.cnt = 0 THEN '' 
      ELSE 
        REPEAT('*', 
               CAST(CAST($HIST_WID AS REAL) * b.cnt 
                      / (SELECT GREATEST(MAX(cnt), $HIST_WID) FROM binned_data) 
                    AS INT)) 
    END AS "Histogram" 
  FROM binned_data AS b
    JOIN units AS u ON b.lb BETWEEN u.lb AND u.ub - 1 OR (b.lb >= u.lb AND u.ub IS NULL)
  ORDER BY b.lb;
EOF
