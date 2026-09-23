# Raw data — provenance and dictionary

The seven CSVs in this folder are the unmodified output of two UN Comtrade API
pulls — three files on **25/08/2026** (Tracks A, B, C: exports) and four on
**15/09/2026** (Tracks D, E1, E2: partner × sector, and imports). They are the
*input* to the SQL cleaning phase, not something to hand-edit. Everything
downstream — `sql/00` through `sql/08` — is reproducible from these files
alone, with no API key and no network access. `sql/00` loads all seven before
any analysis runs; there is no partial or phased load.

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
| **Pulled** | 25/08/2026 (Tracks A, B, C) · 15/09/2026 (Tracks D, E1, E2) |
| **Scope agreed** | 21/08/2026 (Phase 1) · 15/09/2026 (Phase 2) |
| **Flow** | Exports (`flowCode = 'X'`) for A–D; imports (`flowCode = 'M'`) for E1, E2 |
| **Frequency** | Annual (`freqCode = 'A'`) |
| **Period** | 2014–2023 |
| **Valuation** | Exports: exporter-reported FOB, USD. Imports: CIF, USD |

**Why the pull date matters.** UN Comtrade revises figures after first
publication — that is the stated reason 2024–2025 are excluded from this project
(they are still being revised by reporters). A re-pull on a later date will
therefore not necessarily reproduce these files byte-for-byte, and any figure
quoted from this repository is a figure *as Comtrade held it on the pull date
of that file*. The pull date is metadata, not trivia.

