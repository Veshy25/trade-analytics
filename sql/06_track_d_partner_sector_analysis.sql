-- 06_track_d_partner_sector_analysis.sql
-- Track D analysis: India's exports to the 20 Track C partner markets, at HS6,
-- filtered to the five Track B sectors — the partner x sector crosstab that
-- Phase 1 could not answer ("which markets buy India's pharmaceuticals?").
-- Phase 2, pulled 15/09/2026.
--
-- NOTE on views (23/09/2026): every result set exported to data/processed/ is
-- defined once here as a view (v_track_d_*), and sql/08 only copies it out —
-- see 02's header for why. If you change a view, rerun 08.
--
-- Assumptions made here (flagging before running, not after):
--   1. Row inclusion follows 02 assumption 1: both is_reported and
--      is_aggregate rows are summed. V2 re-confirms the two flags partition
--      the table with no overlap.
--   2. Sums are over aggr_level = 6 only. The pull used cmdCode='AG6' and the
--      table is 100% level 6 (V2); the filter is a guard for a future pull,
--      not the double-counting guard — that is the UNIQUE index on
--      (ref_year, partner_code, cmd_code) declared in 01.
--   3. No World row was pulled (V1). Every share below is share of the
--      20-partner PANEL for that sector, not share of India's global exports
--      of that sector. V4 measures the panel's coverage of each sector's
--      Track B (World) total so the shares can be read in context.
--   4. `sector` is DERIVED during the pull from the HS2 prefix of cmd_code
--      (27 / 30 / 71 / 84-85 / 50-63), identically to Track B — see the
--      sector table in data/raw/README.md. It is not returned by the API.
--   5. Reference years are 2014 and 2023. Every partner has all ten years in
--      this pull (V1), so no short-series caveat is needed here, unlike
--      Track A's Bangladesh.
--   6. Concentration (Q4) is HHI on the 0-10,000 scale computed within a
--      sector across the 20-partner panel. Because the panel is not the
--      whole market, the bands (<1,500 / 1,500-2,500 / >2,500) are NOT
--      applied — the same reasoning as 04 Q4. HHI is reported as a trend,
--      not scored against a threshold.
--   7. Two pulls, two dates. Track D was pulled 15/09/2026; Tracks B and C on
--      25/08/2026. Comtrade revises published figures, so the cross-track
--      checks in V3/V4 could in principle show revision drift. In practice
--      they do not, but be exact about what "in practice" means here, because
--      this assumption overstated it until 17/09/2026. Worst absolute
--      divergence per sector over all 200 partner-years: petroleum 0.00%,
--      textiles 0.18%, pharmaceuticals 0.97%, gems & jewellery 1.95%,
--      engineering / machinery 11.54% (Japan, 2022). ELEVEN partner-years
--      exceed 1% — ten of them engineering in 2022, and one gems & jewellery
--      in 2022. Only petroleum matches to the cent; the earlier claim that
--      "every other sector-year matches to the cent" and that "every
--      partner-year over 1% is engineering in 2022" were both false, and V3
--      printed the counter-example directly beneath them. The engineering gap
--      is the same sector-year where Track B already diverges -2.46% from
--      Track A (03 V5, finding 10). That points to a property of India's 2022
--      HS 84/85 records rather than revision between the two pull dates:
--      Tracks A and B come from the SAME 25/08 pull and still diverge there,
--      so the gap exists without any pull-date difference. It is inferred,
--      not proven — no series was pulled on both dates to rule revision out,
--      and the mechanism (value held at chapter level with no HS6 breakdown)
--      is the likely explanation, not a demonstrated one. This assumption
--      stated it as established fact until 23/09/2026.
--   8. Nominal USD throughout (02 assumption 6). Every growth figure is
--      exposed to the 2022 commodity spike, petroleum most of all.
--   9. Every share, growth and CAGR divisor is wrapped in NULLIF(..., 0).

