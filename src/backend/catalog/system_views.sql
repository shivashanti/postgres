/*
 * PostgreSQL System Views
 *
 * Copyright 1996-2003, PostgreSQL Global Development Group
 *
 * $Id: system_views.sql,v 1.2 2003/11/13 22:13:39 tgl Exp $
 */

CREATE VIEW pg_user AS 
    SELECT 
        usename, 
        usesysid, 
        usecreatedb, 
        usesuper, 
        usecatupd, 
        '********'::text as passwd, 
        valuntil, 
        useconfig 
    FROM pg_shadow;

CREATE VIEW pg_rules AS 
    SELECT 
        N.nspname AS schemaname, 
        C.relname AS tablename, 
        R.rulename AS rulename, 
        pg_get_ruledef(R.oid) AS definition 
    FROM (pg_rewrite R JOIN pg_class C ON (C.oid = R.ev_class)) 
        LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace) 
    WHERE R.rulename != '_RETURN';

CREATE VIEW pg_views AS 
    SELECT 
        N.nspname AS schemaname, 
        C.relname AS viewname, 
        pg_get_userbyid(C.relowner) AS viewowner, 
        pg_get_viewdef(C.oid) AS definition 
    FROM pg_class C LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace) 
    WHERE C.relkind = 'v';

CREATE VIEW pg_tables AS 
    SELECT 
        N.nspname AS schemaname, 
        C.relname AS tablename, 
        pg_get_userbyid(C.relowner) AS tableowner, 
        C.relhasindex AS hasindexes, 
        C.relhasrules AS hasrules, 
        (C.reltriggers > 0) AS hastriggers 
    FROM pg_class C LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace) 
    WHERE C.relkind = 'r';

CREATE VIEW pg_indexes AS 
    SELECT 
        N.nspname AS schemaname, 
        C.relname AS tablename, 
        I.relname AS indexname, 
        pg_get_indexdef(I.oid) AS indexdef 
    FROM pg_index X JOIN pg_class C ON (C.oid = X.indrelid) 
         JOIN pg_class I ON (I.oid = X.indexrelid) 
         LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace) 
    WHERE C.relkind = 'r' AND I.relkind = 'i';

CREATE VIEW pg_stats AS 
    SELECT 
        nspname AS schemaname, 
        relname AS tablename, 
        attname AS attname, 
        stanullfrac AS null_frac, 
        stawidth AS avg_width, 
        stadistinct AS n_distinct, 
        CASE 1 
            WHEN stakind1 THEN stavalues1 
            WHEN stakind2 THEN stavalues2 
            WHEN stakind3 THEN stavalues3 
            WHEN stakind4 THEN stavalues4 
        END AS most_common_vals, 
        CASE 1 
            WHEN stakind1 THEN stanumbers1 
            WHEN stakind2 THEN stanumbers2 
            WHEN stakind3 THEN stanumbers3 
            WHEN stakind4 THEN stanumbers4 
        END AS most_common_freqs, 
        CASE 2 
            WHEN stakind1 THEN stavalues1 
            WHEN stakind2 THEN stavalues2 
            WHEN stakind3 THEN stavalues3 
            WHEN stakind4 THEN stavalues4 
        END AS histogram_bounds, 
        CASE 3 
            WHEN stakind1 THEN stanumbers1[1] 
            WHEN stakind2 THEN stanumbers2[1] 
            WHEN stakind3 THEN stanumbers3[1] 
            WHEN stakind4 THEN stanumbers4[1] 
        END AS correlation 
    FROM pg_statistic s JOIN pg_class c ON (c.oid = s.starelid) 
         JOIN pg_attribute a ON (c.oid = attrelid AND attnum = s.staattnum) 
         LEFT JOIN pg_namespace n ON (n.oid = c.relnamespace) 
    WHERE has_table_privilege(c.oid, 'select');

REVOKE ALL on pg_statistic FROM public;

