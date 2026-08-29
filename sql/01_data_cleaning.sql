-- 01_data_cleaning.sql
-- Casts the raw (all-TEXT) staging tables into typed, analysis-ready tables.
--
-- Columns dropped here (present in raw_* but not carried forward):
--   - Quantity/weight fields (qty, netWgt, grossWgt + their estimate flags,
--     alt-qty fields): this project analyses trade VALUE, not volume.
--   - Constant-across-the-pull fields: flowCode/flowDesc (exports only),
--     typeCode/freqCode (commodity/annual only), classificationCode (HS
--     only), customsCode/customsDesc, mosCode, motCode/motDesc,
--     partner2Code/partner2Iso/partner2Desc (not split out), refPeriodId,
--     refMonth, period (redundant with refYear), isOriginalClassification.
--   - cifValue: always null/0 for an exports-only pull (exports are valued
--     FOB, not CIF) — dropped after confirming that below, not assumed.
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

CREATE INDEX idx_clean_a_year_reporter_cmd
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
    sector                                     AS sector
FROM raw_track_b_india_sector_detail;

CREATE INDEX idx_clean_b_year_sector_cmd
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

CREATE INDEX idx_clean_c_year_partner_cmd
    ON clean_track_c_india_partner_view (ref_year, partner_code, cmd_code);

-- ============================================================
-- Validation — run after the above completes
-- ============================================================

-- 1. Row counts must match the raw staging tables exactly (3282 / 16976 / 18956)
SELECT 'A clean' AS table_name, COUNT(*) FROM clean_track_a_country_benchmark
UNION ALL
SELECT 'B clean', COUNT(*) FROM clean_track_b_india_sector_detail
UNION ALL
SELECT 'C clean', COUNT(*) FROM clean_track_c_india_partner_view;

-- 2. Confirm cifValue really was always empty for this exports-only pull
--    (justifies dropping it above rather than just assuming it)
SELECT COUNT(*) AS non_blank_cif_rows
FROM raw_track_a_country_benchmark
WHERE NULLIF(cifvalue, '') IS NOT NULL;

-- 3. Spot check: for exports, primary_value should equal fob_value
--    (per the script's own data-dictionary note) — this should return 0
SELECT COUNT(*) AS mismatches
FROM clean_track_a_country_benchmark
WHERE primary_value IS DISTINCT FROM fob_value;