-- ============================================================
-- Query 1: sector x partner, 2023 — value and share of the sector's panel
--          The crosstab itself. One row per (sector, partner).
-- Exported as track_d_sector_partner_matrix_2023.csv.
-- ============================================================
DROP VIEW IF EXISTS v_track_d_sector_partner_matrix_2023;
CREATE VIEW v_track_d_sector_partner_matrix_2023 AS
WITH sector_partner AS (
    SELECT
        sector,
        partner_desc,
        SUM(fob_value) AS value_2023_usd
    FROM clean_track_d_india_partner_sector
    WHERE aggr_level = 6 AND ref_year = 2023
    GROUP BY sector, partner_desc
)
SELECT
    sector,
    partner_desc,
    ROW_NUMBER() OVER (PARTITION BY sector ORDER BY value_2023_usd DESC, partner_desc) AS rank_in_sector,
    ROUND(value_2023_usd / 1e9, 3)                                                       AS value_2023_bn,
    ROUND(100.0 * value_2023_usd / NULLIF(SUM(value_2023_usd) OVER (PARTITION BY sector), 0), 1)
                                                                                         AS pct_of_sector_panel
FROM sector_partner
ORDER BY sector, rank_in_sector;

SELECT * FROM v_track_d_sector_partner_matrix_2023;

-- ============================================================
-- Query 2: sector x partner — share of the sector's panel, 2014 vs 2023,
--          and the shift in percentage points. Which markets a sector
--          gained and lost over the decade.
-- Exported as track_d_sector_partner_shift.csv.
-- ============================================================
DROP VIEW IF EXISTS v_track_d_sector_partner_shift;
CREATE VIEW v_track_d_sector_partner_shift AS
WITH yearly AS (
    SELECT
        sector,
        partner_desc,
        ref_year,
        SUM(fob_value) AS value_usd
    FROM clean_track_d_india_partner_sector
    WHERE aggr_level = 6 AND ref_year IN (2014, 2023)
    GROUP BY sector, partner_desc, ref_year
),
shares AS (
    SELECT
        sector,
        partner_desc,
        ref_year,
        100.0 * value_usd / NULLIF(SUM(value_usd) OVER (PARTITION BY sector, ref_year), 0) AS share_pct
    FROM yearly
)
SELECT
    sector,
    partner_desc,
    ROUND(MAX(share_pct) FILTER (WHERE ref_year = 2014), 1) AS share_2014_pct,
    ROUND(MAX(share_pct) FILTER (WHERE ref_year = 2023), 1) AS share_2023_pct,
    ROUND(COALESCE(MAX(share_pct) FILTER (WHERE ref_year = 2023), 0)
        - COALESCE(MAX(share_pct) FILTER (WHERE ref_year = 2014), 0), 1) AS shift_ppt
FROM shares
GROUP BY sector, partner_desc
ORDER BY sector, shift_ppt DESC;

SELECT * FROM v_track_d_sector_partner_shift;

-- ============================================================
-- Query 3: top 5 HS6 products per (sector, top-3 partner), 2023
--          What India actually sells to each sector's leading markets.
-- Exported as track_d_top_products_by_market.csv.
-- ============================================================
DROP VIEW IF EXISTS v_track_d_top_products_by_market;
CREATE VIEW v_track_d_top_products_by_market AS
WITH partner_rank AS (
    SELECT
        sector,
        partner_desc,
        SUM(fob_value) AS partner_value_2023,
        ROW_NUMBER() OVER (PARTITION BY sector ORDER BY SUM(fob_value) DESC, partner_desc) AS partner_rank
    FROM clean_track_d_india_partner_sector
    WHERE aggr_level = 6 AND ref_year = 2023
    GROUP BY sector, partner_desc
),
product AS (
    SELECT
        d.sector,
        d.partner_desc,
        d.cmd_code,
        d.cmd_desc,
        SUM(d.fob_value) AS value_2023_usd
    FROM clean_track_d_india_partner_sector d
    JOIN partner_rank p USING (sector, partner_desc)
    WHERE d.aggr_level = 6 AND d.ref_year = 2023 AND p.partner_rank <= 3
    GROUP BY d.sector, d.partner_desc, d.cmd_code, d.cmd_desc
),
ranked AS (
    SELECT
        pr.*,
        p.partner_rank,
        ROW_NUMBER() OVER (PARTITION BY pr.sector, pr.partner_desc
                           ORDER BY pr.value_2023_usd DESC, pr.cmd_code) AS product_rank,
        100.0 * pr.value_2023_usd / NULLIF(p.partner_value_2023, 0)      AS pct_of_partner_sector
    FROM product pr
    JOIN partner_rank p USING (sector, partner_desc)
)
SELECT
    sector,
    partner_rank,
    partner_desc,
    product_rank,
    cmd_code,
    cmd_desc,
    ROUND(value_2023_usd / 1e6, 1)      AS value_2023_mn,
    ROUND(pct_of_partner_sector, 1)     AS pct_of_partner_sector
