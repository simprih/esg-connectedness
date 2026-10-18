"""Build weekly log returns and weekly log realized volatility from the daily prices."""

import numpy as np
import pandas as pd

import config


def daily_log_returns(level):
    """Read the daily prices of one level and return daily log returns."""
    path = config.PROCESSED_DIR / config.DAILY_PRICES_FILE.format(level=level)
    prices = pd.read_csv(path, index_col="date", parse_dates=True)
    return np.log(prices).diff().dropna()


def full_weeks(log_ret):
    """Flag the weeks that contain a full set of daily returns."""
    n_days = log_ret.resample(config.WEEK_RULE).size()
    full = n_days == config.DAYS_PER_WEEK

    # Only the edges of the sample may be partial: a gap inside would mean a data problem
    inner_gaps = full.index[1:-1][~full.iloc[1:-1]]
    if len(inner_gaps) > 0:
        raise ValueError(f"{len(inner_gaps)} incomplete weeks inside the sample, first {inner_gaps[0]:%Y-%m-%d}")
    return full


def weekly_returns(log_ret):
    """Weekly log return: sum of the daily log returns of the week."""
    return log_ret.resample(config.WEEK_RULE).sum()


def weekly_log_rv(log_ret):
    """Weekly log realized volatility: log of the square root of the sum of squared daily returns."""
    return np.log(np.sqrt((log_ret ** 2).resample(config.WEEK_RULE).sum()))


def check_weekly(weekly, name):
    """Stop if a weekly table has missing or infinite values, or unsorted dates."""
    if weekly.isna().any().any():
        raise ValueError(f"{name}: missing values in {weekly.columns[weekly.isna().any()].tolist()}")
    # -inf comes from a week with zero realized volatility
    if np.isinf(weekly).any().any():
        raise ValueError(f"{name}: infinite values in {weekly.columns[np.isinf(weekly).any()].tolist()}")
    if not (weekly.index.is_unique and weekly.index.is_monotonic_increasing):
        raise ValueError(f"{name}: dates are duplicated or not sorted")


def main():
    for level in config.LEVELS:
        log_ret = daily_log_returns(level)

        # A partial week sums fewer squared returns, which biases its volatility downwards
        full = full_weeks(log_ret)
        outputs = {
            config.WEEKLY_RETURNS_FILE: weekly_returns(log_ret).loc[full],
            config.WEEKLY_LOG_RV_FILE: weekly_log_rv(log_ret).loc[full],
        }

        for template, weekly in outputs.items():
            out = config.PROCESSED_DIR / template.format(level=level)
            check_weekly(weekly, out.name)
            weekly.to_csv(out)
            print(f"{out.name}: {len(weekly)} weeks x {weekly.shape[1]} assets, "
                  f"{weekly.index[0]:%Y-%m-%d} to {weekly.index[-1]:%Y-%m-%d}")


if __name__ == "__main__":
    main()
