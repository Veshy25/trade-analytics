# Changelog

Smaller corrections to the SQL comments, the findings and the data dictionary,
moved here on 29/10/2026 from dated notes that sat inside those files. The four
corrections that changed a published claim are also in the findings, under
[Corrections kept visible](insights/key_findings.md#corrections-kept-visible).
Commit history has the rest.

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
  partner-years are positive, the largest by USD 1.
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
