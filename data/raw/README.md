# Raw data — provenance and dictionary

The three CSVs in this folder are the unmodified output of a single UN Comtrade
API pull on 25/08/2026. They are the *input* to the SQL cleaning phase, not
something to hand-edit. Everything downstream — `sql/00` through `sql/05` — is
reproducible from these files alone, with no API key and no network access.

**The pull script itself is deliberately not published.** Comtrade revises
figures after first publication, so a fresh pull would return different numbers
and the repository's committed findings would no longer match what its code
produces. Freezing the raw data — and publishing the checksums below — makes the
analysis reproducible by construction. What the pull *did* is fully documented
here and in `pull_manifest.json`, which is what reproducibility actually
requires; being able to re-run it and get something else is not.

## Provenance

| | |
|---|---|
| **Source** | UN Comtrade, via the official `comtradeapicall` Python client |
| **Endpoint** | `comtradeapi.un.org` (Free APIs product) |
| **Pulled** | 25/08/2026 |
| **Scope agreed** | 21/08/2026 |
| **Flow** | Exports only (`flowCode = 'X'`) |
| **Frequency** | Annual (`freqCode = 'A'`) |
| **Period** | 2014–2023 |
| **Valuation** | Exporter-reported FOB, USD |

**Why the pull date matters.** UN Comtrade revises figures after first
publication — that is the stated reason 2024–2025 are excluded from this project
(they are still being revised by reporters). A re-pull on a later date will
therefore not necessarily reproduce these files byte-for-byte, and any figure
quoted from this repository is a figure *as Comtrade held it on 25/08/2026*.
The pull date is metadata, not trivia.

### `pull_manifest.json`

`pull_manifest.json` in this folder is the machine-readable record of the pull:
timestamps, the exact API parameters per track, row counts, file sizes, and a
**SHA-256 for each CSV** — so the raw data is verifiable, not merely dated.
Anyone can confirm the files here are the ones the pull produced:

```bash
shasum -a 256 data/raw/*.csv        # compare against pull_manifest.json
```

It is written automatically at the end of every pull.

*One caveat, stated because it matters: the manifest committed today was
reconstructed **retroactively** on 08/09/2026. The 25/08/2026 pull predates the
manifest feature, so its date comes from the CSVs' filesystem mtimes — reliable
to the day, but not to the second, and the `_reconstructed` block in the JSON
says so. Future pulls record exact start and finish timestamps directly.*

*A `pulled_at` column inside each CSV was considered and rejected: `sql/00`
loads positionally, so a 48th column would desync every `raw_*` staging table
from the data already committed. A sidecar file carries the same metadata and
touches no schema.*

## Exact API parameters

| Track | File | `reporterCode` | `cmdCode` | `partnerCode` |
|---|---|---|---|---|
| **A** | `track_a_country_benchmark_hs2.csv` | IND, CHN, BGD, VNM | `AG2` (HS2, all ~97 chapters) | World (0) |
| **B** | `track_b_india_sector_detail_hs6.csv` | IND | `AG6` (HS6), filtered post-pull to 5 sectors | World (0) |
| **C** | `track_c_india_partner_view_hs2.csv` | IND | `AG2` | 20 named partners, **no World row** |

Common to all three: `flowCode='X'`, `period=2014…2023` (one call per year),
`partner2Code='0'`. ISO3 codes are resolved to Comtrade numeric codes at
runtime.

**Track C partners (20):** USA, ARE, CHN, BGD, MDV, GBR, DEU, NPL, SGP, VNM,
NLD, SAU, FRA, LKA, IDN, MYS, ITA, BEL, ZAF, JPN.
There is deliberately no World row, so every share computed in `sql/04` is a
share *of these twenty*, not of India's global exports. `sql/04` Q4 and V5
quantify that panel against Track A's India→World total (61.9%–64.4%).

**Track B sectors → HS2 chapters:**

| Sector | Chapters |
|---|---|
| `textiles` | 50–63 |
| `pharmaceuticals` | 30 |
| `gems_jewellery` | 71 |
| `petroleum_products` | 27 |
| `engineering_machinery` | 84, 85 |