FROM ranked
WHERE product_rank <= 5
ORDER BY sector, partner_rank, product_rank;

SELECT * FROM v_track_d_top_products_by_market;

-- ============================================================
-- Query 4: market concentration per sector, per year — top-3 partner share
--          and HHI across the 20-partner panel. Trend only (assumption 6).
-- Exported as track_d_sector_market_concentration.csv.
-- ============================================================
DROP VIEW IF EXISTS v_track_d_sector_market_concentration;
CREATE VIEW v_track_d_sector_market_concentration AS
WITH yearly AS (
    SELECT
        sector,
        ref_year,
        partner_desc,
        SUM(fob_value) AS value_usd
    FROM clean_track_d_india_partner_sector
    WHERE aggr_level = 6
    GROUP BY sector, ref_year, partner_desc
),
shares AS (
    SELECT
        sector,
        ref_year,
        partner_desc,
        value_usd / NULLIF(SUM(value_usd) OVER (PARTITION BY sector, ref_year), 0) AS share,
        ROW_NUMBER() OVER (PARTITION BY sector, ref_year ORDER BY value_usd DESC, partner_desc) AS rnk
    FROM yearly
)
SELECT
    sector,
    ref_year,
    ROUND(100.0 * SUM(share) FILTER (WHERE rnk <= 3), 1) AS top3_partner_share_pct,
    ROUND(SUM(share * share) * 10000, 0)                  AS hhi_panel,
    COUNT(*) FILTER (WHERE share > 0)                     AS partners_with_trade
FROM shares
GROUP BY sector, ref_year
ORDER BY sector, ref_year;

SELECT * FROM v_track_d_sector_market_concentration;

-- ============================================================
-- Query 5: CAGR 2014 -> 2023 per (sector, partner), with the 2023 value so
--          a large growth rate off a tiny base is visible for what it is.
--          Pairs with no trade in 2014 get NULL, not a made-up rate.
-- Exported as track_d_sector_partner_cagr.csv.
-- ============================================================
DROP VIEW IF EXISTS v_track_d_sector_partner_cagr;
CREATE VIEW v_track_d_sector_partner_cagr AS
WITH yearly AS (
    SELECT
        sector,
        partner_desc,
        ref_year,
        SUM(fob_value) AS value_usd
    FROM clean_track_d_india_partner_sector
    WHERE aggr_level = 6 AND ref_year IN (2014, 2023)
    GROUP BY sector, partner_desc, ref_year
),
paired AS (
    SELECT
        sector,
        partner_desc,
        MAX(value_usd) FILTER (WHERE ref_year = 2014) AS value_2014,
        MAX(value_usd) FILTER (WHERE ref_year = 2023) AS value_2023
    FROM yearly
    GROUP BY sector, partner_desc
)
SELECT
    sector,
    partner_desc,
    ROUND(value_2014 / 1e6, 1) AS value_2014_mn,
    ROUND(value_2023 / 1e6, 1) AS value_2023_mn,
    ROUND(100.0 * (POWER(value_2023 / NULLIF(value_2014, 0), 1.0 / 9) - 1), 2) AS cagr_pct
FROM paired
ORDER BY sector, cagr_pct DESC NULLS LAST;

SELECT * FROM v_track_d_sector_partner_cagr;


-- ============================================================
-- Validation — run before trusting the queries above
-- ============================================================

-- V1. Partner coverage and series completeness. Expect 20 partners, no
--     World (partner_code 0), and 10 years for every partner. The partner
--     set is asserted in 01 validation 6; the ten years are asserted here
--     (23/09/2026).
DO $$
DECLARE lo bigint; hi bigint;
BEGIN
    SELECT MIN(n), MAX(n) INTO lo, hi FROM (
        SELECT partner_code, COUNT(DISTINCT ref_year) AS n
        FROM clean_track_d_india_partner_sector GROUP BY partner_code) y;
    IF lo <> 10 OR hi <> 10 THEN
        RAISE EXCEPTION '06 V1: years per partner range % to %, expected 10', lo, hi;
    END IF;
    RAISE NOTICE '06 V1 PASSED: all 20 Track D partners carry 10 years.';
