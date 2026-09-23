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
-- NOTE on views (23/09/2026): every result set exported to data/processed/ is
-- defined once here as a view (v_track_b_*), and sql/08 only copies it out —
-- see 02's header for why. If you change a view, rerun 08.
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
--
--      TWO MORE LIMITS ON READING Q6 (added 23/09/2026).
--      (a) Tonnes are summed over weight-bearing rows only, so when coverage
--          moves between the endpoint years the tonnage change moves with it.
--          Q6 now also carries a coverage-adjusted tonnage (tonnes scaled up
--          by 1 / value coverage), which assumes the unweighed rows ship at
--          the same USD/kg as the weighed ones. For textiles, coverage fell
--          97.8% -> 93.0% and the change in tonnes goes from -14.9% raw to
--          -10.5% adjusted: the direction holds, the size does not. The same
--          coverage gap is why value change != tonnes change x unit value
--          change in Q6 (engineering: 1.781 x 1.448 = 2.579 against a value
--          ratio of 2.727; the ratio between them is exactly the coverage
--          ratio 96.2 / 91.0).
--      (b) A sector's USD/kg is a MIX-WEIGHTED average across hundreds of
--          products, not a price. It rises when the mix shifts toward
--          heavier-value goods even if no single price moves. Engineering is
--          the case in point — see Q6b.


-- ============================================================
-- Query 1: sector export value trend, by year
--          Exported as data/processed/track_b_sector_year_totals.csv.
-- ============================================================
DROP VIEW IF EXISTS v_track_b_sector_year_totals;
CREATE VIEW v_track_b_sector_year_totals AS
SELECT
    sector,
    ref_year,
    ROUND(SUM(fob_value) / 1e9, 3) AS sector_value_usd_bn
FROM clean_track_b_india_sector_detail
WHERE aggr_level = 6
  AND partner_code = 0
GROUP BY sector, ref_year
ORDER BY sector, ref_year;

