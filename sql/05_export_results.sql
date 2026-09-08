-- 05_export_results.sql
-- Writes the headline result sets to data/processed/ as CSVs.
--
-- Why this file exists: 00-04 leave every answer inside PostgreSQL. Anyone
-- reading this repository on GitHub — which is most readers — cannot see a
-- single number the analysis produced without standing up a database and a
-- 12 MB load first. This file closes that gap by committing the outputs
-- alongside the queries that make them.
--
-- These CSVs are DERIVED, not source. data/raw/ is the input of record; if the
-- two ever disagree, data/raw/ plus 00-04 wins. Regenerate rather than edit.
--
-- Run from the repository root, after 00-04:
--   psql -d trade_analytics -v ON_ERROR_STOP=1 -f sql/05_export_results.sql
--
-- \copy paths are relative to the directory psql was launched from, and
-- data/processed/ must already exist (git does not track empty directories,
-- so it is kept alive by the CSVs themselves).
-- ============================================================


-- Track A — country-year totals, the base series behind every trend claim.
\copy (SELECT reporter_desc, ref_year, ROUND(SUM(fob_value)/1e9, 3) AS total_export_value_usd_bn FROM clean_track_a_country_benchmark WHERE aggr_level = 2 GROUP BY reporter_desc, ref_year ORDER BY reporter_desc, ref_year) TO 'data/processed/track_a_country_year_totals.csv' WITH (FORMAT csv, HEADER true)

-- Track A — decade CAGR per country, with each country's own span shown so a
-- 4-year Bangladesh rate is never read as a 9-year one.
\copy (WITH yearly AS (SELECT reporter_desc, reporter_iso, ref_year, SUM(fob_value) AS total_usd FROM clean_track_a_country_benchmark WHERE aggr_level = 2 GROUP BY 1,2,3), bounds AS (SELECT reporter_iso, MIN(ref_year) AS first_year, MAX(ref_year) AS last_year, COUNT(*) AS years_present FROM yearly GROUP BY 1) SELECT y.reporter_desc, b.first_year, b.last_year, b.years_present, ROUND(f.total_usd/1e9,3) AS first_year_bn, ROUND(l.total_usd/1e9,3) AS last_year_bn, ROUND(100.0*(POWER(l.total_usd/NULLIF(f.total_usd,0), 1.0/NULLIF(b.last_year-b.first_year,0))-1),2) AS cagr_pct FROM bounds b JOIN yearly y ON y.reporter_iso=b.reporter_iso AND y.ref_year=b.last_year JOIN yearly f ON f.reporter_iso=b.reporter_iso AND f.ref_year=b.first_year JOIN yearly l ON l.reporter_iso=b.reporter_iso AND l.ref_year=b.last_year ORDER BY cagr_pct DESC) TO 'data/processed/track_a_cagr.csv' WITH (FORMAT csv, HEADER true)

-- Track A — indexed series, each country rebased to 100 at its own first year.
-- This is the series behind the README chart.
\copy (WITH yearly AS (SELECT reporter_desc, reporter_iso, ref_year, SUM(fob_value) AS total_usd FROM clean_track_a_country_benchmark WHERE aggr_level = 2 GROUP BY 1,2,3), based AS (SELECT reporter_desc, ref_year, total_usd, FIRST_VALUE(total_usd) OVER (PARTITION BY reporter_iso ORDER BY ref_year) AS base_usd, MIN(ref_year) OVER (PARTITION BY reporter_iso) AS base_year FROM yearly) SELECT reporter_desc, ref_year, base_year, ROUND(total_usd/1e9,3) AS total_bn, ROUND(100.0*total_usd/NULLIF(base_usd,0),1) AS index_base_100 FROM based ORDER BY reporter_desc, ref_year) TO 'data/processed/track_a_indexed_series.csv' WITH (FORMAT csv, HEADER true)

