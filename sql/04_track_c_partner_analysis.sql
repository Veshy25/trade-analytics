-- 04_track_c_partner_analysis.sql
-- Track C analysis: India's HS2 exports to 20 major partner markets,
-- 2014-2023. Partners (ISO3): USA, ARE, CHN, BGD, MDV, GBR, DEU, NPL, SGP,
-- VNM, NLD, SAU, FRA, LKA, IDN, MYS, ITA, BEL, ZAF, JPN.
--
-- Source table: clean_track_c_india_partner_view (built in 01_data_cleaning.sql).
--
-- NOTE: sql/08_export_results.sql re-states several of the queries below in
-- order to write them out as CSVs. If you change a query here, rerun 08 so the
-- committed files under data/processed/ do not silently go stale.
--
-- Assumptions made here (flagging before running, not after):
--   1. This pull requested 20 named partners and NO World aggregate. So
--      every row is a real partner market, there is no World total to
--      exclude, and all "share" figures below are share-OF-THESE-20 by
--      construction — not shares of India's global exports.
--      Validation V5 quantifies panel coverage against Track A's India->World
--      total so the shares can be read in context.
--   2. Partner-year totals sum aggr_level = 2 rows (HS2 chapters). The pull
--      used cmdCode='AG2', so there are no all-commodities TOTAL rows to
--      double-count; the filter guards against coarser rollup rows entering
--      a level-2 sum. It is not the double-counting guard — that is the
--      UNIQUE index on (ref_year, partner_code, cmd_code) declared in 01.
--      Validation V2 shows the split.
--   3. Within aggr_level = 2, every row is summed regardless of is_reported
--      vs is_aggregate — same partition logic Track A established (V4
--      re-checks: no overlap, jointly exhaustive). See 02 assumption 1 for
--      what is_aggregate means — it is a rollup marker, not an estimation
--      marker.
--   4. Decade comparisons use 2014 (first) and 2023 (last). Validation V3
--      lists any partner with a short series to caveat (cf. Bangladesh in
--      Track A).
--   5. Values are USD, exporter-reported FOB.
--   6. Every growth / share ratio wraps its divisor in NULLIF(..., 0) so a
--      zero or missing base returns NULL rather than raising an error.


-- ============================================================
-- Query 1: export value to each partner, by year
-- ============================================================
SELECT
    partner_desc,
    ref_year,
    SUM(fob_value) AS total_export_value_usd
FROM clean_track_c_india_partner_view
WHERE aggr_level = 2
GROUP BY partner_desc, ref_year
ORDER BY partner_desc, ref_year;


-- ============================================================
-- Query 2: exports to each partner with year-on-year growth %
--           LAG() partitioned by partner; first year of each series is NULL
-- ============================================================
WITH partner_yearly AS (
    SELECT
        partner_desc,
        ref_year,
        SUM(fob_value) AS total_export_value_usd
    FROM clean_track_c_india_partner_view
    WHERE aggr_level = 2
    GROUP BY partner_desc, ref_year
)
SELECT
    partner_desc,
    ref_year,
    total_export_value_usd,
    LAG(total_export_value_usd) OVER (
        PARTITION BY partner_desc ORDER BY ref_year
    ) AS prior_year_value_usd,
    ROUND(
        100.0 * (
            total_export_value_usd
            - LAG(total_export_value_usd) OVER (PARTITION BY partner_desc ORDER BY ref_year)
        ) / NULLIF(
            LAG(total_export_value_usd) OVER (PARTITION BY partner_desc ORDER BY ref_year),
            0
        ),
        1
    ) AS yoy_growth_pct
FROM partner_yearly
ORDER BY partner_desc, ref_year;


