-- 07_track_e_imports_trade_balance.sql
-- Track E analysis: imports and trade balance. Two import pulls (15/09/2026):
--   E1 — India, China, Bangladesh, Vietnam -> World, HS2   (mirror of Track A)
--   E2 — India <- the 20 Track C partners, HS2               (mirror of Track C)
-- joined to the Phase 1 export tables to produce balances. Phase 2.
--
-- NOTE on views (23/09/2026): every result set exported to data/processed/ is
-- defined once here as a view (v_track_e_*), and sql/08 only copies it out —
-- see 02's header for why. If you change a view, rerun 08. Q2 is the query
-- whose 08 copy had drifted: 08 took cmd_desc from the export side only,
-- without the COALESCE this file added on 17/09/2026. Harmless on this data
-- (V6 proves the chapter sets match), but the committed CSV came from the
-- unfixed copy until 23/09/2026.
--
-- Assumptions made here (flagging before running, not after):
--   1. VALUATION BASIS DIFFERS. Exports are FOB (Track A/C, fob_value);
--      imports are CIF (E1/E2, cif_value — 01 validation 5 confirms
--      primary_value = cif_value on 100% of import rows). Every balance in
--      this file is FOB exports minus CIF imports. That is how published
--      merchandise balances are constructed, but the CIF side carries
--      freight and insurance the FOB side does not, so deficits are
--      overstated (and surpluses understated) by that margin. The size of
--      that margin is NOT measured here and cannot be from this data — it is
--      a convention. The IMF's Direction of Trade Statistics used a 10%
--      CIF/FOB factor historically and has used 6% since its March 2017
--      upgrade, based on the OECD International Transport and Insurance Costs
--      database (Marini, Dippelsman and Stanger, "New Estimates for Direction
--      of Trade Statistics", IMF WP/18/16, 2018). Treat ~6-10% as the assumed
--      range, higher for long-haul and low-value-density trade — not a
--      finding. This file quoted 10% as "long-standing" and 10-20% as the
--      range until 23/09/2026, which was out of date. No adjustment is
--      applied; the caveat travels with the number.
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
--   9. THE PARTNER PANEL WAS BUILT FOR EXPORTS (added 23/09/2026). E2 reuses
--      Track C's twenty partners, which were chosen on the export side (04
--      assumption 7). India's import sources are a different set, and the
--      panel under-represents exactly the suppliers that drive its deficit:
--      in 2023 it covers 54.7% of India's imports overall, but only 33.9% of
--      mineral fuels (HS 27) and 37.8% of precious stones and metals (HS 71)
--      — V5b. Energy and gold suppliers outside the twenty are missing. So
--      every Q3 ranking is a ranking WITHIN THE PANEL: "China's deficit is
--      larger than the next four combined" holds among these twenty, and
--      says nothing about bilateral deficits with countries the panel leaves
--      out. The coverage figure (V5) was always disclosed; the direction of
--      the bias was not.

-- ============================================================
-- Query 1: country trade balance, year by year
--          exports (Track A) - imports (E1), and balance as % of total trade
--          Exported as track_e_country_trade_balance.csv.
-- ============================================================
DROP VIEW IF EXISTS v_track_e_country_trade_balance;
CREATE VIEW v_track_e_country_trade_balance AS
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

SELECT * FROM v_track_e_country_trade_balance;

