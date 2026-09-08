-- 02_track_a_export_value_trend.sql
-- Track A analysis: India vs comparators (China, Bangladesh, Vietnam) —
-- total export value trend, 2014-2023 (Q1/Q2, HS2 aggregated to a single
-- country-year total), plus each country's top HS2 export categories (Q3),
-- covering the "top categories and trends" scope stated in the README.
--
-- NOTE: sql/05_export_results.sql re-states several of the queries below in
-- order to write them out as CSVs. If you change a query here, rerun 05 so the
-- committed files under data/processed/ do not silently go stale.
--
-- Assumptions made here (flagging before running, not after):
--   1. Totals include both directly-reported chapter values (is_reported
--      = true) and Comtrade-derived aggregate rows (is_aggregate = true).
--      Note what is_aggregate actually means: the record was COMPUTED BY
--      ROLLING UP more detailed lines. It describes how the figure was
--      assembled, not whether it was estimated — estimation is carried
--      separately by legacy_estimation_flag, which is a different question
--      and is not filtered on here. These two flags are mutually exclusive
--      and together cover every row (verified against the raw CSV: 675
--      reported + 2607 aggregate = 3282, no overlap), so summing both
--      gives the most complete country-year total available rather than
--      an artificially undercounted one. 03 and 04 apply the same rule and
--      point back to this assumption for the definition.
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
--      rows are aggr_level = 2, no rollup rows present. The filter guards
--      against coarser rollup rows entering a level-2 sum if that ever
--      changes; it is not the double-counting guard and never was — that
--      is the UNIQUE index on (ref_year, reporter_code, cmd_code) declared
--      in 01. Not a fix to today's data (same pattern 03/04 apply to their
--      own pulls).
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


-- ============================================================
-- Query 4: decade CAGR and index to base year = 100
--
-- Query 2 answers "what happened in 2019". Neither of these does the thing a
-- reader actually wants from a ten-year benchmark, which is a single compound
-- number per country and a series that can be plotted on one axis.
--
-- Why indexing is not optional here: China (~USD 3.4tn in 2023), India
-- (431bn) and Bangladesh (40bn) cannot share an absolute axis. Plotted raw
-- this is one visible line and three hugging zero. Rebasing each country to
-- 100 at its own first year makes the four series directly comparable.
--
-- Bangladesh caveat (assumption 2): it has 2015-2018 only, so its base year
-- is 2015 and its CAGR spans 3 years, not 9. first_year, last_year and
-- years_present are returned precisely so a 4-year growth rate is never
-- silently read as a decade one — Bangladesh's 8.08% is not comparable to
-- Vietnam's 9.96% without saying over what.
--
-- Nominal USD throughout (assumption 6). The 2022 commodity spike inflates
-- any series ending in 2022; part of what reads as growth is price, not
-- volume, petroleum most of all.
-- ============================================================
WITH yearly AS (
    SELECT
        reporter_desc,
        reporter_iso,
        ref_year,
        SUM(fob_value) AS total_usd
    FROM clean_track_a_country_benchmark
    WHERE aggr_level = 2
    GROUP BY reporter_desc, reporter_iso, ref_year
),
bounds AS (
    SELECT
        reporter_iso,
        MIN(ref_year) AS first_year,
        MAX(ref_year) AS last_year,
        COUNT(*)      AS years_present
    FROM yearly
    GROUP BY reporter_iso
)
SELECT
    y.reporter_desc,
    b.first_year,
    b.last_year,
    b.years_present,
    ROUND(f.total_usd / 1e9, 1) AS first_year_bn,
    ROUND(l.total_usd / 1e9, 1) AS last_year_bn,
    -- CAGR over the country's OWN span, not an assumed 9 years. The exponent
    -- is 1/(last-first); with a 4-year Bangladesh series that divisor is 3.
    ROUND(
        100.0 * (
            POWER(l.total_usd / NULLIF(f.total_usd, 0),
                  1.0 / NULLIF(b.last_year - b.first_year, 0)) - 1
        ),
        2
    ) AS cagr_pct
FROM bounds b
JOIN yearly y ON y.reporter_iso = b.reporter_iso AND y.ref_year = b.last_year
JOIN yearly f ON f.reporter_iso = b.reporter_iso AND f.ref_year = b.first_year
JOIN yearly l ON l.reporter_iso = b.reporter_iso AND l.ref_year = b.last_year
ORDER BY cagr_pct DESC;


