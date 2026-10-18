"""Build the daily price tables (17 assets, USD) from the raw MSCI and Bloomberg exports."""

import pandas as pd
import config


def read_msci_file(path):
    """Read one MSCI export into a date-indexed frame with short asset codes."""
    df = pd.read_excel(path, header=config.MSCI_HEADER_ROW, thousands=",")

    # The copyright notice at the bottom sits in the date column: it fails to parse and is dropped
    df["Date"] = pd.to_datetime(df["Date"], format=config.MSCI_DATE_FORMAT, errors="coerce")
    df = df.dropna(subset=["Date"]).set_index("Date")

    unknown = set(df.columns) - set(config.MSCI_COLUMNS)
    if unknown:
        raise ValueError(f"{path.name}: unknown columns {sorted(unknown)}")

    # Some exports are not sorted by date
    return df.rename(columns=config.MSCI_COLUMNS).sort_index()


def read_msci_level(level):
    """Stack the date chunks of each lot, then put ESG and parent indices side by side."""
    lots = []
    for lot in config.MSCI_LOTS:
        files = sorted(config.RAW_DIR.glob(f"{lot}_{level}_*.xls"))
        if len(files) != config.MSCI_N_CHUNKS:
            raise ValueError(f"{lot}_{level}: expected {config.MSCI_N_CHUNKS} files, found {len(files)}")

        df = pd.concat([read_msci_file(f) for f in files]).sort_index()
        if df.index.duplicated().any():
            raise ValueError(f"{lot}_{level}: overlapping dates between chunks")

        # MSCI repeats the previous close on holidays, so every weekday must be present
        missing = pd.bdate_range(df.index[0], df.index[-1]).difference(df.index)
        if len(missing) > 0:
            raise ValueError(f"{lot}_{level}: {len(missing)} missing weekdays, first {missing[0]:%Y-%m-%d}")
        lots.append(df)

    return pd.concat(lots, axis=1)


def read_bloomberg():
    """Split the BDH export (one date/price block per asset) into a date-indexed frame."""
    raw = pd.read_excel(config.BLOOMBERG_FILE, header=None)

    series = []
    for j in range(0, raw.shape[1], config.BLOOMBERG_BLOCK_WIDTH):
        name = raw.iat[0, j]
        block = raw.iloc[1:, [j, j + 1]].dropna()
        dates = pd.to_datetime(block[j].astype(float), unit="D", origin=config.EXCEL_ORIGIN)
        prices = pd.Series(block[j + 1].astype(float).to_numpy(), index=dates)
        series.append(prices.rename(config.BLOOMBERG_RENAME.get(name, name)))

    return pd.concat(series, axis=1).sort_index()


def check_prices(prices, level):
    """Stop if the table is not a complete, ordered panel of positive prices."""
    if prices.isna().any().any():
        raise ValueError(f"{level}: missing values in {prices.columns[prices.isna().any()].tolist()}")
    if not (prices.index.is_unique and prices.index.is_monotonic_increasing):
        raise ValueError(f"{level}: dates are duplicated or not sorted")
    # Log returns are computed next, so every price must be strictly positive
    if (prices <= 0).any().any():
        raise ValueError(f"{level}: non-positive prices in {prices.columns[(prices <= 0).any()].tolist()}")


def main():
    config.PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    bloomberg = read_bloomberg()

    for level in config.LEVELS:
        msci = read_msci_level(level)

        # Bloomberg was exported with Fill=P, so it must cover every MSCI trading day
        missing = msci.index.difference(bloomberg.index)
        if len(missing) > 0:
            raise ValueError(f"{level}: {len(missing)} MSCI dates missing in Bloomberg, first {missing[0]:%Y-%m-%d}")

        prices = msci.join(bloomberg, how="inner")[config.ASSET_ORDER].rename_axis("date")
        check_prices(prices, level)

        out = config.PROCESSED_DIR / config.DAILY_PRICES_FILE.format(level=level)
        prices.to_csv(out)
        print(f"{out.name}: {len(prices)} days x {prices.shape[1]} assets, "
              f"{prices.index[0]:%Y-%m-%d} to {prices.index[-1]:%Y-%m-%d}")


if __name__ == "__main__":
    main()
