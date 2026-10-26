"""Crisis-calm tests on the TVP-VAR gap: circular calendar shift (main test) and Newey-West regression."""

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import statsmodels.api as sm
from statsmodels.stats.multitest import multipletests

import config

C = config.COLORS
LEVEL = "price"
TESTED = [c for c in config.CRISIS_LABELS if c not in config.DESCRIPTION_ONLY_CRISES]
SERIES = {"mean": "Average of the five pairs", **{p: config.PAIR_LABELS[p] for p in config.TWINS.values()}}


def read_inputs():
    """Weekly gaps and the crisis label of each week in both windows; description-only crisis weeks are dropped."""
    measures = pd.read_csv(config.TABLES_DIR / config.TVP_MEASURES_FILE.format(level=LEVEL, lag=config.TVP_MAIN_LAG),
                           index_col="date", parse_dates=True)
    weeks = pd.read_csv(config.PROCESSED_DIR / config.CRISIS_WEEKS_FILE, parse_dates=["date"])
    periods = weeks.pivot(index="date", columns="window", values="period").reindex(measures.index)
    if periods.isna().any().any():
        raise ValueError("some weeks of the TVP-VAR measures have no crisis label")
    keep = ~periods[config.CRISIS_WINDOW_MAIN].isin(config.DESCRIPTION_ONLY_CRISES)
    return measures[keep], periods[keep]


def crisis_indicator(period, dropped=None):
    """1 in tested crisis weeks, 0 in calm weeks, NaN in the weeks of a crisis removed from the test."""
    crisis = period.isin(TESTED).astype(float)
    if dropped is not None:
        crisis[period == dropped] = np.nan
    return crisis.to_numpy()


def gap(delta, crisis):
    """Mean of delta in crisis weeks minus its mean in calm weeks."""
    return delta[crisis == 1].mean() - delta[crisis == 0].mean()


def shift_test(delta, crisis):
    """D(k) for every circular shift k of the crisis calendar, and the share of shifts with |D(k)| >= |D(0)|."""
    n = len(delta)
    d = np.array([gap(delta, np.roll(crisis, k)) for k in range(n)])
    exceed = np.abs(d) >= np.abs(d[0]) - 1e-12
    k = np.arange(n)
    # Shifts shorter than SHIFT_MIN_WEEKS (either way) nearly overlap the true crises
    far = (k == 0) | ((k >= config.SHIFT_MIN_WEEKS) & (k <= n - config.SHIFT_MIN_WEEKS))
    return d, exceed.mean(), exceed[far].mean()


def nw_auto_lag(crisis, resid):
    """Newey-West (1994) plug-in lag for the Bartlett kernel, without prewhitening, on the crisis coefficient score."""
    n = len(resid)
    h = crisis * resid
    m = int(np.floor(4 * (n / 100) ** (2 / 9)))
    sigma = np.array([h[j:] @ h[:n - j] / n for j in range(m + 1)])
    s0 = sigma[0] + 2 * sigma[1:].sum()
    s1 = 2 * (np.arange(1, m + 1) * sigma[1:]).sum()
    return int(np.floor(1.1447 * ((s1 / s0) ** 2 * n) ** (1 / 3)))


def newey_west(delta, crisis, lags):
    """OLS of delta on a constant and the crisis dummy, with HAC (Bartlett) standard errors."""
    ok = ~np.isnan(crisis)
    X = sm.add_constant(crisis[ok])
    if lags == "auto":
        lags = nw_auto_lag(crisis[ok], sm.OLS(delta[ok], X).fit().resid)
    fit = sm.OLS(delta[ok], X).fit(cov_type="HAC", cov_kwds={"maxlags": lags})
    return {"b": fit.params[1], "se": fit.bse[1], "t": fit.tvalues[1], "p": fit.pvalues[1], "lags": lags}


def run_tests(delta, crisis):
    """Calendar-shift test and both Newey-West variants for one gap series and one crisis calendar."""
    d, p_a, p_a_far = shift_test(delta, crisis)
    nw_auto = newey_west(delta, crisis, "auto")
    nw_fixed = newey_west(delta, crisis, config.NW_FIXED_LAGS)
    row = {"D": d[0], "crisis_weeks": int((crisis == 1).sum()), "calm_weeks": int((crisis == 0).sum()),
           "p_A": p_a, "p_A_no_short_shifts": p_a_far,
           "b": nw_auto["b"], "se_nw_auto": nw_auto["se"], "t_nw_auto": nw_auto["t"], "p_nw_auto": nw_auto["p"],
           "nw_auto_lags": nw_auto["lags"],
           "se_nw_52": nw_fixed["se"], "t_nw_52": nw_fixed["t"], "p_nw_52": nw_fixed["p"]}
    return row, d


