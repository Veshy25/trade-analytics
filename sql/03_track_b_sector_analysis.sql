-- 03_track_b_sector_analysis.sql
-- Track B analysis: India's export profile within 5 focus sectors —
-- textiles (HS 50-63), pharmaceuticals (30), gems & jewellery (71),
-- petroleum products (27), engineering/machinery (84-85). HS6 product-level
-- detail, India -> World, 2014-2023.
--
-- Source table: clean_track_b_india_sector_detail (built in 01_data_cleaning.sql).
-- Every row is India as reporter, World (partner_code = 0) as partner, and
-- carries a `sector` label that is DERIVED, not returned by the API: it was
-- assigned during the pull by mapping the HS2 prefix of cmdCode to one of the
-- five sector names (27 / 30 / 71 / 84-85 / 50-63 — see the sector table in
-- data/raw/README.md). Every other column comes straight from Comtrade.
--
-- NOTE: sql/08_export_results.sql re-states several of the queries below in
-- order to write them out as CSVs. If you change a query here, rerun 08 so the
-- committed files under data/processed/ do not silently go stale.
--
-- Assumptions made here (flagging before running, not after):
--   1. Sector and product totals sum only aggr_level = 6 rows (true HS6
--      product detail). The pull used cmdCode='AG6', so the table should be
--      almost entirely level 6; the filter guards against coarser level-2/4
--      rollup rows entering an HS6 sum. It is not the double-counting guard
--      — that is the UNIQUE index declared in 01. Validation V2 shows the
--      split.
--   2. Within aggr_level = 6, every row is summed regardless of is_reported
--      vs is_aggregate. These two flags partition the rows (mutually
--      exclusive, jointly exhaustive) with no overlap, so summing both gives
--      the most complete total rather than an undercount. See 02 assumption 1
--      for what is_aggregate means — it is a rollup marker, not an estimation
--      marker. Validation V3 re-checks the partition here.
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
--   7. VOLUME (Queries 6-8, added 15/09/2026 for Phase 2). net_wgt in kg is
--      the single volume measure. qty is in mixed units (u, m2, carat, kWh)
--      and is never summed. Volume exists only at HS6 — Comtrade does not
--      aggregate mixed units to chapter level, so this is sector-level by
--      construction and Track A (HS2) has no volume at all. Coverage is not
--      uniform: at build time the share of sector VALUE sitting on rows with
--      a populated net_wgt was petroleum 100.0/98.3, pharma 100.0/100.0,
--      textiles 97.8/93.0, engineering 96.2/91.0, gems 40.2/67.0 (2014/2023,
--      from Q8). Unit values (USD/kg) are computed only over rows that carry
--      both value and weight, so numerator and denominator cover the same
--      trade. Any sector under 80% value coverage in either endpoint year —
--      gems & jewellery — gets its volume row reported but flagged, and no
--      volume claim is made for it. Weight is also a poor measure of gems by
--      nature (a carat of diamond and a kilo of scrap silver are not the same
--      "volume"); the flag is about coverage, but the caveat would stand even
--      at 100%.
--
--      HOW MUCH OF THE WEIGHT IS COMTRADE'S, NOT INDIA'S (added 17/09/2026).
--      Coverage is not the only gate, and the more important one was missing.
--      Where a reporter files no net weight, Comtrade estimates it — and its
--      stated method (UNSD, "Quantity and Weight information in UN Comtrade",
--      October 2009) is to derive the missing weight FROM THE VALUE using
--      weighted or standard unit values. Estimated weight is therefore not an
--      independent measurement of volume; it is value divided by an assumed
--      price. Q8 reported only the share of ROWS flagged, which for petroleum
--      reads a comfortable 24-63%. Weighted by kilograms — the thing actually
--      being summed — the share is 95.3% in 2014 and 95.3% in 2023, peaking
--      at 99.7%, because the few estimated rows are the enormous ones. Q8 now
--      carries weight_estimated_kg_pct alongside the row share for exactly
--      this reason, and Q7's petroleum series must be read with it: the
--      volume-not-price reading in key_findings.md finding 17 holds only as
--      far as Comtrade's unit-value assumptions hold. Row share and kg share
--      diverge most where it matters most, so never quote the row figure as
--      the tonnage figure.


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
        -- latest wording, not a GROUP BY key: 73 HS6 codes in this table
        -- were reworded across TWO editions — 42 at 2017 (HS 2017) and 34 at
        -- 2022 (HS 2022), three codes in both (see 02 assumption 7; this
        -- comment said "by HS 2022" until 17/09/2026). Grouping on cmd_desc
        -- split them and truncated value_2014_2023_usd to the rows sharing
        -- the latest wording — fixed 15/09/2026; one top-10 row was affected
        -- (petroleum 270750: 3.58bn -> 3.62bn, itself a 2017 rewording).
        (ARRAY_AGG(cmd_desc ORDER BY ref_year DESC))[1]  AS cmd_desc,
        SUM(fob_value) FILTER (WHERE ref_year = 2023) AS value_2023_usd,
        SUM(fob_value)                                AS value_2014_2023_usd
    FROM clean_track_b_india_sector_detail
    WHERE aggr_level = 6
      AND partner_code = 0
    GROUP BY sector, cmd_code
),
ranked AS (
    SELECT
        pt.*,
        -- ROW_NUMBER(), not RANK(), matching 02 Q3. Products that stopped
        -- being exported before 2023 have a NULL value_2023_usd and all tie
        -- on it — 37 such products in engineering/machinery and 37 in
        -- textiles. RANK() would give every one of them the same rank, and a
        -- "<= 10" filter placed on a tie block returns the whole block. The
        -- full-period tie-break also makes the order deterministic between
        -- runs rather than dependent on scan order.
        ROW_NUMBER() OVER (
            PARTITION BY sector
            ORDER BY value_2023_usd DESC NULLS LAST,
                     value_2014_2023_usd DESC,
                     cmd_code
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
--
-- hs6_products_2023 counts products carrying a 2023 line, not every product
-- the sector has ever held — the CTE filters to ref_year = 2023, so a product
-- that stopped being exported before 2023 is correctly absent from a 2023
-- concentration measure. The two counts differ: engineering 826 vs 863
-- all-years, textiles 784 vs 821, pharmaceuticals 43 vs 53. Quote the 2023
-- count alongside the 2023 HHI; the all-years figure is context, not a
-- denominator for this index. Both counts are now returned as columns
-- (17/09/2026) — the all-years figure was quoted in key_findings.md finding 6
-- while existing only in this comment, which is exactly the kind of
-- untraceable number the project claims not to have.
-- ============================================================
WITH product_all_years AS (
    SELECT sector, COUNT(DISTINCT cmd_code) AS hs6_products_all_years
    FROM clean_track_b_india_sector_detail
    WHERE aggr_level = 6 AND partner_code = 0
    GROUP BY sector
),
product_2023 AS (
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
        -- ROW_NUMBER() so the "rnk <= 5" filter below returns exactly five
        -- products per sector. RANK() would return the whole tie block if the
        -- 5th and 6th products shared a value, inflating top5_share_pct.
        ROW_NUMBER() OVER (
            PARTITION BY sector ORDER BY value_2023_usd DESC, cmd_code
        ) AS rnk
    FROM product_2023
)
SELECT
    s.sector,
    COUNT(*)                                               AS hs6_products_2023,
    MAX(pa.hs6_products_all_years)                         AS hs6_products_all_years,
    ROUND(100.0 * SUM(s.share) FILTER (WHERE s.rnk <= 5), 1) AS top5_share_pct,
    ROUND(SUM(s.share * s.share) * 10000, 0)               AS hhi_2023
FROM shares s
JOIN product_all_years pa USING (sector)
GROUP BY s.sector
ORDER BY hhi_2023 DESC;


-- ============================================================
-- Query 6: volume vs value, 2014 -> 2023, per sector (assumption 7)
--          How much of each sector's decade growth is tonnes, and how much
--          is price. Unit value is USD per kg over weight-bearing rows only.
-- ============================================================
WITH ep AS (
    SELECT
        sector,
        ref_year,
        SUM(fob_value)                                           AS value_usd,
        SUM(fob_value) FILTER (WHERE net_wgt > 0)                AS value_weighed_usd,
        SUM(net_wgt)   FILTER (WHERE net_wgt > 0)                AS net_wgt_kg
    FROM clean_track_b_india_sector_detail
    WHERE aggr_level = 6 AND partner_code = 0 AND ref_year IN (2014, 2023)
    GROUP BY sector, ref_year
),
wide AS (
    SELECT
        sector,
        MAX(value_usd)         FILTER (WHERE ref_year = 2014) AS value_2014,
        MAX(value_usd)         FILTER (WHERE ref_year = 2023) AS value_2023,
        MAX(value_weighed_usd) FILTER (WHERE ref_year = 2014) AS vw_2014,
        MAX(value_weighed_usd) FILTER (WHERE ref_year = 2023) AS vw_2023,
        MAX(net_wgt_kg)        FILTER (WHERE ref_year = 2014) AS kg_2014,
        MAX(net_wgt_kg)        FILTER (WHERE ref_year = 2023) AS kg_2023
    FROM ep
    GROUP BY sector
)
SELECT
    sector,
    ROUND(value_2014 / 1e9, 2)                                             AS value_2014_bn,
    ROUND(value_2023 / 1e9, 2)                                             AS value_2023_bn,
    ROUND(kg_2014 / 1e9, 3)                                                AS mn_tonnes_2014,
    ROUND(kg_2023 / 1e9, 3)                                                AS mn_tonnes_2023,
    ROUND(vw_2014 / NULLIF(kg_2014, 0), 3)                                 AS usd_per_kg_2014,
    ROUND(vw_2023 / NULLIF(kg_2023, 0), 3)                                 AS usd_per_kg_2023,
    ROUND(100.0 * (POWER(value_2023 / NULLIF(value_2014, 0), 1.0 / 9) - 1), 2) AS value_cagr_pct,
    ROUND(100.0 * (POWER(kg_2023    / NULLIF(kg_2014, 0),    1.0 / 9) - 1), 2) AS volume_cagr_pct,
    ROUND(100.0 * (kg_2023 / NULLIF(kg_2014, 0) - 1), 1)                   AS volume_change_pct,
    ROUND(100.0 * ((vw_2023 / NULLIF(kg_2023, 0)) / NULLIF(vw_2014 / NULLIF(kg_2014, 0), 0) - 1), 1)
                                                                           AS unit_value_change_pct,
    ROUND(100.0 * vw_2014 / NULLIF(value_2014, 0), 1)                      AS value_coverage_2014_pct,
    ROUND(100.0 * vw_2023 / NULLIF(value_2023, 0), 1)                      AS value_coverage_2023_pct,
    CASE WHEN vw_2014 / NULLIF(value_2014, 0) < 0.8
           OR vw_2023 / NULLIF(value_2023, 0) < 0.8
         THEN 'LOW COVERAGE — no volume claim' ELSE 'ok' END               AS volume_flag
FROM wide
ORDER BY sector;

-- ============================================================
-- Query 7: petroleum products, year by year — tonnes, USD, USD/kg, and each
--          indexed to 2014 = 100. The 2022 spike in three columns.
-- ============================================================
WITH yearly AS (
    SELECT
        ref_year,
        SUM(fob_value)                              AS value_usd,
        SUM(fob_value) FILTER (WHERE net_wgt > 0)   AS value_weighed_usd,
        SUM(net_wgt)   FILTER (WHERE net_wgt > 0)   AS net_wgt_kg
    FROM clean_track_b_india_sector_detail
    WHERE aggr_level = 6 AND partner_code = 0 AND sector = 'petroleum_products'
    GROUP BY ref_year
),
based AS (
    SELECT
        *,
        value_weighed_usd / NULLIF(net_wgt_kg, 0)                         AS usd_per_kg,
        FIRST_VALUE(value_usd)   OVER (ORDER BY ref_year)                 AS base_value,
        FIRST_VALUE(net_wgt_kg)  OVER (ORDER BY ref_year)                 AS base_kg,
        FIRST_VALUE(value_weighed_usd / NULLIF(net_wgt_kg, 0)) OVER (ORDER BY ref_year) AS base_unit
    FROM yearly
)
SELECT
    ref_year,
    ROUND(value_usd / 1e9, 1)                                   AS value_bn,
    ROUND(net_wgt_kg / 1e9, 1)                                  AS mn_tonnes,
    ROUND(usd_per_kg, 3)                                        AS usd_per_kg,
    ROUND(100.0 * value_usd  / NULLIF(base_value, 0), 1)        AS value_index,
    ROUND(100.0 * net_wgt_kg / NULLIF(base_kg, 0), 1)           AS volume_index,
    ROUND(100.0 * usd_per_kg / NULLIF(base_unit, 0), 1)         AS unit_value_index
FROM based
ORDER BY ref_year;

-- ============================================================
-- Query 8: volume coverage per sector per year — the gate on Q6/Q7.
--          Share of sector value on rows with a populated net_wgt, and TWO
--          measures of how much of that weight Comtrade estimated rather than
--          the reporter filing it.
--
--          Read weight_estimated_kg_pct, not weight_estimated_rows_pct, when
--          judging a volume claim. The row share treats a 10-tonne line and a
--          10-million-tonne line alike; the kg share weights them by what is
--          actually being summed. For petroleum the two diverge violently —
--          28.9% of rows but 95.3% of tonnage in 2023 — because the estimated
--          rows are the big ones. Comtrade derives missing weight from value
--          via unit values (assumption 7), so a high kg share means the
--          "volume" series is substantially value divided by an assumed
--          price, and a volume-versus-price conclusion drawn from it is
--          partly circular. The row-share column is kept only so the two can
--          be compared; it was the only one here until 17/09/2026.
-- ============================================================
SELECT
    sector,
    ref_year,
    COUNT(*)                                                                    AS hs6_rows,
    COUNT(*) FILTER (WHERE net_wgt > 0)                                         AS rows_with_weight,
    ROUND(100.0 * SUM(fob_value) FILTER (WHERE net_wgt > 0)
          / NULLIF(SUM(fob_value), 0), 1)                                       AS value_coverage_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE net_wgt > 0 AND is_net_wgt_estimated)
          / NULLIF(COUNT(*) FILTER (WHERE net_wgt > 0), 0), 1)                  AS weight_estimated_rows_pct,
    ROUND(100.0 * SUM(net_wgt) FILTER (WHERE net_wgt > 0 AND is_net_wgt_estimated)
          / NULLIF(SUM(net_wgt) FILTER (WHERE net_wgt > 0), 0), 1)              AS weight_estimated_kg_pct
FROM clean_track_b_india_sector_detail
WHERE aggr_level = 6 AND partner_code = 0
GROUP BY sector, ref_year
ORDER BY sector, ref_year;


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
-- Inner join: a sector-year in one track but not the other would be dropped
-- from the reconciliation rather than flagged by it — the one place a silent
-- skip would be worst. A no-op here (both tracks hold all 50 sector-years, and
-- the row count below proves it), but stated rather than assumed.
JOIN track_a_sector a USING (sector, ref_year)
ORDER BY b.sector, b.ref_year;