CREATE VIEW pg_stat_all_tables AS 
    SELECT 
            C.oid AS relid, 
            N.nspname AS schemaname, 
            C.relname AS relname, 
            pg_stat_get_numscans(C.oid) AS seq_scan, 
            pg_stat_get_tuples_returned(C.oid) AS seq_tup_read, 
            sum(pg_stat_get_numscans(I.indexrelid)) AS idx_scan, 
            sum(pg_stat_get_tuples_fetched(I.indexrelid)) AS idx_tup_fetch, 
            pg_stat_get_tuples_inserted(C.oid) AS n_tup_ins, 
            pg_stat_get_tuples_updated(C.oid) AS n_tup_upd, 
            pg_stat_get_tuples_deleted(C.oid) AS n_tup_del 
    FROM pg_class C LEFT JOIN 
         pg_index I ON C.oid = I.indrelid 
         LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace) 
    WHERE C.relkind = 'r' 
    GROUP BY C.oid, N.nspname, C.relname;

CREATE VIEW pg_stat_sys_tables AS 
    SELECT * FROM pg_stat_all_tables 
    WHERE schemaname IN ('pg_catalog', 'pg_toast');

CREATE VIEW pg_stat_user_tables AS 
    SELECT * FROM pg_stat_all_tables 
    WHERE schemaname NOT IN ('pg_catalog', 'pg_toast');

CREATE VIEW pg_statio_all_tables AS 
    SELECT 
            C.oid AS relid, 
            N.nspname AS schemaname, 
            C.relname AS relname, 
            pg_stat_get_blocks_fetched(C.oid) - 
                    pg_stat_get_blocks_hit(C.oid) AS heap_blks_read, 
            pg_stat_get_blocks_hit(C.oid) AS heap_blks_hit, 
            sum(pg_stat_get_blocks_fetched(I.indexrelid) - 
                    pg_stat_get_blocks_hit(I.indexrelid)) AS idx_blks_read, 
            sum(pg_stat_get_blocks_hit(I.indexrelid)) AS idx_blks_hit, 
            pg_stat_get_blocks_fetched(T.oid) - 
                    pg_stat_get_blocks_hit(T.oid) AS toast_blks_read, 
            pg_stat_get_blocks_hit(T.oid) AS toast_blks_hit, 
            pg_stat_get_blocks_fetched(X.oid) - 
                    pg_stat_get_blocks_hit(X.oid) AS tidx_blks_read, 
            pg_stat_get_blocks_hit(X.oid) AS tidx_blks_hit 
    FROM pg_class C LEFT JOIN 
            pg_index I ON C.oid = I.indrelid LEFT JOIN 
            pg_class T ON C.reltoastrelid = T.oid LEFT JOIN 
            pg_class X ON T.reltoastidxid = X.oid 
            LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace) 
    WHERE C.relkind = 'r' 
    GROUP BY C.oid, N.nspname, C.relname, T.oid, X.oid;

CREATE VIEW pg_statio_sys_tables AS 
    SELECT * FROM pg_statio_all_tables 
    WHERE schemaname IN ('pg_catalog', 'pg_toast');

CREATE VIEW pg_statio_user_tables AS 
    SELECT * FROM pg_statio_all_tables 
    WHERE schemaname NOT IN ('pg_catalog', 'pg_toast');

CREATE VIEW pg_stat_all_indexes AS 
    SELECT 
            C.oid AS relid, 
            I.oid AS indexrelid, 
            N.nspname AS schemaname, 
            C.relname AS relname, 
            I.relname AS indexrelname, 
            pg_stat_get_numscans(I.oid) AS idx_scan, 
            pg_stat_get_tuples_returned(I.oid) AS idx_tup_read, 
            pg_stat_get_tuples_fetched(I.oid) AS idx_tup_fetch 
    FROM pg_class C JOIN 
            pg_index X ON C.oid = X.indrelid JOIN 
            pg_class I ON I.oid = X.indexrelid 
            LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace) 
    WHERE C.relkind = 'r';

CREATE VIEW pg_stat_sys_indexes AS 
    SELECT * FROM pg_stat_all_indexes 
    WHERE schemaname IN ('pg_catalog', 'pg_toast');

CREATE VIEW pg_stat_user_indexes AS 
    SELECT * FROM pg_stat_all_indexes 
    WHERE schemaname NOT IN ('pg_catalog', 'pg_toast');

