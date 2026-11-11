# Changelog

Smaller corrections to the SQL comments, the findings and the data dictionary,
moved here on 29/10/2026 from dated notes that sat inside those files. The four
corrections that changed a published claim are also in the findings, under
[Corrections kept visible](insights/key_findings.md#corrections-kept-visible).
Commit history has the rest.

## 11/11/2026 — points from the fifth cold audit

- **Finding 1.** Retitled "slowest of the three economies with a full decade of
  data", previously "slowest of the four". Bangladesh's rate covers 2015–2018
  only, and over that window India (6.85%) grew faster than China (3.03%); the
  four-country figures for it are now in the finding (`sql/02` S9).
- **Finding 7.** The title no longer says "never highly concentrated", which
  holds on the 2010 bands only; this matches the Markets page change below.
- **Result sets.** Three figures the findings quote were in no CSV and now are:
  `track_d_reconciliation_vs_track_c.csv`, `track_d_panel_coverage.csv` and
  `track_e_panel_coverage.csv`. `supporting_figures.csv` gains S9–S12 and three
  rows under S8. Result sets: 28 → 31.
- **Assertions.** `07` V5 checks the published 50.4–58.2% itself, where it
  checked a 50.0–58.5 band, and reads the view the query prints. `02` V3 and
  `07` V4 assert the two totals matched to WITS, and `01` validation 9 asserts
  one name per reporter and partner code, since the views group on names.
  PASSED notices: 15 → 18.
- **Clean tables.** Columns that no query read are dropped from `sql/01`:
  quantity and weight on Track D, `qty` and its unit on Track B, and
  `legacy_estimation_flag` on Tracks C, D, E1 and E2. No result changes.
- **Dashboard text.** `data/processed/README.md` lists the figures that are typed
  into dashboard titles and caveats, with the CSV each comes from.
- **SQL comments.** The dated correction notes that still sat in the SQL files
  are removed; each is recorded in the sections below, and the comments now
  describe what each query does today. `sql/04` V5 reads its coverage from
  Query 4's view instead of restating the query.
- **Wording.**
  - Petroleum does not reconcile "exactly" across the two pulls: 85 of its 200
    partner-years are identical and the rest differ by up to USD 2.
  - "All 97 chapters exist in every year" holds for India and China; Viet Nam
    and Bangladesh lack one to four in some years.
  - `sql/06` S8 gave USD 1 as the largest positive gap; that is the gap on the
    largest percentage, and the largest in dollars is USD 17. The 23/09/2026
    entry below is corrected to match.
  - Comtrade's weight estimate comes from the value under two of its three
    methods, not one (finding 17, `sql/03` assumption 7, README).
  - Finding 17 quoted 2022's indices on a 2014 base as evidence of a price
    spike; it now quotes the 2021 → 2022 change.
  - Findings 13, 16 and 20: two sentences are marked as interpretation, one is
    replaced by a figure, and the transshipment caution is extended to the UAE.
  - `scripts/make_chart.py`: two figures in the docstring were taken from
    rounded indices (37.9% and 16.9%, previously 38.0% and 16.8%).
  - Data dictionary: `netWgt` is also carried on Track A and `isQtyEstimated`
    on Track B; `sql/01` said "48-50%" where the dictionary says 48.3–50.5%.
  - README and `data/raw/README.md` said the data "would have to be pulled
    manually from the site"; both now point to the documented pull.
  - Stale comments in `sql/01`, `02` and `03`; a `_usd` convention in
    `data/processed/README.md` that no column used.

## 11/11/2026 — Markets page no longer applies a concentration verdict

- **Dashboard.** The Markets page no longer applies a merger-guideline verdict
  to India's export-market concentration, in line with the Sectors page. The
  chart title is now "Concentration of India's export markets (HHI,
  2014–2023)", previously "India's export markets are never highly
  concentrated"; the 2,500 reference line is removed; and the caveat names
  both US thresholds, 2,500 (2010 guidelines) and 1,800 (2023 guidelines), as
  antitrust heuristics. The upper bound of the possible range passes 1,800 in
  2014–2016, 2022 and 2023, as finding 7 states. The partner chart's tooltip
  now reads "Partner" rather than "Partner Display".