END $$;

SELECT
    COUNT(DISTINCT partner_code)                                     AS partners,
    COUNT(*) FILTER (WHERE partner_code = 0)                         AS world_rows,
    MIN(years_present)                                               AS min_years_per_partner,
    MAX(years_present)                                               AS max_years_per_partner
FROM clean_track_d_india_partner_sector d
JOIN (
    SELECT partner_code, COUNT(DISTINCT ref_year) AS years_present
    FROM clean_track_d_india_partner_sector
    GROUP BY partner_code
) y USING (partner_code);

-- V2. Aggregation level and flag partition. Expect: only level 6;
--     both_true = 0, neither_true = 0, reported + aggregate = 225298.
SELECT
    aggr_level,
    COUNT(*)                                                     AS rows_at_level,
    COUNT(*) FILTER (WHERE is_reported AND is_aggregate)         AS both_true,
    COUNT(*) FILTER (WHERE NOT is_reported AND NOT is_aggregate) AS neither_true,
    COUNT(*) FILTER (WHERE is_reported)                          AS reported_rows,
    COUNT(*) FILTER (WHERE is_aggregate)                         AS aggregate_rows
FROM clean_track_d_india_partner_sector
GROUP BY aggr_level;

-- V3. Cross-track reconciliation vs Track C (same partners, HS2, pulled
--     25/08/2026). Track D summed over a sector's HS6 rows for a (partner,
--     year) should match Track C's corresponding HS2 chapter(s) for that
--     partner. Reported per sector as the worst absolute % divergence over
--     all 200 partner-years. Result at build time (assumption 7): petroleum
--     0.00 / textiles 0.18 / pharma 0.97 / gems 1.95 / engineering 11.54.
--     Eleven partner-years exceed 1%: ten engineering 2022, one gems 2022.
--     Direction is never materially positive (HS6 sum <= HS2 chapter): 332
--     of the 1,000 partner-years are positive, but the largest is 0.002%
--     (USD 1, Maldives gems 2014) — rounding, not value. This said "always
--     negative" until 23/09/2026.
--
--     The join below is inner, so a sector-year present in one track and not
--     the other would vanish from the comparison instead of failing it. That
--     is a no-op on this data — both panels hold the same 20 partners (01
--     validation 6) and 10 years for every partner (06 V1 for D; Track C is
--     complete per 04 V3) — and the assertion after this query checks the
--     join returns all 1,000 partner-years. Until 23/09/2026 this comment
--     said 01 validation 6 asserted both partners and years; it was a plain
--     SELECT, and it covers the partner set only.
DROP VIEW IF EXISTS v_track_d_reconciliation_vs_c;
CREATE VIEW v_track_d_reconciliation_vs_c AS
WITH d AS (
    SELECT sector, partner_code, ref_year, SUM(fob_value) AS d_value
    FROM clean_track_d_india_partner_sector
    WHERE aggr_level = 6
    GROUP BY sector, partner_code, ref_year
),
c AS (
    SELECT
        CASE
            WHEN cmd_code = '27' THEN 'petroleum_products'
            WHEN cmd_code = '30' THEN 'pharmaceuticals'
            WHEN cmd_code = '71' THEN 'gems_jewellery'
            WHEN cmd_code IN ('84', '85') THEN 'engineering_machinery'
            WHEN cmd_code BETWEEN '50' AND '63' THEN 'textiles'
        END AS sector,
        partner_code,
        ref_year,
        SUM(fob_value) AS c_value
    FROM clean_track_c_india_partner_view
    WHERE aggr_level = 2
    GROUP BY 1, 2, 3
),
joined AS (
    SELECT
        d.sector, d.partner_code, d.ref_year, d.d_value, c.c_value,
        100.0 * (d.d_value - c.c_value) / NULLIF(c.c_value, 0) AS pct_diff
    FROM d
    JOIN c USING (sector, partner_code, ref_year)
)
SELECT
    sector,
    COUNT(*)                                   AS partner_years,
    ROUND(MIN(pct_diff), 2)                    AS min_pct_diff,
    ROUND(MAX(pct_diff), 2)                    AS max_pct_diff,
    ROUND(MAX(ABS(pct_diff)), 2)               AS worst_abs_pct_diff,
    COUNT(*) FILTER (WHERE ABS(pct_diff) > 1)  AS partner_years_over_1pct
