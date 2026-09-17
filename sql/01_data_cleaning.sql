-- 01_data_cleaning.sql
-- Casts the raw (all-TEXT) staging tables into typed, analysis-ready tables.
--
-- Columns dropped here (present in raw_* but not carried forward):
--   - Quantity/weight fields on the HS2 tracks (A, C, E1, E2): Comtrade does
--     not aggregate mixed units to chapter level, so these carry no usable
--     magnitude. Be precise about the shape of that emptiness, because an
--     earlier version of this note overstated it: netWgt is BLANK on 48-50%
--     of HS2 rows and qty on 21-30%, and every remaining value is exactly 0
--     — there is not a single positive qty or netWgt on any HS2 track. So
--     the analytical conclusion (nothing to sum) holds, but "blank on 100%
--     of those rows" was wrong and is corrected here. On the HS6 tracks
--     (B, D) netWgt IS populated (~90% positive) and is carried forward as
--     net_wgt (kg) plus its estimate flag, together with qty and its unit
--     for per-product reference — qty is never summed, since it mixes units
--     (u, m2, carat, kWh). The alt-qty and grossWgt fields are dropped on
--     every track. Added 15/09/2026 for the Phase 2 volume analysis
--     (03 Q6-Q8); before that the project carried value only.
--   - Constant-across-the-pull fields: flowCode/flowDesc (constant within
--     each track: X on A-D, M on E1/E2),
--     typeCode/freqCode (commodity/annual only), customsCode/customsDesc,
--     mosCode, motCode/motDesc,
--     partner2Code/partner2Iso/partner2Desc (not split out), refPeriodId,
--     refMonth, period (redundant with refYear), isOriginalClassification.
--   - classificationCode is NOT constant and was wrongly listed above as
--     such until 17/09/2026. It records the HS edition the reporter filed
--     under and moves with the calendar: H4 through 2016, H5 from 2017, H6
--     from 2022 — and it varies by REPORTER as well as by year, since Viet
--     Nam filed 2017 under H4 while the other three had moved to H5. That
--     makes it the key to the description rewordings documented in 02
--     assumption 7, so it is carried forward on Track B (where the HS6
--     rewording analysis lives) as classification_code and checked in
--     validation query 7. It stays dropped on the tracks that never group
--     on cmd_desc.
--   - is_leaf and partner_iso: dropped 17/09/2026. Neither was read by any
--     query in 02-08; partner_desc and cmd_code carry the same information
--     in the form the analysis actually uses. Carrying a column no query
--     reads is dead weight in a published schema.
--   - cifValue on the EXPORT tracks: 873 of 3282 Track A raw rows carry a
--     non-blank cifValue, and all 873 hold exactly 0 — "populated" was the
--     wrong word for this and is corrected here. Dropped either way:
--     exports are valued FOB, and validation query 3 asserts primary_value
--     equals fob_value in every row, so cifValue is never the field the
--     analysis reads from.
--   - fobValue on the IMPORT tracks (E1, E2): the mirror case, and the same
--     correction. fobvalue is blank on 73.5% of E1 rows and 69.6% of E2
--     rows, never on 100%; the remainder hold exactly 0. No import row
--     carries a positive fobvalue, so cif_value is kept instead. Validation
--     query 5 asserts primary_value = cif_value. Any trade-balance figure
--     in 07 is therefore FOB exports minus CIF imports — the standard
--     published construction, stated there.
--
-- Run the validation block at the end after each CREATE TABLE to confirm
-- row counts match the raw staging tables and no values were silently
-- dropped by a bad cast.

-- ============================================================
-- Track A: country benchmark (India/China/Bangladesh/Vietnam, HS2)
-- ============================================================
DROP TABLE IF EXISTS clean_track_a_country_benchmark;
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
    isnetwgtestimated::boolean                 AS is_net_wgt_estimated,
    isreported::boolean                        AS is_reported,
    isaggregate::boolean                       AS is_aggregate
FROM raw_track_a_country_benchmark;