- **Screenshots.** The Markets and Trade Balance screenshots are regenerated.
  Trade Balance now shows −43.7 for electrical machinery and +6.1 for fish.

## 10/11/2026 — dashboard slicer, opening page and trade-balance rounding

- **Dashboard.** The Benchmark page's top-ten chart now follows the country
  slicer, as the README describes; it had stayed on India for every country.
  The report now opens on the Benchmark page rather than Trade Balance.
- **Rounding.** `track_e_india_chapter_balance_2023.csv` now gives `balance_bn`
  to 3 dp (previously 2), so the dashboard's one-decimal figures round from the
  value rather than from a rounded figure. Electrical machinery (HS 85) shows
  −43.7, as in finding 18 (previously −43.8), and fish (HS 03) +6.1 (previously
  +6.2). No other figure changes.

## 05/11/2026 — dashboard, raw-data notice and repository history

- **Repository history.** The repository was recreated on this date so that the
  seven raw UN Comtrade CSVs are gone from its history as well as from `main`:
  at 284,752 records they exceed UN Comtrade's 100,000-record free limit for
  redistribution. Commit dates are kept. Earlier commit IDs and pull-request
  numbers no longer resolve; the review table in the README uses the new IDs.
- **Raw-data notice.** The notices in the README and `data/raw/README.md` now
  state that limit, replacing "permission has been requested".
- **Dashboard.** Pages 4 (Sector × Market) and 5 (Trade Balance) are added. The
  Sectors table no longer prints a merger-guideline verdict, and the Benchmark
  treemap is labelled as gross gains with the falls and net figure stated, which
  closes the fourth cold audit.
- **Wording.**
  - Finding 19's title called the USA and the Netherlands "the surplus markets";
    11 of the 20 are in surplus, and those two are the largest.
  - The findings preamble said five things and lists six.
  - The petroleum chart's footnote said weight is estimated "from value"; that
    is one of the three methods finding 17 names.
  - `data/raw/README.md` still described the CSVs as present, and
    `data/processed/README.md` and `sql/06` called page 4 planned.

## 29/10/2026 — points from the fourth cold audit

- **Raw data.** The seven raw UN Comtrade CSVs were removed from the
  repository: UN Comtrade's terms require permission to republish its data
  unmodified, and that permission has been requested. See the README.
- **Supporting figures.** Counts quoted in the findings, the README and SQL
  comments that no result set returned now come from named queries (`sql/02`
  S1–S4, `sql/03` S5–S7, `sql/06` S8), exported by `sql/08` as
  `data/processed/supporting_figures.csv`. Result sets: 27 → 28.
- **Assertions.** `03` V5, `04` V5 and `06` V3/V4 now check the published
  values themselves, not ceilings or ranges that would pass if the figures
  moved. `01` validation 8 asserts Track D has no zero-value rows, which the
  heatmap relies on. PASSED notices: 14 → 15.
- **Export order.** `track_d_sector_partner_shift.csv` was sorted on a key with
  ties (12 groups); a partner tie-break makes it deterministic. Same rows, a
  different order within ties.
- **Wording.**
  - The Bangladesh gap is "most likely" in the source, not proven.
  - India's 2023 total matches WITS to its published precision (USD 10), not
    "to the dollar".
  - The South Asian neighbours in the panel are four (Bhutan and Pakistan are
    not in it), not "all four".
  - Three figures were rounded from the 2 dp CSV rather than the value: −43.7,
    16.2 and +22.2 (previously −43.8, 16.3, +22.3).
  - The 23/09/2026 review is the third cold audit, not "a second".
  - The flag-code citation now points to a document a reader can open (FAO,
    UNSD and ITC, *Trade data processing and validation methodology*, 2019),
    and the weight-estimation methods are all three that document names.
  - Data dictionary: netWgt blanks are 48.3–50.5% (not "48–50%"); the
    dropped-column list was incomplete; the manifest's `pulls` array starts
    with the 15/09/2026 pull.
  - Seven exploratory queries are labelled as such.
  - Stale comments in `sql/02`, `03`, `04` and `scripts/make_chart.py`.

