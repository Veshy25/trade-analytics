-- 01_data_cleaning.sql
-- Casts the raw (all-TEXT) staging tables into typed, analysis-ready tables.
--
-- Columns dropped here (present in raw_* but not carried forward). The rule:
-- a column in a clean table needs a query that reads it.
--   - Quantity/weight fields on the HS2 tracks (A, C, E1, E2): Comtrade does
--     not aggregate mixed units to chapter level, so these carry no usable
--     magnitude. netWgt is BLANK on 48.3-50.5% of HS2 rows and qty on 21-30%,
--     and every remaining value is exactly 0 — there is not a single positive
--     qty or netWgt on any HS2 track. Track A alone keeps net_wgt and its
--     estimate flag, so that 02 S2 and V1a can show exactly that.
--   - On Track B (HS6, India -> World) netWgt IS populated (~90% positive)
--     and is carried forward as net_wgt (kg) with is_net_wgt_estimated, for
--     the volume analysis in 03 Q6-Q8, and is_qty_estimated for 02 S1. qty
--     and its unit are dropped: quantity mixes units (u, m2, carat, kWh) and
--     is never summed. The alt-qty and grossWgt fields are dropped too.
--   - On Track D (HS6 by partner) every quantity and weight field is dropped:
--     volume is analysed on Track B only, and 06 reads value alone.
--   - legacy_estimation_flag is kept on Tracks A and B, where 02 V1a and S1
--     read it, and dropped on C, D, E1 and E2, where nothing does.
--   - Constant-across-the-pull fields: flowCode/flowDesc (constant within
--     each track: X on A-D, M on E1/E2),
--     typeCode/freqCode (commodity/annual only), customsCode/customsDesc,
--     mosCode, motCode/motDesc,
--     partner2Code/partner2Iso/partner2Desc (not split out), refPeriodId,
--     refMonth, period (redundant with refYear), isOriginalClassification.
--   - classificationCode is NOT constant. It records the HS edition the reporter filed
--     under and moves with the calendar: H4 through 2016, H5 from 2017, H6
--     from 2022 — and it varies by REPORTER as well as by year, since Viet
--     Nam filed 2017 under H4 while the other three had moved to H5. That
--     makes it the key to the description rewordings documented in 02
--     assumption 7, so it is carried forward on Track B (where the HS6
--     rewording analysis lives) as classification_code and checked in
--     validation query 7. It stays dropped on the tracks that never group
--     on cmd_desc.
--   - is_leaf and partner_iso: read by no query in 02-08; partner_desc and
--     cmd_code carry the same information in the form the analysis uses.
--   - cifValue on the EXPORT tracks: 873 of 3282 Track A raw rows carry a
--     non-blank cifValue, and all 873 hold exactly 0. Dropped: exports are
--     valued FOB, and validation query 3 asserts primary_value equals
--     fob_value in every row, so cifValue is never the field the analysis
--     reads from.
--   - fobValue on the IMPORT tracks (E1, E2): the mirror case. fobvalue is
--     blank on 73.5% of E1 rows and 69.6% of E2 rows; the remainder hold
--     exactly 0. No import row carries a positive fobvalue, so cif_value is
--     kept instead. Validation query 5 asserts primary_value = cif_value.
--     Any trade-balance figure in 07 is therefore FOB exports minus CIF
--     imports — the standard published construction, stated there.
--
-- DROP ... CASCADE: 02-07 define the exported result sets as views over these
-- tables, so a plain DROP TABLE would refuse to run on a database that has
-- been built before. CASCADE drops those views with the tables; re-running
-- 02-07 recreates them. Nothing else depends on clean_*.