-- ============================================================
-- Query 3: top partners ranked, with share of the tracked panel
--           latest year (2023) and full-period (2014-2023) totals
-- ============================================================
WITH partner_totals AS (
    SELECT
        partner_desc,
        SUM(fob_value) FILTER (WHERE ref_year = 2023) AS value_2023_usd,
        SUM(fob_value)                                AS value_2014_2023_usd
    FROM clean_track_c_india_partner_view
    WHERE aggr_level = 2
    GROUP BY partner_desc
)
SELECT
    partner_desc,
    value_2023_usd,
    -- ROW_NUMBER() throughout this file, matching 02 Q3: a league table of 20
    -- partners should read 1-20 with no repeated or skipped positions, and
    -- every rank here either drives a "top N" filter or is differenced
    -- against another rank — both of which a RANK() tie block corrupts.
    ROW_NUMBER() OVER (
        ORDER BY value_2023_usd DESC NULLS LAST, value_2014_2023_usd DESC
    ) AS rank_2023,
    ROUND(
        100.0 * value_2023_usd / NULLIF(SUM(value_2023_usd) OVER (), 0),
        1
    ) AS pct_of_tracked_2023,
    value_2014_2023_usd,
    ROW_NUMBER() OVER (
        ORDER BY value_2014_2023_usd DESC NULLS LAST, partner_desc
    ) AS rank_period,
    ROUND(
        100.0 * value_2014_2023_usd / NULLIF(SUM(value_2014_2023_usd) OVER (), 0),
        1
    ) AS pct_of_tracked_period
FROM partner_totals
ORDER BY rank_2023;


-- ============================================================
-- Query 4: partner concentration over time
--           top-5 partner share and HHI per year, across the 20-partner panel
--           plus a bounded estimate of the true whole-market HHI
--
-- Do NOT read hhi_panel against the bands quoted in 03 Query 5. Those bands
-- (<1500 unconcentrated, >2500 concentrated) assume shares sum to a whole
-- market. This panel is 62-64% of India's exports, so every share is inflated
-- by ~1.6x and HHI, being quadratic, by ~2.5x. Applying the bands to
-- hhi_panel would overstate concentration by more than the bands are wide.
--
-- The panel figure is still recoverable, though, rather than merely
-- unusable. If s_i are the panel shares and c is coverage (Track A's
-- India->World total is the denominator, computed in V5), then each partner's
-- true share is s_i * c, so:
--
--   hhi_true_lower = hhi_panel * c^2
--       the unobserved residual is spread thinly across many small markets
--       and contributes ~nothing. India's residual is ~37% split across
--       ~180 reporters, so this is the realistic end of the range.
--
--   hhi_true_upper = hhi_panel * c^2 + (1 - c)^2 * 10000
--       the entire residual is a single hidden partner. Implausible, but it
--       is a genuine ceiling: no arrangement of the unobserved markets can
--       push HHI above it.
--
-- The true value sits between. That range is what should be read against the
-- bands, and it is decisive: the upper bound peaks at 1889 (2022) and never
-- approaches the 2500 concentrated threshold, while the realistic lower bound
-- sits around 390-480. India's export markets are unconcentrated on this
-- measure under ANY assumption about the unobserved third of the market —
-- a stronger statement than the panel figure alone can support.
-- ============================================================
WITH partner_yearly AS (
    SELECT
        partner_desc,
        ref_year,
        SUM(fob_value) AS value_usd
    FROM clean_track_c_india_partner_view
    WHERE aggr_level = 2
    GROUP BY partner_desc, ref_year
),
shares AS (
    SELECT
        ref_year,
        partner_desc,
        value_usd / NULLIF(SUM(value_usd) OVER (PARTITION BY ref_year), 0) AS share,
        -- ROW_NUMBER() so "rnk <= 5" returns exactly five partners per year;
        -- a RANK() tie at 5th/6th would push six into top5_partner_share_pct.
        ROW_NUMBER() OVER (
            PARTITION BY ref_year ORDER BY value_usd DESC, partner_desc
        ) AS rnk
    FROM partner_yearly
),
panel_hhi AS (
    SELECT
        ref_year,
        SUM(share) FILTER (WHERE rnk <= 5) AS top5_share,
        SUM(share * share) * 10000         AS hhi_panel,
        SUM(value_usd)                     AS panel_value_usd
    FROM shares
    JOIN partner_yearly USING (ref_year, partner_desc)
    GROUP BY ref_year
),
india_world AS (
    -- Track A's India -> World HS2 total is the only whole-market denominator
    -- available in this project; Track C was pulled without a World row on
    -- purpose (assumption 1). This is the cross-track dependency noted in the
    -- README run order: 04 cannot be run before 02's clean table exists.
    SELECT ref_year, SUM(fob_value) AS world_value_usd
    FROM clean_track_a_country_benchmark
    WHERE reporter_iso = 'IND' AND aggr_level = 2
    GROUP BY ref_year
),
coverage AS (
    SELECT
        p.ref_year,
        p.top5_share,
        p.hhi_panel,
        p.panel_value_usd / NULLIF(w.world_value_usd, 0) AS c
    FROM panel_hhi p
    JOIN india_world w USING (ref_year)
)
SELECT
    ref_year,
    ROUND(100.0 * top5_share, 1) AS top5_partner_share_pct,
    ROUND(hhi_panel, 0)          AS hhi_panel,
    ROUND(100.0 * c, 1)          AS panel_coverage_pct,
    ROUND(hhi_panel * POWER(c, 2), 0)                            AS hhi_true_lower,
    ROUND(hhi_panel * POWER(c, 2) + POWER(1 - c, 2) * 10000, 0)  AS hhi_true_upper
