-- 08_export_results.sql
-- Writes the headline result sets to data/processed/ as CSVs.
--
-- Why this file exists: 00-07 leave every answer inside PostgreSQL. Anyone
-- reading this repository on GitHub — which is most readers — cannot see a
-- single number the analysis produced without standing up a database and a
-- ~90 MB load first. This file closes that gap by committing the outputs
-- alongside the queries that make them.
--
-- How it works (rebuilt 23/09/2026). Every result set is defined ONCE, as a
-- view in the analysis file that owns it (v_track_a_* in 02, v_track_b_* in
-- 03, and so on), and each line below only copies a view out. Until this
-- date the file re-stated all 24 queries as one-line copies, up to 1,530
-- characters each, and two had drifted from the queries they were named
-- after: 07 Q2's cmd_desc lost the COALESCE added on 17/09/2026, and several
-- Track A and B columns were rounded differently here than in 02/03. With
-- the views there is nothing left to drift. The ORDER BY on each line is
-- deliberate: a view's own ORDER BY is not guaranteed to survive a SELECT
-- from it, and the CSVs must come out byte-identical run after run.
--
-- These CSVs are DERIVED, not source. data/raw/ is the input of record; if the
-- two ever disagree, data/raw/ plus 00-07 wins. Regenerate rather than edit.
--
-- Run from the repository root, after 00-07 — the views only exist once
-- 02-07 have run:
--   psql -d trade_analytics -v ON_ERROR_STOP=1 -f sql/08_export_results.sql
--
-- \copy paths are relative to the directory psql was launched from, and
-- data/processed/ must already exist (git does not track empty directories,
-- so it is kept alive by the CSVs themselves). 27 result sets: 24 until
-- 23/09/2026, plus India's chapter contribution to growth (02 Q6),
-- engineering's unit value with and without phones (03 Q6b) and the
-- partner panel's import coverage by chapter (07 V5b).
-- ============================================================

-- Track A (sql/02)
\copy (SELECT * FROM v_track_a_country_year_totals ORDER BY reporter_desc, ref_year) TO 'data/processed/track_a_country_year_totals.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_a_cagr ORDER BY cagr_pct DESC) TO 'data/processed/track_a_cagr.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_a_indexed_series ORDER BY reporter_desc, ref_year) TO 'data/processed/track_a_indexed_series.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_a_reporting_basis ORDER BY reporter_desc, ref_year) TO 'data/processed/track_a_reporting_basis.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_a_top10_chapters ORDER BY reporter_desc, rank_2023) TO 'data/processed/track_a_top10_chapters.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_a_india_chapter_change_2022_2023 ORDER BY direction, rank_on_side) TO 'data/processed/track_a_india_chapter_change_2022_2023.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_a_india_chapter_contribution ORDER BY rank_by_change) TO 'data/processed/track_a_india_chapter_contribution_2014_2023.csv' WITH (FORMAT csv, HEADER true)

-- Track B (sql/03)
\copy (SELECT * FROM v_track_b_sector_year_totals ORDER BY sector, ref_year) TO 'data/processed/track_b_sector_year_totals.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_b_sector_concentration_2023 ORDER BY hhi_2023 DESC) TO 'data/processed/track_b_sector_concentration_2023.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_b_cross_track_reconciliation ORDER BY sector, ref_year) TO 'data/processed/track_b_cross_track_reconciliation.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_b_sector_volume_vs_value ORDER BY sector) TO 'data/processed/track_b_sector_volume_vs_value.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_b_engineering_unit_value_mix ORDER BY ref_year) TO 'data/processed/track_b_engineering_unit_value_mix.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_b_petroleum_volume_series ORDER BY ref_year) TO 'data/processed/track_b_petroleum_volume_series.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_b_volume_coverage ORDER BY sector, ref_year) TO 'data/processed/track_b_volume_coverage.csv' WITH (FORMAT csv, HEADER true)

-- Track C (sql/04)
\copy (SELECT * FROM v_track_c_partner_totals ORDER BY rank_2023) TO 'data/processed/track_c_partner_totals.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_c_partner_concentration ORDER BY ref_year) TO 'data/processed/track_c_partner_concentration.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_c_partner_rank_moves ORDER BY rank_2023 NULLS LAST) TO 'data/processed/track_c_partner_rank_moves.csv' WITH (FORMAT csv, HEADER true)

-- Track D (sql/06)
\copy (SELECT * FROM v_track_d_sector_partner_matrix_2023 ORDER BY sector, rank_in_sector) TO 'data/processed/track_d_sector_partner_matrix_2023.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_d_sector_partner_shift ORDER BY sector, shift_ppt DESC) TO 'data/processed/track_d_sector_partner_shift.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_d_top_products_by_market ORDER BY sector, partner_rank, product_rank) TO 'data/processed/track_d_top_products_by_market.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_d_sector_market_concentration ORDER BY sector, ref_year) TO 'data/processed/track_d_sector_market_concentration.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_d_sector_partner_cagr ORDER BY sector, cagr_pct DESC NULLS LAST) TO 'data/processed/track_d_sector_partner_cagr.csv' WITH (FORMAT csv, HEADER true)

-- Track E (sql/07)
\copy (SELECT * FROM v_track_e_country_trade_balance ORDER BY reporter_desc, ref_year) TO 'data/processed/track_e_country_trade_balance.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_e_india_chapter_balance_2023 ORDER BY side, rank_on_side) TO 'data/processed/track_e_india_chapter_balance_2023.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_e_india_partner_balance ORDER BY balance_2023_bn) TO 'data/processed/track_e_india_partner_balance.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_e_india_import_mix ORDER BY rank_2023) TO 'data/processed/track_e_india_import_mix.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_track_e_panel_import_coverage_2023 ORDER BY rank_by_imports) TO 'data/processed/track_e_panel_import_coverage_2023.csv' WITH (FORMAT csv, HEADER true)