-- Uniqueness is the real double-counting guard, not the aggr_level filter
-- applied in 02/03/04: if the same country-year-chapter ever arrived as both
-- a reported and an aggregate line, both would be level 2 and both would be
-- summed. Declaring these UNIQUE makes a bad re-pull fail loudly at load
-- instead of silently inflating every total. Verified at build time: 0
-- duplicate groups in all six tracks (this note said "three" until
-- 17/09/2026, from before Tracks D, E1 and E2 existed).
CREATE UNIQUE INDEX idx_clean_a_year_reporter_cmd
    ON clean_track_a_country_benchmark (ref_year, reporter_code, cmd_code);

-- ============================================================
-- Track B: India sector detail (HS6, 5 sectors)
-- ============================================================
DROP TABLE IF EXISTS clean_track_b_india_sector_detail;
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
    -- Volume (added 15/09/2026): net_wgt in kg is the one measure that can be
    -- summed within a sector; qty is in mixed units (u, m2, carat, kWh) and
    -- is kept only for per-product reference, never summed.
    NULLIF(netwgt, '')::numeric                AS net_wgt,
    isnetwgtestimated::boolean                 AS is_net_wgt_estimated,
    NULLIF(qty, '')::numeric                   AS qty,
    NULLIF(qtyunitabbr, '')                    AS qty_unit
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
DROP TABLE IF EXISTS clean_track_c_india_partner_view;
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
    NULLIF(legacyestimationflag, '')::smallint AS legacy_estimation_flag,
    isreported::boolean                        AS is_reported,
    isaggregate::boolean                       AS is_aggregate
FROM raw_track_c_india_partner_view;

CREATE UNIQUE INDEX idx_clean_c_year_partner_cmd
    ON clean_track_c_india_partner_view (ref_year, partner_code, cmd_code);

-- ============================================================
-- Track D: India partner x sector (HS6, 20 partners, 5 sectors) — Phase 2
-- Same column set as Track B, including volume, plus a partner in the key.
-- ============================================================
DROP TABLE IF EXISTS clean_track_d_india_partner_sector;
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
    NULLIF(legacyestimationflag, '')::smallint AS legacy_estimation_flag,
    isreported::boolean                        AS is_reported,
    isaggregate::boolean                       AS is_aggregate,
    sector                                     AS sector,
    NULLIF(netwgt, '')::numeric                AS net_wgt,
    isnetwgtestimated::boolean                 AS is_net_wgt_estimated,
    NULLIF(qty, '')::numeric                   AS qty,
    NULLIF(qtyunitabbr, '')                    AS qty_unit
FROM raw_track_d_india_partner_sector;

CREATE UNIQUE INDEX idx_clean_d_year_partner_cmd
    ON clean_track_d_india_partner_sector (ref_year, partner_code, cmd_code);

-- ============================================================
-- Track E1: country imports (India/China/Bangladesh/Vietnam, HS2) — Phase 2
-- Mirror of Track A with cif_value in place of fob_value (imports are CIF).
-- ============================================================
DROP TABLE IF EXISTS clean_track_e_country_imports;
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
    NULLIF(legacyestimationflag, '')::smallint AS legacy_estimation_flag,
    isreported::boolean                        AS is_reported,
    isaggregate::boolean                       AS is_aggregate
FROM raw_track_e_country_imports;

CREATE UNIQUE INDEX idx_clean_e1_year_reporter_cmd
    ON clean_track_e_country_imports (ref_year, reporter_code, cmd_code);

-- ============================================================
-- Track E2: India partner imports (HS2, 20 partners) — Phase 2
-- Mirror of Track C with cif_value in place of fob_value.
-- ============================================================
DROP TABLE IF EXISTS clean_track_e_india_partner_imports;
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
    NULLIF(legacyestimationflag, '')::smallint AS legacy_estimation_flag,
    isreported::boolean                        AS is_reported,
    isaggregate::boolean                       AS is_aggregate
FROM raw_track_e_india_partner_imports;

CREATE UNIQUE INDEX idx_clean_e2_year_partner_cmd
    ON clean_track_e_india_partner_imports (ref_year, partner_code, cmd_code);

-- ============================================================
-- Validation — run after the above completes
-- ============================================================

