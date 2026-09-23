-- 02_track_a_export_value_trend.sql
-- Track A analysis: India vs comparators (China, Bangladesh, Vietnam) —
-- total export value trend, 2014-2023 (Q1/Q2, HS2 aggregated to a single
-- country-year total), plus each country's top HS2 export categories (Q3),
-- covering the "top categories and trends" scope stated in the README, plus
-- the chapters behind the 2023 fall (Q5) and each chapter's contribution to
-- the decade's growth (Q6).
--
-- NOTE on views (23/09/2026): every result set exported to data/processed/ is
-- defined ONCE here, as a view (v_track_a_*), and sql/08 only copies the view
-- out. Until this date 08 re-stated each query as a one-line copy, and two of
-- those copies had drifted from the queries they were named after (a missing
-- COALESCE in the Track E chapter balance, and different rounding here). The
-- views are the only objects this file creates; they read clean_* only. If you
-- change a view, rerun 08 so the committed CSVs follow.
--
-- Assumptions made here (flagging before running, not after):
--   1. Totals include both directly-reported chapter values (is_reported
--      = true) and Comtrade-derived aggregate rows (is_aggregate = true).
--      Note what is_aggregate actually means: the record was COMPUTED BY
--      ROLLING UP more detailed lines. It describes how the figure was
--      assembled, not whether it was estimated. Nothing in this pull marks
--      a VALUE as estimated at all: legacy_estimation_flag, which this file
--      treated as that marker until 17/09/2026, is a quantity/net-weight
--      code — see V1a, where the misreading is set out and corrected.
--      These two flags are mutually exclusive
--      and together cover every row (verified against the raw CSV: 675
--      reported + 2607 aggregate = 3282, no overlap), so summing both
--      gives the most complete country-year total available rather than
--      an artificially undercounted one. 03 and 04 apply the same rule and
--      point back to this assumption for the definition.
--   2. Bangladesh only has data for 2015-2018 in this pull (India, China,
--      Vietnam have the full 2014-2023 range). Any chart or narrative built
--      on this query needs to caveat Bangladesh's shorter series rather than
--      imply a 10-year comparison across all four countries.
--
--      On the claim that this is "a genuine gap in what UN Comtrade holds,
--      not a pull error" — narrowed 17/09/2026. The evidence originally
--      offered was that BGD rows exist only for refYear 2015-2018 in the raw
--      CSV, which is circular: the CSV is the pull, so it cannot testify that
--      the pull was complete. What can be said independently is that WITS
--      carries no Bangladesh merchandise export total after 2015, so the
--      sparseness is not an artefact of this project's request. Treat
--      "genuine gap" as well-supported but not proven here.
--
--      Year labelling — RESOLVED 23/09/2026. From 17/09/2026 this assumption
--      recorded that WITS showed Bangladesh's latest total (31,734,162.42
--      thousand USD) under the year 2016 while this pull holds it under 2015.
--      Re-checked against the WITS page source: the value is labelled 2015
--      (series entry Year '2015', Export 31734162.419), the 2015 profile page
--      headlines it as 2015, and the 2016 page has no export figure of its
--      own — it only repeats the chart series that ends in 2015. That page
--      is the likely source of the earlier misreading. WITS and this pull
--      agree on the year; there is no off-by-one.
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
--   6. All values are nominal USD, exporter-reported FOB. No deflator is
--      applied anywhere in this project (that would need a price index the
--      pull does not include), so the 2022 commodity spike sits inside every
--      series and part of what reads as 2014-to-2023 growth is price rather
--      than volume, petroleum most of all. Query 4 and 4b, the CAGR and
--      indexed series, are the figures most exposed to this. Stated again in
--      the README scope table and the key_findings.md preamble.
--   7. HS descriptions are NOT stable across the decade, and TWO editions
--      move them, not one. The five HS2 chapter rewordings (15, 16, 24, 84,
--      88) are all HS 2022, from ref_year 2022 onward — e.g. 84 changed from
--      "Nuclear reactors, boilers, machinery ..." to "Machinery and
--      mechanical appliances, boilers, nuclear reactors ...". The 73 HS6
--      products reworded in Track B/D are NOT: 42 of them change at 2017
--      (the HS 2017 edition, classificationCode H4 -> H5) and 34 at 2022
--      (HS 2022, H5 -> H6), three codes (570490, 847510, 852352) changing
--      in both years — 847510 and 852352 revert to their pre-2017 wording.
--      This file said "HS 2022" for the HS6 count until 17/09/2026, which
--      was wrong: the worked example below, petroleum 270750, is itself a
--      2017 change ("ASTM D 86 method" -> "ISO 3405 method (equivalent to
--      the ASTM D 86 method)"). The edition each row was filed under is in
--      classificationCode, carried forward on Track B and mapped in 01
--      validation 7. Any
--      multi-year GROUP BY that includes cmd_desc therefore splits one code
--      into two rows and silently truncates the full-period sum to the years
--      sharing the latest wording. Query 3 grouped that way until
--      15/09/2026: China's HS 84 full-period value read 1,062.6bn instead of
--      4,385.0bn (India 56.8 vs 197.7, Vietnam 61.7 vs 169.0); 2023 values
--      and all ranks were unaffected. The fix groups on cmd_code only and
--      shows the latest year's description. Found during Phase 2 (07 Q4 had
--      the same bug); the correction is kept visible here, per the README.
--
--      The fix assumes the CODE is stable even where its wording is not.
--      At HS2 that holds: all 97 chapters exist in every year. At HS6 it does
--      NOT (added 23/09/2026). Each HS edition also splits, merges and retires
--      codes — e.g. mobile phones were 851712 until 2021 and 851713
--      (smartphones) / 851714 (other) from 2022. Of the codes Track B shows
--      with no 2023 row, most (32 of 37 in engineering, 30 of 37 in textiles,
--      8 of 10 in pharmaceuticals) last appear in 2016 or 2021, the final year
--      before an edition change. So any per-code series or count that spans
--      2016/2017 or 2021/2022 at HS6 is not like-for-like: a code that
--      "disappears" was usually retired or split, not stopped being exported.
--      This project does not map codes across editions (that would need the
--      UNSD HS correlation tables); product-level claims are kept within a
--      single edition or stated as code counts, never as product counts.

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
-- yoy_growth_pct as NULL, since there's nothing before it in the data -
-- that's expected, not a bug. Totals are in USD bn to 3 dp; Query 1 above
-- keeps the unrounded dollars (the figure finding 11 matches to WITS).
-- ============================================================
-- Exported as data/processed/track_a_country_year_totals.csv (sql/08).
DROP VIEW IF EXISTS v_track_a_country_year_totals;
CREATE VIEW v_track_a_country_year_totals AS
WITH yearly_totals AS (
    SELECT
        reporter_desc,
        ref_year,
        SUM(fob_value) AS total_usd
    FROM clean_track_a_country_benchmark
    WHERE aggr_level = 2
    GROUP BY reporter_desc, ref_year
)
SELECT
    reporter_desc,
    ref_year,
    ROUND(total_usd / 1e9, 3) AS total_export_value_usd_bn,
    -- growth is computed on the unrounded totals, then rounded
    ROUND(
        100.0 * (
            total_usd
            - LAG(total_usd) OVER (PARTITION BY reporter_desc ORDER BY ref_year)
        ) / NULLIF(
            LAG(total_usd) OVER (PARTITION BY reporter_desc ORDER BY ref_year),
            0
        ),
        1
    ) AS yoy_growth_pct