-- Track A — estimation-flag sensitivity by country-year (02 V1a). The regime
-- change is the point: read estimated_pct as ~0 or ~90-100, not as a gradient.
\copy (WITH by_country_year AS (SELECT reporter_iso, ref_year, SUM(fob_value) AS total_usd, COALESCE(SUM(fob_value) FILTER (WHERE legacy_estimation_flag = 4),0) AS estimated_usd FROM clean_track_a_country_benchmark WHERE aggr_level = 2 GROUP BY 1,2) SELECT reporter_iso, ref_year, ROUND(total_usd/1e9,3) AS total_bn, ROUND((total_usd-estimated_usd)/1e9,3) AS as_reported_bn, ROUND(100.0*estimated_usd/NULLIF(total_usd,0),1) AS estimated_pct FROM by_country_year ORDER BY reporter_iso, ref_year) TO 'data/processed/track_a_estimation_sensitivity.csv' WITH (FORMAT csv, HEADER true)

-- Track A — top 10 HS2 chapters per country, ranked on 2023 value.
\copy (WITH chapter_totals AS (SELECT reporter_desc, cmd_code, cmd_desc, SUM(fob_value) FILTER (WHERE ref_year = 2023) AS value_2023_usd, SUM(fob_value) AS value_2014_2023_usd FROM clean_track_a_country_benchmark WHERE aggr_level = 2 GROUP BY 1,2,3), ranked AS (SELECT ct.*, ROW_NUMBER() OVER (PARTITION BY reporter_desc ORDER BY value_2023_usd DESC NULLS LAST, value_2014_2023_usd DESC) AS rnk FROM chapter_totals ct) SELECT reporter_desc, rnk AS rank_2023, cmd_code, cmd_desc, ROUND(value_2023_usd/1e9,3) AS value_2023_bn, ROUND(value_2014_2023_usd/1e9,3) AS value_2014_2023_bn FROM ranked WHERE rnk <= 10 ORDER BY reporter_desc, rnk) TO 'data/processed/track_a_top10_chapters.csv' WITH (FORMAT csv, HEADER true)

-- Track B — sector-year totals for India's five focus sectors.
\copy (SELECT sector, ref_year, ROUND(SUM(fob_value)/1e9,3) AS sector_value_usd_bn FROM clean_track_b_india_sector_detail WHERE aggr_level = 6 AND partner_code = 0 GROUP BY 1,2 ORDER BY 1,2) TO 'data/processed/track_b_sector_year_totals.csv' WITH (FORMAT csv, HEADER true)

-- Track B — 2023 product concentration per sector (top-5 share and HHI).
\copy (WITH product_2023 AS (SELECT sector, cmd_code, SUM(fob_value) AS value_2023_usd FROM clean_track_b_india_sector_detail WHERE aggr_level = 6 AND partner_code = 0 AND ref_year = 2023 GROUP BY 1,2), shares AS (SELECT sector, cmd_code, value_2023_usd, value_2023_usd/NULLIF(SUM(value_2023_usd) OVER (PARTITION BY sector),0) AS share, ROW_NUMBER() OVER (PARTITION BY sector ORDER BY value_2023_usd DESC, cmd_code) AS rnk FROM product_2023) SELECT sector, COUNT(*) AS hs6_products_2023, ROUND(100.0*SUM(share) FILTER (WHERE rnk <= 5),1) AS top5_share_pct, ROUND(SUM(share*share)*10000,0) AS hhi_2023 FROM shares GROUP BY sector ORDER BY hhi_2023 DESC) TO 'data/processed/track_b_sector_concentration_2023.csv' WITH (FORMAT csv, HEADER true)

