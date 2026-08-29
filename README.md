# International Trade Analytics: India's Export Profile (2014–2023)

A SQL-driven analysis of India's export performance over the past decade, benchmarked against three comparator economies (China, Bangladesh, Vietnam), sourced directly from the UN Comtrade API. Built as a portfolio project pairing PostgreSQL analysis with a Power BI dashboard.

## Why this project

This project reflects a long-standing interest in international trade and export markets. Trade data offered a stronger sourcing story than a pre-packaged Kaggle dataset — it required deliberately scoping an API pull rather than just loading a CSV someone else had already cleaned.

## Data source

**UN Comtrade API** (https://comtradeplus.un.org) — the UN Statistics Division's official repository of international merchandise trade statistics, built from member states' own customs declarations. Chosen over DGFT (India-only, narrower) and Kaggle mirrors (secondhand, unclear provenance) specifically for the stronger, more defensible sourcing story: primary international data, pulled programmatically, with documented reliability caveats (see below) rather than taken at face value.

### Scope

| Dimension | Decision |
|---|---|
| Reporters | India (primary) + China, Bangladesh, Vietnam (comparators) |
| Time range | 2014–2023 (10 years) |
| Trade flow | Exports only (Phase 1) |
| Product detail | HS2 (chapter-level) across all ~97 chapters, for all 4 reporters — the broad "top categories and trends" layer. Plus HS6 (product-level) drill-down for India specifically, across 5 sectors: textiles, pharmaceuticals, gems & jewellery, petroleum products, and engineering/machinery |
| Partner markets | India's exports also pulled by ~20 major partner countries (HS2 level) |

2024–2025 were deliberately excluded: UN Comtrade figures for recent years are frequently still being revised by reporting countries, so the pull is scoped to finalised, stable data.

Imports and trade-balance analysis are an intended Phase 2 extension, not covered here yet.

## Data reliability

International trade statistics carry known limitations worth stating upfront rather than discovering later:

- **Exporter/importer asymmetry.** The same shipment reported by both trading partners rarely matches exactly — exports are valued FOB (free-on-board), imports CIF (cost, insurance, freight), a gap that alone can run 10–20%. This dataset uses each country's own *exporter*-reported figures consistently, never a partner's mirrored import figure, to avoid mixing valuation bases.
- **Reporting gaps get filled by estimation, not left blank.** When a country hasn't reported for a given year, UN Comtrade fills the gap via mirror data or extrapolation. The raw data carries explicit flags for this (`isReported`, `legacyEstimationFlag`) so it's possible to distinguish as-reported figures from filled-in ones during cleaning.
- **Confidentiality suppression.** Some countries withhold specific commodity/partner detail; the trade still counts in higher-level totals but won't appear broken out at the detailed level.

## Repository structure

```
trade-analytics/
├── data/
│   └── raw/                    # Raw CSV output from the UN Comtrade API pull
│       ├── track_a_country_benchmark_hs2.csv
│       ├── track_b_india_sector_detail_hs6.csv
│       └── track_c_india_partner_view_hs2.csv
├── sql/
│   ├── 00_create_staging_tables.sql   # Raw (all-TEXT) staging tables
│   └── ...                             # Numbered analysis queries, one per question
├── insights/
│   └── key_findings.md         # Plain-English findings, separate from raw SQL
└── README.md
```

## Reproducing the analysis

The API pull script itself isn't included in this repo; the three CSVs it produced are committed directly under `data/raw/`, so the analysis can be rebuilt without needing an API key.

1. Load the CSVs in `data/raw/` into PostgreSQL via `sql/00_create_staging_tables.sql` (raw, all-TEXT staging tables), one `COPY`/import per table.
2. Run `sql/01_data_cleaning.sql` to cast and clean into analysis-ready tables.

## Analysis & findings

*In progress.* SQL cleaning and analysis queries live in `sql/`, numbered by question. Findings, once written up, will be summarised in plain English in `insights/key_findings.md`.

## Tech stack

PostgreSQL 18 · pgAdmin 4 · Python (UN Comtrade API pull) · Power BI (planned dashboard phase)
