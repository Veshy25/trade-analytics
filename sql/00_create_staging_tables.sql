-- 00_create_staging_tables.sql
-- Raw staging tables for the UN Comtrade pull tracks — three from the
-- 25/08/2026 pull (A, B, C) and three from the 15/09/2026 pull (D, E1, E2).
-- Every CSV under data/raw/ is loaded here, before any analysis file runs.
-- Every column is TEXT on purpose: this is a raw landing zone, not the
-- analysis-ready schema. Casting to proper types (int, numeric, boolean,
-- date) and cleaning belongs in 01_data_cleaning.sql, not here.
--
-- Column order below matches the CSV header order exactly — pgAdmin's
-- Import/Export Data tool loads positionally, so this order must not change
-- unless the CSV column order also changes.

DROP TABLE IF EXISTS raw_track_a_country_benchmark;
CREATE TABLE raw_track_a_country_benchmark (
    typecode                text,
    freqcode                text,
    refperiodid             text,
    refyear                 text,
    refmonth                text,
    period                  text,
    reportercode            text,
    reporteriso             text,
    reporterdesc            text,
    flowcode                text,
    flowdesc                text,
    partnercode             text,
    partneriso              text,
    partnerdesc             text,
    partner2code            text,
    partner2iso             text,
    partner2desc            text,
    classificationcode      text,
    classificationsearchcode text,
    isoriginalclassification text,
    cmdcode                 text,
    cmddesc                 text,
    aggrlevel               text,
    isleaf                  text,
    customscode             text,
    customsdesc             text,
    moscode                 text,
    motcode                 text,
    motdesc                 text,
    qtyunitcode             text,
    qtyunitabbr             text,
    qty                     text,
    isqtyestimated          text,
    altqtyunitcode          text,
    altqtyunitabbr          text,
    altqty                  text,
    isaltqtyestimated       text,
    netwgt                  text,
    isnetwgtestimated       text,
    grosswgt                text,
    isgrosswgtestimated     text,
    cifvalue                text,
    fobvalue                text,
    primaryvalue            text,
    legacyestimationflag    text,
    isreported              text,
    isaggregate             text
);

DROP TABLE IF EXISTS raw_track_b_india_sector_detail;
CREATE TABLE raw_track_b_india_sector_detail (
    typecode                text,
    freqcode                text,
    refperiodid             text,
    refyear                 text,
    refmonth                text,
    period                  text,
    reportercode            text,
    reporteriso             text,
    reporterdesc            text,
    flowcode                text,
    flowdesc                text,
    partnercode             text,
    partneriso              text,
    partnerdesc             text,
    partner2code            text,
    partner2iso             text,
    partner2desc            text,
    classificationcode      text,
    classificationsearchcode text,
    isoriginalclassification text,
    cmdcode                 text,
    cmddesc                 text,
    aggrlevel               text,
    isleaf                  text,
    customscode             text,
    customsdesc             text,
    moscode                 text,
    motcode                 text,
    motdesc                 text,
    qtyunitcode             text,
    qtyunitabbr             text,
    qty                     text,
    isqtyestimated          text,
    altqtyunitcode          text,
    altqtyunitabbr          text,
    altqty                  text,
    isaltqtyestimated       text,
    netwgt                  text,
    isnetwgtestimated       text,
    grosswgt                text,
    isgrosswgtestimated     text,
    cifvalue                text,
    fobvalue                text,
    primaryvalue            text,
    legacyestimationflag    text,
    isreported              text,
    isaggregate             text,
    sector                  text
);

DROP TABLE IF EXISTS raw_track_c_india_partner_view;
CREATE TABLE raw_track_c_india_partner_view (
    typecode                text,
    freqcode                text,
    refperiodid             text,
    refyear                 text,
    refmonth                text,
    period                  text,
    reportercode            text,
    reporteriso             text,
    reporterdesc            text,
    flowcode                text,
    flowdesc                text,
    partnercode             text,
    partneriso              text,
    partnerdesc             text,
    partner2code            text,
    partner2iso             text,
    partner2desc            text,
    classificationcode      text,
    classificationsearchcode text,
    isoriginalclassification text,
    cmdcode                 text,
    cmddesc                 text,
    aggrlevel               text,
    isleaf                  text,
    customscode             text,
    customsdesc             text,
    moscode                 text,
    motcode                 text,
    motdesc                 text,
    qtyunitcode             text,
    qtyunitabbr             text,
    qty                     text,
    isqtyestimated          text,
    altqtyunitcode          text,
    altqtyunitabbr          text,
    altqty                  text,
    isaltqtyestimated       text,
    netwgt                  text,
    isnetwgtestimated       text,
    grosswgt                text,
    isgrosswgtestimated     text,
    cifvalue                text,
    fobvalue                text,
    primaryvalue            text,
    legacyestimationflag    text,
    isreported              text,
    isaggregate             text
);