FROM yearly_totals
ORDER BY reporter_desc, ref_year;

SELECT * FROM v_track_a_country_year_totals;

-- ============================================================
-- Query 3: top 10 HS2 export categories per country
--          ranked on 2023 value; full-period total shown alongside
--
-- rank_basis (added 23/09/2026) says what each rank was computed on. For
-- Bangladesh, which has no 2023 data (assumption 2), rank_2023 is a
-- full-period rank and value_2023_bn is blank — the column name alone
-- implied a 2023 ranking that does not exist.
-- ============================================================
DROP VIEW IF EXISTS v_track_a_top10_chapters;
CREATE VIEW v_track_a_top10_chapters AS
WITH chapter_totals AS (
    SELECT
        reporter_desc,
        cmd_code,
        -- latest wording, not a GROUP BY key (assumption 7)
        (ARRAY_AGG(cmd_desc ORDER BY ref_year DESC))[1]  AS cmd_desc,
        SUM(fob_value) FILTER (WHERE ref_year = 2023) AS value_2023_usd,
        SUM(fob_value)                                AS value_2014_2023_usd
    FROM clean_track_a_country_benchmark
    WHERE aggr_level = 2
    GROUP BY reporter_desc, cmd_code
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
        ) AS rnk,
        BOOL_OR(value_2023_usd IS NOT NULL) OVER (PARTITION BY reporter_desc) AS has_2023
    FROM chapter_totals ct
)
SELECT
    reporter_desc,
    rnk                                   AS rank_2023,
    cmd_code,
    cmd_desc,
    ROUND(value_2023_usd / 1e9, 3)        AS value_2023_bn,
    ROUND(value_2014_2023_usd / 1e9, 3)   AS value_2014_2023_bn,
    CASE WHEN has_2023 THEN '2023 value'
         ELSE 'full-period value (no 2023 data)' END AS rank_basis