-- 1. Row counts must match the raw staging tables exactly.
--    These are ASSERTIONS, not prints. Until 17/09/2026 this block was a
--    plain SELECT and the data dictionary nevertheless claimed a mismatch
--    would "fail loudly" — it would not have: a truncated raw file loaded,
--    cleaned and ran through every downstream track without a single error,
--    quietly changing every total. The expected counts live in the VALUES
--    list below, in one place, and a mismatch now aborts the script here.
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
--    of them is exactly 0, not a real CIF figure. Earlier wording called them
--    "populated", which implied a value worth carrying; corrected 17/09/2026.
--    Either way it doesn't affect analysis, since query 3 below asserts that
--    primary_value (what clean_* carries forward) equals fob_value in every
--    row. Expect non_blank_cif_rows = 873, positive_cif_rows = 0.
SELECT
    COUNT(*) FILTER (WHERE NULLIF(cifvalue, '') IS NOT NULL)          AS non_blank_cif_rows,
    COUNT(*) FILTER (WHERE NULLIF(cifvalue, '')::numeric > 0)         AS positive_cif_rows
FROM raw_track_a_country_benchmark;

-- 3. For exports, primary_value must equal fob_value on every row — this is
--    what makes it safe to drop cifValue. Asserted, not just printed.
DO $$
DECLARE n bigint;
BEGIN
    SELECT COUNT(*) INTO n
    FROM clean_track_a_country_benchmark
    WHERE primary_value IS DISTINCT FROM fob_value;
    IF n <> 0 THEN
        RAISE EXCEPTION '01 validation 3: % Track A rows have primary_value <> fob_value', n;
    END IF;
    RAISE NOTICE '01 validation 3 PASSED: primary_value = fob_value on all Track A rows.';
END $$;

SELECT COUNT(*) AS mismatches
FROM clean_track_a_country_benchmark
WHERE primary_value IS DISTINCT FROM fob_value;

-- ---- Phase 2 additions (15/09/2026) ----

-- 4. Volume coverage on the HS6 tracks: share of rows with a populated
--    net_wgt. Expect ~0.90 on both B and D. This is the number that decides
--    whether a volume claim in 03 Q6-Q8 can be made at all.
SELECT 'B' AS track,
       ROUND(AVG((net_wgt IS NOT NULL AND net_wgt > 0)::int), 3) AS net_wgt_coverage
FROM clean_track_b_india_sector_detail
UNION ALL
SELECT 'D',
       ROUND(AVG((net_wgt IS NOT NULL AND net_wgt > 0)::int), 3)
FROM clean_track_d_india_partner_sector;

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

-- 6. Track D must have no World row and exactly the Track C partner panel.
--    Expect world_rows = 0, partners_d = 20, partners_only_in_one = 0.
SELECT
    (SELECT COUNT(*) FROM clean_track_d_india_partner_sector WHERE partner_code = 0) AS world_rows,
    (SELECT COUNT(DISTINCT partner_code) FROM clean_track_d_india_partner_sector)     AS partners_d,
    (SELECT COUNT(*) FROM (
        (SELECT partner_code FROM clean_track_d_india_partner_sector
         EXCEPT
         SELECT partner_code FROM clean_track_c_india_partner_view)
        UNION ALL
        (SELECT partner_code FROM clean_track_c_india_partner_view
         EXCEPT
         SELECT partner_code FROM clean_track_d_india_partner_sector)
    ) x) AS partners_only_in_one;

-- Note on the parentheses above (added 17/09/2026). EXCEPT and UNION ALL
-- have equal precedence in SQL and associate left to right, so the
-- unparenthesised form
--     A EXCEPT B UNION ALL C EXCEPT D
-- evaluates as ((A EXCEPT B) UNION ALL C) EXCEPT D, which collapses to
-- C EXCEPT D — a one-directional test that silently drops the D-not-in-C
-- half the comment promised. It returned 0 anyway on this data because the
-- two panels are identical, so the bug was invisible; it would not have been
-- once they diverged, which is the only case the check exists for.

-- 7. HS edition map (added 17/09/2026, F-2). classification_code was listed
--    as a constant and dropped until this date; it is the edition key behind
--    the description rewordings that 02 assumption 7 documents, so Track B
--    now carries it and this is where the boundaries are made visible.
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
