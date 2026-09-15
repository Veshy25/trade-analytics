"""
make_chart.py — the three charts in the README and the findings.

Reads from data/processed/ (produced by sql/08_export_results.sql) and writes
to insights/:

  1. track_a_indexed_series.csv          -> indexed_export_trend.png
  2. track_b_petroleum_volume_series.csv -> petroleum_volume_vs_value.png   (Phase 2)
  3. track_d_sector_partner_matrix_2023.csv -> sector_partner_heatmap_2023.png (Phase 2)

Chart 1 — the four-country benchmark.

Why indexed and not absolute: China exported ~USD 3.4tn in 2023, Bangladesh
~USD 40bn — an 85x spread. On a shared absolute axis this is one visible line
and three flat against zero. Rebasing each country to 100 at its own first
year makes the four growth paths directly comparable, which is the whole point
of a benchmark.

Bangladesh is drawn dashed because it has 2015-2018 only (Track A assumption
2); a solid line would imply a decade series it does not have.

Chart 2 — petroleum products: value, tonnes and USD/kg, each indexed to
2014 = 100. Three lines on one axis is the point: it shows the 2015-2020
value collapse was price (tonnes held) and the 2014-2023 growth was volume
(unit value ended below where it started). 03 Q7.

Chart 3 — sector x partner heatmap, 2023: each sector's 20-partner panel
split by partner, share of the sector's panel. Rows are sectors, columns the
partners ordered by total across sectors; cells show the percentage. 06 Q1.
Shares are of the panel, not of India's world exports (06 V4).

Run from the repository root, after sql/08_export_results.sql:
    pip3 install pandas matplotlib
    python3 scripts/make_chart.py
"""

import pathlib

import matplotlib
matplotlib.use("Agg")  # no display needed; write straight to file
import matplotlib.pyplot as plt
import pandas as pd

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROCESSED = ROOT / "data" / "processed"
INSIGHTS = ROOT / "insights"
SRC = PROCESSED / "track_a_indexed_series.csv"
OUT = INSIGHTS / "indexed_export_trend.png"

# Deliberate colour choices: India emphasised, comparators receding.
STYLE = {
    "India":      {"color": "#C1440E", "lw": 2.6, "ls": "-",  "z": 5},
    "Viet Nam":   {"color": "#2E6E8E", "lw": 1.8, "ls": "-",  "z": 4},
    "China":      {"color": "#6B8E23", "lw": 1.8, "ls": "-",  "z": 3},
    "Bangladesh": {"color": "#8C6D9E", "lw": 1.8, "ls": "--", "z": 2},
}


def chart_indexed_trend() -> None:
    df = pd.read_csv(SRC)

    fig, ax = plt.subplots(figsize=(9, 5.2))

    for country, g in df.groupby("reporter_desc"):
        g = g.sort_values("ref_year")
        s = STYLE.get(country, {"color": "#888", "lw": 1.5, "ls": "-", "z": 1})
        ax.plot(
            g["ref_year"], g["index_base_100"],
            color=s["color"], linewidth=s["lw"], linestyle=s["ls"],
            zorder=s["z"], marker="o", markersize=3.5,
            label=f"{country} (base {int(g['base_year'].iloc[0])})",
        )
        # Label each line at its right-hand end rather than relying on the
        # legend alone — easier to read than four entries in a box.
        last = g.iloc[-1]
        ax.annotate(
            f"{last['index_base_100']:.0f}",
            xy=(last["ref_year"], last["index_base_100"]),
            xytext=(6, 0), textcoords="offset points",
            color=s["color"], fontsize=9, fontweight="bold",
            va="center",
        )

    ax.axhline(100, color="#999", linewidth=0.8, linestyle=":", zorder=1)

    ax.set_title(
        "Merchandise exports, each country indexed to 100 at its own base year",
        fontsize=12, pad=12,
    )
    ax.set_xlabel("Year")
    ax.set_ylabel("Index (base year = 100)")
    ax.set_xticks(range(2014, 2024))
    ax.grid(axis="y", color="#E4E4E4", linewidth=0.8)
    ax.set_axisbelow(True)
    for spine in ("top", "right"):
        ax.spines[spine].set_visible(False)

    ax.legend(frameon=False, fontsize=9, loc="upper left")

    fig.text(
        0.01, 0.015,
        "Source: UN Comtrade, pulled 25/08/2026. Exports, FOB, nominal USD. "
        "Bangladesh dashed: 2015-2018 only.",
        fontsize=7.5, color="#666",
    )

    fig.tight_layout(rect=(0, 0.035, 1, 1))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT, dpi=160)
    print(f"wrote {OUT.relative_to(ROOT)}")