-- ============================================================
-- Query 2: India's chapter-level balance, 2023 — the 10 largest deficits
--          and the 10 largest surpluses by HS2 chapter
--          Exported as track_e_india_chapter_balance_2023.csv.
-- ============================================================
DROP VIEW IF EXISTS v_track_e_india_chapter_balance_2023;
CREATE VIEW v_track_e_india_chapter_balance_2023 AS
WITH x AS (
    SELECT cmd_code, cmd_desc, SUM(fob_value) AS exports_usd
    FROM clean_track_a_country_benchmark
    WHERE aggr_level = 2 AND reporter_iso = 'IND' AND ref_year = 2023
    GROUP BY 1, 2
),
m AS (
    SELECT cmd_code, cmd_desc, SUM(cif_value) AS imports_usd
    FROM clean_track_e_country_imports
    WHERE aggr_level = 2 AND reporter_iso = 'IND' AND ref_year = 2023
    GROUP BY 1, 2
),
-- The join is FULL OUTER so a chapter India imports but does not export (or
-- vice versa) still appears. cmd_desc must therefore be COALESCEd across both
-- sides: taking it from x alone would print a NULL description for any
-- import-only chapter. That is a no-op on this data — all 97 chapters are
-- present on both sides in 2023, asserted in V6 below — but the query should
-- not depend on that holding.
bal AS (
    SELECT
        COALESCE(x.cmd_code, m.cmd_code)                    AS cmd_code,
        COALESCE(x.cmd_desc, m.cmd_desc)                    AS cmd_desc,
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

SELECT * FROM v_track_e_india_chapter_balance_2023;

-- ============================================================
-- Query 3: India's bilateral balance with each of the 20 partners,
--          2014 vs 2023 — exports (Track C) minus imports (E2). A ranking
--          within the panel only (assumption 9).
--          Exported as track_e_india_partner_balance.csv.
-- ============================================================
DROP VIEW IF EXISTS v_track_e_india_partner_balance;
CREATE VIEW v_track_e_india_partner_balance AS
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
-- Inner join, deliberately: a partner-year present on only one side would be
-- dropped silently, and balance_change_bn below would go NULL if either 2014
-- or 2023 were missing. Verified a no-op here — all 20 partners carry both an
-- export and an import row in both years, so the join returns 40 of 40 pairs;
-- V6 asserts it rather than leaving it to trust.
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

SELECT * FROM v_track_e_india_partner_balance;

-- ============================================================
-- Query 4: India's import basket — top 10 HS2 chapters, 2014 vs 2023,
--          share of total imports. The import-side twin of 02 Query 3.
--          Exported as track_e_india_import_mix.csv.
-- ============================================================
DROP VIEW IF EXISTS v_track_e_india_import_mix;
CREATE VIEW v_track_e_india_import_mix AS
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

SELECT * FROM v_track_e_india_import_mix;


-- ============================================================
-- Validation — run before trusting the queries above
-- ============================================================

-- V1. Partner scope. E1 must be World only; E2 must be the 20 Track C
--     partners with no World row. Expect: e1_non_world = 0, e2_partners = 20,
--     e2_world_rows = 0, e2_partners_not_in_c = 0. The E2 half is asserted
--     in 01 validation 6; the E1 half is asserted here (23/09/2026).
DO $$
DECLARE n bigint;
BEGIN
    SELECT COUNT(*) INTO n FROM clean_track_e_country_imports WHERE partner_code <> 0;
    IF n <> 0 THEN
        RAISE EXCEPTION '07 V1: % E1 rows have a partner other than World', n;
    END IF;
    RAISE NOTICE '07 V1 PASSED: every E1 row is reporter -> World.';
END $$;

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

-- V5 assertion (added 23/09/2026): the published range is 50-58%; at build
-- time it runs 50.4-58.2%.
DO $$
DECLARE lo numeric; hi numeric; n bigint;
BEGIN
    SELECT COUNT(*),
           MIN(ROUND(100.0 * p.v / NULLIF(w.v, 0), 1)),
           MAX(ROUND(100.0 * p.v / NULLIF(w.v, 0), 1))
      INTO n, lo, hi
    FROM (SELECT ref_year, SUM(cif_value) AS v FROM clean_track_e_india_partner_imports
          WHERE aggr_level = 2 GROUP BY ref_year) p
    JOIN (SELECT ref_year, SUM(cif_value) AS v FROM clean_track_e_country_imports
          WHERE aggr_level = 2 AND reporter_iso = 'IND' GROUP BY ref_year) w USING (ref_year);
    IF n <> 10 OR lo < 50.0 OR hi > 58.5 THEN
        RAISE EXCEPTION '07 V5: % years, E2 coverage % to % percent (expected 10 years, 50 to 58)', n, lo, hi;
    END IF;
    RAISE NOTICE '07 V5 PASSED: E2 covers % to % percent of India''s imports.', lo, hi;
END $$;

-- V5b. Panel import coverage by chapter, 2023 (added 23/09/2026, behind
--      assumption 9). One row per HS2 chapter, largest import chapters first:
--      India's imports from the world (E1), from the twenty (E2), and the
--      share the panel sees. Mineral fuels (27) and precious stones and
--      metals (71), the two largest deficit chapters after electronics, are
--      where the panel is thinnest. Exported as
--      track_e_panel_import_coverage_2023.csv.
DROP VIEW IF EXISTS v_track_e_panel_import_coverage_2023;
CREATE VIEW v_track_e_panel_import_coverage_2023 AS
WITH w AS (
    SELECT cmd_code,
           (ARRAY_AGG(cmd_desc))[1] AS cmd_desc,   -- one year, one wording
           SUM(cif_value)           AS world_usd
    FROM clean_track_e_country_imports
    WHERE aggr_level = 2 AND reporter_iso = 'IND' AND ref_year = 2023
    GROUP BY cmd_code
),
p AS (
    SELECT cmd_code, SUM(cif_value) AS panel_usd
    FROM clean_track_e_india_partner_imports
    WHERE aggr_level = 2 AND ref_year = 2023
    GROUP BY cmd_code
)
SELECT
    ROW_NUMBER() OVER (ORDER BY w.world_usd DESC, w.cmd_code)         AS rank_by_imports,
    w.cmd_code,
    w.cmd_desc,
    ROUND(w.world_usd / 1e9, 3)                                        AS india_imports_2023_bn,
    ROUND(COALESCE(p.panel_usd, 0) / 1e9, 3)                           AS panel_imports_2023_bn,
    ROUND(100.0 * COALESCE(p.panel_usd, 0) / NULLIF(w.world_usd, 0), 1) AS panel_coverage_pct
FROM w
-- LEFT join: a chapter India imports only from outside the panel must show
-- 0% coverage, not vanish.
LEFT JOIN p USING (cmd_code)
ORDER BY rank_by_imports;

SELECT * FROM v_track_e_panel_import_coverage_2023;


-- V6. Join-coverage assertions (added 17/09/2026). Q2 and Q3 both join an
--     export track to an import track. Both are no-ops on this data, and both
--     would drop or blank rows silently if that ever stopped being true, so
--     the condition is asserted rather than assumed. A cold audit on
--     16/09/2026 flagged them as latent; this is the answer to that.
DO $$
DECLARE
    only_one_side bigint;
    pairs         bigint;
BEGIN
    -- Q2: every 2023 HS2 chapter must appear on both the export and import side.
    SELECT COUNT(*) INTO only_one_side FROM (
        (SELECT cmd_code FROM clean_track_a_country_benchmark
          WHERE aggr_level = 2 AND reporter_iso = 'IND' AND ref_year = 2023
         EXCEPT
         SELECT cmd_code FROM clean_track_e_country_imports
          WHERE aggr_level = 2 AND reporter_iso = 'IND' AND ref_year = 2023)
        UNION ALL
        (SELECT cmd_code FROM clean_track_e_country_imports
          WHERE aggr_level = 2 AND reporter_iso = 'IND' AND ref_year = 2023
         EXCEPT
         SELECT cmd_code FROM clean_track_a_country_benchmark
          WHERE aggr_level = 2 AND reporter_iso = 'IND' AND ref_year = 2023)
    ) q;
    IF only_one_side <> 0 THEN
        RAISE EXCEPTION
            '07 V6: % HS2 chapters appear on only one side of the 2023 balance — Q2 relies on COALESCE for cmd_desc, check the output', only_one_side;
    END IF;

    -- Q3: all 20 partners must carry both flows in both 2014 and 2023 (40 pairs).
    SELECT COUNT(*) INTO pairs FROM (
        SELECT x.partner_code, x.ref_year
        FROM (SELECT DISTINCT partner_code, ref_year FROM clean_track_c_india_partner_view
               WHERE aggr_level = 2 AND ref_year IN (2014, 2023)) x
        JOIN (SELECT DISTINCT partner_code, ref_year FROM clean_track_e_india_partner_imports
               WHERE aggr_level = 2 AND ref_year IN (2014, 2023)) m
          USING (partner_code, ref_year)
    ) p;
    IF pairs <> 40 THEN
        RAISE EXCEPTION
            '07 V6: Q3 partner-year join returns % pairs, expected 40 — a partner is missing a flow in 2014 or 2023', pairs;
    END IF;

    RAISE NOTICE '07 V6 PASSED: Q2 chapter coverage symmetric, Q3 returns all 40 partner-year pairs.';
END $$;