-- ============================================================
-- Track A: country benchmark (India/China/Bangladesh/Vietnam, HS2)
-- ============================================================
DROP TABLE IF EXISTS clean_track_a_country_benchmark CASCADE;
CREATE TABLE clean_track_a_country_benchmark AS
SELECT
    refyear::int                               AS ref_year,
    reportercode::int                          AS reporter_code,
    reporteriso                                AS reporter_iso,
    reporterdesc                               AS reporter_desc,
    partnercode::int                           AS partner_code,
    partnerdesc                                AS partner_desc,
    cmdcode                                    AS cmd_code,
    cmddesc                                    AS cmd_desc,
    aggrlevel::smallint                        AS aggr_level,
    NULLIF(fobvalue, '')::numeric              AS fob_value,
    NULLIF(primaryvalue, '')::numeric          AS primary_value,
    NULLIF(legacyestimationflag, '')::smallint AS legacy_estimation_flag,
    -- net_wgt is kept only so 02 S2 can show it holds no weight at HS2:
    -- blank stays NULL and '0' stays 0, which is the distinction S2 counts.
    NULLIF(netwgt, '')::numeric                AS net_wgt,
    isnetwgtestimated::boolean                 AS is_net_wgt_estimated,
    isreported::boolean                        AS is_reported,
    isaggregate::boolean                       AS is_aggregate
FROM raw_track_a_country_benchmark;

-- Uniqueness is the real double-counting guard, not the aggr_level filter
-- applied in 02/03/04: if the same country-year-chapter ever arrived as both
-- a reported and an aggregate line, both would be level 2 and both would be
-- summed. Declaring these UNIQUE makes a bad re-pull fail loudly at load
-- instead of silently inflating every total. Verified at build time: 0
-- duplicate groups in all six tracks.
CREATE UNIQUE INDEX idx_clean_a_year_reporter_cmd
    ON clean_track_a_country_benchmark (ref_year, reporter_code, cmd_code);

-- ============================================================
-- Track B: India sector detail (HS6, 5 sectors)
-- ============================================================
DROP TABLE IF EXISTS clean_track_b_india_sector_detail CASCADE;
CREATE TABLE clean_track_b_india_sector_detail AS
SELECT
    refyear::int                               AS ref_year,
    reportercode::int                          AS reporter_code,
    reporteriso                                AS reporter_iso,
    reporterdesc                               AS reporter_desc,
    partnercode::int                           AS partner_code,
    partnerdesc                                AS partner_desc,
    cmdcode                                    AS cmd_code,
    cmddesc                                    AS cmd_desc,
    aggrlevel::smallint                        AS aggr_level,
    NULLIF(fobvalue, '')::numeric              AS fob_value,
    NULLIF(primaryvalue, '')::numeric          AS primary_value,
    NULLIF(legacyestimationflag, '')::smallint AS legacy_estimation_flag,
    isreported::boolean                        AS is_reported,
    isaggregate::boolean                       AS is_aggregate,
    classificationcode                         AS classification_code,
    sector                                     AS sector,
    -- Volume: net_wgt in kg is the one measure that can be summed within a
    -- sector. qty is in mixed units (u, m2, carat, kWh) and is not carried.
    NULLIF(netwgt, '')::numeric                AS net_wgt,
    isnetwgtestimated::boolean                 AS is_net_wgt_estimated,
    isqtyestimated::boolean                    AS is_qty_estimated    -- for 02 S1
FROM raw_track_b_india_sector_detail;

-- Note on this key: `sector` is derived from the HS2 prefix of `cmd_code`,
-- so it is functionally dependent on cmd_code and adds nothing to uniqueness
-- — this is effectively (ref_year, cmd_code), which holds only because
-- Track B is India -> World only. The partner split anticipated in 03
-- assumption 3 now exists as Track D, which is why Track D's key below
-- includes partner_code and this one does not.
CREATE UNIQUE INDEX idx_clean_b_year_sector_cmd
    ON clean_track_b_india_sector_detail (ref_year, sector, cmd_code);

-- ============================================================
-- Track C: India partner-market view (HS2, ~20 partners)
-- ============================================================
DROP TABLE IF EXISTS clean_track_c_india_partner_view CASCADE;
CREATE TABLE clean_track_c_india_partner_view AS
SELECT
    refyear::int                               AS ref_year,
    reportercode::int                          AS reporter_code,
    reporteriso                                AS reporter_iso,
    reporterdesc                               AS reporter_desc,
    partnercode::int                           AS partner_code,
    partnerdesc                                AS partner_desc,
    cmdcode                                    AS cmd_code,
    cmddesc                                    AS cmd_desc,
    aggrlevel::smallint                        AS aggr_level,
    NULLIF(fobvalue, '')::numeric              AS fob_value,
    NULLIF(primaryvalue, '')::numeric          AS primary_value,
    isreported::boolean                        AS is_reported,
    isaggregate::boolean                       AS is_aggregate
