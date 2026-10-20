"""Count crisis and calm weeks for each crisis window, after the TVP-VAR prior training weeks."""

import pandas as pd

import config


def is_crisis_week(thursday, start, end):
    """A Friday-to-Thursday week is a crisis week if one of its trading days falls in [start, end]."""
    trading_days = pd.bdate_range(thursday - pd.Timedelta(days=6), thursday)
    return ((trading_days >= start) & (trading_days <= end)).any()


def crisis_flags(weeks, crises):
    """One boolean column per crisis, one row per week; also returns the number of overlapping weeks."""
    flags = pd.DataFrame(
        {c.crisis: [is_crisis_week(w, c.start, c.end) for w in weeks] for c in crises.itertuples()},
        index=weeks,
    )
    # A week in two crises goes to the crisis that starts, i.e. the one with the latest start date
    starts = crises.set_index("crisis")["start"]
    overlapping = flags.index[flags.sum(axis=1) > 1]
    for week in overlapping:
        keep = starts[flags.columns[flags.loc[week]]].idxmax()
        flags.loc[week] = flags.columns == keep
    return flags, len(overlapping)


def count_window(flags, n_overlapping, window):
    """Weeks per crisis, then weeks in a tested crisis, reassigned overlaps, and calm weeks."""
    tested = [c for c in flags.columns if c not in config.DESCRIPTION_ONLY_CRISES]
    n_crises = flags.sum(axis=1)
    rows = [{"window": window, "group": c, "weeks": int(flags[c].sum()),
             "first_week": flags.index[flags[c]].min(), "last_week": flags.index[flags[c]].max()}
            for c in flags.columns]
    rows.append({"window": window, "group": "reassigned_overlaps", "weeks": n_overlapping})
    for group, mask in (("tested_crises", flags[tested].any(axis=1)),
                        ("calm", n_crises == 0)):
        rows.append({"window": window, "group": group, "weeks": int(mask.sum()),
                     "first_week": flags.index[mask].min(), "last_week": flags.index[mask].max()})
    return pd.DataFrame(rows)


def main():
    crises = pd.read_csv(config.CRISIS_FILE, parse_dates=["start", "end"])
    weekly = pd.read_csv(config.PROCESSED_DIR / config.WEEKLY_LOG_RV_FILE.format(level="price"),
                         index_col="date", parse_dates=True)
    weeks = weekly.index[config.TVP_PRIOR_WEEKS:]

    counts = pd.concat([count_window(*crisis_flags(weeks, crises[crises.window == w]), w)
                        for w in crises.window.unique()], ignore_index=True)

    config.TABLES_DIR.mkdir(parents=True, exist_ok=True)
    counts.to_csv(config.TABLES_DIR / config.CRISIS_COUNTS_FILE, index=False)
    print(f"{len(weeks)} weeks after the {config.TVP_PRIOR_WEEKS} prior weeks, "
          f"{weeks[0]:%Y-%m-%d} to {weeks[-1]:%Y-%m-%d}\n")
    print(counts.to_string(index=False))


if __name__ == "__main__":
    main()
