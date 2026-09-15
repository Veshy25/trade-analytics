-- 07_track_e_imports_trade_balance.sql
-- Track E analysis: imports and trade balance. Two import pulls (15/09/2026):
--   E1 — India, China, Bangladesh, Vietnam -> World, HS2   (mirror of Track A)
--   E2 — India <- the 20 Track C partners, HS2               (mirror of Track C)
-- joined to the Phase 1 export tables to produce balances. Phase 2.
--
-- NOTE: sql/08_export_results.sql re-states several of the queries below in
-- order to write them out as CSVs. If you change a query here, rerun 08 so the
-- committed files under data/processed/ do not silently go stale.
--
-- Assumptions made here (flagging before running, not after):
--   1. VALUATION BASIS DIFFERS. Exports are FOB (Track A/C, fob_value);
--      imports are CIF (E1/E2, cif_value — 01 validation 5 confirms
--      primary_value = cif_value on 100% of import rows). Every balance in
--      this file is FOB exports minus CIF imports. That is how published
--      merchandise balances are constructed, but the CIF side carries
--      freight and insurance the FOB side does not, so deficits are
--      overstated (and surpluses understated) by that margin — the README's
--      "Data reliability" section puts it at roughly 10-20% of the import
--      value. No adjustment is applied; the caveat travels with the number.
--   2. Row inclusion and aggregation follow 02 assumptions 1 and 3: both
--      is_reported and is_aggregate rows are summed (V3 re-confirms the
--      partition), aggr_level = 2 only.
--   3. Bangladesh's import series is 2015-2018, the same gap as its exports
--      (V2). Its balance exists only for those four years.
--   4. E2 has no World row (V1). Bilateral balances cover the 20 partners
--      only, and E2 shares are share-of-panel. V5 measures E2's coverage of
--      E1's India total, the import-side twin of 04 V5.
--   5. Two pulls, two dates: exports 25/08/2026, imports 15/09/2026.
--      Balances therefore combine figures as Comtrade held them on two
--      different days. Nothing in this file cross-checks a value that was
--      pulled twice, so revision cannot be measured here; it is stated,
--      not quantified.
--   6. Nominal USD throughout (02 assumption 6). The 2022 commodity spike is
--      on BOTH sides of India's balance — petroleum is its largest export
--      chapter and crude its largest import — so 2022's deficit is partly
--      a price event too.
--   7. Every share, growth and ratio divisor is wrapped in NULLIF(..., 0).
--   8. Query 4 groups on cmd_code only and shows the latest year's
--      description — HS 2022 reworded chapters 15, 16, 24, 84 and 88 from
--      2022 onward (02 assumption 7). This is the query where that bug was
--      first noticed: grouping on cmd_desc made HS 84 and 15 appear to have
--      no 2014 imports at all.

-- ============================================================
-- Query 1: country trade balance, year by year
--          exports (Track A) - imports (E1), and balance as % of total trade
-- ============================================================
WITH x AS (
    SELECT reporter_iso, reporter_desc, ref_year, SUM(fob_value) AS exports_usd
    FROM clean_track_a_country_benchmark
    WHERE aggr_level = 2
    GROUP BY 1, 2, 3
),
m AS (
    SELECT reporter_iso, ref_year, SUM(cif_value) AS imports_usd
    FROM clean_track_e_country_imports
    WHERE aggr_level = 2
    GROUP BY 1, 2
)
SELECT
    x.reporter_desc,
    x.ref_year,
    ROUND(x.exports_usd / 1e9, 1)                                                     AS exports_bn,
    ROUND(m.imports_usd / 1e9, 1)                                                     AS imports_bn,
    ROUND((x.exports_usd - m.imports_usd) / 1e9, 1)                                   AS balance_bn,
    ROUND(100.0 * (x.exports_usd - m.imports_usd)
          / NULLIF(x.exports_usd + m.imports_usd, 0), 1)                              AS balance_pct_of_trade,
    ROUND(100.0 * x.exports_usd / NULLIF(m.imports_usd, 0), 1)                        AS export_cover_pct
FROM x
JOIN m USING (reporter_iso, ref_year)
ORDER BY x.reporter_desc, x.ref_year;