FROM ranked
WHERE rnk <= 10
ORDER BY reporter_desc, rnk;

SELECT * FROM v_track_a_top10_chapters;


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
DROP VIEW IF EXISTS v_track_a_cagr;
CREATE VIEW v_track_a_cagr AS
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
    l.reporter_desc,
    b.first_year,
    b.last_year,
    b.years_present,
    ROUND(f.total_usd / 1e9, 3) AS first_year_bn,
    ROUND(l.total_usd / 1e9, 3) AS last_year_bn,
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
-- Two joins, not three: `l` is the last year (and supplies reporter_desc),
-- `f` the first. A third join on the same last-year key was carried here
-- until 17/09/2026 purely to read reporter_desc off it.
JOIN yearly f ON f.reporter_iso = b.reporter_iso AND f.ref_year = b.first_year
JOIN yearly l ON l.reporter_iso = b.reporter_iso AND l.ref_year = b.last_year
ORDER BY cagr_pct DESC;

SELECT * FROM v_track_a_cagr;


-- ============================================================
-- Query 4b: full indexed series, each country rebased to 100 at its own
--            first available year. This is the series to plot.
-- ============================================================
DROP VIEW IF EXISTS v_track_a_indexed_series;
CREATE VIEW v_track_a_indexed_series AS
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
    ROUND(total_usd / 1e9, 3)                              AS total_bn,
    ROUND(100.0 * total_usd / NULLIF(base_usd, 0), 1)      AS index_base_100
FROM based
ORDER BY reporter_desc, ref_year;

SELECT * FROM v_track_a_indexed_series;


-- ============================================================
-- Query 5: India's largest chapter movements, 2022 -> 2023 (added
--          17/09/2026). key_findings.md finding 3 attributes most of the
--          2023 fall to three chapters — petroleum, gems and iron & steel —
--          and until this query existed those three figures were derived
--          ad hoc and cited to a CSV that does not contain them. They are a
--          headline claim about the single biggest year-on-year move in the
--          series, so they get a named query and a committed result set like
--          everything else.
--
--          Grouped on cmd_code only, never cmd_desc (assumption 7). Both
--          years sit inside HS 2022 here so no code is currently split, but
--          the pattern is the one that broke Q3, and a later pull could
--          extend the window across an edition boundary.
-- ============================================================
DROP VIEW IF EXISTS v_track_a_india_chapter_change_2022_2023;
CREATE VIEW v_track_a_india_chapter_change_2022_2023 AS
WITH india_chapter AS (
    SELECT
        cmd_code,
        (ARRAY_AGG(cmd_desc ORDER BY ref_year DESC))[1]      AS cmd_desc,
        SUM(fob_value) FILTER (WHERE ref_year = 2022)        AS value_2022_usd,
        SUM(fob_value) FILTER (WHERE ref_year = 2023)        AS value_2023_usd
    FROM clean_track_a_country_benchmark
    WHERE reporter_iso = 'IND'
      AND aggr_level = 2
    GROUP BY cmd_code
),
moved AS (
    SELECT
        ic.*,
        COALESCE(value_2023_usd, 0) - COALESCE(value_2022_usd, 0) AS change_usd,
        ROW_NUMBER() OVER (ORDER BY COALESCE(value_2023_usd,0) - COALESCE(value_2022_usd,0) ASC,  cmd_code) AS fall_rank,
        ROW_NUMBER() OVER (ORDER BY COALESCE(value_2023_usd,0) - COALESCE(value_2022_usd,0) DESC, cmd_code) AS rise_rank
    FROM india_chapter ic
)
SELECT
    CASE WHEN fall_rank <= 10 THEN 'fall' ELSE 'rise' END AS direction,
    CASE WHEN fall_rank <= 10 THEN fall_rank ELSE rise_rank END AS rank_on_side,
    cmd_code,
    cmd_desc,
    ROUND(value_2022_usd / 1e9, 2) AS value_2022_bn,
    ROUND(value_2023_usd / 1e9, 2) AS value_2023_bn,
    ROUND(change_usd / 1e9, 2)     AS change_bn
