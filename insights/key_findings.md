# Trade Analytics — Key Findings

India's merchandise exports, 2014–2023, benchmarked against China, Bangladesh
and Vietnam. Every figure below is traceable to a named query in `sql/`, and
the underlying result sets are committed as CSVs in `data/processed/` so
nothing here has to be taken on trust.

**Read this first — three things that shape every number on the page:**

- **All figures are nominal USD**, exporter-reported FOB. There is no deflator
  applied. The 2022 global commodity spike is therefore *inside* these numbers:
  part of what reads as growth is price, not volume, and petroleum is where
  that distortion is largest.
- **Bangladesh has 2015–2018 only** — four years, no 2023. This is a genuine
  gap in what UN Comtrade holds, not a pull error (`sql/02` assumption 2). Its
  growth rate spans three years and is not comparable to a nine-year rate
  without saying so.
- **Track C shares are share-of-panel, not share-of-world.** The 20 partner
  markets cover 61.9%–64.4% of India's exports, so a partner at "27.8%" holds
  27.8% of the tracked panel, not of India's global exports.

---

## Headline

> Over 2014–2023 India's exports compounded at **3.46% a year**, reaching
> **USD 431.4bn**. Vietnam — a smaller exporter than India in 2014 — compounded
> at **9.96%** and more than doubled. The gap is not a bad decade for India so
> much as a structural one: India's growth is concentrated in a commodity
> (petroleum, 20.7% of 2023 exports) whose value moves with world prices, while
> Vietnam's is concentrated in manufactured goods.

![Indexed export trend, four countries](indexed_export_trend.png)

---

## 1. India grew, but slowest of the four benchmarked economies

**CAGR 2014→2023: India 3.46%, China 4.16%, Vietnam 9.96%.**
Bangladesh compounded at 8.08%, but over 2015–2018 only.

| Country | First year | Last year | First (USD bn) | Last (USD bn) | CAGR |
|---|---|---|---:|---:|---:|
| Viet Nam | 2014 | 2023 | 150.2 | 353.1 | **9.96%** |
| Bangladesh | 2015 | 2018 | 31.7 | 40.1 | 8.08% *(3 yrs)* |
| China | 2014 | 2023 | 2,342.3 | 3,379.7 | 4.16% |
| **India** | 2014 | 2023 | 317.5 | **431.4** | **3.46%** |

*Source: `sql/02` Query 4 · `data/processed/track_a_cagr.csv`*