FROM raw_track_c_india_partner_view;

CREATE UNIQUE INDEX idx_clean_c_year_partner_cmd
    ON clean_track_c_india_partner_view (ref_year, partner_code, cmd_code);

-- ============================================================
-- Track D: India partner x sector (HS6, 20 partners, 5 sectors) — Phase 2
-- Value columns only (volume is analysed on Track B), plus a partner in the key.
-- ============================================================
DROP TABLE IF EXISTS clean_track_d_india_partner_sector CASCADE;
CREATE TABLE clean_track_d_india_partner_sector AS
SELECT
    refyear::int                               AS ref_year,
    reportercode::int                          AS reporter_code,
    reporteriso                                AS reporter_iso,
    reporterdesc                               AS reporter_desc,
    partnercode::int                           AS partner_code,
    partnerdesc                                AS partner_desc,
    cmdcode                                    AS cmd_code,
    cmddesc                                    AS cmd_desc,
    aggrlevel::smallint                        AS aggr_level,
    NULLIF(fobvalue, '')::numeric              AS fob_value,
    NULLIF(primaryvalue, '')::numeric          AS primary_value,
    isreported::boolean                        AS is_reported,
    isaggregate::boolean                       AS is_aggregate,
    sector                                     AS sector
FROM raw_track_d_india_partner_sector;

CREATE UNIQUE INDEX idx_clean_d_year_partner_cmd
    ON clean_track_d_india_partner_sector (ref_year, partner_code, cmd_code);

-- ============================================================
-- Track E1: country imports (India/China/Bangladesh/Vietnam, HS2) — Phase 2
-- Mirror of Track A with cif_value in place of fob_value (imports are CIF).
-- ============================================================
DROP TABLE IF EXISTS clean_track_e_country_imports CASCADE;
CREATE TABLE clean_track_e_country_imports AS
SELECT
    refyear::int                               AS ref_year,
    reportercode::int                          AS reporter_code,
    reporteriso                                AS reporter_iso,
    reporterdesc                               AS reporter_desc,
    partnercode::int                           AS partner_code,
    partnerdesc                                AS partner_desc,
    cmdcode                                    AS cmd_code,
    cmddesc                                    AS cmd_desc,
    aggrlevel::smallint                        AS aggr_level,
    NULLIF(cifvalue, '')::numeric              AS cif_value,
    NULLIF(primaryvalue, '')::numeric          AS primary_value,
    isreported::boolean                        AS is_reported,
    isaggregate::boolean                       AS is_aggregate
FROM raw_track_e_country_imports;

CREATE UNIQUE INDEX idx_clean_e1_year_reporter_cmd
    ON clean_track_e_country_imports (ref_year, reporter_code, cmd_code);

-- ============================================================
-- Track E2: India partner imports (HS2, 20 partners) — Phase 2
-- Mirror of Track C with cif_value in place of fob_value.
-- ============================================================
DROP TABLE IF EXISTS clean_track_e_india_partner_imports CASCADE;
CREATE TABLE clean_track_e_india_partner_imports AS
SELECT
    refyear::int                               AS ref_year,
    reportercode::int                          AS reporter_code,
    reporteriso                                AS reporter_iso,
    reporterdesc                               AS reporter_desc,
    partnercode::int                           AS partner_code,
    partnerdesc                                AS partner_desc,
    cmdcode                                    AS cmd_code,
    cmddesc                                    AS cmd_desc,
    aggrlevel::smallint                        AS aggr_level,
    NULLIF(cifvalue, '')::numeric              AS cif_value,
    NULLIF(primaryvalue, '')::numeric          AS primary_value,
    isreported::boolean                        AS is_reported,
    isaggregate::boolean                       AS is_aggregate
FROM raw_track_e_india_partner_imports;

CREATE UNIQUE INDEX idx_clean_e2_year_partner_cmd
    ON clean_track_e_india_partner_imports (ref_year, partner_code, cmd_code);

-- ============================================================
-- Validation — run after the above completes
-- ============================================================

