#!/bin/bash
#
# This script extracts how much storage the projects have used each year between
# 2010 and 2019, inclusive. When a file exists for only part of the year, its
# size is scaled by the fraction of the year it existed.

set -o errexit -o nounset -o pipefail

export PGHOST
export PGUSER


main()
{
  if [[ "$#" -lt 3 ]]
  then
    printf 'Usage: project-storage-report ICAT_DBMS ICAT_USER ZONE\n' >&2
    return 1
  fi

  PGHOST="$1"
  PGUSER="$2"

  local zone="$3"

  report "$zone"
}


report()
{
  local zone="$1"

  psql ICAT <<SQL
\\timing on

BEGIN;

CREATE TEMPORARY TABLE data(project, create_ts, file_size, create_year_begin_ts, create_year_end_ts)
  ON COMMIT DROP AS
  SELECT
    SUBSTRING(c.coll_name FROM '/$zone/home/shared/#"[^/]+#"%' FOR '#'),
    d.create_ts :: BIGINT,
    d.data_size / 1000000000.0,
    DATE_PART('epoch', DATE_TRUNC('year', TO_TIMESTAMP(d.create_ts :: BIGINT))),
    DATE_PART('epoch', DATE_TRUNC('year', TO_TIMESTAMP(d.create_ts :: BIGINT)) + INTERVAL '1 year')
  FROM r_coll_main AS c JOIN r_data_main AS d ON d.coll_id = c.coll_id
  WHERE c.coll_name LIKE '/$zone/home/shared/%'
    AND d.resc_name = 'CyVerseRes'
    AND d.create_ts < '0' || DATE_PART('epoch', DATE_TRUNC('year', NOW()));

CREATE TEMPORARY TABLE data_exist(project, create_year, file_size, exist_frac) ON COMMIT DROP AS
  SELECT
    project,
    DATE_PART('year', TO_TIMESTAMP(create_ts)),
    file_size,
    (create_year_end_ts - create_ts) / (create_year_end_ts - create_year_begin_ts)
  FROM data;
CREATE INDEX data_exist_idx ON data_exist(project, create_year);

CREATE TEMPORARY TABLE volume(project, year, avg_vol, end_vol) ON COMMIT DROP AS
  SELECT project, create_year, SUM(file_size * exist_frac) :: NUMERIC, SUM(file_size) :: NUMERIC
  FROM data_exist
  GROUP BY project, create_year;
CREATE INDEX volume_idx ON volume(project, year);

CREATE TEMPORARY TABLE years(year INT) ON COMMIT DROP;
INSERT INTO years
  VALUES (2010), (2011), (2012), (2013), (2014), (2015), (2016), (2017), (2018), (2019);
CREATE INDEX years_idx ON years(year);

SELECT
  v1.project                                                                      AS "Project",
  y.year                                                                         AS "Year",
  ROUND(SUM(CASE WHEN v1.year = y.year THEN v1.avg_vol ELSE v1.end_vol END), 3)  AS "Volume (GB)"
FROM years AS y JOIN volume v1 ON v1.year <= y.year
GROUP BY v1.project, y.year
ORDER BY v1.project, y.year;

ROLLBACK;
SQL
}


main "$@"
