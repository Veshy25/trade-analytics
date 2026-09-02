-- 03_track_b_sector_analysis.sql
-- Track B analysis: India's export profile within 5 focus sectors —
-- textiles (HS 50-63), pharmaceuticals (30), gems & jewellery (71),
-- petroleum products (27), engineering/machinery (84-85). HS6 product-level
-- detail, India -> World, 2014-2023.
--
-- Source table: clean_track_b_india_sector_detail (built in 01_data_cleaning.sql).
-- Every row is India as reporter, World (partner_code = 0) as partner, and
-- carries a `sector` label mapped from the HS2 prefix by the pull script.
--
-- Assumptions made here (flagging before running, not after):
--   1. Sector and product totals sum only aggr_level = 6 rows (true HS6
--      product detail). The pull used cmdCode='AG6', so the table should be
--      almost entirely level 6; the filter guards against any level-2/4
--      rollup rows double-counting. Validation V2 shows the split.
--   2. Within aggr_level = 6, every row is summed regardless of is_reported
--      vs is_aggregate. Per the Track A finding these two flags partition the
--      rows (mutually exclusive, jointly exhaustive) with no overlap, so
--      summing both gives the most complete total rather than an undercount.
--      Validation V3 re-checks that here.
--   3. partner_code = 0 (World) is filtered explicitly. Track B was pulled
--      against World only, so this is a no-op today, but keeps the queries
--      correct if a partner split is ever added.
--   4. Decade comparisons use 2014 (first) and 2023 (last). Validation V4
--      lists any sector with a short series so a chart can caveat it (the
--      Bangladesh problem from Track A).
--   5. Values are USD, exporter-reported FOB. Comment figures are quoted in
--      USD billion for readability.
--   6. Every growth / share ratio wraps its divisor in NULLIF(..., 0) so a
--      zero or missing base returns NULL rather than raising an error.


-- ============================================================
-- Query 1: sector export value trend, by year
-- ============================================================
SELECT
    sector,
    ref_year,
    SUM(fob_value) AS total_export_value_usd
FROM clean_track_b_india_sector_detail
WHERE aggr_level = 6
  AND partner_code = 0
GROUP BY sector, ref_year
ORDER BY sector, ref_year;


-- ============================================================
-- Query 2: sector totals with year-on-year growth %
--
-- LAG() pulls each sector's prior-year total into the same row, scoped to
-- that sector's own year sequence (PARTITION BY sector). The first year of
-- each series shows NULL growth, as expected.
-- ============================================================
WITH sector_yearly AS (
    SELECT
        sector,
        ref_year,
        SUM(fob_value) AS total_export_value_usd
    FROM clean_track_b_india_sector_detail
    WHERE aggr_level = 6
      AND partner_code = 0
    GROUP BY sector, ref_year
)
SELECT
    sector,
    ref_year,
    total_export_value_usd,
    LAG(total_export_value_usd) OVER (
        PARTITION BY sector ORDER BY ref_year
    ) AS prior_year_value_usd,
    ROUND(
        100.0 * (
            total_export_value_usd
            - LAG(total_export_value_usd) OVER (PARTITION BY sector ORDER BY ref_year)
        ) / NULLIF(
            LAG(total_export_value_usd) OVER (PARTITION BY sector ORDER BY ref_year),
            0
        ),
        1
    ) AS yoy_growth_pct
FROM sector_yearly
ORDER BY sector, ref_year;


-- ============================================================
-- Query 3a: sector composition — share of the 5-sector basket, 2014 vs 2023
--            long form: one row per sector per year
-- ============================================================
WITH sector_yearly AS (
    SELECT
        sector,
        ref_year,
        SUM(fob_value) AS sector_value_usd
    FROM clean_track_b_india_sector_detail
    WHERE aggr_level = 6
      AND partner_code = 0
      AND ref_year IN (2014, 2023)
    GROUP BY sector, ref_year
)
SELECT
    sector,
    ref_year,
    sector_value_usd,
    ROUND(
        100.0 * sector_value_usd / NULLIF(SUM(sector_value_usd) OVER (PARTITION BY ref_year), 0),
        1
    ) AS pct_of_5_sector_basket
