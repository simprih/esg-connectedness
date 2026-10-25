"""Figures of the TVP-VAR connectedness measures, and the mean ESG minus parent gap in crisis and calm weeks."""

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.transforms as mtransforms
import pandas as pd

import config

C = config.COLORS
LEVEL = "price"


def read_inputs():
    """Weekly TVP-VAR measures from R/09 and the crisis label of each week (main window)."""
    measures = pd.read_csv(config.TABLES_DIR / config.TVP_MEASURES_FILE.format(level=LEVEL, lag=config.TVP_MAIN_LAG),
                           index_col="date", parse_dates=True)
    weeks = pd.read_csv(config.PROCESSED_DIR / config.CRISIS_WEEKS_FILE, parse_dates=["date"])
    weeks = weeks[weeks.window == config.CRISIS_WINDOW_MAIN].set_index("date")["period"]
    period = weeks.reindex(measures.index)
    if period.isna().any():
        raise ValueError("some weeks of the TVP-VAR measures have no crisis label")
    return measures, period


def crisis_spans(period):
    """Contiguous runs of crisis weeks, from the Friday of the first week to the Thursday of the last."""
    run = (period != period.shift()).cumsum()
    crisis = period != "calm"
    return [(weeks.iloc[0], weeks.index[0] - pd.Timedelta(days=6), weeks.index[-1])
            for _, weeks in period[crisis].groupby(run[crisis])]


def style(ax, spans, label_crises=False):
    """Recessive chrome, crisis weeks shaded behind the data."""
    for name, start, end in spans:
        ax.axvspan(start, end, color=C["crisis"], lw=0, zorder=0)
        if label_crises:
            ax.text(start + (end - start) / 2, 1.01, config.CRISIS_LABELS.get(name, name), ha="center", va="bottom",
                    fontsize=7, color=C["muted"], transform=mtransforms.blended_transform_factory(ax.transData, ax.transAxes))
    ax.grid(axis="y", color=C["grid"], lw=0.6)
    ax.set_axisbelow(True)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(C["baseline"])
    ax.tick_params(colors=C["ink_secondary"], labelsize=8, length=3)
    ax.margins(x=0)


def title(ax, text):
    ax.set_title(text, loc="left", fontsize=9, color=C["ink"])


def save(fig, name):
    config.FIGURES_DIR.mkdir(parents=True, exist_ok=True)
    stem = f"{name}_{LEVEL}_lag{config.TVP_MAIN_LAG}"
    for ext in ("png", "pdf"):
        fig.savefig(config.FIGURES_DIR / f"{stem}.{ext}", dpi=200, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    return stem


def plot_tci(measures, spans):
    fig, ax = plt.subplots(figsize=(9, 3.2))
    style(ax, spans, label_crises=True)
    ax.plot(measures.index, measures.tci, color=C["parent"], lw=1.4)
    ax.set_ylabel("TCI (%)", fontsize=8, color=C["ink_secondary"])
    title(ax, f"Total connectedness index, TVP-VAR({config.TVP_MAIN_LAG}), H = 10\n")
    return save(fig, config.TVP_FIGURES[0])


def plot_from_ex_twin(measures, spans):
    fig, axes = plt.subplots(len(config.TWINS), 1, figsize=(9, 11), sharex=True, sharey=True)
    for i, (ax, (esg, parent)) in enumerate(zip(axes, config.TWINS.items())):
        style(ax, spans, label_crises=i == 0)
        ax.plot(measures.index, measures[f"from_ex_twin_{parent}"], color=C["parent"], lw=1.2, label="Parent index")
        ax.plot(measures.index, measures[f"from_ex_twin_{esg}"], color=C["esg"], lw=1.2, label="ESG (Selection) index")
        title(ax, f"{config.PAIR_LABELS[parent]}\n" if i == 0 else config.PAIR_LABELS[parent])
        ax.set_ylabel("FROM ex-twin (%)", fontsize=8, color=C["ink_secondary"])
    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="upper right", ncol=2, frameon=False, fontsize=8, bbox_to_anchor=(0.98, 1.0))
    fig.suptitle("Shocks received from the rest of the system (FROM minus the twin's share), TVP-VAR(1)",
                 x=0.02, ha="left", fontsize=10, color=C["ink"])
    fig.tight_layout(rect=(0, 0, 1, 0.98))
    return save(fig, config.TVP_FIGURES[1])


def plot_delta(measures, spans):
    panels = [(f"delta_{p}", config.PAIR_LABELS[p]) for p in config.TWINS.values()] + [("delta_mean", "Average of the five pairs")]
    fig, axes = plt.subplots(3, 2, figsize=(10, 8), sharex=True, sharey=True)
    for i, (ax, (col, label)) in enumerate(zip(axes.flat, panels)):
        style(ax, spans, label_crises=i < 2)
        ax.axhline(0, color=C["ink_secondary"], lw=0.8)
        ax.plot(measures.index, measures[col], color=C["parent"], lw=1.1)
        title(ax, f"{label}\n" if i < 2 else label)
        if i % 2 == 0:
            ax.set_ylabel("ESG minus parent (pp)", fontsize=8, color=C["ink_secondary"])
    fig.suptitle("Gap in FROM ex-twin, ESG minus parent (below 0: the ESG index receives fewer shocks), TVP-VAR(1)",
                 x=0.02, ha="left", fontsize=10, color=C["ink"])
    fig.tight_layout(rect=(0, 0, 1, 0.97))
    return save(fig, config.TVP_FIGURES[2])


def crisis_calm_table(measures, period):
    """Mean gap in crisis and calm weeks and their difference D, without any test."""
    crisis = ~period.isin(["calm", *config.DESCRIPTION_ONLY_CRISES])
    calm = period == "calm"
    rows = []
    for col in [f"delta_{p}" for p in config.TWINS.values()] + ["delta_mean"]:
        name = col.removeprefix("delta_")
        rows.append({"pair": config.PAIR_LABELS.get(name, "Average of the five pairs"),
                     "crisis": measures.loc[crisis, col].mean(), "calm": measures.loc[calm, col].mean(),
                     "crisis_weeks": int(crisis.sum()), "calm_weeks": int(calm.sum())})
    table = pd.DataFrame(rows)
    table.insert(3, "D", table.crisis - table.calm)
    table.to_csv(config.TABLES_DIR / config.TVP_DELTA_CRISIS_FILE.format(level=LEVEL, lag=config.TVP_MAIN_LAG),
                 index=False)
    return table


def main():
    measures, period = read_inputs()
    spans = crisis_spans(period)
    for stem in (plot_tci(measures, spans), plot_from_ex_twin(measures, spans), plot_delta(measures, spans)):
        print(f"figure: output/figures/{stem}.png (+ .pdf)")
    print()
    print(crisis_calm_table(measures, period).round(3).to_string(index=False))


if __name__ == "__main__":
    main()