FROM coverage
ORDER BY ref_year;


-- ============================================================
-- Query 5a: partner mix shift — rank in 2014 vs 2023 and the move
--            rank_improvement > 0 means the partner climbed the table
--            (its rank number got smaller)
-- ============================================================
WITH partner_year AS (
    SELECT
        partner_desc,
        ref_year,
        SUM(fob_value) AS value_usd
    FROM clean_track_c_india_partner_view
    WHERE aggr_level = 2
      AND ref_year IN (2014, 2023)
    GROUP BY partner_desc, ref_year
),
ranked AS (
    SELECT
        partner_desc,
        ref_year,
        value_usd,
        -- ROW_NUMBER(): these ranks are subtracted from each other below to
        -- give rank_improvement, so a tie block in either year would make the
        -- difference meaningless.
        ROW_NUMBER() OVER (
            PARTITION BY ref_year ORDER BY value_usd DESC, partner_desc
        ) AS rnk
    FROM partner_year
)
SELECT
    partner_desc,
    MAX(value_usd) FILTER (WHERE ref_year = 2014) AS value_2014_usd,
    MAX(rnk)       FILTER (WHERE ref_year = 2014) AS rank_2014,
    MAX(value_usd) FILTER (WHERE ref_year = 2023) AS value_2023_usd,
    MAX(rnk)       FILTER (WHERE ref_year = 2023) AS rank_2023,
    MAX(rnk) FILTER (WHERE ref_year = 2014)
        - MAX(rnk) FILTER (WHERE ref_year = 2023) AS rank_improvement
FROM ranked
GROUP BY partner_desc
ORDER BY rank_2023 NULLS LAST;