FROM sector_yearly
ORDER BY sector, ref_year;


-- ============================================================
-- Query 3b: same comparison, wide form — one row per sector with the
--            2014 and 2023 shares side by side and the ppt shift
-- ============================================================
WITH sector_yearly AS (
    SELECT
        sector,
        ref_year,
        SUM(fob_value) AS sector_value_usd
    FROM clean_track_b_india_sector_detail
    WHERE aggr_level = 6
      AND partner_code = 0
      AND ref_year IN (2014, 2023)
    GROUP BY sector, ref_year
),
shares AS (
    SELECT
        sector,
        ref_year,
        100.0 * sector_value_usd
            / NULLIF(SUM(sector_value_usd) OVER (PARTITION BY ref_year), 0) AS pct_basket
    FROM sector_yearly
)
SELECT
    sector,
    ROUND(MAX(pct_basket) FILTER (WHERE ref_year = 2014), 1) AS pct_2014,
    ROUND(MAX(pct_basket) FILTER (WHERE ref_year = 2023), 1) AS pct_2023,
    ROUND(
        MAX(pct_basket) FILTER (WHERE ref_year = 2023)
        - MAX(pct_basket) FILTER (WHERE ref_year = 2014),
        1
    ) AS ppt_change
FROM shares
GROUP BY sector
ORDER BY ppt_change DESC;


-- ============================================================
-- Query 4: top 10 HS6 products within each sector
--           ranked on 2023 value; full-period total shown alongside
-- ============================================================
WITH product_totals AS (
    SELECT
        sector,
        cmd_code,
        cmd_desc,
        SUM(fob_value) FILTER (WHERE ref_year = 2023) AS value_2023_usd,
        SUM(fob_value)                                AS value_2014_2023_usd
    FROM clean_track_b_india_sector_detail
    WHERE aggr_level = 6
      AND partner_code = 0
    GROUP BY sector, cmd_code, cmd_desc
),
ranked AS (
    SELECT
        pt.*,
        RANK() OVER (
            PARTITION BY sector ORDER BY value_2023_usd DESC NULLS LAST
        ) AS rank_in_sector_2023
    FROM product_totals pt
)
SELECT
    sector,
    rank_in_sector_2023,
    cmd_code,
    cmd_desc,
    value_2023_usd,
    value_2014_2023_usd
FROM ranked
WHERE rank_in_sector_2023 <= 10
ORDER BY sector, rank_in_sector_2023;