## Row counts

| File | Rows | Size |
|---|---:|---:|
| `track_a_country_benchmark_hs2.csv` | 3,282 | ~0.92 MB |
| `track_b_india_sector_detail_hs6.csv` | 16,976 | ~5.95 MB |
| `track_c_india_partner_view_hs2.csv` | 18,956 | ~5.35 MB |

Checksums for all three are in `pull_manifest.json`.

`sql/01` asserts these same counts after cleaning — raw and clean must agree.

## Columns

Each CSV carries **47 columns** as returned by the API. `sql/01` keeps the 16
that the analysis uses and drops the rest (quantity, weight, transport mode,
customs and alt-quantity fields — all either empty or irrelevant to an
exports-only value analysis).

### Kept in `clean_*`

| Raw column | Clean column | Type | Notes |
|---|---|---|---|
| `refYear` | `ref_year` | integer | 2014–2023 |
| `reporterCode` | `reporter_code` | integer | Comtrade numeric code |
| `reporterISO` | `reporter_iso` | text | IND / CHN / BGD / VNM |
| `reporterDesc` | `reporter_desc` | text | |
| `partnerCode` | `partner_code` | integer | `0` = World |
| `partnerISO` | `partner_iso` | text | |
| `partnerDesc` | `partner_desc` | text | |
| `cmdCode` | `cmd_code` | **text** | **Kept as text on purpose** — chapters 01–09 are zero-padded, and casting to integer would mangle nine HS chapters and break the string range comparison in `03` V5 |
| `cmdDesc` | `cmd_desc` | text | |
| `aggrLevel` | `aggr_level` | smallint | 2 = HS2 chapter, 6 = HS6 product |
| `isLeaf` | `is_leaf` | boolean | |
| `fobvalue` | `fob_value` | numeric | Free-on-board value, USD — the analysis value |
| `primaryValue` | `primary_value` | numeric | Equals `fob_value` in every row here (exports only); `sql/01` validation asserts 0 mismatches |
| `legacyEstimationFlag` | `legacy_estimation_flag` | smallint | Only two values present: `0` (as reported) and `4` (Comtrade estimate). See `sql/02` V1a — exposure is a regime, not a gradient |
| `isReported` | `is_reported` | boolean | This exact row was directly reported |
| `isAggregate` | `is_aggregate` | boolean | Row was **computed by rolling up** more detailed lines. This is *not* an estimation marker — that is `legacy_estimation_flag`. The two axes are independent |
| `sector` | `sector` | text | **Track B only — DERIVED, not from the API.** Assigned during the pull by mapping the HS2 prefix of `cmdCode` to one of the five sector labels above (see the sector table earlier in this file) |

### Dropped in cleaning

`cifvalue` (populated on 873 Track A rows but irrelevant to an exports-only
pull — `sql/01` validates that `primary_value = fob_value` throughout), plus
`qty`, `altQty`, `netWgt`, `grossWgt` and their unit/estimated companions,
`motCode`/`motDesc`, `customsCode`/`customsDesc`, `mosCode`, `classificationCode`,
`typeCode`, `freqCode`, `period`, `flowCode`/`flowDesc` (constant across the
pull) and the various `*Note` fields.

## Reproducing the analysis

Nothing needs re-pulling. Run `sql/00` through `sql/05` from the repository root
against a PostgreSQL database — the CSVs here are the only input required, and
`sql/01` asserts the expected row counts so a mismatch fails loudly rather than
producing quiet nonsense.

To confirm the files are the ones the analysis was built on:

```bash
shasum -a 256 data/raw/*.csv        # compare against pull_manifest.json
```

If you want equivalent data for your own work, the pull is fully specified
above — reporters, period, `cmdCode`, `flowCode` and the partner list are all
recorded, and a free UN Comtrade API key plus the `comtradeapicall` client will
reproduce the request. Expect different figures for the recent years: that
difference is the reason this repository ships the data rather than the puller.