## 23/09/2026 — points from the third cold audit

- `sql/01`, `sql/02` V1a and finding 12: the flag-to-boolean containment on
  Track B was described as "exactly … no exceptions"; it holds in one direction
  only (2,905 flag-0 rows are estimated too).
- `sql/03` Q4 and finding 6: codes with no 2023 row were called "products that
  stopped being exported"; most are codes retired or split by an HS edition.
  The column `hs6_products_all_years` was renamed `hs6_codes_all_years`, having
  been read as "37 more products".
- `sql/04` Query 3: a full-period rank and share that nothing read were dropped
  when the query became a view; Query 4 lost a redundant second join.
- `sql/06` assumption 7 and `data/raw/README.md`: the explanation of the
  engineering 2022 gap was stated as fact; it is an inference. V3: the HS6 sum
  was described as "always negative" against the HS2 chapter; 332 of 1,000
  partner-years are positive, the largest by USD 17.
- `sql/07`: Q2's committed CSV came from an older copy of the query in `08`
  that lacked a COALESCE (harmless on this data); the CIF/FOB margin was quoted
  as 10% "long-standing" with a 10–20% range, which was out of date.
- Findings: finding 5 was titled "the growth is entirely in engineering"
  (it is 61%); finding 10 said the two tracks were "independently pulled …
  within a rounding error"; finding 15's title said every sector except gems
  and pharma concentrated further into the USA (wrong for gems and petroleum);
  finding 17 named petroleum as the least trustworthy volume series, against
  its own table; the Bangladesh note said WITS labelled its value 2016 (it is
  2015).
- `data/raw/README.md`: some sizes were in MiB, so the same file was quoted as
  74.9 and 78.5 MB; `sql/01` validation 3 covered Track A only while the text
  said "throughout"; an inference about revision drift was stated as fact.
- `sql/01` validation 6 (the partner panel) was a plain `SELECT` covering
  Tracks C and D while `sql/06` described it as asserted; it is now asserted
  and covers E2.
- `sql/02`: `track_a_top10_chapters.csv` gained `rank_basis`, because
  `rank_2023` is a full-period rank for Bangladesh; `rows_flag4` and
  `rows_netwgt_est` were printed but not exported.
- `sql/03` V5 printed its divergence at 1 dp (−2.5) while finding 10 cited
  −2.46.

## 17/09/2026 — points from the second cold audit

- `sql/01` and `data/raw/README.md`: `classificationCode` was listed as
  constant; it records the HS edition and changes by year and reporter. The
  uniqueness note said "three" tracks, from before Tracks D, E1 and E2 existed.
  `fobvalue` on the import tracks was described as "blank on 100%"; it is blank
  or exactly 0, never positive. The API response was said to carry `*Note`
  fields; it does not.
- `sql/02`: `legacy_estimation_flag` was treated as a value-estimation marker
  (see finding 12); the 73 HS6 rewordings were all attributed to HS 2022 (42
  are HS 2017). A third join kept only to read `reporter_desc` was removed.
- `sql/03`: Q8 reported only the row share of estimated weight; the
  kilogram-weighted share was added beside it.
- `sql/06` assumption 7 and `data/raw/README.md`: Track D was said to match
  Track C "to the cent everywhere except engineering"; the query's own output
  showed small gaps in textiles, pharmaceuticals and gems.
- Finding 18: the ten largest surpluses and deficits were summed as USD 65.3bn
  and 310.9bn; they are 80.8bn and 305.9bn.
- `sql/01`: validation 1 (row counts) was a plain `SELECT` while the data
  dictionary said a mismatch would fail loudly; the panel check's
  `EXCEPT … UNION ALL` ran left to right without parentheses and tested one
  direction only.
- `sql/02`: the Bangladesh gap was called genuine on the evidence of the pull
  itself, which is circular; the three chapter falls in finding 3 were derived
  ad hoc and cited to a CSV that did not hold them (now Query 5).
- `sql/07` V6: the two export-to-import joins were unasserted.