def plot_shifts(d):
    fig, ax = plt.subplots(figsize=(7, 3.4))
    ax.hist(d, bins=40, color=C["parent"], edgecolor="white", linewidth=0.6)
    ax.axvline(d[0], color=C["ink"], lw=1.4)
    ax.text(d[0], 1.01, f"observed D = {d[0]:+.3f}", ha="center", va="bottom", fontsize=8, color=C["ink"],
            transform=ax.get_xaxis_transform())
    ax.grid(axis="y", color=C["grid"], lw=0.6)
    ax.set_axisbelow(True)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(C["baseline"])
    ax.tick_params(colors=C["ink_secondary"], labelsize=8, length=3)
    ax.set_xlabel("D(k): mean gap in shifted crisis weeks minus calm weeks (pp)", fontsize=8, color=C["ink_secondary"])
    ax.set_ylabel("Number of shifts k", fontsize=8, color=C["ink_secondary"])
    ax.set_title(f"Circular calendar shifts, average of the five pairs ({len(d)} shifts)\n", loc="left", fontsize=9,
                 color=C["ink"])
    config.FIGURES_DIR.mkdir(parents=True, exist_ok=True)
    stem = f"{config.CRISIS_TEST_FIGURE}_{LEVEL}_lag{config.TVP_MAIN_LAG}"
    for ext in ("png", "pdf"):
        fig.savefig(config.FIGURES_DIR / f"{stem}.{ext}", dpi=200, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    return stem


def main():
    measures, periods = read_inputs()
    main_period = periods[config.CRISIS_WINDOW_MAIN]
    crisis = crisis_indicator(main_period)

    pairs = []
    for name, label in SERIES.items():
        row, d = run_tests(measures[f"delta_{name}"].to_numpy(), crisis)
        pairs.append({"series": label, **row})
        if name == "mean":
            stem = plot_shifts(d)
    pairs = pd.DataFrame(pairs)
    is_pair = pairs.series != SERIES["mean"]
    pairs.loc[is_pair, "p_A_holm"] = multipletests(pairs.loc[is_pair, "p_A"], method="holm")[1]

    delta_mean = measures["delta_mean"].to_numpy()
    cases = [("Main: average of 5 pairs, short windows", crisis)]
    cases += [(f"Without {config.CRISIS_LABELS[c]}", crisis_indicator(main_period, dropped=c)) for c in TESTED]
    cases += [("Long windows", crisis_indicator(periods[config.CRISIS_WINDOW_ROBUST]))]
    summary = pd.DataFrame([{"test": name, **run_tests(delta_mean, cal)[0]} for name, cal in cases])

    config.TABLES_DIR.mkdir(parents=True, exist_ok=True)
    summary.to_csv(config.TABLES_DIR / config.CRISIS_TEST_SUMMARY_FILE.format(level=LEVEL, lag=config.TVP_MAIN_LAG),
                   index=False)
    pairs.to_csv(config.TABLES_DIR / config.CRISIS_TEST_PAIRS_FILE.format(level=LEVEL, lag=config.TVP_MAIN_LAG),
                 index=False)

    print(f"T = {len(delta_mean)} weeks, {int(crisis.sum())} crisis, {int((crisis == 0).sum())} calm; "
          f"figure: output/figures/{stem}.png (+ .pdf)\n")
    cols = ["test", "D", "p_A", "p_A_no_short_shifts", "p_nw_auto", "nw_auto_lags", "p_nw_52"]
    print(summary[cols].round(4).to_string(index=False))
    print()
    cols = ["series", "D", "p_A", "p_A_holm", "p_A_no_short_shifts", "se_nw_auto", "t_nw_auto", "p_nw_auto",
            "nw_auto_lags", "se_nw_52", "t_nw_52", "p_nw_52"]
    print(pairs[cols].round(4).to_string(index=False))


if __name__ == "__main__":
    main()