-- ============================================================
-- Query 4b: full indexed series, each country rebased to 100 at its own
--            first available year. This is the series to plot.
-- ============================================================
WITH yearly AS (
    SELECT
        reporter_desc,
        reporter_iso,
        ref_year,
        SUM(fob_value) AS total_usd
    FROM clean_track_a_country_benchmark
    WHERE aggr_level = 2
    GROUP BY reporter_desc, reporter_iso, ref_year
),
based AS (
    SELECT
        reporter_desc,
        ref_year,
        total_usd,
        FIRST_VALUE(total_usd) OVER (
            PARTITION BY reporter_iso ORDER BY ref_year
        ) AS base_usd,
        MIN(ref_year) OVER (PARTITION BY reporter_iso) AS base_year
    FROM yearly
)
SELECT
    reporter_desc,
    ref_year,
    base_year,
    ROUND(total_usd / 1e9, 1)                              AS total_bn,
    ROUND(100.0 * total_usd / NULLIF(base_usd, 0), 1)      AS index_base_100
FROM based
ORDER BY reporter_desc, ref_year;


-- ============================================================
-- Validation — run before trusting the queries above
-- ============================================================

-- V1a. Estimation sensitivity, by country-year.
--      The README states the raw data carries flags that distinguish
--      as-reported figures from filled-in ones. This is where that claim is
--      exercised rather than asserted. legacy_estimation_flag takes only two
--      values in this pull: 0 (as reported) and 4 (estimated by Comtrade).
--
--      Read estimated_pct as a REGIME MARKER, not a gradient. Almost every
--      country-year is either ~0% or ~90-100%, not somewhere in between:
--      India is 0% through 2018 and 79-100% from 2019; Vietnam switches on in
--      2018 and back down to 11-19% in 2022-23; China flips on in 2016, off
--      again in 2017, then on from 2018. Bangladesh is 0% in 2015 and ~90%
--      for 2016-2018.
--
--      Consequence for any 2014-vs-2023 comparison: the two endpoints are not
--      constructed the same way. India's 2014 total is entirely as-reported;
--      its 2023 total is 78.8% Comtrade-estimated. That does not invalidate
--      the comparison — these are the standard published figures — but it is
--      a caveat that belongs next to the growth number, not in a footnote.
WITH by_country_year AS (
    SELECT
        reporter_iso,
        ref_year,
        SUM(fob_value)                                                        AS total_usd,
        COALESCE(SUM(fob_value) FILTER (WHERE legacy_estimation_flag = 4), 0) AS estimated_usd
    FROM clean_track_a_country_benchmark
    WHERE aggr_level = 2
    GROUP BY reporter_iso, ref_year
)
SELECT
    reporter_iso,
    ref_year,
    ROUND(total_usd / 1e9, 1)                              AS total_bn,
    ROUND((total_usd - estimated_usd) / 1e9, 1)            AS as_reported_bn,
    ROUND(100.0 * estimated_usd / NULLIF(total_usd, 0), 1) AS estimated_pct
FROM by_country_year
ORDER BY reporter_iso, ref_year;

-- V1b. Estimation sensitivity, decade summary per country.
--      first_flagged_year is the column that makes the regime change visible
--      in a single row: nothing is flagged before it, most things after it.
WITH by_country AS (
    SELECT
        reporter_iso,
        SUM(fob_value)                                                        AS total_usd,
        COALESCE(SUM(fob_value) FILTER (WHERE legacy_estimation_flag = 4), 0) AS estimated_usd,
        COUNT(*)                                                              AS rows_all,
        COUNT(*) FILTER (WHERE legacy_estimation_flag = 4)                    AS rows_estimated,
        MIN(ref_year) FILTER (WHERE legacy_estimation_flag = 4)               AS first_flagged_year
    FROM clean_track_a_country_benchmark
    WHERE aggr_level = 2
    GROUP BY reporter_iso
)
SELECT
    reporter_iso,
    ROUND(total_usd / 1e9, 1)                              AS decade_total_bn,
    ROUND(100.0 * estimated_usd / NULLIF(total_usd, 0), 1) AS estimated_pct,
    rows_estimated,
    rows_all,
    first_flagged_year
FROM by_country
ORDER BY estimated_pct DESC;

-- V2. Flag partition check. is_reported and is_aggregate must be mutually
--     exclusive and jointly exhaustive, which is what assumption 1 relies on.
--     Expect: both_true = 0, neither_true = 0, reported + aggregate = 3282.
--     Note this is a DIFFERENT question from V1 above — is_aggregate describes
--     how a figure was assembled (rolled up), legacy_estimation_flag describes
--     whether it was estimated. Rows can be aggregate and as-reported, or
--     reported and estimated; the two axes are independent.
SELECT
    COUNT(*) FILTER (WHERE is_reported AND is_aggregate)         AS both_true,
    COUNT(*) FILTER (WHERE NOT is_reported AND NOT is_aggregate) AS neither_true,
    COUNT(*) FILTER (WHERE is_reported)                          AS reported_rows,
    COUNT(*) FILTER (WHERE is_aggregate)                         AS aggregate_rows,
    COUNT(*)                                                     AS total_rows
FROM clean_track_a_country_benchmark;