Indexed to each country's own base year, 2023 stands at **235 for Vietnam,
144 for China, 136 for India**. Vietnam's exports grew **135% against India's
36%** over the same ten years — close to four times the growth, from a starting
base less than half the size (USD 150.2bn against India's 317.5bn in 2014). By
2023 Vietnam had closed to 82% of India's total.

*Source: `sql/02` Query 4b · `data/processed/track_a_indexed_series.csv`*

## 2. The decade is really two halves, and the first one went backwards

India's exports **fell for two consecutive years from the 2014 base**, bottoming
at USD 260.3bn in 2016 — 18% below where the decade started. The index does not
recover to 100 until 2019.

| Year | USD bn | YoY |
|---|---:|---:|
| 2014 | 317.5 | — |
| 2015 | 264.4 | **−16.7%** |
| 2016 | 260.3 | −1.5% |
| 2017 | 294.4 | +13.1% |
| 2018 | 322.5 | +9.6% |
| 2019 | 323.3 | +0.2% |
| 2020 | 275.5 | **−14.8%** |
| 2021 | 394.8 | **+43.3%** |
| 2022 | 452.7 | +14.7% |
| 2023 | 431.4 | −4.7% |

Quoting decade CAGR alone hides this. A reader told "3.46% a year" pictures
steady compounding; the actual path is −18%, then +74% off the trough.

*Source: `sql/02` Queries 1–2 · `data/processed/track_a_country_year_totals.csv`*

## 3. 2022 was the peak, and it was substantially a price event

**USD 452.7bn in 2022 is the decade high** — 40% above 2019 in nominal terms.
Petroleum (HS 27) went from USD 56.4bn in 2021 to **98.5bn in 2022**, a 75%
jump in one year, in a year when crude prices rose sharply.

The 2023 fall confirms it. India's exports dropped USD 21.3bn from 2022, and
**petroleum alone accounts for USD 9.1bn of that — 43% of the total decline**,
from a chapter that is 20.7% of exports. Gems & jewellery (−5.8bn) and iron and
steel (−3.4bn) supply most of the rest.

*Source: `sql/02` Queries 1 and 3 · `data/processed/track_a_top10_chapters.csv`*

Because these are nominal figures, any 2014-vs-2023 or 2019-vs-2022 comparison
in this project carries an unquantified price component. Deflating to constant
USD would need a price index the project does not currently pull — a stated
limitation, not an oversight.

## 4. India's export basket is led by a commodity, not a manufacture

**Mineral fuels (HS 27) are 20.7% of India's 2023 exports at USD 89.3bn** —
nearly three times the next chapter.

| Rank | HS2 | Chapter | 2023 USD bn | Share |
|---:|---|---|---:|---:|
| 1 | 27 | Mineral fuels, oils | **89.3** | **20.7%** |
| 2 | 71 | Pearls, precious stones, jewellery | 33.4 | 7.7% |
| 3 | 85 | Electrical machinery | 32.3 | 7.5% |
| 4 | 84 | Machinery, mechanical appliances | 29.3 | 6.8% |
| 5 | 30 | Pharmaceutical products | 21.3 | 4.9% |
| 6 | 87 | Vehicles | 20.8 | 4.8% |

This is the mechanism behind finding 1. A fifth of the export book prices off
world energy markets, which is why India's series swings hardest in both 2020
and 2022 while Vietnam's climbs steadily through both.

*Source: `sql/02` Query 3 · `data/processed/track_a_top10_chapters.csv`*

## 5. Within the five focus sectors, the growth is entirely in engineering

**Engineering/machinery compounded at 11.79%, nearly tripling from USD 22.6bn
to 61.6bn.** Two of the five sectors *shrank* in nominal terms.

| Sector | 2014 USD bn | 2023 USD bn | CAGR |
|---|---:|---:|---:|
| Engineering / machinery | 22.6 | 61.6 | **+11.79%** |
| Pharmaceuticals | 11.7 | 21.3 | +6.92% |
| Petroleum products | 62.3 | 89.3 | +4.08% |
| Textiles | 38.6 | 34.2 | **−1.33%** |
| Gems & jewellery | 40.7 | 33.4 | **−2.16%** |

Textiles and gems & jewellery are traditional strengths of India's export base,
and both are smaller in 2023 than in 2014 *before* any inflation adjustment. In
real terms the decline is steeper than shown.

*Source: `sql/03` Queries 1–3 · `data/processed/track_b_sector_year_totals.csv`*

## 6. Sector concentration varies by two orders of magnitude

**Textiles HHI 118; pharmaceuticals HHI 5,751** — a 49× spread on the same
0–10,000 scale.

| Sector | HS6 products (2023) | Top-5 share | HHI 2023 |
|---|---:|---:|---:|
| Pharmaceuticals | 43 | 91.3% | **5,751** |
| Petroleum products | 41 | 98.6% | 5,238 |
| Gems & jewellery | 53 | 96.5% | 3,831 |
| Engineering / machinery | 826 | 36.2% | 624 |
| Textiles | 784 | 15.4% | **118** |

**Caveat that must travel with this number:** the three highest scores are
sectors defined as a *single HS2 chapter* (27, 30, 71). They are concentrated
partly by construction — a definition artefact as much as a market fact.
Textiles (14 chapters) and engineering (2) are not comparable to them without
that qualification.

`hs6_products_2023` counts products with a 2023 line, which is the correct
denominator for a 2023 index but is **not** the sector's full product count —
engineering holds 863 products across the decade and textiles 821, 37 more each
than appear in 2023.

*Source: `sql/03` Query 5 · `data/processed/track_b_sector_concentration_2023.csv`*

## 7. India's export markets are unconcentrated — provably, not just apparently

The 20-partner panel returns **HHI 1,180 in 2023**, but that number is computed
on a panel covering only 63.1% of India's exports, so it overstates
concentration by roughly 2.5× (shares inflate ~1.6×; HHI is quadratic).

Rescaling against Track A's India→World total brackets the true figure:

| | 2014 | 2023 |
|---|---:|---:|
| Panel HHI (not band-comparable) | 1,007 | 1,180 |
| Panel coverage | 61.9% | 63.1% |
| **True HHI, lower bound** | 386 | **470** |
| **True HHI, upper bound** | 1,839 | **1,831** |

The upper bound assumes the entire unobserved 37% is a *single* hidden partner —
absurd, but it is a genuine ceiling. Even then the figure peaks at 1,889 (2022)
and never approaches the 2,500 "concentrated" threshold. **India's export
markets are unconcentrated under any assumption about the unobserved third**,
which is a stronger claim than the panel figure alone can support.

*Source: `sql/04` Query 4 · `data/processed/track_c_partner_concentration.csv`*

## 8. But the top of the partner table is concentrated

**The USA alone takes 27.8% of the tracked panel at USD 75.8bn in 2023** — more
than twice the UAE in second place, and the top five take 59.0%.

| Rank | Partner | 2023 USD bn | Share of panel |
|---:|---|---:|---:|
| 1 | USA | **75.8** | **27.8%** |
| 2 | United Arab Emirates | 33.0 | 12.1% |
| 3 | Netherlands | 23.1 | 8.5% |
| 4 | China | 16.2 | 6.0% |
| 5 | United Kingdom | 12.5 | 4.6% |

Findings 7 and 8 are not in tension: the *tail* is long enough to keep whole-
market HHI low, while the *head* is heavy enough that a single trading
relationship carries real exposure. HHI is the wrong instrument for that risk;
the top-1 share is the right one.

*Source: `sql/04` Query 2 · `data/processed/track_c_partner_totals.csv`*

## 9. The Netherlands is the decade's biggest mover

**The Netherlands climbed from 8th to 3rd** in India's partner table between
2014 and 2023, reaching USD 23.1bn. Italy, Nepal and Indonesia each rose five
places from lower starting positions.

*Source: `sql/04` Query 5a*

A caution on interpretation: the Netherlands hosts Rotterdam, Europe's largest
port, so some of this is transshipment recorded against the port of entry rather
than final consumption. Comtrade records the declared partner. This is a known
limitation of partner-level trade data, not a data error.
*[Interpretation, not a figure derived from this dataset.]*

## 10. The sector detail reconciles to the chapter rollup within 2.46%

Track B (HS6 product detail) and Track A (HS2 chapter rollup) are separate API
pulls at different aggregation levels. Summing the Track A chapters behind each
sector should reproduce the Track B sector totals.

**Across all 50 sector-years the worst divergence is −2.46%** (engineering/
machinery, 2022), with mean divergence −0.25% or tighter in every sector. The
second-worst is −1.05%.

This is the project's strongest internal control: two independently pulled
datasets, at different granularities, agree to within a rounding error.

*Source: `sql/03` V5 · `data/processed/track_b_cross_track_reconciliation.csv`*

## 11. The chapter totals reconcile exactly to the published all-commodities figure

India's 2023 exports, summed here from 97 HS2 chapters, come to
**USD 431,411,977,211**. WITS (World Bank / ITC / UNCTAD / UN Comtrade / WTO)
publishes India's 2023 merchandise exports as **USD 431,411,977.21 thousand** —
identical to the dollar.

This confirms the aggregation is exactly right: no chapter missing, nothing
double-counted, no rollup row silently included.

**Honest limit on this check:** WITS draws on UN Comtrade, so it is not a fully
independent source. It validates the *arithmetic*, not Comtrade's underlying
figure. A genuinely independent anchor would be India's DGCI&S national
statistics, which are compiled on a fiscal-year (April–March) basis and so are
not directly comparable to these calendar-year totals.

*Source: `sql/02` Query 1 · [WITS India country profile](https://wits.worldbank.org/CountryProfile/en/IND), accessed 08/09/2026*

## 12. Half of India's decade export value is Comtrade-estimated — and it is a regime, not a spread

**51.6% of India's 2014–2023 export value sits on rows flagged
`legacyEstimationFlag = 4`** (Comtrade estimate rather than as-reported). China
is 72.4%, Bangladesh 70.2%, Vietnam 46.0%.

The important part is *how* that exposure is distributed. It is not a uniform
haircut across the decade — almost every country-year is either ~0% or
~90–100%:

| Year | India | China | Vietnam | Bangladesh |
|---|---:|---:|---:|---:|
| 2014 | 0.0 | 0.0 | 0.0 | — |
| 2015 | 0.0 | 0.0 | 0.0 | 0.0 |
| 2016 | 0.0 | **99.8** | 0.0 | **90.7** |
| 2017 | 0.0 | 0.0 | 0.0 | **89.4** |
| 2018 | 0.0 | **92.3** | **98.4** | **89.2** |
| 2019 | **99.9** | **95.4** | **98.3** | — |
| 2020 | **98.8** | **97.8** | **99.0** | — |
| 2021 | **100.0** | **98.8** | **85.2** | — |
| 2022 | **86.3** | **98.6** | 18.8 | — |
| 2023 | **78.8** | **97.9** | 11.0 | — |

**Consequence for everything above.** India's 2014 total is entirely
as-reported; its 2023 total is 78.8% estimated. The two endpoints of the
headline growth comparison are not constructed the same way. This does not
invalidate the comparison — these are the standard published figures, and no
serious trade analysis avoids them — but it is a material caveat that belongs
next to the growth number rather than in a footnote.

*Source: `sql/02` V1a/V1b · `data/processed/track_a_estimation_sensitivity.csv`*

---

## What this analysis does not answer

Stated as scope, not discovered as gaps:

- **Which markets buy which sectors.** Track B is HS6 to World; Track C is HS2
  by partner. Nothing here answers "who buys India's pharmaceuticals" — that
  needs a fourth pull (India → 20 partners at HS6 across the five sectors) and
  is Phase 2.
- **Real versus nominal.** No deflator is applied anywhere. See the note at the
  top and finding 3.
- **Imports and trade balance.** Exports only in Phase 1.
- **Volume versus value.** Quantity columns are dropped in cleaning; every
  figure here is value.
- **Why.** This is a descriptive analysis. It establishes what happened and
  quantifies it; it does not model causes.

---

*All figures: UN Comtrade, pulled 25/08/2026, exports, FOB, nominal USD.
Reproduce with `sql/00` → `sql/04`, then `sql/05_export_results.sql`.*