**Two dates, one analysis.** Because Tracks D and E were pulled three weeks
after A–C, any query that combines them — every trade balance in `sql/07`,
every cross-track check in `sql/06` — mixes figures as held on two different
days. `sql/06` V3 measures this directly by reconciling Track D (15/09) against
Track C (25/08) for the same partner-years. Petroleum matches exactly across
all 200 partner-years; textiles (worst 0.18%), pharmaceuticals (0.97%) and gems
& jewellery (1.95%) stay within 2%; engineering/machinery in 2022 runs to
−11.5%. Eleven of the 1,000 partner-years checked exceed 1% — ten engineering
2022 and one gems 2022. (This paragraph claimed a match "to the cent everywhere
except engineering" until 17/09/2026, which the query's own output contradicted.)
The engineering gap is consistent with a property of Comtrade's HS 84/85 records
for that year rather than revision drift: Track B diverges from Track A in the
same sector-year (finding 10), and those two come from the *same* 25/08 pull.
That is an inference, not a proof — no series was pulled on both dates, so
revision between them cannot be ruled out directly. (This paragraph stated it
as established fact until 23/09/2026.) The three Phase 1 files were **not**
re-pulled and are byte-identical to their 25/08/2026 checksums.

### `pull_manifest.json`

`pull_manifest.json` in this folder is the machine-readable record of the pull:
timestamps, the exact API parameters per track, row counts, file sizes, and a
**SHA-256 for each CSV** — so the raw data is verifiable, not merely dated.
Anyone can confirm the files here are the ones the pull produced:

```bash
shasum -a 256 data/raw/*.csv        # compare against pull_manifest.json
```

It is written automatically at the end of every pull, and **merged, not
overwritten**: a later pull adds or replaces only the entries for the tracks it
fetched. Entries written since 15/09/2026 carry a `track` label, their own
`pulled_on` date and `pull` timestamps; the three original entries have neither
and inherit the top-level `pull` block. A `pulls` array logs each run.

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

| Track | File | `reporterCode` | `cmdCode` | `partnerCode` | `flowCode` | Pulled |
|---|---|---|---|---|---|---|
| **A** | `track_a_country_benchmark_hs2.csv` | IND, CHN, BGD, VNM | `AG2` (HS2, all ~97 chapters) | World (0) | `X` | 25/08/2026 |
| **B** | `track_b_india_sector_detail_hs6.csv` | IND | `AG6` (HS6), filtered post-pull to 5 sectors | World (0) | `X` | 25/08/2026 |
| **C** | `track_c_india_partner_view_hs2.csv` | IND | `AG2` | 20 named partners, **no World row** | `X` | 25/08/2026 |
| **D** | `track_d_india_partner_sector_hs6_2014_2018.csv`, `…_2019_2023.csv` | IND | `AG6` (HS6), filtered post-pull to 5 sectors | the same 20 partners, **no World row** | `X` | 15/09/2026 |
| **E1** | `track_e_country_imports_hs2.csv` | IND, CHN, BGD, VNM | `AG2` | World (0) | `M` | 15/09/2026 |
| **E2** | `track_e_india_partner_imports_hs2.csv` | IND | `AG2` | the same 20 partners, **no World row** | `M` | 15/09/2026 |

Common to all: `period=2014…2023` (one call per year), `partner2Code='0'`,
`customsCode='C00'`, `motCode='0'`. ISO3 codes are resolved to Comtrade numeric
codes at runtime. Track D was fetched as one call per year with the full
partner list; no response reached the API's 100,000-record cap, so no
per-partner fallback was needed. It is delivered as **two files split by year
range** because the single file came to 78.5 MB (74.9 MiB) — past GitHub's
50 MiB warning threshold, though still under its 100 MiB hard limit. The two
committed halves total the same 78.5 MB; `sql/00` loads both into one table.
Sizes in this file are decimal MB throughout; until 23/09/2026 some were MiB,
so the same bytes were quoted as both 74.9 and 78.5 MB.

**Partners (20, identical for Tracks C, D and E2):** USA, ARE, CHN, BGD, MDV,
GBR, DEU, NPL, SGP, VNM, NLD, SAU, FRA, LKA, IDN, MYS, ITA, BEL, ZAF, JPN.
**This is a selected panel, not India's top 20 markets.** No selection rule
survives in the project's records. It contains India's largest export
destinations, all four South Asian neighbours regardless of size (the Maldives
takes 0.2% of the panel) and Viet Nam, a Track A comparator; several markets
larger than the smallest members are left out. It was chosen for exports and
reused unchanged for imports (E2), where it under-represents energy and gold
suppliers — `sql/04` assumption 7 and `sql/07` assumption 9.
There is deliberately no World row, so every share computed in `sql/04`,
`sql/06` and `sql/07` is a share *of these twenty*, not of India's global
trade. Panel coverage is measured in each file: 61.9%–64.4% of India's exports
(`sql/04` V5), 57–70% of each sector's exports in 2023 and 52.3%–71.3% across
all fifty sector-years (`sql/06` V4), 50–58% of India's imports (`sql/07` V5).

**Track B and D sectors → HS2 chapters** (the `sector` column is derived
identically in both):

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
| `track_a_country_benchmark_hs2.csv` | 3,282 | 0.92 MB |
| `track_b_india_sector_detail_hs6.csv` | 16,976 | 5.95 MB |
| `track_c_india_partner_view_hs2.csv` | 18,956 | 5.35 MB |
| `track_d_india_partner_sector_hs6_2014_2018.csv` | 110,211 | 37.86 MB |
| `track_d_india_partner_sector_hs6_2019_2023.csv` | 115,087 | 40.67 MB |
| `track_e_country_imports_hs2.csv` | 3,294 | 0.93 MB |
| `track_e_india_partner_imports_hs2.csv` | 16,946 | 4.78 MB |

Checksums for all seven are in `pull_manifest.json`. Track D's two files load
into one table (225,298 rows).

`sql/01` asserts these same counts after cleaning — raw and clean must agree.
As of 17/09/2026 that is literally true: validation 1 is a `DO` block that
raises and aborts the run on a mismatch. Until then it was a plain `SELECT`
that printed the counts, and this sentence overstated it — a short raw file
would have loaded, cleaned and run every downstream track without error.

## Columns

Each CSV carries **47 columns** as returned by the API (48 on the HS6 tracks
B and D, which add the derived `sector`). The headers of D, E1 and E2 are
byte-identical to those of B, A and C respectively, which is why `sql/00`
declares their staging tables `LIKE` the Phase 1 ones. `sql/01` keeps the
columns the analysis uses and drops the rest; which columns are kept differs
slightly by track — see the notes column.

### Kept in `clean_*`

| Raw column | Clean column | Type | Notes |
|---|---|---|---|
| `refYear` | `ref_year` | integer | 2014–2023 |
| `reporterCode` | `reporter_code` | integer | Comtrade numeric code |
| `reporterISO` | `reporter_iso` | text | IND / CHN / BGD / VNM |
| `reporterDesc` | `reporter_desc` | text | |
| `partnerCode` | `partner_code` | integer | `0` = World |
| `partnerDesc` | `partner_desc` | text | |
| `cmdCode` | `cmd_code` | **text** | **Kept as text on purpose** — chapters 01–09 are zero-padded, and casting to integer would mangle nine HS chapters and break the string range comparison in `03` V5 |
| `cmdDesc` | `cmd_desc` | text | |
| `aggrLevel` | `aggr_level` | smallint | 2 = HS2 chapter, 6 = HS6 product |
| `isLeaf` | — | boolean | Dropped 17/09/2026: read by no query in `02`–`08` |
| `fobvalue` | `fob_value` | numeric | **Export tracks (A–D).** Free-on-board value, USD — the analysis value |
| `cifvalue` | `cif_value` | numeric | **Import tracks (E1, E2).** Cost-insurance-freight value, USD — the analysis value for imports. `fobvalue` is blank on 73.5% of E1 rows and 69.6% of E2 rows and holds exactly `0` on the rest — never a positive value — and is dropped there. (Said "blank on 100%" until 17/09/2026.) |
| `primaryValue` | `primary_value` | numeric | Equals `fob_value` on every export row and `cif_value` on every import row; `sql/01` validations 3 and 5 assert 0 mismatches each |
| `legacyEstimationFlag` | `legacy_estimation_flag` | smallint | **A quantity/net-weight estimation code, NOT a value-estimation marker.** UNSD, *Quantity and Weight information in UN Comtrade* (October 2009), §4.1: `0` = no estimation, `2` = quantity only, `4` = net weight only, `6` = both. Tracks A, C, E1 and E2 carry only `0` and `4`; Tracks B and D carry all four (B: 6,382 / 162 / 3,776 / 6,656 rows, with flag `6` on 56% of Track B value). This file described `4` as "Comtrade estimate" until 17/09/2026 — see `sql/02` V1a and finding 12 for the correction |
| `isReported` | `is_reported` | boolean | This exact row was directly reported |
| `isAggregate` | `is_aggregate` | boolean | Row was **computed by rolling up** more detailed lines rather than filed directly at this level. It marks how a value was *assembled*, not whether it was estimated — and neither does `legacy_estimation_flag`, which is about weight. Each reporter switches from `isReported` to `isAggregate` once and never back (China 2015, Viet Nam and Bangladesh 2016, India 2017); `sql/02` V1a/V1b report it |
| `sector` | `sector` | text | **Tracks B and D only — DERIVED, not from the API.** Assigned during the pull by mapping the HS2 prefix of `cmdCode` to one of the five sector labels above (see the sector table earlier in this file) |
| `netWgt` | `net_wgt` | numeric | **Tracks B and D only** (HS6). Net weight in kg — the single volume measure used in `sql/03` Q6–Q8. Populated (positive) on ~90% of HS6 rows. On the HS2 tracks it is blank on 48–50% of rows and exactly `0` on the rest — no positive value anywhere — because Comtrade does not aggregate mixed units to chapter level; "blank on 100%" was the wrong description and is corrected here. Carried since 15/09/2026 |
| `isNetWgtEstimated` | `is_net_wgt_estimated` | boolean | Tracks B and D, and Track A since 17/09/2026 (where `sql/02` V1a uses it to assert what `legacy_estimation_flag` means). Comtrade's estimate flag for the weight, reported per sector-year in `sql/03` Q8 both as a row share and — the one that matters for a volume claim — as `weight_estimated_kg_pct` |
| `classificationCode` | `classification_code` | text | **Not constant — the HS edition the row was filed under.** `H4` to 2016, `H5` from 2017, `H6` from 2022, and it varies by reporter as well as by year (Viet Nam filed 2017 under `H4`). Carried on Track B from 17/09/2026 and mapped in `sql/01` validation 7; dropped on tracks that never group on `cmdDesc` |
| `partnerISO` | — | text | Dropped 17/09/2026: read by no query in `02`–`08`; `partner_desc` carries it |
| `qty` / `qtyUnitAbbr` | `qty` / `qty_unit` | numeric / text | Tracks B and D. Quantity in the commodity's own unit (u, m², carat, kWh, kg…). Kept for per-product reference only — **never summed**, because units differ within a sector |

### Dropped in cleaning

On the export tracks, `cifvalue` — non-blank on 873 Track A rows, but all 873
hold exactly `0`, so "populated" overstated it; irrelevant to an FOB-valued
export in any case, and `sql/01` validation 3 asserts `primary_value = fob_value`
on every export track (A, B, C and D — Track A only until 23/09/2026, when this
sentence already said "throughout").
On the import tracks, `fobvalue` (blank or `0`, never positive). On the HS2
tracks, all quantity and weight fields — blank or `0` by construction, never
positive; on the HS6 tracks, `altQty`, `grossWgt` and their unit/estimated
companions. `isLeaf` and `partnerISO` were dropped on 17/09/2026 as unread by
any query. On every track: `motCode`/`motDesc`, `customsCode`/`customsDesc`,
`mosCode`, `typeCode`, `freqCode`, `period`, `flowCode`/`flowDesc` (constant
within each track), `partner2*`, `refPeriodId`, `refMonth` and
`isOriginalClassification`. `classificationCode` is dropped everywhere except
Track B — it is *not* constant, and this file listed it as such until
17/09/2026. There are no `*Note` fields in this API response; an earlier
version of this list said there were.

### A note on `cmdDesc`

HS descriptions are **not stable across the decade**, and two editions move
them. The five HS2 chapter rewordings (15, 16, 24, 84, 88) are HS 2022, from
`refYear` 2022 onward. The 73 HS6 products reworded in Tracks B/D are not:
**42 change at 2017** (HS 2017, `classificationCode` H4 → H5) and **34 at 2022**
(HS 2022, H5 → H6), with three codes — 570490, 847510, 852352 — changing in
both years, two of which revert to their pre-2017 wording. This file attributed
all 73 to HS 2022 until 17/09/2026. The description is a label that changes,
and `classificationCode` is the column that says which edition a row belongs
to. Any multi-year `GROUP BY` that includes `cmdDesc` splits one code into two
rows — `sql/02` assumption 7 records the case where that happened and was
corrected.

**The code is the key only within one edition.** This file used to say "the
code is the key" without qualification. At HS2 that holds — all 97 chapters
exist every year. At HS6 it does not: each edition also *splits, merges and
retires* codes (mobile phones were `851712` until 2021, then `851713`
smartphones and `851714` other). Most HS6 codes that "disappear" from Track B
do so in 2016 or 2021, the year before an edition change — retired or split,
not discontinued. So a per-code series spanning 2016/2017 or 2021/2022 is not
like-for-like, and a count of distinct codes across the decade is not a count
of products. This project does not map codes across editions (that would need
UNSD's HS correlation tables); it keeps product-level claims within a single
edition or states them as code counts.

## Reproducing the analysis

Nothing needs re-pulling. Run `sql/00` through `sql/08` from the repository root
against a PostgreSQL database — the CSVs here are the only input required, and
`sql/01` asserts the expected row counts (and the FOB/CIF valuation invariants)
in `DO` blocks that `RAISE EXCEPTION`, so a mismatch fails loudly rather than
producing quiet nonsense.

To confirm the files are the ones the analysis was built on:

```bash
shasum -a 256 data/raw/*.csv        # compare against pull_manifest.json
```

If you want equivalent data for your own work, both pulls are fully specified
above — reporters, period, `cmdCode`, `flowCode` and the partner list are all
recorded, and a free UN Comtrade API key plus the `comtradeapicall` client will
reproduce the request. Expect different figures for the recent years: that
difference is the reason this repository ships the data rather than the puller.