FROM moved
WHERE fall_rank <= 10 OR rise_rank <= 10
ORDER BY direction, rank_on_side;

SELECT * FROM v_track_a_india_chapter_change_2022_2023;


-- ============================================================
-- Query 6: each chapter's contribution to India's 2014 -> 2023 change
--          (added 23/09/2026, behind the headline).
--
--          The headline used to say India's growth was "concentrated in"
--          petroleum, quoting HS 27's 20.7% share of 2023 exports. That is a
--          LEVEL share. The question the headline was answering is about
--          GROWTH, and the level share does not answer it. This query does:
--          of the USD 113.9bn net increase, HS 27 supplied 27.0bn (23.7%),
--          while electrical machinery (85, 20.5%) and machinery (84, 13.8%)
--          together supplied 34.3%. Petroleum is the largest single
--          contributor, not the concentration of the growth.
--
--          pct_of_net_change is each chapter's change over the NET change,
--          so falling chapters carry negative shares and the column sums to
--          100 before rounding (100.3 as printed). share_2023_pct is the level share, kept alongside so the two
--          are never confused again. Grouped on cmd_code only (assumption 7);
--          all 97 chapters are present in both years for India.
-- ============================================================
DROP VIEW IF EXISTS v_track_a_india_chapter_contribution;
CREATE VIEW v_track_a_india_chapter_contribution AS
WITH ic AS (
    SELECT
        cmd_code,
        (ARRAY_AGG(cmd_desc ORDER BY ref_year DESC))[1]  AS cmd_desc,
        SUM(fob_value) FILTER (WHERE ref_year = 2014)    AS v14,
        SUM(fob_value) FILTER (WHERE ref_year = 2023)    AS v23
    FROM clean_track_a_country_benchmark
    WHERE reporter_iso = 'IND'
      AND aggr_level = 2
    GROUP BY cmd_code
),
tot AS (
    SELECT SUM(v14) AS t14, SUM(v23) AS t23 FROM ic
)
SELECT
    ROW_NUMBER() OVER (ORDER BY COALESCE(v23,0) - COALESCE(v14,0) DESC, cmd_code) AS rank_by_change,
    cmd_code,
    cmd_desc,
    ROUND(v14 / 1e9, 3)                                                    AS value_2014_bn,
    ROUND(v23 / 1e9, 3)                                                    AS value_2023_bn,
    ROUND((COALESCE(v23,0) - COALESCE(v14,0)) / 1e9, 3)                    AS change_bn,
    ROUND(100.0 * (COALESCE(v23,0) - COALESCE(v14,0)) / NULLIF(t23 - t14, 0), 1) AS pct_of_net_change,
    ROUND(100.0 * v23 / NULLIF(t23, 0), 1)                                 AS share_2023_pct
FROM ic CROSS JOIN tot
ORDER BY rank_by_change;

SELECT * FROM v_track_a_india_chapter_contribution;


-- ============================================================
-- Validation — run before trusting the queries above
-- ============================================================