-- Track B — cross-track reconciliation (03 V5). Track B's HS6 sector totals
-- against Track A's HS2 chapter rollup for the same sector-years.
\copy (WITH track_b_sector AS (SELECT sector, ref_year, SUM(fob_value) AS b_value_usd FROM clean_track_b_india_sector_detail WHERE aggr_level = 6 AND partner_code = 0 GROUP BY 1,2), track_a_sector AS (SELECT CASE WHEN cmd_code='27' THEN 'petroleum_products' WHEN cmd_code='30' THEN 'pharmaceuticals' WHEN cmd_code='71' THEN 'gems_jewellery' WHEN cmd_code IN ('84','85') THEN 'engineering_machinery' WHEN cmd_code BETWEEN '50' AND '63' THEN 'textiles' END AS sector, ref_year, SUM(fob_value) AS a_value_usd FROM clean_track_a_country_benchmark WHERE reporter_iso='IND' AND cmd_code IN ('27','30','71','84','85','50','51','52','53','54','55','56','57','58','59','60','61','62','63') GROUP BY 1,2) SELECT b.sector, b.ref_year, ROUND(b.b_value_usd/1e9,3) AS track_b_bn, ROUND(a.a_value_usd/1e9,3) AS track_a_bn, ROUND(100.0*(b.b_value_usd-a.a_value_usd)/NULLIF(a.a_value_usd,0),2) AS pct_diff FROM track_b_sector b JOIN track_a_sector a USING (sector, ref_year) ORDER BY b.sector, b.ref_year) TO 'data/processed/track_b_cross_track_reconciliation.csv' WITH (FORMAT csv, HEADER true)

-- Track C — partner totals and share of the 20-partner panel.
\copy (WITH partner_totals AS (SELECT partner_desc, SUM(fob_value) FILTER (WHERE ref_year = 2023) AS value_2023_usd, SUM(fob_value) AS value_2014_2023_usd FROM clean_track_c_india_partner_view WHERE aggr_level = 2 GROUP BY 1) SELECT partner_desc, ROW_NUMBER() OVER (ORDER BY value_2023_usd DESC NULLS LAST, value_2014_2023_usd DESC) AS rank_2023, ROUND(value_2023_usd/1e9,3) AS value_2023_bn, ROUND(100.0*value_2023_usd/NULLIF(SUM(value_2023_usd) OVER (),0),1) AS pct_of_panel_2023, ROUND(value_2014_2023_usd/1e9,3) AS value_2014_2023_bn FROM partner_totals ORDER BY rank_2023) TO 'data/processed/track_c_partner_totals.csv' WITH (FORMAT csv, HEADER true)

-- Track C — partner concentration over time, with the bounded whole-market
-- HHI estimate (04 Q4). hhi_panel alone is NOT band-comparable; the bounds are.
\copy (WITH partner_yearly AS (SELECT partner_desc, ref_year, SUM(fob_value) AS value_usd FROM clean_track_c_india_partner_view WHERE aggr_level = 2 GROUP BY 1,2), shares AS (SELECT ref_year, partner_desc, value_usd/NULLIF(SUM(value_usd) OVER (PARTITION BY ref_year),0) AS share, ROW_NUMBER() OVER (PARTITION BY ref_year ORDER BY value_usd DESC, partner_desc) AS rnk FROM partner_yearly), panel_hhi AS (SELECT ref_year, SUM(share) FILTER (WHERE rnk <= 5) AS top5_share, SUM(share*share)*10000 AS hhi_panel, SUM(value_usd) AS panel_value_usd FROM shares JOIN partner_yearly USING (ref_year, partner_desc) GROUP BY ref_year), india_world AS (SELECT ref_year, SUM(fob_value) AS world_value_usd FROM clean_track_a_country_benchmark WHERE reporter_iso='IND' AND aggr_level=2 GROUP BY 1), coverage AS (SELECT p.ref_year, p.top5_share, p.hhi_panel, p.panel_value_usd/NULLIF(w.world_value_usd,0) AS c FROM panel_hhi p JOIN india_world w USING (ref_year)) SELECT ref_year, ROUND(100.0*top5_share,1) AS top5_partner_share_pct, ROUND(hhi_panel,0) AS hhi_panel, ROUND(100.0*c,1) AS panel_coverage_pct, ROUND(hhi_panel*POWER(c,2),0) AS hhi_true_lower, ROUND(hhi_panel*POWER(c,2)+POWER(1-c,2)*10000,0) AS hhi_true_upper FROM coverage ORDER BY ref_year) TO 'data/processed/track_c_partner_concentration.csv' WITH (FORMAT csv, HEADER true)