-- 1. Row counts must match the raw staging tables exactly.
--    These are ASSERTIONS, not prints: a truncated or duplicated raw file
--    would otherwise load, clean and run through every downstream track
--    without an error, quietly changing every total. The expected counts
--    live in the VALUES list below, in one place, and a mismatch aborts the
--    script here.
DO $$
DECLARE
    r record;
    n bigint;
BEGIN
    FOR r IN
        SELECT * FROM (VALUES
            ('clean_track_a_country_benchmark',      3282),
            ('clean_track_b_india_sector_detail',   16976),
            ('clean_track_c_india_partner_view',    18956),
            ('clean_track_d_india_partner_sector', 225298),
            ('clean_track_e_country_imports',        3294),
            ('clean_track_e_india_partner_imports', 16946)
        ) AS t(table_name, expected_rows)
    LOOP
        EXECUTE format('SELECT COUNT(*) FROM %I', r.table_name) INTO n;
        IF n <> r.expected_rows THEN
            RAISE EXCEPTION
                '01 validation 1: % holds % rows, expected % — the raw load is incomplete, duplicated or from a different pull',
                r.table_name, n, r.expected_rows;
        END IF;
    END LOOP;
    RAISE NOTICE '01 validation 1 PASSED: all six clean tables match their expected row counts.';
END $$;

-- The same counts as a printed table, for the reader who wants to see them
-- rather than just be told nothing raised.
SELECT 'A clean' AS table_name, COUNT(*) FROM clean_track_a_country_benchmark
UNION ALL
SELECT 'B clean', COUNT(*) FROM clean_track_b_india_sector_detail
UNION ALL
SELECT 'C clean', COUNT(*) FROM clean_track_c_india_partner_view
UNION ALL
SELECT 'D clean', COUNT(*) FROM clean_track_d_india_partner_sector
UNION ALL
SELECT 'E1 clean', COUNT(*) FROM clean_track_e_country_imports
UNION ALL
SELECT 'E2 clean', COUNT(*) FROM clean_track_e_india_partner_imports;

-- 2. cifValue is NOT always blank in this exports-only pull — expect 873
--    non-blank, not 0. But note what those 873 rows actually hold: every one
--    of them is exactly 0, not a real CIF figure. It doesn't affect analysis, since query 3 below asserts that
--    primary_value (what clean_* carries forward) equals fob_value in every
--    row. Expect non_blank_cif_rows = 873, positive_cif_rows = 0.
SELECT
    COUNT(*) FILTER (WHERE NULLIF(cifvalue, '') IS NOT NULL)          AS non_blank_cif_rows,
    COUNT(*) FILTER (WHERE NULLIF(cifvalue, '')::numeric > 0)         AS positive_cif_rows
FROM raw_track_a_country_benchmark;

-- 3. For exports, primary_value must equal fob_value on every row — this is
--    what makes it safe to drop cifValue. Asserted, not just printed, on all
--    four export tracks.
DO $$
DECLARE n_a bigint; n_b bigint; n_c bigint; n_d bigint;
BEGIN
    SELECT COUNT(*) INTO n_a FROM clean_track_a_country_benchmark   WHERE primary_value IS DISTINCT FROM fob_value;
    SELECT COUNT(*) INTO n_b FROM clean_track_b_india_sector_detail WHERE primary_value IS DISTINCT FROM fob_value;
    SELECT COUNT(*) INTO n_c FROM clean_track_c_india_partner_view  WHERE primary_value IS DISTINCT FROM fob_value;
    SELECT COUNT(*) INTO n_d FROM clean_track_d_india_partner_sector WHERE primary_value IS DISTINCT FROM fob_value;
    IF n_a + n_b + n_c + n_d <> 0 THEN
        RAISE EXCEPTION '01 validation 3: primary_value <> fob_value on A:% B:% C:% D:% rows', n_a, n_b, n_c, n_d;
    END IF;
    RAISE NOTICE '01 validation 3 PASSED: primary_value = fob_value on all Track A, B, C and D rows.';
END $$;

SELECT 'A' AS track, COUNT(*) AS mismatches FROM clean_track_a_country_benchmark   WHERE primary_value IS DISTINCT FROM fob_value
UNION ALL
SELECT 'B', COUNT(*) FROM clean_track_b_india_sector_detail WHERE primary_value IS DISTINCT FROM fob_value
UNION ALL
SELECT 'C', COUNT(*) FROM clean_track_c_india_partner_view  WHERE primary_value IS DISTINCT FROM fob_value
UNION ALL
SELECT 'D', COUNT(*) FROM clean_track_d_india_partner_sector WHERE primary_value IS DISTINCT FROM fob_value;

