"""
make_chart.py — the one chart in the README.

Reads data/processed/track_a_indexed_series.csv (produced by
sql/05_export_results.sql) and writes insights/indexed_export_trend.png.

Why indexed and not absolute: China exported ~USD 3.4tn in 2023, Bangladesh
~USD 40bn — an 85x spread. On a shared absolute axis this is one visible line
and three flat against zero. Rebasing each country to 100 at its own first
year makes the four growth paths directly comparable, which is the whole point
of a benchmark.

Bangladesh is drawn dashed because it has 2015-2018 only (Track A assumption
2); a solid line would imply a decade series it does not have.

Run from the repository root, after sql/05_export_results.sql:
    pip3 install pandas matplotlib
    python3 scripts/make_chart.py
"""

import pathlib

import matplotlib
matplotlib.use("Agg")  # no display needed; write straight to file
import matplotlib.pyplot as plt
import pandas as pd

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "processed" / "track_a_indexed_series.csv"
OUT = ROOT / "insights" / "indexed_export_trend.png"

# Deliberate colour choices: India emphasised, comparators receding.
STYLE = {
    "India":      {"color": "#C1440E", "lw": 2.6, "ls": "-",  "z": 5},
    "Viet Nam":   {"color": "#2E6E8E", "lw": 1.8, "ls": "-",  "z": 4},
    "China":      {"color": "#6B8E23", "lw": 1.8, "ls": "-",  "z": 3},
    "Bangladesh": {"color": "#8C6D9E", "lw": 1.8, "ls": "--", "z": 2},
}


def main() -> None:
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


if __name__ == "__main__":
    main()