-- ============================================================
-- Query 5b: what India sells to its top 5 partners —
--            top 5 HS2 chapters per partner, 2023
-- ============================================================
WITH top_partners AS (
    SELECT partner_code, partner_desc
    FROM (
        SELECT
            partner_code,
            partner_desc,
            ROW_NUMBER() OVER (
                ORDER BY SUM(fob_value) FILTER (WHERE ref_year = 2023) DESC,
                         partner_desc
            ) AS rnk
        FROM clean_track_c_india_partner_view
        WHERE aggr_level = 2
        GROUP BY partner_code, partner_desc
    ) r
    WHERE rnk <= 5
),
chapter_values AS (
    SELECT
        c.partner_desc,
        c.cmd_code,
        c.cmd_desc,
        SUM(c.fob_value) AS value_2023_usd,
        ROW_NUMBER() OVER (
            PARTITION BY c.partner_desc ORDER BY SUM(c.fob_value) DESC, c.cmd_code
        ) AS chapter_rank
    FROM clean_track_c_india_partner_view c
    JOIN top_partners tp ON tp.partner_code = c.partner_code
    WHERE c.aggr_level = 2
      AND c.ref_year = 2023
    GROUP BY c.partner_desc, c.cmd_code, c.cmd_desc
)
SELECT
    partner_desc,
    chapter_rank,
    cmd_code,
    cmd_desc,
    value_2023_usd
FROM chapter_values
WHERE chapter_rank <= 5
ORDER BY partner_desc, chapter_rank;


-- ============================================================
-- Validation — run before trusting the queries above
-- ============================================================

-- V1. Partner coverage. Expect ~20 named partners and NO World (partner_code
--     = 0) row. If a code-0 row exists, add "AND partner_code <> 0" to every
--     query above.
SELECT
    partner_code,
    partner_desc,
    COUNT(*)      AS row_count,
    MIN(ref_year) AS first_year,
    MAX(ref_year) AS last_year
FROM clean_track_c_india_partner_view
GROUP BY partner_code, partner_desc
ORDER BY row_count DESC;

-- V2. Aggregation levels. Expect aggr_level = 2 only (HS2 chapters). Any
--     other level is unexpected for an AG2 pull — investigate before summing.
SELECT aggr_level, COUNT(*) AS row_count, SUM(fob_value) AS total_value_usd
FROM clean_track_c_india_partner_view
GROUP BY aggr_level
ORDER BY aggr_level;

-- V3. Partner series completeness. Any partner with years_present < 10 needs
--     its trend / growth charts caveated.
SELECT
    partner_desc,
    MIN(ref_year)            AS first_year,
    MAX(ref_year)            AS last_year,
    COUNT(DISTINCT ref_year) AS years_present
FROM clean_track_c_india_partner_view
WHERE aggr_level = 2
GROUP BY partner_desc
ORDER BY years_present, partner_desc;

-- V4. is_reported vs is_aggregate at HS2. overlap_rows must be 0 and
--     reported + aggregate must equal total_hs2_rows.
SELECT
    COUNT(*)                                             AS total_hs2_rows,
    COUNT(*) FILTER (WHERE is_reported)                  AS reported_rows,
    COUNT(*) FILTER (WHERE is_aggregate)                 AS aggregate_rows,
    COUNT(*) FILTER (WHERE is_reported AND is_aggregate) AS overlap_rows
FROM clean_track_c_india_partner_view
WHERE aggr_level = 2;

-- V5. Panel coverage: what share of India's TOTAL exports do these 20
--     partners represent? Track C has no World row, so this is measured
--     against Track A's India-to-World HS2 rows. A high, stable ratio means
--     the panel's shares approximate true destination shares; a low ratio
--     means read every "pct_of_tracked" column strictly as within-panel.
WITH tracked AS (
    SELECT ref_year, SUM(fob_value) AS tracked_partners_usd
    FROM clean_track_c_india_partner_view
    WHERE aggr_level = 2
    GROUP BY ref_year
),
india_world AS (
    SELECT ref_year, SUM(fob_value) AS india_world_usd
    FROM clean_track_a_country_benchmark
    WHERE reporter_iso = 'IND'
    GROUP BY ref_year
)
SELECT
    t.ref_year,
    t.tracked_partners_usd,
    w.india_world_usd,
    ROUND(100.0 * t.tracked_partners_usd / NULLIF(w.india_world_usd, 0), 1) AS tracked_pct_of_india_total
FROM tracked t
JOIN india_world w USING (ref_year)
ORDER BY t.ref_year;