CREATE VIEW pg_statio_all_indexes AS 
    SELECT 
            C.oid AS relid, 
            I.oid AS indexrelid, 
            N.nspname AS schemaname, 
            C.relname AS relname, 
            I.relname AS indexrelname, 
            pg_stat_get_blocks_fetched(I.oid) - 
                    pg_stat_get_blocks_hit(I.oid) AS idx_blks_read, 
            pg_stat_get_blocks_hit(I.oid) AS idx_blks_hit 
    FROM pg_class C JOIN 
            pg_index X ON C.oid = X.indrelid JOIN 
            pg_class I ON I.oid = X.indexrelid 
            LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace) 
    WHERE C.relkind = 'r';

CREATE VIEW pg_statio_sys_indexes AS 
    SELECT * FROM pg_statio_all_indexes 
    WHERE schemaname IN ('pg_catalog', 'pg_toast');

CREATE VIEW pg_statio_user_indexes AS 
    SELECT * FROM pg_statio_all_indexes 
    WHERE schemaname NOT IN ('pg_catalog', 'pg_toast');

CREATE VIEW pg_statio_all_sequences AS 
    SELECT 
            C.oid AS relid, 
            N.nspname AS schemaname, 
            C.relname AS relname, 
            pg_stat_get_blocks_fetched(C.oid) - 
                    pg_stat_get_blocks_hit(C.oid) AS blks_read, 
            pg_stat_get_blocks_hit(C.oid) AS blks_hit 
    FROM pg_class C 
            LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace) 
    WHERE C.relkind = 'S';

CREATE VIEW pg_statio_sys_sequences AS 
    SELECT * FROM pg_statio_all_sequences 
    WHERE schemaname IN ('pg_catalog', 'pg_toast');

CREATE VIEW pg_statio_user_sequences AS 
    SELECT * FROM pg_statio_all_sequences 
    WHERE schemaname NOT IN ('pg_catalog', 'pg_toast');

CREATE VIEW pg_stat_activity AS 
    SELECT 
            D.oid AS datid, 
            D.datname AS datname, 
            pg_stat_get_backend_pid(S.backendid) AS procpid, 
            pg_stat_get_backend_userid(S.backendid) AS usesysid, 
            U.usename AS usename, 
            pg_stat_get_backend_activity(S.backendid) AS current_query, 
            pg_stat_get_backend_activity_start(S.backendid) AS query_start 
    FROM pg_database D, 
            (SELECT pg_stat_get_backend_idset() AS backendid) AS S, 
            pg_shadow U 
    WHERE pg_stat_get_backend_dbid(S.backendid) = D.oid AND 
            pg_stat_get_backend_userid(S.backendid) = U.usesysid;

CREATE VIEW pg_stat_database AS 
    SELECT 
            D.oid AS datid, 
            D.datname AS datname, 
            pg_stat_get_db_numbackends(D.oid) AS numbackends, 
            pg_stat_get_db_xact_commit(D.oid) AS xact_commit, 
            pg_stat_get_db_xact_rollback(D.oid) AS xact_rollback, 
            pg_stat_get_db_blocks_fetched(D.oid) - 
                    pg_stat_get_db_blocks_hit(D.oid) AS blks_read, 
            pg_stat_get_db_blocks_hit(D.oid) AS blks_hit 
    FROM pg_database D;

CREATE VIEW pg_locks AS 
    SELECT * 
    FROM pg_lock_status() AS L(relation oid, database oid, 
	transaction xid, pid int4, mode text, granted boolean);

CREATE VIEW pg_settings AS 
    SELECT * 
    FROM pg_show_all_settings() AS A 
    (name text, setting text, context text, vartype text, 
     source text, min_val text, max_val text);

CREATE RULE pg_settings_u AS 
    ON UPDATE TO pg_settings 
    WHERE new.name = old.name DO 
    SELECT set_config(old.name, new.setting, 'f');

CREATE RULE pg_settings_n AS 
    ON UPDATE TO pg_settings 
    DO INSTEAD NOTHING;
