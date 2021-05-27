-- This is a pure SQL version of
-- /var/lib/irods/scripts/irods/database_upgrade.py optimized for upgrading the
-- ICAT DB in the CyVerse iRODS 4.1.10 deployment to iRODS 4.2.8. The script can
-- can be found at
-- https://github.com/irods/irods/blob/4.2.8/scripts/irods/database_upgrade.py.

\timing on

-- Our database schema  version is 4, so the conversion steps for versions 2 - 4
-- can be mostly skipped. We are mssing a specific query that was supposed to be
-- added in version 3. The follow statement will add that query.

\echo adding missing the DataObjInCollReCur specific query.
INSERT INTO r_specific_query (alias, sqlStr, create_ts)
VALUES (
	'DataObjInCollReCur',
	'WITH coll AS (SELECT coll_id, coll_name FROM r_coll_main WHERE R_COLL_MAIN.coll_name = ? OR R_COLL_MAIN.coll_name LIKE ?) SELECT DISTINCT d.data_id, (SELECT coll_name FROM coll WHERE coll.coll_id = d.coll_id) coll_name, d.data_name, d.data_repl_num, d.resc_name, d.data_path, d.resc_hier FROM R_DATA_MAIN d WHERE d.coll_id = ANY(ARRAY(SELECT coll_id FROM coll)) ORDER BY coll_name, d.data_name, d.data_repl_num',
	-- XXX: create_ts should begin with 0 for consistency with its other values
	/*'1388534400'*/ '01388534400' );

\echo
\echo begin conversion to schema version 5

\echo adding resc_id column to r_data_main
-- This will hold the Id of the storage resource and act as a foreign key of
-- r_resc_main.resc_id.
ALTER TABLE r_data_main ADD resc_id BIGINT;

\echo adding resc_parent_context column to r_resc_main
ALTER TABLE r_resc_main ADD resc_parent_context VARCHAR(4000);

\echo changing definition of the DataObjInCollReCur specific query
-- It will use r_data_main.resc_id to identify the storage resource instead of
-- the defunct r_data_main.resc_hier column.
UPDATE r_specific_query
SET sqlstr =
	'WITH coll AS (SELECT coll_id, coll_name FROM R_COLL_MAIN WHERE R_COLL_MAIN.coll_name = ? OR R_COLL_MAIN.coll_name LIKE ?) SELECT DISTINCT d.data_id, (SELECT coll_name FROM coll WHERE coll.coll_id = d.coll_id) coll_name, d.data_name, d.data_repl_num, d.resc_name, d.data_path, d.resc_id FROM R_DATA_MAIN d WHERE d.coll_id = ANY(ARRAY(SELECT coll_id FROM coll)) ORDER BY coll_name, d.data_name, d.data_repl_num'
WHERE alias = 'DataObjInCollReCur';

\echo populating r_data_main.resc_id
-- For each entry in r_data_main set resc_id by using r_resc_hier to look up the
-- Id of the corresponding storage resource in r_resc_main. Here's a pseudocode
-- summary of the logic in database_upgrade.py.
--
--   for ($resc_id, $resc_name) in (SELECT resc_id, resc_name FROM r_resc_main):
--     UPDATE r_data_main
--     SET resc_id = $resc_id::BIGINT
--     WHERE resc_hier = $resc_name OR resc_hier LIKE '%;' || $resc_name;
--
-- Only storage resources will have Ids set in r_data_main. Since storage
-- resources have no child resources, `r_resc_main.resc_children = ''`. We don't
-- use the bundleResc resource, so we can exclude it. Also, all of our storage
-- resources have a parent resource, meaning its resource hierarchy value will
-- begin with the parent name followed by a semicolon (';') and end with the
-- storage resource name. This means we can exclude the condition
-- `resc_hier = $resc_name`. Here's a rewrite in SQL statement of the above
-- pseudocode with these simplification as a single SQL statement.
BEGIN;

CREATE TEMPORARY TABLE hierarchies(id, hier) ON COMMIT DROP AS
WITH RECURSIVE hier_steps AS (
	SELECT resc_id AS id, '' || resc_name AS hier, resc_parent AS parent
	FROM r_resc_main
	WHERE resc_children = ''
	UNION
	SELECT c.id, p.resc_name || ';' || c.hier, p.resc_parent
	FROM r_resc_main AS p JOIN hier_steps AS c ON c.parent = p.resc_name )
SELECT id, hier FROM hier_steps WHERE parent = '';

CREATE INDEX idx_hierarchies ON hierarchies(hier, id);

UPDATE r_data_main AS d
SET resc_id = r.id
FROM hierarchies AS r
WHERE d.resc_hier = r.hier AND r.hier != 'bundleResc';