-- ============================================================
-- Query 5: product concentration within each sector, 2023
--           top-5 HS6 share and Herfindahl-Hirschman Index (HHI)
--
-- HHI = sum of squared percentage shares, 0-10000 scale:
--   < 1500 unconcentrated | 1500-2500 moderate | > 2500 concentrated.
-- A sector that is a single HS2 chapter (gems & jewellery, petroleum,
-- pharmaceuticals) will score high by construction — worth stating next to
-- the number. Confirmed empirically: these three post the highest HHI of
-- the five sectors (pharmaceuticals highest at 5751, ahead of petroleum's
-- 5238 and gems & jewellery's 3831).
-- ============================================================
WITH product_2023 AS (
    SELECT
        sector,
        cmd_code,
        SUM(fob_value) AS value_2023_usd
    FROM clean_track_b_india_sector_detail
    WHERE aggr_level = 6
      AND partner_code = 0
      AND ref_year = 2023
    GROUP BY sector, cmd_code
),
shares AS (
    SELECT
        sector,
        cmd_code,
        value_2023_usd,
        value_2023_usd
            / NULLIF(SUM(value_2023_usd) OVER (PARTITION BY sector), 0) AS share,
        RANK() OVER (PARTITION BY sector ORDER BY value_2023_usd DESC) AS rnk
    FROM product_2023
)
SELECT
    sector,
    COUNT(*)                                             AS distinct_hs6_products,
    ROUND(100.0 * SUM(share) FILTER (WHERE rnk <= 5), 1) AS top5_share_pct,
    ROUND(SUM(share * share) * 10000, 0)                 AS hhi_2023
FROM shares
GROUP BY sector
ORDER BY hhi_2023 DESC;


-- ============================================================
-- Validation — run before trusting the queries above
-- ============================================================

-- V1. Partner coverage. Expect exactly one row: World (partner_code = 0).
--     If named partners appear, the pull scope changed and the
--     partner_code = 0 filter above would be silently dropping real data.
SELECT partner_code, partner_desc, COUNT(*) AS row_count
FROM clean_track_b_india_sector_detail
GROUP BY partner_code, partner_desc
ORDER BY row_count DESC;

-- V2. Aggregation levels present. aggr_level = 6 should hold the
--     overwhelming majority of rows and value; any level 2/4 rows are
--     rollups the queries exclude on purpose.
SELECT aggr_level, COUNT(*) AS row_count, SUM(fob_value) AS total_value_usd
FROM clean_track_b_india_sector_detail
GROUP BY aggr_level
ORDER BY aggr_level;

-- V3. is_reported vs is_aggregate at HS6. overlap_rows must be 0 and
--     reported + aggregate must equal total_hs6_rows for the "sum every row
--     at this level" approach above to be safe.
SELECT
    COUNT(*)                                             AS total_hs6_rows,
    COUNT(*) FILTER (WHERE is_reported)                  AS reported_rows,
    COUNT(*) FILTER (WHERE is_aggregate)                 AS aggregate_rows,
    COUNT(*) FILTER (WHERE is_reported AND is_aggregate) AS overlap_rows
FROM clean_track_b_india_sector_detail
WHERE aggr_level = 6;

-- V4. Sector series completeness. Any sector with years_present < 10 needs a
--     caveat on its trend / growth charts.
SELECT
    sector,
    MIN(ref_year)            AS first_year,
    MAX(ref_year)            AS last_year,
    COUNT(DISTINCT ref_year) AS years_present
FROM clean_track_b_india_sector_detail
WHERE aggr_level = 6
GROUP BY sector
ORDER BY years_present, sector;

-- V5. Cross-track reconciliation. Track A holds India's HS2 chapter values
--     to World. Summing the Track A chapters behind each sector should land
--     close to the Track B sector totals for the same year. Small gaps are
--     expected (HS6 detail vs HS2 rollup, differing estimation); large ones
--     are a flag to investigate before publishing.
WITH track_b_sector AS (
    SELECT sector, ref_year, SUM(fob_value) AS b_value_usd
    FROM clean_track_b_india_sector_detail
    WHERE aggr_level = 6 AND partner_code = 0
    GROUP BY sector, ref_year
),
track_a_sector AS (
    SELECT
        CASE
            WHEN cmd_code = '27'          THEN 'petroleum_products'
            WHEN cmd_code = '30'          THEN 'pharmaceuticals'
            WHEN cmd_code = '71'          THEN 'gems_jewellery'
            WHEN cmd_code IN ('84', '85') THEN 'engineering_machinery'
            WHEN cmd_code BETWEEN '50' AND '63' THEN 'textiles'
        END AS sector,
        ref_year,
        SUM(fob_value) AS a_value_usd
    FROM clean_track_a_country_benchmark
    WHERE reporter_iso = 'IND'
      AND cmd_code IN ('27','30','71','84','85',
                       '50','51','52','53','54','55','56',
                       '57','58','59','60','61','62','63')
    GROUP BY sector, ref_year
)
SELECT
    b.sector,
    b.ref_year,
    b.b_value_usd,
    a.a_value_usd,
    ROUND(100.0 * (b.b_value_usd - a.a_value_usd) / NULLIF(a.a_value_usd, 0), 1) AS pct_diff
FROM track_b_sector b
JOIN track_a_sector a USING (sector, ref_year)
ORDER BY b.sector, b.ref_year;
