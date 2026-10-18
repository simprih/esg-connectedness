"""Table 1: descriptive statistics and tests of the weekly returns and weekly log realized volatility."""

import numpy as np
import pandas as pd
from arch.unitroot import DFGLS
from scipy import stats
from statsmodels.tsa.stattools import acf, adfuller

import config

TESTED = ("skewness", "ex_kurtosis", "jb", "adf", "ers", "q", "q2")


def read_weekly(template, level):
    """Read one weekly table written by 02."""
    path = config.PROCESSED_DIR / template.format(level=level)
    return pd.read_csv(path, index_col="date", parse_dates=True)


def weighted_ljung_box(x, lag):
    """Weighted Ljung-Box test of Fisher and Gallagher (2012), as in ConnectednessApproach::WeightedBoxTest."""
    n = len(x)
    k = np.arange(1, lag + 1)
    rho = acf(x, nlags=lag)[1:]
    weights = (lag - k + 1) / lag
    stat = n * (n + 2) * np.sum(weights * rho ** 2 / (n - k))

    # Gamma approximation of the null distribution
    shape = 0.75 * (lag + 1) ** 2 * lag / (2 * lag ** 2 + 3 * lag + 1)
    scale = (2 / 3) * (2 * lag ** 2 + 3 * lag + 1) / (lag * (lag + 1))
    return stat, stats.gamma.sf(stat, a=shape, scale=scale)


def describe_series(x):
    """All statistics of one series, with the p-value of each test."""
    jb = stats.jarque_bera(x)
    adf = adfuller(x, maxlag=config.ADF_MAX_LAG, regression="c", autolag="AIC", result_object=True)
    ers = DFGLS(x, lags=config.ERS_LAGS, trend="c")
    q, q_p = weighted_ljung_box(x, config.PORTMANTEAU_LAG)
    q2, q2_p = weighted_ljung_box(x ** 2, config.PORTMANTEAU_LAG)

    return {
        "mean": x.mean(),
        "sd": x.std(ddof=1),
        "skewness": stats.skew(x), "skewness_p": stats.skewtest(x).pvalue,
        "ex_kurtosis": stats.kurtosis(x), "ex_kurtosis_p": stats.kurtosistest(x).pvalue,
        "jb": jb.statistic, "jb_p": jb.pvalue,
        "adf": adf.statistic, "adf_p": adf.pvalue,
        "ers": ers.stat, "ers_p": ers.pvalue,
        "q": q, "q_p": q_p,
        "q2": q2, "q2_p": q2_p,
    }


def describe_panel(weekly, panel):
    """One row per asset, for one panel (returns or log_rv)."""
    rows = [{"panel": panel, "asset": asset, **describe_series(weekly[asset].to_numpy())}
            for asset in weekly.columns]
    return pd.DataFrame(rows)


def stars(p):
    """Significance stars: one per level in SIGNIF_LEVELS that p does not exceed."""
    return "*" * sum(p <= level for level in config.SIGNIF_LEVELS)


def format_table(table):
    """Paper layout: values rounded, significance as stars, p-values dropped."""
    d = config.TABLE_DIGITS
    out = table[["panel", "asset"]].copy()
    for col in ("mean", "sd"):
        out[col] = table[col].map(lambda v: f"{v:.{d}f}")
    for col in TESTED:
        out[col] = [f"{v:.{d}f}{stars(p)}" for v, p in zip(table[col], table[f"{col}_p"])]

    lag = config.PORTMANTEAU_LAG
    return out.rename(columns={"q": f"q_{lag}", "q2": f"q2_{lag}"})


def main():
    config.TABLES_DIR.mkdir(parents=True, exist_ok=True)

    for level in config.LEVELS:
        # Only the mean and sd change with the scale: every test is scale-invariant
        returns = read_weekly(config.WEEKLY_RETURNS_FILE, level) * config.RETURNS_SCALE
        log_rv = read_weekly(config.WEEKLY_LOG_RV_FILE, level)

        table = pd.concat([describe_panel(returns, "returns"), describe_panel(log_rv, "log_rv")],
                          ignore_index=True)
        if table.drop(columns=["panel", "asset"]).isna().any().any():
            raise ValueError(f"{level}: a statistic could not be computed")

        table1 = format_table(table)
        table.to_csv(config.TABLES_DIR / config.TABLE1_STATS_FILE.format(level=level), index=False)
        out = config.TABLES_DIR / config.TABLE1_FILE.format(level=level)
        table1.to_csv(out, index=False)
        print(f"{out.name}: {len(table1)} series x {table1.shape[1] - 2} statistics")


if __name__ == "__main__":
    main()