-- V1a. Reporting basis and net-weight estimation exposure, by country-year.
--      CORRECTED 17/09/2026 — this block previously asserted something false,
--      and the correction is kept visible rather than quietly rewritten.
--
--      What it used to say. Until 17/09/2026 this validation read
--      legacy_estimation_flag = 4 as "estimated by Comtrade rather than
--      as-reported" and reported the share of export VALUE on those rows as
--      an estimation exposure — the number behind finding 12 and the
--      README's "reporting gaps get filled by estimation" paragraph.
--
--      Why that was wrong. legacyEstimationFlag is a quantity and net-weight
--      code, not a value code. UN Statistics Division, "Quantity and Weight
--      information in UN Comtrade" (October 2009), section 4.1:
--          0 = no estimation
--          2 = quantity estimation only
--          4 = net weight estimation only
--          6 = both quantity and net weight are estimated
--      Neither that document nor the 2019 methodology guide describes a flag
--      for an estimated value.
--
--      The data says the same without the document. On Track B, which carries
--      the flag and both modern booleans, every flag-2 row (162) is
--      quantity-only estimated, every flag-4 row (3,776) net-weight-only and
--      every flag-6 row (6,656) both. The reverse does NOT hold there either:
--      2,905 flag-0 Track B rows are estimated too (2 quantity-only, 1,187
--      net-weight-only, 1,716 both). This paragraph said "exactly ... no
--      exceptions" until 23/09/2026, which is true only in the flag-to-boolean
--      direction. On Track A the first query below asserts the same
--      containment.
--
--      The asymmetry matters and is easy to get wrong: the implication runs
--      ONE WAY. 552 Track A rows carry is_net_wgt_estimated = true with a
--      legacy flag of 0 — six reporter-years before 2019 (China 2015 and
--      2017, India 2017 and 2018, Viet Nam 2016 and 2017) where the boolean
--      is set and the legacy field was never back-filled. Flag 4 implies
--      net-weight estimation; net-weight estimation does not imply flag 4.
--      So flag 0 is not a clean "nothing estimated here" marker either.
--
--      And the sting: netWgt on this HS2 pull holds no positive value at all
--      (blank on 48.3% of Track A rows, exactly 0 on the remaining 51.7% —
--      see 01's header note). The flag marks estimation of a quantity this
--      track does not carry. It says nothing about the export values every
--      figure in this project is built from.
--
--      What IS a real change in construction, and is reported below, is the
--      is_reported -> is_aggregate switch: each reporter files chapter
--      figures directly for its first year or two, then Comtrade assembles
--      them by rolling up the reporter's HS6 detail. China switches at 2015,
--      Viet Nam and Bangladesh at 2016, India at 2017, and none switches
--      back. That is a genuine "the endpoints are not built the same way"
--      caveat for any 2014-vs-2023 comparison — which is the caveat the old
--      wording was reaching for with the wrong column.

-- V1a-i. Containment assertion: every flag-4 row must be net-weight
--        estimated. This is the claim the corrected reading rests on, so it
--        is asserted rather than described. The converse is NOT asserted —
--        see the note above.
DO $$
DECLARE n bigint;
BEGIN
    SELECT COUNT(*) INTO n
    FROM clean_track_a_country_benchmark
    WHERE legacy_estimation_flag = 4 AND NOT is_net_wgt_estimated;
    IF n <> 0 THEN
        RAISE EXCEPTION
            '02 V1a: % rows carry legacy_estimation_flag = 4 without is_net_wgt_estimated — the flag is not a net-weight code on this pull', n;
    END IF;
    RAISE NOTICE '02 V1a PASSED: all legacy_estimation_flag = 4 rows are net-weight-estimated rows.';
END $$;

-- V1a-ii. The country-year table itself. Exported as
--         data/processed/track_a_reporting_basis.csv (sql/08). rows_flag4 and
--         rows_netwgt_est were printed here but left out of the CSV until
--         23/09/2026; they are now in both, so the 552-row gap described
--         above can be read from a committed file.
DROP VIEW IF EXISTS v_track_a_reporting_basis;
CREATE VIEW v_track_a_reporting_basis AS
WITH by_country_year AS (
    SELECT
        reporter_desc,
        ref_year,
        SUM(fob_value)                                                          AS total_usd,
        COALESCE(SUM(fob_value) FILTER (WHERE is_net_wgt_estimated), 0)         AS netwgt_est_usd,
        COUNT(*)                                                                AS rows_all,
        COUNT(*) FILTER (WHERE is_aggregate)                                    AS rows_aggregate,
        COUNT(*) FILTER (WHERE is_reported)                                     AS rows_reported,
        COUNT(*) FILTER (WHERE legacy_estimation_flag = 4)                      AS rows_flag4,
        COUNT(*) FILTER (WHERE is_net_wgt_estimated)                            AS rows_netwgt_est
    FROM clean_track_a_country_benchmark
    WHERE aggr_level = 2
    GROUP BY reporter_desc, ref_year
)
SELECT
    reporter_desc,
    ref_year,
    ROUND(total_usd / 1e9, 3)                                   AS total_bn,
    -- Share of value sitting on rows whose NET WEIGHT Comtrade estimated.
    -- Not a share of estimated value; there is no such column.
    ROUND(100.0 * netwgt_est_usd / NULLIF(total_usd, 0), 1)     AS pct_value_on_netwgt_est_rows,
    ROUND(100.0 * rows_aggregate / NULLIF(rows_all, 0), 1)      AS pct_rows_is_aggregate,
    ROUND(100.0 * rows_reported  / NULLIF(rows_all, 0), 1)      AS pct_rows_is_reported,
    -- The gap between these two is the legacy field's under-population,
    -- not a difference in meaning.
    rows_flag4,
    rows_netwgt_est
FROM by_country_year
ORDER BY reporter_desc, ref_year;

SELECT * FROM v_track_a_reporting_basis;

-- V1b. Decade summary per country: when the construction basis switched.
--      basis_switch_year is the first year the reporter's chapter figures
--      arrive as Comtrade rollups instead of direct filings. Nothing before
--      it is an aggregate; nothing after it is not.
WITH by_country AS (
    SELECT
        reporter_desc,
        SUM(fob_value)                                                  AS total_usd,
        COALESCE(SUM(fob_value) FILTER (WHERE is_net_wgt_estimated), 0) AS netwgt_est_usd,
        COUNT(*)                                                        AS rows_all,
        COUNT(*) FILTER (WHERE is_net_wgt_estimated)                    AS rows_netwgt_est,
        MIN(ref_year) FILTER (WHERE is_aggregate)                       AS basis_switch_year,
        MIN(ref_year)                                                   AS first_year,
        MAX(ref_year)                                                   AS last_year
    FROM clean_track_a_country_benchmark
    WHERE aggr_level = 2
    GROUP BY reporter_desc
)
SELECT
    reporter_desc,
    first_year,
    last_year,
    basis_switch_year,
    ROUND(total_usd / 1e9, 1)                                AS decade_total_bn,
    ROUND(100.0 * netwgt_est_usd / NULLIF(total_usd, 0), 1)  AS pct_value_on_netwgt_est_rows,
    rows_netwgt_est,
    rows_all
FROM by_country
ORDER BY reporter_desc;

-- V2. Flag partition check. is_reported and is_aggregate must be mutually
--     exclusive and jointly exhaustive, which is what assumption 1 relies on.
--     Expect: both_true = 0, neither_true = 0, reported + aggregate = 3282.
--     Note this is a DIFFERENT question from the net-weight flags in V1
--     above. is_aggregate describes how a VALUE was assembled (rolled up from
--     HS6 detail); is_net_wgt_estimated and legacy_estimation_flag describe
--     whether a WEIGHT was estimated. The two axes are independent, and
--     neither marks an estimated value — see V1a.
SELECT
    COUNT(*) FILTER (WHERE is_reported AND is_aggregate)         AS both_true,
    COUNT(*) FILTER (WHERE NOT is_reported AND NOT is_aggregate) AS neither_true,
    COUNT(*) FILTER (WHERE is_reported)                          AS reported_rows,
    COUNT(*) FILTER (WHERE is_aggregate)                         AS aggregate_rows,
    COUNT(*)                                                     AS total_rows
FROM clean_track_a_country_benchmark;
