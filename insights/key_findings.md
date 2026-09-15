# Trade Analytics — Key Findings

India's merchandise trade, 2014–2023: exports benchmarked against China,
Bangladesh and Vietnam (findings 1–12), then — from a second pull — where each
sector's exports go, imports and trade balance, and volume against value
(findings 13–20). Every figure below is traceable to a named query in `sql/`,
and the underlying result sets are committed as CSVs in `data/processed/` so
nothing here has to be taken on trust.

**Read this first — five things that shape every number on the page:**

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
  27.8% of the tracked panel, not of India's global exports. The same applies
  to Track D (57–70% of each sector's exports, `sql/06` V4) and to Track E2
  (50–58% of India's imports, `sql/07` V5).
- **Balances are FOB exports minus CIF imports.** Imports are valued including
  freight and insurance; exports are not. That is how published merchandise
  balances are built, but it overstates every deficit here by the freight
  margin (`sql/07` assumption 1).
- **Two pulls, two dates.** Exports were pulled 25/08/2026; imports and the
  partner × sector data on 15/09/2026. Every cross-check between them is
  reported in the SQL validation blocks; none showed revision drift.

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
and 2022 while Vietnam's climbs steadily through both. Finding 17 adds the
volume side: across the whole decade, petroleum's growth was tonnes, not price.

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

---

# Phase 2 — markets by sector, imports, and volume

Second pull, 15/09/2026. Three new tracks: **D** — India's exports to the same
20 partners at HS6 for the five sectors; **E** — imports for the four countries
and for India by partner; and the volume columns already in Track B, carried
into the analysis for the first time.

## 13. The USA takes 62% of India's pharma exports to the panel — and at least 35% of the world total

**USD 7.55bn of pharmaceuticals went to the USA in 2023: 62.2% of the
20-partner panel**, with the UK (5.2%) and South Africa (5.1%) a distant second
and third. Pharma is the most single-market-dependent sector by a wide margin.

| Sector | #1 market | Share of panel | #2 | #3 |
|---|---|---:|---|---|
| Pharmaceuticals | USA | **62.2%** | UK 5.2% | South Africa 5.1% |
| Gems & jewellery | USA | 44.8% | UAE 33.4% | Belgium 9.7% |
| Textiles | USA | 38.7% | Bangladesh 11.0% | UAE 8.2% |
| Engineering / machinery | USA | 37.4% | UAE 11.6% | UK 7.3% |
| Petroleum products | Netherlands | 28.5% | UAE 14.2% | USA 12.4% |

Because the panel covers only 57.0% of India's pharma exports to the world
(`sql/06` V4), the USA's share of the *world* total is at least
7.55 / 21.30 = **35.4%** — a floor, not an estimate, since the unobserved 43%
could contain more US trade but not less. Four of the five sectors have the USA
as their largest market; petroleum is the exception.

What the USA buys is packaged medicaments (HS 300490, 300420, 300410 — the top
three products), not bulk actives.

![Sector × partner heatmap, 2023](sector_partner_heatmap_2023.png)

*Source: `sql/06` Queries 1 and 3 · `data/processed/track_d_sector_partner_matrix_2023.csv`, `track_d_top_products_by_market.csv`*

## 14. Finding 9 explained: the Netherlands' rise is petroleum, and it displaced Saudi Arabia and Japan

**The Netherlands' share of India's panel petroleum exports went from 7.3% in
2014 to 28.5% in 2023** — a 21.2-point gain, the largest shift of any
sector–market pair in the data — reaching USD 15.0bn. Over the same period
**Saudi Arabia fell from 18.8% to 1.8%** (USD 7.2bn → 0.9bn) and **Japan from
5.4% to 0.3%** (2.1bn → 0.1bn).

| Sector | Market | 2014 share | 2023 share | Shift |
|---|---|---:|---:|---:|
| Petroleum | Netherlands | 7.3% | 28.5% | **+21.2 pt** |
| Petroleum | Saudi Arabia | 18.8% | 1.8% | **−17.1 pt** |
| Gems & jewellery | UAE | 47.6% | 33.4% | −14.2 pt |
| Engineering | USA | 24.1% | 37.4% | +13.3 pt |
| Gems & jewellery | USA | 32.5% | 44.8% | +12.3 pt |
| Textiles | USA | 26.7% | 38.7% | +12.0 pt |
| Textiles | China | 11.8% | 4.6% | −7.2 pt |

The Rotterdam caution in finding 9 stands: a share of this is refined product
landed at Europe's largest port for onward distribution, recorded against the
Netherlands. Comtrade records the declared partner.

*Source: `sql/06` Query 2 · `data/processed/track_d_sector_partner_shift.csv`*

## 15. Every sector except gems and pharma concentrated further into the USA

**Engineering's panel HHI rose from 998 to 1,745 and textiles' from 1,287 to
1,857** between 2014 and 2023, in both cases because the USA's share grew by
12–13 points. The top-3 share rose from 42.5% to 56.2% for engineering and
51.6% to 57.9% for textiles. Gems (3,472 → 3,240) and pharma (4,134 → 3,991)
eased slightly from much higher levels; they were already two-market and
one-market books.

These are panel HHIs and are not scored against the usual bands — the panel is
not the whole market (`sql/06` assumption 6). The direction is what the data
supports: the manufactured-goods sectors are becoming more US-dependent, not
less.

*Source: `sql/06` Query 4 · `data/processed/track_d_sector_market_concentration.csv`*

## 16. India runs a structural deficit that widened from USD 142bn to 241bn; Vietnam swung to surplus

**India imported USD 672.1bn in 2023 against exports of 431.4bn — a deficit
of USD 240.7bn, 21.8% of total trade.** The deficit was USD 141.8bn in 2014
(18.3% of trade) and has stayed between 14% and 24% of trade every year since,
narrowest in 2020 (14.4%) and 2016 (15.6%) — both years when import prices
collapsed — and widest in 2022 (23.6%). Exports covered 64.2% of imports in 2023,
down from 69.1% in 2014.

| Country | 2014 balance (USD bn) | 2023 balance (USD bn) | 2023, % of trade |
|---|---:|---:|---:|
| China | +383.1 | **+823.0** | +13.9% |
| Viet Nam | +2.4 | **+27.6** | +4.1% |
| India | −141.8 | **−240.7** | −21.8% |
| Bangladesh | −16.3 *(2015)* | −40.4 *(2018)* | −33.5% *(2018)* |

Vietnam is the contrast case again: roughly balanced in 2014, it has run a
surplus every year since 2016 and reached +27.6bn in 2023. It did this with
imports growing almost as fast as exports — it is not import substitution, it
is an export base that grew faster than the country's own demand.

The 2023 India total matches WITS's published figure of USD 672,140 million,
the import-side twin of finding 11.

*Source: `sql/07` Query 1, V4 · `data/processed/track_e_country_trade_balance.csv` · [WITS India country profile](https://wits.worldbank.org/CountryProfile/en/Country/IND/Year/2023/Summary), accessed 15/09/2026*

## 17. Petroleum's decade growth was volume, not price — the reverse of what the value series suggests

**India shipped 108.9 million tonnes of petroleum products in 2023 against
73.1 in 2014 — up 49%. The unit value fell from USD 0.853/kg to 0.807/kg, down
5.5%.** The 41% rise in export value over the decade is therefore entirely
tonnage; price ended the period below where it started.

The intervening years were the opposite. From 2014 to 2016, value fell 56% while
tonnes fell only 8%: the collapse was price. 2022's spike was price too — unit
value index 114.6, volume 136.9, value 157.9 — which is what finding 3 said,
and it remains true for that year. But the endpoint comparison is a volume
story, and the value chart alone cannot show it.

![Petroleum: value, volume, unit value indexed](petroleum_volume_vs_value.png)

| Sector | Tonnes 2014→2023 | Unit value 2014→2023 | Value CAGR | Volume CAGR | Reading |
|---|---:|---:|---:|---:|---|
| Petroleum products | +49.0% | −5.5% | 4.1% | 4.5% | all volume |
| Pharmaceuticals | +78.1% | +2.6% | 6.9% | 6.6% | all volume |
| Engineering / machinery | +78.1% | +44.8% | 11.8% | 6.6% | volume *and* price — moving up the value chain |
| Textiles | −14.9% | −0.9% | −1.3% | −1.8% | a real decline in tonnes, not a price effect |
| Gems & jewellery | — | — | −2.2% | — | **no volume claim**: weight covers only 40% of 2014 value |

Textiles is the one sector where the volume data changes the reading most:
5.86 million tonnes in 2023 against 6.89 in 2014, and no year after 2018 back
above the 2014 level except 2021. That is a shrinking physical export, not a
nominal artefact.

Gems & jewellery is excluded on coverage (`sql/03` Q8): only 40% of its 2014
value sits on rows with a net weight, and weight is a poor measure of gems in
any case. The row is in the CSV, flagged.

*Source: `sql/03` Queries 6–8 · `data/processed/track_b_sector_volume_vs_value.csv`, `track_b_petroleum_volume_series.csv`, `track_b_volume_coverage.csv`*

## 18. Half of India's deficit is one chapter, and the surplus chapters are small

**Mineral fuels (HS 27) ran a USD 131.3bn deficit in 2023 — 220.6bn imported
against 89.3bn exported — 55% of the total deficit.** Electrical machinery
(−43.8bn), precious stones and metals (−39.2bn) and machinery (−27.8bn) follow.
India is a net importer in three of its own five focus sectors — petroleum,
gems and engineering — despite being a large exporter in each.

The largest surplus chapter is pharmaceuticals at **+18.7bn** (21.3bn out, 2.6bn
in), then vehicles (+13.1bn) and cereals (+11.1bn). The ten largest surpluses
sum to USD 65.3bn; the ten largest deficits to 310.9bn.

| Side | HS2 | Chapter | Exports | Imports | Balance (USD bn) |
|---|---|---|---:|---:|---:|
| Deficit | 27 | Mineral fuels | 89.3 | 220.6 | **−131.3** |
| Deficit | 85 | Electrical machinery | 32.3 | 76.1 | −43.8 |
| Deficit | 71 | Pearls, stones, precious metals | 33.4 | 72.7 | −39.2 |
| Deficit | 84 | Machinery | 29.3 | 57.1 | −27.8 |
| Surplus | 30 | Pharmaceuticals | 21.3 | 2.6 | **+18.7** |
| Surplus | 87 | Vehicles | 20.8 | 7.7 | +13.1 |
| Surplus | 10 | Cereals | 11.3 | 0.1 | +11.1 |

*Source: `sql/07` Query 2 · `data/processed/track_e_india_chapter_balance_2023.csv`*

## 19. The China deficit more than doubled to USD 106bn; the USA and Netherlands are the surplus markets

**India's bilateral deficit with China was USD 105.7bn in 2023 — 122.0bn
imported, 16.3bn exported — up from 44.8bn in 2014.** It is 44% of India's
total deficit and larger than the next four bilateral deficits combined
(Saudi Arabia −23.8, Indonesia −16.6, Japan −13.7, Germany −8.5).

On the other side, **the USA (+33.7bn) and the Netherlands (+20.7bn)** are the
two large surplus markets. The Netherlands surplus is petroleum (finding 14).
The UAE flipped from a +5.6bn surplus in 2014 to a −4.5bn deficit in 2023, and
Vietnam from +3.7bn to −4.0bn.

| Partner | Exports 2023 | Imports 2023 | Balance 2014 | Balance 2023 | Change |
|---|---:|---:|---:|---:|---:|
| China | 16.3 | 122.0 | −44.8 | **−105.7** | −60.9 |
| Saudi Arabia | 10.8 | 34.6 | −19.6 | −23.8 | −4.2 |
| Indonesia | 7.4 | 24.0 | −10.7 | −16.6 | −5.9 |
| UAE | 33.0 | 37.5 | +5.6 | −4.5 | −10.2 |
| Netherlands | 23.1 | 2.4 | +4.0 | **+20.7** | +16.7 |
| USA | 75.8 | 42.1 | +22.3 | **+33.7** | +11.4 |

The 20 partners cover 50–58% of India's imports (`sql/07` V5), lower than the
export-side panel — India's import sources are more dispersed than its export
markets.

*Source: `sql/07` Query 3 · `data/processed/track_e_india_partner_balance.csv`*

## 20. India's import basket is shifting from fuel to electronics

**Mineral fuels fell from 38.5% of India's imports in 2014 to 32.8% in 2023;
electrical machinery rose from 6.9% to 11.3%** (USD 76.1bn) and machinery from
6.8% to 8.5%. Precious stones and metals fell from 13.0% to 10.8%. The import
book is slowly rebalancing from energy and gold toward capital and electronic
goods — which, set against finding 18, means the deficit is migrating into the
same chapters India is trying to export.

*Source: `sql/07` Query 4 · `data/processed/track_e_india_import_mix.csv`*

---

## A correction made in this phase

**HS descriptions change between HS editions, and one Phase 1 query grouped
on them.** HS 2022 reworded chapters 15, 16, 24, 84 and 88 from 2022 onward.
`sql/02` Query 3 grouped by `cmd_code, cmd_desc` across all ten years, so for
those five chapters the "2014–2023" column summed only 2022–2023. In the
published `track_a_top10_chapters.csv`, HS 84's full-period value read USD
1,062.6bn for China (true: **4,385.0bn**), 56.8bn for India (**197.7bn**) and
61.7bn for Vietnam (**169.0bn**). Every 2023 figure, every rank, and every
number quoted in findings 1–12 was unaffected. Found on 15/09/2026 while
writing `sql/07`, fixed in `02`, `03` and `08`, and recorded in `sql/02`
assumption 7. Left visible here rather than silently corrected.

## What this analysis does not answer

Stated as scope, not discovered as gaps:

- **Real versus nominal, beyond the five sectors.** No deflator is applied
  anywhere. Finding 17 separates volume from price where the data allows —
  HS6, India, five sectors — but Comtrade holds no quantities at chapter
  level, so the four-country benchmark (findings 1–3) stays nominal.
- **Sector detail for the comparators.** China, Bangladesh and Vietnam are
  HS2 to World only, for both exports and imports. Nothing here says what
  Vietnam's surplus is made of.
- **Partner × sector for imports.** Track D is exports. "Where does India's
  machinery come from" would need a fifth pull.
- **Gems & jewellery volume.** Excluded on coverage; see finding 17.
- **Why.** This is a descriptive analysis. It establishes what happened and
  quantifies it; it does not model causes.

---

*All figures: UN Comtrade. Exports pulled 25/08/2026 (Tracks A–C); imports and
partner × sector 15/09/2026 (Tracks D–E). Exports FOB, imports CIF, nominal USD.
Reproduce with `sql/00` → `sql/07`, then `sql/08_export_results.sql`.*