-- ============================================================
-- Query 2: India's chapter-level balance, 2023 — the 10 largest deficits
--          and the 10 largest surpluses by HS2 chapter
-- ============================================================
WITH x AS (
    SELECT cmd_code, cmd_desc, SUM(fob_value) AS exports_usd
    FROM clean_track_a_country_benchmark
    WHERE aggr_level = 2 AND reporter_iso = 'IND' AND ref_year = 2023
    GROUP BY 1, 2
),
m AS (
    SELECT cmd_code, SUM(cif_value) AS imports_usd
    FROM clean_track_e_country_imports
    WHERE aggr_level = 2 AND reporter_iso = 'IND' AND ref_year = 2023
    GROUP BY 1
),
bal AS (
    SELECT
        COALESCE(x.cmd_code, m.cmd_code)                    AS cmd_code,
        x.cmd_desc,
        COALESCE(x.exports_usd, 0)                          AS exports_usd,
        COALESCE(m.imports_usd, 0)                          AS imports_usd,
        COALESCE(x.exports_usd, 0) - COALESCE(m.imports_usd, 0) AS balance_usd
    FROM x
    FULL OUTER JOIN m USING (cmd_code)
),
ranked AS (
    SELECT
        bal.*,
        ROW_NUMBER() OVER (ORDER BY balance_usd ASC,  cmd_code) AS deficit_rank,
        ROW_NUMBER() OVER (ORDER BY balance_usd DESC, cmd_code) AS surplus_rank
    FROM bal
)
SELECT
    CASE WHEN deficit_rank <= 10 THEN 'deficit' ELSE 'surplus' END AS side,
    CASE WHEN deficit_rank <= 10 THEN deficit_rank ELSE surplus_rank END AS rank_on_side,
    cmd_code,
    cmd_desc,
    ROUND(exports_usd / 1e9, 2) AS exports_bn,
    ROUND(imports_usd / 1e9, 2) AS imports_bn,
    ROUND(balance_usd / 1e9, 2) AS balance_bn
FROM ranked
WHERE deficit_rank <= 10 OR surplus_rank <= 10
ORDER BY side, rank_on_side;

-- ============================================================
-- Query 3: India's bilateral balance with each of the 20 partners,
--          2014 vs 2023 — exports (Track C) minus imports (E2)
-- ============================================================
WITH x AS (
    SELECT partner_code, partner_desc, ref_year, SUM(fob_value) AS exports_usd
    FROM clean_track_c_india_partner_view
    WHERE aggr_level = 2 AND ref_year IN (2014, 2023)
    GROUP BY 1, 2, 3
),
m AS (
    SELECT partner_code, ref_year, SUM(cif_value) AS imports_usd
    FROM clean_track_e_india_partner_imports
    WHERE aggr_level = 2 AND ref_year IN (2014, 2023)
    GROUP BY 1, 2
),
j AS (
    SELECT x.partner_desc, x.ref_year, x.exports_usd, m.imports_usd,
           x.exports_usd - m.imports_usd AS balance_usd
    FROM x JOIN m USING (partner_code, ref_year)
)
SELECT
    partner_desc,
    ROUND(MAX(exports_usd) FILTER (WHERE ref_year = 2023) / 1e9, 2) AS exports_2023_bn,
    ROUND(MAX(imports_usd) FILTER (WHERE ref_year = 2023) / 1e9, 2) AS imports_2023_bn,
    ROUND(MAX(balance_usd) FILTER (WHERE ref_year = 2014) / 1e9, 2) AS balance_2014_bn,
    ROUND(MAX(balance_usd) FILTER (WHERE ref_year = 2023) / 1e9, 2) AS balance_2023_bn,
    ROUND((MAX(balance_usd) FILTER (WHERE ref_year = 2023)
         - MAX(balance_usd) FILTER (WHERE ref_year = 2014)) / 1e9, 2)   AS balance_change_bn
FROM j
GROUP BY partner_desc
ORDER BY balance_2023_bn;

-- ============================================================
-- Query 4: India's import basket — top 10 HS2 chapters, 2014 vs 2023,
--          share of total imports. The import-side twin of 02 Query 3.
-- ============================================================
WITH yearly AS (
    SELECT cmd_code, ref_year, SUM(cif_value) AS imports_usd,
           (ARRAY_AGG(cmd_desc))[1] AS cmd_desc   -- one wording per (code, year)
    FROM clean_track_e_country_imports
    WHERE aggr_level = 2 AND reporter_iso = 'IND' AND ref_year IN (2014, 2023)
    GROUP BY 1, 2
),
shares AS (
    SELECT
        cmd_code, cmd_desc, ref_year, imports_usd,
        100.0 * imports_usd / NULLIF(SUM(imports_usd) OVER (PARTITION BY ref_year), 0) AS share_pct
    FROM yearly
),
ranked AS (
    SELECT
        cmd_code,
        (ARRAY_AGG(cmd_desc ORDER BY ref_year DESC))[1]  AS cmd_desc,   -- assumption 8
        MAX(imports_usd) FILTER (WHERE ref_year = 2023) AS imports_2023_usd,
        MAX(share_pct)   FILTER (WHERE ref_year = 2014) AS share_2014_pct,
        MAX(share_pct)   FILTER (WHERE ref_year = 2023) AS share_2023_pct
    FROM shares
    GROUP BY cmd_code
)
SELECT
    ROW_NUMBER() OVER (ORDER BY imports_2023_usd DESC NULLS LAST, cmd_code) AS rank_2023,
    cmd_code,
    cmd_desc,
    ROUND(imports_2023_usd / 1e9, 2)                        AS imports_2023_bn,
    ROUND(share_2014_pct, 1)                                AS share_2014_pct,
    ROUND(share_2023_pct, 1)                                AS share_2023_pct,
    ROUND(COALESCE(share_2023_pct, 0) - COALESCE(share_2014_pct, 0), 1) AS shift_ppt