-- ---- Phase 2 tracks ----

-- 4. Volume coverage on the HS6 tracks: share of rows with a populated
--    net weight. Expect ~0.90 on both B and D. This is the number that
--    decides whether a volume claim in 03 Q6-Q8 can be made at all. Track D
--    is read from its raw table, since its weight is not carried forward.
SELECT 'B' AS track,
       ROUND(AVG((net_wgt IS NOT NULL AND net_wgt > 0)::int), 3) AS net_wgt_coverage
FROM clean_track_b_india_sector_detail
UNION ALL
SELECT 'D',
       ROUND(AVG((COALESCE(NULLIF(netwgt, '')::numeric, 0) > 0)::int), 3)
FROM raw_track_d_india_partner_sector;

-- 5. On the import tracks primary_value must equal cif_value in every row
--    (the mirror of query 3). Expect 0 / 0. Asserted as well as printed.
DO $$
DECLARE n bigint;
BEGIN
    SELECT (SELECT COUNT(*) FROM clean_track_e_country_imports
            WHERE primary_value IS DISTINCT FROM cif_value)
         + (SELECT COUNT(*) FROM clean_track_e_india_partner_imports
            WHERE primary_value IS DISTINCT FROM cif_value)
      INTO n;
    IF n <> 0 THEN
        RAISE EXCEPTION '01 validation 5: % import rows have primary_value <> cif_value', n;
    END IF;
    RAISE NOTICE '01 validation 5 PASSED: primary_value = cif_value on all E1/E2 rows.';
END $$;

SELECT 'E1' AS track, COUNT(*) AS mismatches
FROM clean_track_e_country_imports
WHERE primary_value IS DISTINCT FROM cif_value
UNION ALL
SELECT 'E2', COUNT(*)
FROM clean_track_e_india_partner_imports
WHERE primary_value IS DISTINCT FROM cif_value;

-- 6. The partner panel: Tracks C, D and E2 must carry no World row and the
--    same 20 partners. Asserted: every share-of-panel figure in 04, 06 and
--    07 assumes this identity.
DO $$
DECLARE world_rows bigint; n_c int; n_d int; n_e2 int; only_in_one bigint;
BEGIN
    SELECT (SELECT COUNT(*) FROM clean_track_c_india_partner_view    WHERE partner_code = 0)
         + (SELECT COUNT(*) FROM clean_track_d_india_partner_sector  WHERE partner_code = 0)
         + (SELECT COUNT(*) FROM clean_track_e_india_partner_imports WHERE partner_code = 0)
      INTO world_rows;
    SELECT COUNT(DISTINCT partner_code) INTO n_c  FROM clean_track_c_india_partner_view;
    SELECT COUNT(DISTINCT partner_code) INTO n_d  FROM clean_track_d_india_partner_sector;
    SELECT COUNT(DISTINCT partner_code) INTO n_e2 FROM clean_track_e_india_partner_imports;
    SELECT COUNT(*) INTO only_in_one FROM (
        (SELECT partner_code FROM clean_track_d_india_partner_sector
         EXCEPT SELECT partner_code FROM clean_track_c_india_partner_view)
        UNION ALL
        (SELECT partner_code FROM clean_track_c_india_partner_view
         EXCEPT SELECT partner_code FROM clean_track_d_india_partner_sector)
        UNION ALL
        (SELECT partner_code FROM clean_track_e_india_partner_imports
         EXCEPT SELECT partner_code FROM clean_track_c_india_partner_view)
        UNION ALL
        (SELECT partner_code FROM clean_track_c_india_partner_view
         EXCEPT SELECT partner_code FROM clean_track_e_india_partner_imports)
    ) x;
    IF world_rows <> 0 OR n_c <> 20 OR n_d <> 20 OR n_e2 <> 20 OR only_in_one <> 0 THEN
        RAISE EXCEPTION '01 validation 6: world_rows=% partners C/D/E2=%/%/% only_in_one=%',
            world_rows, n_c, n_d, n_e2, only_in_one;
    END IF;
    RAISE NOTICE '01 validation 6 PASSED: C, D and E2 share one 20-partner panel with no World row.';
