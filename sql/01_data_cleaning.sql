-- 01_data_cleaning.sql
-- Casts the raw (all-TEXT) staging tables into typed, analysis-ready tables.
--
-- Columns dropped here (present in raw_* but not carried forward):
--   - Quantity/weight fields on the HS2 tracks (A, C, E1, E2): Comtrade does
--     not aggregate mixed units to chapter level, so qty/netWgt are blank on
--     100% of those rows — there is nothing to keep. On the HS6 tracks (B, D)
--     netWgt is ~90% populated and IS carried forward, as net_wgt (kg) plus
--     its estimate flag, together with qty and its unit for reference. The
--     alt-qty and grossWgt fields are dropped on every track. Added
--     15/09/2026 for the Phase 2 volume analysis (03 Q6-Q8); before that the
--     project carried value only.
--   - Constant-across-the-pull fields: flowCode/flowDesc (constant within
--     each track: X on A-D, M on E1/E2),
--     typeCode/freqCode (commodity/annual only), classificationCode (HS
--     only), customsCode/customsDesc, mosCode, motCode/motDesc,
--     partner2Code/partner2Iso/partner2Desc (not split out), refPeriodId,
--     refMonth, period (redundant with refYear), isOriginalClassification.
--   - cifValue on the EXPORT tracks: dropped even though not always blank
--     (873 of 3282 Track A raw rows carry a populated cifValue — see
--     validation query 2). Still safe to drop: exports are valued FOB, not
--     CIF, and validation query 3 confirms primary_value equals fob_value in
--     every row, so cifValue is never the field analysis actually reads from.
--   - fobValue on the IMPORT tracks (E1, E2): the mirror case. Imports are
--     valued CIF; fobvalue is blank on 100% of import rows and cif_value is
--     kept instead. Validation query 5 confirms primary_value = cif_value.
--     Any trade-balance figure in 07 is therefore FOB exports minus CIF
--     imports — the standard published construction, stated there.
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
    partneriso                                 AS partner_iso,
    partnerdesc                                AS partner_desc,
    cmdcode                                    AS cmd_code,
    cmddesc                                    AS cmd_desc,
    aggrlevel::smallint                        AS aggr_level,
    isleaf::boolean                            AS is_leaf,
    NULLIF(fobvalue, '')::numeric              AS fob_value,
    NULLIF(primaryvalue, '')::numeric          AS primary_value,
    NULLIF(legacyestimationflag, '')::smallint AS legacy_estimation_flag,
    isreported::boolean                        AS is_reported,
    isaggregate::boolean                       AS is_aggregate
FROM raw_track_a_country_benchmark;

-- Uniqueness is the real double-counting guard, not the aggr_level filter
-- applied in 02/03/04: if the same country-year-chapter ever arrived as both
-- a reported and an aggregate line, both would be level 2 and both would be
-- summed. Declaring these UNIQUE makes a bad re-pull fail loudly at load
-- instead of silently inflating every total. Verified at build time: 0
-- duplicate groups in all three tracks.
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
    partneriso                                 AS partner_iso,
    partnerdesc                                AS partner_desc,
    cmdcode                                    AS cmd_code,
    cmddesc                                    AS cmd_desc,
    aggrlevel::smallint                        AS aggr_level,
    isleaf::boolean                            AS is_leaf,
    NULLIF(fobvalue, '')::numeric              AS fob_value,
    NULLIF(primaryvalue, '')::numeric          AS primary_value,
    NULLIF(legacyestimationflag, '')::smallint AS legacy_estimation_flag,
    isreported::boolean                        AS is_reported,
    isaggregate::boolean                       AS is_aggregate,
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
    partneriso                                 AS partner_iso,
    partnerdesc                                AS partner_desc,
    cmdcode                                    AS cmd_code,
    cmddesc                                    AS cmd_desc,
    aggrlevel::smallint                        AS aggr_level,
    isleaf::boolean                            AS is_leaf,
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
    partneriso                                 AS partner_iso,
    partnerdesc                                AS partner_desc,
    cmdcode                                    AS cmd_code,
    cmddesc                                    AS cmd_desc,
    aggrlevel::smallint                        AS aggr_level,
    isleaf::boolean                            AS is_leaf,
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
    partneriso                                 AS partner_iso,
    partnerdesc                                AS partner_desc,
    cmdcode                                    AS cmd_code,
    cmddesc                                    AS cmd_desc,
    aggrlevel::smallint                        AS aggr_level,
    isleaf::boolean                            AS is_leaf,
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
    partneriso                                 AS partner_iso,
    partnerdesc                                AS partner_desc,
    cmdcode                                    AS cmd_code,
    cmddesc                                    AS cmd_desc,
    aggrlevel::smallint                        AS aggr_level,
    isleaf::boolean                            AS is_leaf,
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

-- 1. Row counts must match the raw staging tables exactly
--    (A 3282 / B 16976 / C 18956 / D 225298 / E1 3294 / E2 16946)
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

-- 2. cifValue is NOT always blank in this exports-only pull — expect 873,
--    not 0. That's fine: it doesn't affect analysis, since query 3 below
--    confirms primary_value (what clean_* actually carries forward) equals
--    fob_value in every row regardless of what's in cifValue.
SELECT COUNT(*) AS non_blank_cif_rows
FROM raw_track_a_country_benchmark
WHERE NULLIF(cifvalue, '') IS NOT NULL;

-- 3. Spot check: for exports, primary_value should equal fob_value
--    (per the script's own data-dictionary note) — this should return 0
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
--    (the mirror of query 3). Expect 0 / 0.
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
        SELECT partner_code FROM clean_track_d_india_partner_sector
        EXCEPT SELECT partner_code FROM clean_track_c_india_partner_view
        UNION ALL
        SELECT partner_code FROM clean_track_c_india_partner_view
        EXCEPT SELECT partner_code FROM clean_track_d_india_partner_sector
    ) x) AS partners_only_in_one;