FROM ranked
ORDER BY rank_2023
LIMIT 10;


-- ============================================================
-- Validation — run before trusting the queries above
-- ============================================================

-- V1. Partner scope. E1 must be World only; E2 must be the 20 Track C
--     partners with no World row. Expect: e1_non_world = 0, e2_partners = 20,
--     e2_world_rows = 0, e2_partners_not_in_c = 0.
SELECT
    (SELECT COUNT(*) FROM clean_track_e_country_imports WHERE partner_code <> 0)          AS e1_non_world,
    (SELECT COUNT(DISTINCT partner_code) FROM clean_track_e_india_partner_imports)         AS e2_partners,
    (SELECT COUNT(*) FROM clean_track_e_india_partner_imports WHERE partner_code = 0)      AS e2_world_rows,
    (SELECT COUNT(*) FROM (
        SELECT partner_code FROM clean_track_e_india_partner_imports
        EXCEPT SELECT partner_code FROM clean_track_c_india_partner_view) x)               AS e2_partners_not_in_c;

-- V2. Series completeness per reporter (E1). Expect 10 years each except
--     Bangladesh 2015-2018 (4), matching its export series exactly.
SELECT reporter_iso, MIN(ref_year) AS first_year, MAX(ref_year) AS last_year,
       COUNT(DISTINCT ref_year) AS years_present
FROM clean_track_e_country_imports
GROUP BY reporter_iso
ORDER BY reporter_iso;

-- V3. Flag partition on both import tables. Expect both_true = 0 and
--     neither_true = 0; reported + aggregate = 3294 (E1) and 16946 (E2).
SELECT 'E1' AS track,
       COUNT(*) FILTER (WHERE is_reported AND is_aggregate)         AS both_true,
       COUNT(*) FILTER (WHERE NOT is_reported AND NOT is_aggregate) AS neither_true,
       COUNT(*) FILTER (WHERE is_reported)                          AS reported_rows,
       COUNT(*) FILTER (WHERE is_aggregate)                         AS aggregate_rows,
       COUNT(*)                                                     AS total_rows
FROM clean_track_e_country_imports
UNION ALL
SELECT 'E2',
       COUNT(*) FILTER (WHERE is_reported AND is_aggregate),
       COUNT(*) FILTER (WHERE NOT is_reported AND NOT is_aggregate),
       COUNT(*) FILTER (WHERE is_reported),
       COUNT(*) FILTER (WHERE is_aggregate),
       COUNT(*)
FROM clean_track_e_india_partner_imports;

-- V4. External anchor for India's 2023 imports (the import-side twin of
--     finding 11). The value below is compared against the WITS country
--     profile figure in insights/key_findings.md; WITS is Comtrade-derived,
--     so this checks the arithmetic, not the source.
SELECT SUM(cif_value) AS india_2023_imports_usd
FROM clean_track_e_country_imports
WHERE aggr_level = 2 AND reporter_iso = 'IND' AND ref_year = 2023;

-- V5. E2 panel coverage: the 20 partners' share of India's total imports
--     (E1), per year — the import-side twin of 04 V5. This is the "share of
--     what" behind every E2 figure.
WITH p AS (
    SELECT ref_year, SUM(cif_value) AS panel_usd
    FROM clean_track_e_india_partner_imports
    WHERE aggr_level = 2
    GROUP BY ref_year
),
w AS (
    SELECT ref_year, SUM(cif_value) AS world_usd
    FROM clean_track_e_country_imports
    WHERE aggr_level = 2 AND reporter_iso = 'IND'
    GROUP BY ref_year
)
SELECT
    p.ref_year,
    ROUND(p.panel_usd / 1e9, 1)                              AS panel_bn,
    ROUND(w.world_usd / 1e9, 1)                              AS india_total_bn,
    ROUND(100.0 * p.panel_usd / NULLIF(w.world_usd, 0), 1)   AS panel_coverage_pct
FROM p JOIN w USING (ref_year)
ORDER BY p.ref_year;