SELECT * FROM v_track_b_sector_year_totals;


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
        -- Grouping on the code fixes rewordings but not code CHANGES: where
        -- an edition split or retired a code, value_2014_2023_usd covers only
        -- the years that code existed (02 assumption 7). The 2023 ranking is
        -- unaffected; the full-period column is per-code, not per-product.
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
        -- ROW_NUMBER(), not RANK(), matching 02 Q3. Codes with no 2023 line
        -- have a NULL value_2023_usd and all tie on it — 37 such codes in
        -- engineering/machinery and 37 in textiles. Most are not products
        -- India stopped exporting: 32 and 30 of them last appear in 2016 or
        -- 2021, the year before an HS edition retired or split the code
        -- (02 assumption 7). This said "products that stopped being
        -- exported" until 23/09/2026. RANK() would give every one of them the same rank, and a
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
-- HHI = sum of squared percentage shares, 0-10000 scale. The bands usually
-- quoted — < 1500 unconcentrated | 1500-2500 moderate | > 2500 highly
-- concentrated — are the 2010 US Horizontal Merger Guidelines' thresholds,
-- an antitrust heuristic borrowed here, not a trade standard. The 2023 US
-- Merger Guidelines (18/12/2023) replaced them with a single > 1800 "highly
-- concentrated" line. Neither is applied as a verdict in this file.
-- A sector that is a single HS2 chapter (gems & jewellery, petroleum,
-- pharmaceuticals) will score high by construction — worth stating next to
-- the number. Confirmed empirically: these three post the highest HHI of
-- the five sectors (pharmaceuticals highest at 5751, ahead of petroleum's
-- 5238 and gems & jewellery's 3831).
--
-- hs6_products_2023 counts codes carrying a 2023 line — within one year and
-- one HS edition a code is a product, so this is the right denominator for a
-- 2023 index. hs6_codes_all_years is NOT a product count: it counts distinct
-- codes across three HS editions (2012, 2017, 2022), so a product whose code
-- was split or renumbered is counted more than once (02 assumption 7).
-- Engineering has 826 codes in 2023 and 863 across the decade, textiles 784
-- vs 821, pharmaceuticals 43 vs 53 — and most of each gap is edition churn,
-- not discontinued exports. The column was named hs6_products_all_years, and
-- key_findings.md finding 6 read it as "37 more products", until 23/09/2026.
-- It is kept (renamed) because the gap itself is the evidence of the churn.
-- Exported as data/processed/track_b_sector_concentration_2023.csv.
-- ============================================================
DROP VIEW IF EXISTS v_track_b_sector_concentration_2023;
CREATE VIEW v_track_b_sector_concentration_2023 AS
WITH codes_all_years AS (
    SELECT sector, COUNT(DISTINCT cmd_code) AS hs6_codes_all_years
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
    MAX(ca.hs6_codes_all_years)                            AS hs6_codes_all_years,
    ROUND(100.0 * SUM(s.share) FILTER (WHERE s.rnk <= 5), 1) AS top5_share_pct,
    ROUND(SUM(s.share * s.share) * 10000, 0)               AS hhi_2023
FROM shares s
JOIN codes_all_years ca USING (sector)
GROUP BY s.sector
ORDER BY hhi_2023 DESC;

SELECT * FROM v_track_b_sector_concentration_2023;


-- ============================================================
-- Query 6: volume vs value, 2014 -> 2023, per sector (assumption 7)
--          How much of each sector's decade growth is tonnes, and how much
--          is price. Unit value is USD per kg over weight-bearing rows only.
--          The last three columns (added 23/09/2026) scale tonnes by value
--          coverage — assumption 7(a); read them beside the raw tonnes, not
--          instead of them. Exported as track_b_sector_volume_vs_value.csv.
-- ============================================================
DROP VIEW IF EXISTS v_track_b_sector_volume_vs_value;
CREATE VIEW v_track_b_sector_volume_vs_value AS
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
),
adj AS (
    -- tonnes / value coverage = tonnes if every row shipped at the weighed
    -- rows' USD/kg
    SELECT
        wide.*,
        kg_2014 * value_2014 / NULLIF(vw_2014, 0) AS kg_adj_2014,
        kg_2023 * value_2023 / NULLIF(vw_2023, 0) AS kg_adj_2023
    FROM wide
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
         THEN 'LOW COVERAGE — no volume claim' ELSE 'ok' END               AS volume_flag,
    ROUND(kg_adj_2014 / 1e9, 3)                                            AS mn_tonnes_cov_adj_2014,
    ROUND(kg_adj_2023 / 1e9, 3)                                            AS mn_tonnes_cov_adj_2023,
    ROUND(100.0 * (kg_adj_2023 / NULLIF(kg_adj_2014, 0) - 1), 1)           AS volume_change_cov_adj_pct
FROM adj
ORDER BY sector;

SELECT * FROM v_track_b_sector_volume_vs_value;

-- ============================================================
-- Query 6b: engineering's unit value with and without mobile phones
--           (added 23/09/2026, assumption 7(b)).
--
--           Engineering's USD/kg rose 44.8% over the decade, which finding 17
--           read as "moving up the value chain". One product line carries
--           most of it. Mobile phones — 851712 until 2021, split into 851713
--           (smartphones) and 851714 (other) in HS 2022 — went from USD
--           0.56bn to 14.29bn at roughly USD 1,000/kg, against ~12 USD/kg for
--           the rest of the sector. Excluding them from BOTH years (all three
--           codes, so the edition change does not bias the comparison), the
--           sector's unit value rises 11.43 -> 12.72 USD/kg, +11.3%.
--           So the rise is mostly a shift in mix toward phones, not higher
--           prices across the basket. (The cold audit of 23/09/2026 quoted
--           +8.4%, which removes phones from 2023 but leaves them in 2014.)
--           Exported as track_b_engineering_unit_value_mix.csv.
-- ============================================================
DROP VIEW IF EXISTS v_track_b_engineering_unit_value_mix;
CREATE VIEW v_track_b_engineering_unit_value_mix AS
WITH base AS (
    SELECT
        ref_year,
        cmd_code IN ('851712', '851713', '851714') AS is_phone,
        fob_value,
        net_wgt
    FROM clean_track_b_india_sector_detail
    WHERE aggr_level = 6 AND partner_code = 0
      AND sector = 'engineering_machinery'
      AND ref_year IN (2014, 2023)
),
yearly AS (
    SELECT
        ref_year,
        SUM(fob_value)                                            AS value_usd,
        SUM(fob_value) FILTER (WHERE is_phone)                    AS phone_value_usd,
        SUM(fob_value) FILTER (WHERE net_wgt > 0)                 AS vw_all,
        SUM(net_wgt)   FILTER (WHERE net_wgt > 0)                 AS kg_all,
        SUM(fob_value) FILTER (WHERE net_wgt > 0 AND NOT is_phone) AS vw_ex,
        SUM(net_wgt)   FILTER (WHERE net_wgt > 0 AND NOT is_phone) AS kg_ex
    FROM base
    GROUP BY ref_year
)
SELECT
    ref_year,
    ROUND(value_usd / 1e9, 2)                                   AS sector_value_bn,
    ROUND(phone_value_usd / 1e9, 2)                             AS phone_value_bn,
    ROUND(100.0 * phone_value_usd / NULLIF(value_usd, 0), 1)    AS phone_share_pct,
    ROUND(vw_all / NULLIF(kg_all, 0), 3)                        AS usd_per_kg_all,
    ROUND(vw_ex  / NULLIF(kg_ex, 0), 3)                         AS usd_per_kg_ex_phones,
    ROUND(100.0 * ((vw_all / NULLIF(kg_all, 0))
          / NULLIF(FIRST_VALUE(vw_all / NULLIF(kg_all, 0)) OVER (ORDER BY ref_year), 0) - 1), 1)
                                                                AS unit_value_change_all_pct,
    ROUND(100.0 * ((vw_ex / NULLIF(kg_ex, 0))
          / NULLIF(FIRST_VALUE(vw_ex / NULLIF(kg_ex, 0)) OVER (ORDER BY ref_year), 0) - 1), 1)
                                                                AS unit_value_change_ex_phones_pct
FROM yearly
ORDER BY ref_year;

SELECT * FROM v_track_b_engineering_unit_value_mix;

-- ============================================================
-- Query 7: petroleum products, year by year — tonnes, USD, USD/kg, and each
--          indexed to 2014 = 100. The 2022 spike in three columns.
--          Exported as track_b_petroleum_volume_series.csv.
-- ============================================================
DROP VIEW IF EXISTS v_track_b_petroleum_volume_series;
CREATE VIEW v_track_b_petroleum_volume_series AS
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

SELECT * FROM v_track_b_petroleum_volume_series;

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
--          Exported as track_b_volume_coverage.csv.
-- ============================================================
DROP VIEW IF EXISTS v_track_b_volume_coverage;
CREATE VIEW v_track_b_volume_coverage AS
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

SELECT * FROM v_track_b_volume_coverage;


-- ============================================================
-- Validation — run before trusting the queries above
-- ============================================================

-- V1. Partner coverage. Expect exactly one row: World (partner_code = 0).
--     If named partners appear, the pull scope changed and the
--     partner_code = 0 filter above would be silently dropping real data.
--     Asserted since 23/09/2026.
DO $$
DECLARE n bigint;
BEGIN
    SELECT COUNT(*) INTO n FROM clean_track_b_india_sector_detail WHERE partner_code <> 0;
    IF n <> 0 THEN
        RAISE EXCEPTION '03 V1: % Track B rows have a partner other than World', n;
    END IF;
    RAISE NOTICE '03 V1 PASSED: every Track B row is India -> World.';
END $$;

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
--     expected (HS6 detail vs HS2 rollup); large ones are a flag to
--     investigate before publishing. Exported as
--     track_b_cross_track_reconciliation.csv, at 2 dp — the -2.46% that
--     finding 10 quotes. (The printed query rounded to 1 dp until
--     23/09/2026, so it showed -2.5 while the finding cited it for -2.46.)
--
--     At build time: worst -2.462% (engineering/machinery 2022), 44 of 50
--     sector-years within 0.005%, 8 identical to the dollar.
DROP VIEW IF EXISTS v_track_b_cross_track_reconciliation;
CREATE VIEW v_track_b_cross_track_reconciliation AS
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
    ROUND(b.b_value_usd / 1e9, 3)                                                AS track_b_bn,
    ROUND(a.a_value_usd / 1e9, 3)                                                AS track_a_bn,
    ROUND(100.0 * (b.b_value_usd - a.a_value_usd) / NULLIF(a.a_value_usd, 0), 2) AS pct_diff
FROM track_b_sector b
-- Inner join: a sector-year in one track but not the other would be dropped
-- from the reconciliation rather than flagged by it — the one place a silent
-- skip would be worst. A no-op here: both tracks hold all 50 sector-years,
-- and the assertion below checks that the join returns all 50.
JOIN track_a_sector a USING (sector, ref_year)
ORDER BY b.sector, b.ref_year;

SELECT * FROM v_track_b_cross_track_reconciliation;

-- V5 assertion (added 23/09/2026): all 50 sector-years reconcile, and none
-- by more than 2.5%. The tolerance is the published claim, not a fitted
-- number — finding 10 says "within 2.5%" — so a change that breaks it has
-- to change the finding too.
DO $$
DECLARE n bigint; worst numeric;
BEGIN
    SELECT COUNT(*), MAX(ABS(pct_diff)) INTO n, worst FROM v_track_b_cross_track_reconciliation;
    IF n <> 50 OR worst > 2.5 THEN
        RAISE EXCEPTION '03 V5: % sector-years reconciled (expected 50), worst |divergence| % percent', n, worst;
    END IF;
    RAISE NOTICE '03 V5 PASSED: 50 sector-years reconcile Track B to Track A within 2.5 percent (worst % percent).', worst;
END $$;