COMMIT;

\echo repurposing r_resc_main.resc_parent as a foreign key to r_resc_main.resc_id
UPDATE r_resc_main AS rdm
SET resc_parent = am.resc_id
FROM (SELECT resc_name, resc_id FROM r_resc_main) AS am
WHERE am.resc_name = rdm.resc_parent;

\echo populatiing r_resc_main.resc_parent_context
-- For each child resource in r_resc_main, set the value of resc_parent_context
-- from its value in the parent resource's resc_children entry. Here's a
-- pseudocode summary of the logic in database_upgrade.py
--
--   for ($resc_id, $resc_children) in (
--     SELECT resc_id, resc_children FROM r_resc_main WHERE resc_children IS NOT NULL
--   ):
--     # resc_children has the form '[<resc-child>[;<resc-child>]*]' where
--     # <resc-child> has the form '<child-name>{[<parent-context>]}'. The
--     # following statement creates a <resc-child> list by splitting
--     # resc_children on ';'. It then tranforms this list into a list of
--     # <child-name>*<parent-context> tuples.
--     $child_contexts = [
--       (m.group(1), m.group(2)) for m in [
--         '^([^{}]*)\\{([^{}]*)\\}'.match(s) for s in $resc_children.split(';')
--       ] if m ]
--     for ($child_name, $context) in $child_contexts:
--       UPDATE r_resc_main SET resc_parent_context = $context WHERE resc_name = $child_name
--
-- iRODS sets r_resc_main.resc_children to an empty string ('') instead of NULL
-- when the resource has no chidren. Given this, here's a rewrite of the above
-- pseudocode as a single SQL statement.
UPDATE r_resc_main AS cr
SET resc_parent_context = pr.child_context[2]
FROM (
		SELECT
			resc_id,
			REGEXP_MATCH(REGEXP_SPLIT_TO_TABLE(resc_children, ';'), '^([^{}]*)\{([^{}]*)\}')
				AS child_context
		FROM r_resc_main
		WHERE resc_children != ''
	) AS pr
WHERE cr.resc_name = pr.child_context[1];

\echo completing conversion to schema version 5
UPDATE r_grid_configuration
SET option_value = 5
WHERE namespace = 'database' AND option_name = 'schema_version';

\echo
\echo converting to schema version 6

\echo creating index on r_data_main.resc_id
CREATE INDEX idx_data_main7 ON r_data_main (resc_id);

\echo creating index on r_data_main.data_is_dirty
CREATE INDEX idx_data_main8 ON r_data_main (data_is_dirty);

\echo completing conversion to schema version 6
UPDATE r_grid_configuration
SET option_value = 6
WHERE namespace = 'database' AND option_name = 'schema_version';

\echo
\echo converting to schema version 7

\echo ensuring all nonempty groups each consider themself as a member
-- For each group with an entry in r_user_group, ensure there is an entry
-- identifying the group as a member of itself. Here's a pseudocode summary of
-- the logic in database_upgrade.py
--
--   $current_ts = '0' + $POSIX_EPOCH
--   for ($group_id) in (
--     SELECT DISTINCT group_user_id
--     FROM r_user_group WHERE group_user_id NOT IN (
--       SELECT DISTINCT group_user_id FROM r_user_group WHERE group_user_id = user_id )
--   ):
--     INSERT INTO r_user_group VALUES ($group_id, $group_id, $current_ts, $current_ts)
--
-- Here's a rewrite as a singe SQL statement.
INSERT INTO r_user_group
SELECT DISTINCT
	group_user_id,
	group_user_id,
	'0' || DATE_PART('epoch', CURRENT_TIMESTAMP(0)),
	'0' || DATE_PART('epoch', CURRENT_TIMESTAMP(0))
FROM r_user_group
WHERE group_user_id NOT IN (
	SELECT DISTINCT group_user_id FROM r_user_group WHERE group_user_id = user_id );

\echo adding listGroupsForUser specific query.
INSERT INTO r_specific_query (alias, sqlStr, create_ts)
VALUES (
	'listGroupsForUser',
	'select group_user_id, user_name from R_USER_GROUP ug inner join R_USER_MAIN u on ug.group_user_id = u.user_id where user_type_name = ''rodsgroup'' and ug.user_id = (select user_id from R_USER_MAIN where user_name = ? and user_type_name != ''rodsgroup'')',
	-- XXX: create_ts should begin with 0 for consistency with its other values
	/*'1580297960'*/ '01580297960' );

\echo completing conversion to schema version 7
UPDATE r_grid_configuration
SET option_value = 7
WHERE namespace = 'database' AND option_name = 'schema_version';