FROM joined
GROUP BY sector
ORDER BY worst_abs_pct_diff DESC;

SELECT * FROM v_track_d_reconciliation_vs_c;

-- V3 assertion (added 23/09/2026). Holds the data to what the findings and
-- README publish: 1,000 partner-years compared, worst divergence 11.54%,
-- eleven over 1%. Not an export — the view exists so the assertion reads the
-- same numbers the query prints.
DO $$
DECLARE n bigint; worst numeric; over1 bigint;
BEGIN
    SELECT SUM(partner_years), MAX(worst_abs_pct_diff), SUM(partner_years_over_1pct)
      INTO n, worst, over1
    FROM v_track_d_reconciliation_vs_c;
    IF n <> 1000 OR worst > 11.54 OR over1 <> 11 THEN
        RAISE EXCEPTION '06 V3: % partner-years, worst % percent, % over 1 percent (expected 1000 / <= 11.54 / 11)', n, worst, over1;
    END IF;
    RAISE NOTICE '06 V3 PASSED: 1000 partner-years, worst % percent, 11 over 1 percent.', worst;
END $$;

-- V4. Panel coverage vs Track B (India -> World, same HS6 rows, pulled
--     25/08/2026). Track D summed over all 20 partners as a share of Track
--     B's sector total, per year. This is the "share of what" behind every
--     Q1/Q2 percentage. Expect roughly the 60-65% band Track C showed, but
--     per sector it will vary — that variation is itself a finding. At build
--     time, 2023: textiles 70.2 / engineering 68.9 / gems 67.9 / petroleum
--     58.8 / pharma 57.0. Pharma's low coverage matters: the 20-partner
--     panel misses ~43% of India's pharma exports, so "USA = 62% of the
--     panel" (Q1) is NOT "USA = 62% of India's pharma exports".
DROP VIEW IF EXISTS v_track_d_panel_coverage;
CREATE VIEW v_track_d_panel_coverage AS
WITH d AS (
    SELECT sector, ref_year, SUM(fob_value) AS panel_value
    FROM clean_track_d_india_partner_sector
    WHERE aggr_level = 6
    GROUP BY sector, ref_year
),
b AS (
    SELECT sector, ref_year, SUM(fob_value) AS world_value
    FROM clean_track_b_india_sector_detail
    WHERE aggr_level = 6 AND partner_code = 0
    GROUP BY sector, ref_year
)
SELECT
    d.sector,
    d.ref_year,
    ROUND(d.panel_value / 1e9, 3)                                   AS panel_bn,
    ROUND(b.world_value / 1e9, 3)                                   AS world_bn,
    ROUND(100.0 * d.panel_value / NULLIF(b.world_value, 0), 1)      AS panel_coverage_pct
FROM d
JOIN b USING (sector, ref_year)
ORDER BY d.sector, d.ref_year;

SELECT * FROM v_track_d_panel_coverage;

-- V4 assertion (added 23/09/2026): the published coverage ranges — 57.0 to
-- 70.2% of each sector's exports in 2023, 52.3 to 71.3% over all fifty
-- sector-years.
DO $$
DECLARE n bigint; lo numeric; hi numeric; lo23 numeric; hi23 numeric;
BEGIN
    SELECT COUNT(*), MIN(panel_coverage_pct), MAX(panel_coverage_pct),
           MIN(panel_coverage_pct) FILTER (WHERE ref_year = 2023),
           MAX(panel_coverage_pct) FILTER (WHERE ref_year = 2023)
      INTO n, lo, hi, lo23, hi23
    FROM v_track_d_panel_coverage;
    IF n <> 50 OR lo < 52.3 OR hi > 71.3 OR lo23 < 57.0 OR hi23 > 70.2 THEN
        RAISE EXCEPTION '06 V4: % sector-years, range % to %, 2023 % to % (expected 50, 52.3-71.3, 2023 57.0-70.2)', n, lo, hi, lo23, hi23;
    END IF;
    RAISE NOTICE '06 V4 PASSED: coverage % to % percent (2023: % to %).', lo, hi, lo23, hi23;
END $$;
