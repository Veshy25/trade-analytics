-- 00_create_staging_tables.sql
-- Raw staging tables for the three UN Comtrade pull tracks.
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
-- Load step
--
-- The three commands below load the committed CSVs into the tables created
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

-- Expected after loading: 3282 / 16976 / 18956 rows respectively.
SELECT 'raw A' AS table_name, COUNT(*) FROM raw_track_a_country_benchmark
UNION ALL SELECT 'raw B', COUNT(*) FROM raw_track_b_india_sector_detail
UNION ALL SELECT 'raw C', COUNT(*) FROM raw_track_c_india_partner_view;
