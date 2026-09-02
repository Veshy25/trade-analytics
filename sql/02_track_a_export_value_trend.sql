-- 02_track_a_export_value_trend.sql
-- Track A analysis: India vs comparators (China, Bangladesh, Vietnam) —
-- total export value trend, 2014-2023 (Q1/Q2, HS2 aggregated to a single
-- country-year total), plus each country's top HS2 export categories (Q3),
-- covering the "top categories and trends" scope stated in the README.
--
-- Assumptions made here (flagging before running, not after):
--   1. Totals include both directly-reported chapter values (is_reported
--      = true) and Comtrade's own aggregate estimates for gaps
--      (is_aggregate = true). These two flags are mutually exclusive and
--      together cover every row (verified against the raw CSV: 675
--      reported + 2607 aggregate = 3282, no overlap), so summing both
--      gives the most complete country-year total available rather than
--      an artificially undercounted one.
--   2. Bangladesh only has data for 2015-2018 in this pull (India, China,
--      Vietnam have the full 2014-2023 range) - this is a genuine gap in
--      what UN Comtrade holds for Bangladesh over this window, not a pull
--      error (verified against the raw CSV: BGD rows only exist for
--      refYear 2015-2018). Any chart or narrative built on this query
--      needs to caveat Bangladesh's shorter series rather than imply a
--      10-year comparison across all four countries.
--   3. Totals sum aggr_level = 2 rows only (HS2 chapters). The pull used
--      cmdCode='AG2' for all four reporters, so the table should be
--      entirely level 2 — verified: 100% of clean_track_a_country_benchmark
--      rows are aggr_level = 2, no rollup rows present. The filter is a
--      guard against double-counting if that ever changes, not a fix to
--      today's data (same pattern 03/04 apply to their own pulls).
--   4. Query 2's growth divisor is wrapped in NULLIF(...,0), matching 03/04's
--      pattern, so a zero or missing prior-year base returns NULL rather
--      than raising an error. No reporter-year currently sums to 0 or NULL
--      in this data, so this is a consistency/future-proofing fix, not a
--      correction to a live bug.
--   5. Query 3 ranks each country's HS2 chapters by 2023 value (full-period
--      total shown alongside), same shape as 03's Q4 (top products per
--      sector) and 04's Q5b (top chapters per partner). Uses ROW_NUMBER(),
--      not RANK(): Bangladesh has no 2023 row at all (assumption 2), so
--      every one of its chapters ties on a NULL 2023 value — RANK() would
--      let all ~97 chapters through the "top 10" filter instead of 10.
--      ROW_NUMBER() with value_2014_2023_usd as the tie-break caps
--      Bangladesh at its top 10 chapters by full-period value instead.

-- ============================================================
-- Query 1: total export value by country and year
-- ============================================================
SELECT
    reporter_desc,
    ref_year,
    SUM(fob_value) AS total_export_value_usd
FROM clean_track_a_country_benchmark
WHERE aggr_level = 2
GROUP BY reporter_desc, ref_year
ORDER BY reporter_desc, ref_year;

-- ============================================================
-- Query 2: same totals, with year-on-year growth %
--
-- LAG() pulls each country's PRIOR-year total into the same row, so
-- growth is calculated within each reporter's own year sequence
-- (PARTITION BY reporter_desc) rather than comparing across countries.
-- For Bangladesh, LAG() operates on the row order within its partition,
-- not the calendar year value - so 2016's "prior year" correctly
-- resolves to 2015 (both present, contiguous) even though 2014 is
-- missing entirely. The first year in each country's series will show
-- prior_year_value_usd and yoy_growth_pct as NULL, since there's nothing
-- before it in the data - that's expected, not a bug.
-- ============================================================
WITH yearly_totals AS (
    SELECT
        reporter_desc,
        ref_year,
        SUM(fob_value) AS total_export_value_usd
    FROM clean_track_a_country_benchmark
    WHERE aggr_level = 2
    GROUP BY reporter_desc, ref_year
)
SELECT
    reporter_desc,
    ref_year,
    total_export_value_usd,
    LAG(total_export_value_usd) OVER (
        PARTITION BY reporter_desc ORDER BY ref_year
    ) AS prior_year_value_usd,
    ROUND(
        100.0 * (
            total_export_value_usd
            - LAG(total_export_value_usd) OVER (
                PARTITION BY reporter_desc ORDER BY ref_year
              )
        ) / NULLIF(
            LAG(total_export_value_usd) OVER (
                PARTITION BY reporter_desc ORDER BY ref_year
            ),
            0
        ),
        1
    ) AS yoy_growth_pct
FROM yearly_totals
ORDER BY reporter_desc, ref_year;

-- ============================================================
-- Query 3: top 10 HS2 export categories per country
--          ranked on 2023 value; full-period total shown alongside
-- ============================================================
WITH chapter_totals AS (
    SELECT
        reporter_desc,
        cmd_code,
        cmd_desc,
        SUM(fob_value) FILTER (WHERE ref_year = 2023) AS value_2023_usd,
        SUM(fob_value)                                AS value_2014_2023_usd
    FROM clean_track_a_country_benchmark
    WHERE aggr_level = 2
    GROUP BY reporter_desc, cmd_code, cmd_desc
),
ranked AS (
    SELECT
        ct.*,
        -- ROW_NUMBER(), not RANK(): for Bangladesh (no 2023 data at all,
        -- so every value_2023_usd is NULL) RANK() would tie every chapter at
        -- rank 1 and the "<= 10" filter below would let all ~97 chapters
        -- through. ROW_NUMBER() plus the value_2014_2023_usd tie-break
        -- caps Bangladesh's rows at 10, ordered by full-period value —
        -- a defensible fallback given it has no current-year figure.
        ROW_NUMBER() OVER (
            PARTITION BY reporter_desc
            ORDER BY value_2023_usd DESC NULLS LAST, value_2014_2023_usd DESC
        ) AS rank_in_country_2023
    FROM chapter_totals ct
)
SELECT
    reporter_desc,
    rank_in_country_2023,
    cmd_code,
    cmd_desc,
    value_2023_usd,
    value_2014_2023_usd
FROM ranked
WHERE rank_in_country_2023 <= 10
ORDER BY reporter_desc, rank_in_country_2023;