END $$;

-- Note on the parentheses above. EXCEPT and UNION ALL
-- have equal precedence in SQL and associate left to right, so the
-- unparenthesised form
--     A EXCEPT B UNION ALL C EXCEPT D
-- evaluates as ((A EXCEPT B) UNION ALL C) EXCEPT D, which collapses to
-- C EXCEPT D — a one-directional test that silently drops the D-not-in-C
-- half. On identical panels both forms return 0, so only the parenthesised
-- one would catch a divergence, which is the case the check exists for.

-- 7. HS edition map. classification_code is the edition key behind the
--    description rewordings that 02 assumption 7 documents, so Track B
--    carries it and this is where the boundaries are made visible.
--    Expect: H4 for 2014-2016, H5 for 2017-2021, H6 for 2022-2023, one
--    edition per year on Track B (India only). The Track A panel is NOT
--    one-per-year — Viet Nam filed 2017 under H4 while India, China and
--    Bangladesh had moved to H5 — which is why the second query splits by
--    reporter. Any future pull that breaks the "one edition per Track B
--    year" pattern invalidates the grouping fix in 02 Q3 and 03 Q4.
SELECT ref_year,
       STRING_AGG(DISTINCT classification_code, ',' ORDER BY classification_code) AS editions,
       COUNT(DISTINCT classification_code)                                        AS n_editions
FROM clean_track_b_india_sector_detail
GROUP BY ref_year
ORDER BY ref_year;

SELECT reporterdesc AS reporter_desc,
       refyear::int AS ref_year,
       STRING_AGG(DISTINCT classificationcode, ',' ORDER BY classificationcode) AS editions
FROM raw_track_a_country_benchmark
GROUP BY reporterdesc, refyear::int
HAVING COUNT(DISTINCT classificationcode) > 1
    OR refyear::int = 2017
ORDER BY reporter_desc, ref_year;

-- 8. No zero or blank values on Track D. The sector x
--    partner heatmap (scripts/make_chart.py, chart 3) reads "a row exists" as
--    "there was trade", which holds only while no Track D row has a zero or
--    blank value. Asserted rather than assumed, so a re-pull that breaks it
--    stops here instead of mislabelling a cell.
DO $$
DECLARE n bigint;
BEGIN
    SELECT COUNT(*) INTO n
    FROM clean_track_d_india_partner_sector
    WHERE fob_value IS NULL OR fob_value = 0;
    IF n > 0 THEN
        RAISE EXCEPTION '01 validation 8: % Track D rows have a zero or blank value', n;
    END IF;
    RAISE NOTICE '01 validation 8 PASSED: no zero or blank values on Track D.';
END $$;

-- 9. One name per code. The views in 02, 04, 06 and 07 group on reporter_desc
--    and partner_desc, so a country renamed between years would split into
--    two rows — the failure 02 assumption 7 describes for HS descriptions.
DO $$
DECLARE n bigint;
BEGIN
    SELECT COUNT(*) INTO n FROM (
        SELECT reporter_code FROM clean_track_a_country_benchmark
         GROUP BY reporter_code HAVING COUNT(DISTINCT reporter_desc) > 1
        UNION ALL
        SELECT reporter_code FROM clean_track_e_country_imports
         GROUP BY reporter_code HAVING COUNT(DISTINCT reporter_desc) > 1
        UNION ALL
        SELECT partner_code FROM clean_track_c_india_partner_view
         GROUP BY partner_code HAVING COUNT(DISTINCT partner_desc) > 1
        UNION ALL
        SELECT partner_code FROM clean_track_d_india_partner_sector
         GROUP BY partner_code HAVING COUNT(DISTINCT partner_desc) > 1
        UNION ALL
        SELECT partner_code FROM clean_track_e_india_partner_imports
         GROUP BY partner_code HAVING COUNT(DISTINCT partner_desc) > 1
    ) x;
    IF n > 0 THEN
        RAISE EXCEPTION '01 validation 9: % reporter or partner codes carry more than one name', n;
    END IF;
    RAISE NOTICE '01 validation 9 PASSED: every reporter and partner code carries one name.';
END $$;
