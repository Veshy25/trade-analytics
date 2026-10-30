# Results — what each CSV holds

The 28 CSVs here are the analysis results, written by `sql/08_export_results.sql`
from views defined in `sql/02`–`sql/07`. They are derived, not source:
regenerate them by re-running the SQL rather than editing them.

## Conventions

- **Money** is nominal USD, with no deflator. The suffix gives the unit: `_bn`
  is USD billions and `_mn` is USD millions. `_usd` columns are in dollars.
- **Exports** are FOB and **imports** are CIF. A balance is FOB exports minus
  CIF imports (`sql/07` assumption 1).
- **`_pct`** is a percentage, already multiplied by 100 (`27.8` means 27.8%).
  **`_ppt`** is a change in percentage points.
- **Shares of a partner are shares of the 20-partner panel**, not of India's
  world trade. The panel holds 61.9–64.4% of India's exports.
- **Sectors** are labelled `engineering_machinery`, `gems_jewellery`,
  `petroleum_products`, `pharmaceuticals` and `textiles`; the HS2 chapters
  behind each are in [`data/raw/README.md`](../raw/README.md).
- **HHI** (Herfindahl–Hirschman Index) runs from 0 to 10,000; higher means more
  concentrated.
- **Rounding** happens once, in the view: 1 to 3 decimal places depending on
  the column. Re-derive a figure from the CSV's own precision, not from a
  rounded figure in the prose.

## Track A — four-country benchmark (`sql/02`)

| File | Grain | Notes |
|---|---|---|
| `track_a_country_year_totals.csv` | reporter × year | `yoy_growth_pct` is blank in each reporter's first year. Bangladesh has 2015–2018 only. |
| `track_a_cagr.csv` | reporter | `cagr_pct` is compounded over `first_year`–`last_year`, so Bangladesh's spans 3 years and the others 9. |
| `track_a_indexed_series.csv` | reporter × year | `index_base_100` = total ÷ the reporter's `base_year` total × 100. |
| `track_a_top10_chapters.csv` | reporter × rank | `value_2014_2023_bn` is the decade total. `rank_basis` says what the rank was computed on: 2023 value, or the full period for Bangladesh, which has no 2023 row. |
| `track_a_india_chapter_change_2022_2023.csv` | India, 10 largest rises + 10 largest falls | `direction` is `rise` or `fall`; `change_bn` = 2023 − 2022. |
| `track_a_india_chapter_contribution_2014_2023.csv` | India × HS2 chapter (97) | `pct_of_net_change` = the chapter's change ÷ India's **net** change (USD 113.9bn), so falling chapters are negative and the column sums to about 100. `share_2023_pct` is the chapter's share of 2023 exports. |
| `track_a_reporting_basis.csv` | reporter × year | `pct_rows_is_aggregate` / `pct_rows_is_reported` = share of rows rolled up vs filed. `pct_value_on_netwgt_est_rows` = share of **value** on rows whose **net weight** Comtrade estimated; it is not a share of estimated value. `rows_flag4` and `rows_netwgt_est` are the row counts behind that (finding 12). |

## Track B — India's five sectors at HS6 (`sql/03`)