-- ============================================================
-- Phase 2 tracks (pulled 15/09/2026). Each new CSV has a header that is
-- byte-identical to the Phase 1 track it mirrors — verified before these
-- tables were written — so LIKE is used to guarantee the same columns in
-- the same order, which is what positional \copy depends on. A new column
-- in one of the mirrored tables above would propagate here automatically;
-- a change to a Phase 2 CSV's header would not, and would need a fresh
-- explicit definition.
-- ============================================================

-- Track D — India -> 20 partners, HS6, 5 sectors (mirrors Track B's 48
-- columns incl. the derived `sector`). Delivered as TWO CSVs split by year
-- range because the single file exceeded 50 MB; both load into this one
-- table.
DROP TABLE IF EXISTS raw_track_d_india_partner_sector;
CREATE TABLE raw_track_d_india_partner_sector
    (LIKE raw_track_b_india_sector_detail);

-- Track E1 — the 4 Track A reporters, imports (flow=M), HS2, World
-- (mirrors Track A's 47 columns).
DROP TABLE IF EXISTS raw_track_e_country_imports;
CREATE TABLE raw_track_e_country_imports
    (LIKE raw_track_a_country_benchmark);

-- Track E2 — India's imports (flow=M) from the 20 partners, HS2
-- (mirrors Track C's 47 columns).
DROP TABLE IF EXISTS raw_track_e_india_partner_imports;
CREATE TABLE raw_track_e_india_partner_imports
    (LIKE raw_track_c_india_partner_view);

-- ============================================================
-- Load step
--
-- The commands below load every committed CSV into the tables created
-- above. Run this file from the repository root, because the paths are
-- relative to the working directory psql was started in, not to this file.
--
--   psql -d trade_analytics -v ON_ERROR_STOP=1 -f sql/00_create_staging_tables.sql
--
-- \copy (not COPY) is deliberate: \copy is a psql client command that reads
-- the file from the machine running psql, so it needs no server-side file
-- permissions and works against a remote database unchanged.
--
-- Column order matters. \copy with HEADER true skips the header row but does
-- NOT match on header names — it assigns columns positionally, so the raw_*
-- table definitions above must stay in the exact order the CSVs are
-- written in. Reordering a column in one place and not the other loads silently
-- and wrongly.
--
-- pgAdmin's Import/Export Data tool does the same thing through the GUI and
-- is equally positional; either route is fine.
-- ============================================================

\copy raw_track_a_country_benchmark FROM 'data/raw/track_a_country_benchmark_hs2.csv' WITH (FORMAT csv, HEADER true)
\copy raw_track_b_india_sector_detail FROM 'data/raw/track_b_india_sector_detail_hs6.csv' WITH (FORMAT csv, HEADER true)
\copy raw_track_c_india_partner_view FROM 'data/raw/track_c_india_partner_view_hs2.csv' WITH (FORMAT csv, HEADER true)

-- Phase 2 (15/09/2026 pull). Track D is two files into one table.
\copy raw_track_d_india_partner_sector FROM 'data/raw/track_d_india_partner_sector_hs6_2014_2018.csv' WITH (FORMAT csv, HEADER true)
\copy raw_track_d_india_partner_sector FROM 'data/raw/track_d_india_partner_sector_hs6_2019_2023.csv' WITH (FORMAT csv, HEADER true)
\copy raw_track_e_country_imports FROM 'data/raw/track_e_country_imports_hs2.csv' WITH (FORMAT csv, HEADER true)
\copy raw_track_e_india_partner_imports FROM 'data/raw/track_e_india_partner_imports_hs2.csv' WITH (FORMAT csv, HEADER true)

-- Expected after loading:
--   A 3282 / B 16976 / C 18956            (Phase 1)
--   D 225298 (110211 + 115087) / E1 3294 / E2 16946   (Phase 2)
SELECT 'raw A' AS table_name, COUNT(*) FROM raw_track_a_country_benchmark
UNION ALL SELECT 'raw B', COUNT(*) FROM raw_track_b_india_sector_detail
UNION ALL SELECT 'raw C', COUNT(*) FROM raw_track_c_india_partner_view
UNION ALL SELECT 'raw D', COUNT(*) FROM raw_track_d_india_partner_sector
UNION ALL SELECT 'raw E1', COUNT(*) FROM raw_track_e_country_imports
UNION ALL SELECT 'raw E2', COUNT(*) FROM raw_track_e_india_partner_imports;