def chart_petroleum_volume() -> None:
    src = PROCESSED / "track_b_petroleum_volume_series.csv"
    out = INSIGHTS / "petroleum_volume_vs_value.png"
    df = pd.read_csv(src).sort_values("ref_year")

    series = [
        ("value_index",      "Export value (USD)",  "#C1440E", 2.6, "-"),
        ("volume_index",     "Volume (tonnes)",     "#2E6E8E", 2.0, "-"),
        ("unit_value_index", "Unit value (USD/kg)", "#6B8E23", 1.8, "--"),
    ]
    fig, ax = plt.subplots(figsize=(9, 5.2))
    for col, label, color, lw, ls in series:
        ax.plot(df["ref_year"], df[col], color=color, linewidth=lw, linestyle=ls,
                marker="o", markersize=3.5, label=label, zorder=3)
        last = df.iloc[-1]
        ax.annotate(f"{last[col]:.0f}", xy=(last["ref_year"], last[col]),
                    xytext=(6, 0), textcoords="offset points",
                    color=color, fontsize=9, fontweight="bold", va="center")

    ax.axhline(100, color="#999", linewidth=0.8, linestyle=":", zorder=1)
    ax.set_title("India's petroleum-product exports: value, volume and unit value, 2014 = 100",
                 fontsize=12, pad=12)
    ax.set_xlabel("Year")
    ax.set_ylabel("Index (2014 = 100)")
    ax.set_xticks(range(2014, 2024))
    ax.grid(axis="y", color="#E4E4E4", linewidth=0.8)
    ax.set_axisbelow(True)
    for spine in ("top", "right"):
        ax.spines[spine].set_visible(False)
    ax.legend(frameon=False, fontsize=9, loc="upper left")
    fig.text(0.01, 0.015,
             "Source: UN Comtrade, pulled 25/08/2026. HS 27 at HS6, India to World, FOB, nominal USD. "
             "Unit value over rows carrying net weight (98-100% of value).",
             fontsize=7.5, color="#666")
    fig.tight_layout(rect=(0, 0.035, 1, 1))
    fig.savefig(out, dpi=160)
    print(f"wrote {out.relative_to(ROOT)}")


def chart_sector_partner_heatmap() -> None:
    src = PROCESSED / "track_d_sector_partner_matrix_2023.csv"
    out = INSIGHTS / "sector_partner_heatmap_2023.png"
    df = pd.read_csv(src)

    sector_label = {
        "petroleum_products": "Petroleum products",
        "engineering_machinery": "Engineering / machinery",
        "gems_jewellery": "Gems & jewellery",
        "textiles": "Textiles",
        "pharmaceuticals": "Pharmaceuticals",
    }
    # Partners ordered by total 2023 value across the five sectors, largest first.
    partner_order = (df.groupby("partner_desc")["value_2023_bn"].sum()
                       .sort_values(ascending=False).index.tolist())
    sector_order = (df.groupby("sector")["value_2023_bn"].sum()
                      .sort_values(ascending=False).index.tolist())
    mat = (df.pivot(index="sector", columns="partner_desc", values="pct_of_sector_panel")
             .reindex(index=sector_order, columns=partner_order).fillna(0))

    fig, ax = plt.subplots(figsize=(12, 4.6))
    im = ax.imshow(mat.values, cmap="YlOrRd", aspect="auto", vmin=0, vmax=mat.values.max())
    ax.set_xticks(range(len(partner_order)))
    ax.set_xticklabels(partner_order, rotation=45, ha="right", fontsize=8.5)
    ax.set_yticks(range(len(sector_order)))
    ax.set_yticklabels([sector_label.get(s, s) for s in sector_order], fontsize=9.5)
    for i in range(mat.shape[0]):
        for j in range(mat.shape[1]):
            v = mat.values[i, j]
            if v >= 1.0:
                ax.text(j, i, f"{v:.0f}", ha="center", va="center", fontsize=7.5,
                        color="white" if v > 0.55 * mat.values.max() else "#222")
    for spine in ax.spines.values():
        spine.set_visible(False)
    ax.set_title("Where each sector's exports go, 2023 — share of the sector's 20-partner panel (%)",
                 fontsize=12, pad=12)
    cbar = fig.colorbar(im, ax=ax, fraction=0.025, pad=0.02)
    cbar.ax.tick_params(labelsize=8)
    cbar.set_label("% of sector panel", fontsize=8.5)
    fig.text(0.01, 0.015,
             "Source: UN Comtrade, pulled 15/09/2026. India to 20 partners at HS6, FOB, nominal USD. "
             "Panel covers 57-70% of each sector's world exports (06 V4). Cells under 1% unlabelled.",
             fontsize=7.5, color="#666")
    fig.tight_layout(rect=(0, 0.04, 1, 1))
    fig.savefig(out, dpi=160)
    print(f"wrote {out.relative_to(ROOT)}")


def main() -> None:
    INSIGHTS.mkdir(parents=True, exist_ok=True)
    chart_indexed_trend()
    chart_petroleum_volume()
    chart_sector_partner_heatmap()


if __name__ == "__main__":
    main()