| File | Grain | Notes |
|---|---|---|
| `track_b_sector_year_totals.csv` | sector × year | Sum of HS6 rows to World. |
| `track_b_sector_concentration_2023.csv` | sector | `hs6_products_2023` = codes with a 2023 row. `hs6_codes_all_years` = codes seen in any year; the gap is mostly HS edition churn, not lost products. `top5_share_pct` and `hhi_2023` measure **product** concentration within the sector. |
| `track_b_cross_track_reconciliation.csv` | sector × year | `pct_diff` = (Track B − Track A) ÷ Track A × 100, so negative means the HS6 detail sums below the HS2 chapters. |
| `track_b_sector_volume_vs_value.csv` | sector | Volume is net weight: `mn_tonnes_*` = million tonnes. `value_coverage_*_pct` = share of value on rows that carry a weight. `volume_flag` is `LOW COVERAGE — no volume claim` when that is under 80% in either year (gems). `mn_tonnes_cov_adj_*` = tonnes scaled up to the sector's full value (tonnes × value ÷ value with weight), and `volume_change_cov_adj_pct` is the change on that basis. |
| `track_b_engineering_unit_value_mix.csv` | year (2014, 2023) | Engineering's USD/kg with and without mobile phones (`phone_*`), to separate a mix shift from a price change. |
| `track_b_petroleum_volume_series.csv` | year | `value_index`, `volume_index` and `unit_value_index` are each 2014 = 100. |
| `track_b_volume_coverage.csv` | sector × year | `weight_estimated_kg_pct` = share of tonnage that Comtrade estimated, weighted by kilograms. Use it rather than `weight_estimated_rows_pct`, which counts rows and understates the exposure, because the estimated rows are the large ones. |

## Track C — the 20-partner panel (`sql/04`)

| File | Grain | Notes |
|---|---|---|
| `track_c_partner_totals.csv` | partner | `pct_of_panel_2023` is a share of the panel. |
| `track_c_partner_concentration.csv` | year | `hhi_panel` treats the panel as the whole market. `panel_coverage_pct` = the panel's share of India's exports. `hhi_true_lower` / `hhi_true_upper` bound India's whole-market HHI: the rest of its exports either fully dispersed, or all in one market. |
| `track_c_partner_rank_moves.csv` | partner | `rank_improvement` = rank 2014 − rank 2023, so positive means the partner climbed. |

## Track D — sector × partner (`sql/06`)

| File | Grain | Notes |
|---|---|---|
| `track_d_sector_partner_matrix_2023.csv` | sector × partner | `pct_of_sector_panel` = the partner's share of that sector's panel exports. |
| `track_d_sector_partner_shift.csv` | sector × partner | `shift_ppt` = `share_2023_pct` − `share_2014_pct`. |
| `track_d_top_products_by_market.csv` | sector × top-3 partner × top-5 product | `value_2023_mn` is USD millions. `pct_of_partner_sector` = the product's share of that partner's exports in that sector. |
| `track_d_sector_market_concentration.csv` | sector × year | `hhi_panel` is **market** concentration within the panel. `partners_with_trade` counts partners with a non-zero share. |
| `track_d_sector_partner_cagr.csv` | sector × partner | `cagr_pct` 2014–2023 on USD millions. The input for the planned Sector × Market dashboard page. |

## Track E — imports and trade balance (`sql/07`)

| File | Grain | Notes |
|---|---|---|
| `track_e_country_trade_balance.csv` | reporter × year | `balance_pct_of_trade` = balance ÷ (exports + imports) × 100. `export_cover_pct` = exports ÷ imports × 100. |
| `track_e_india_chapter_balance_2023.csv` | India, 10 largest deficit + 10 largest surplus chapters | `side` is `deficit` or `surplus`. |
| `track_e_india_partner_balance.csv` | partner | Balances for 2014 and 2023; `balance_change_bn` = 2023 − 2014. |
| `track_e_india_import_mix.csv` | India's top-10 import chapters | `shift_ppt` = 2023 share − 2014 share. |
| `track_e_panel_import_coverage_2023.csv` | India × HS2 chapter (97) | `panel_coverage_pct` = imports from the 20 partners ÷ India's world imports, by chapter. Low on fuels and gold (finding 19). |

## Supporting figures (`sql/02`, `03`, `06`)

| File | Grain | Notes |
|---|---|---|
| `supporting_figures.csv` | one row per figure | Counts quoted in the findings, the README or SQL comments that no other result set returns. `figure_id` names the query (`02 S1a` is `sql/02` S1), `unit` gives the unit of `value`, and `cited_in` says where it is quoted. |
