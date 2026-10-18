"""Project-wide parameters: paths, raw file formats and asset names."""

from pathlib import Path

# Paths
ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "data" / "raw"  # read-only
PROCESSED_DIR = ROOT / "data" / "processed"
BLOOMBERG_FILE = RAW_DIR / "bloomberg_daily.xlsx"
DAILY_PRICES_FILE = "daily_prices_{level}.csv"  # written by 01, read by 02

# MSCI exports: 6 metadata rows above the header, dates stored as text ("Sep 1, 2010")
MSCI_HEADER_ROW = 6
MSCI_DATE_FORMAT = "%b %d, %Y"
MSCI_LOTS = ("esg", "parents")
MSCI_N_CHUNKS = 4  # the MSCI site only allows short daily downloads

# Bloomberg BDH export: Excel serial dates, one block of 3 columns per asset (date, price, empty)
EXCEL_ORIGIN = "1899-12-30"
BLOOMBERG_BLOCK_WIDTH = 3

LEVELS = ("price", "net")  # price = main analysis, net = robustness

# Rename by name, never by position: column order differs between MSCI lots
MSCI_COLUMNS = {
    "USA Standard (Large+Mid Cap)": "usa",
    "EUROPE Standard (Large+Mid Cap)": "europe",
    "JAPAN Standard (Large+Mid Cap)": "japan",
    "EM (EMERGING MARKETS) Standard (Large+Mid Cap)": "em",
    "PACIFIC ex JAPAN Standard (Large+Mid Cap)": "pxj",
    # MSCI Selection = former MSCI ESG Leaders
    "MSCI USA Selection Index Standard (Large+Mid Cap)": "usa_esg",
    "MSCI Europe Selection Index Standard (Large+Mid Cap)": "europe_esg",
    "MSCI Japan Selection Index Standard (Large+Mid Cap)": "japan_esg",
    "MSCI EM (Emerging Markets) Selection Index Standard (Large+Mid Cap)": "em_esg",
    "MSCI Pacific ex Japan Selection Index Standard (Large+Mid Cap)": "pxj_esg",
}

BLOOMBERG_RENAME = {"Brent": "brent"}

ASSET_ORDER = [
    "usa", "usa_esg", "europe", "europe_esg", "japan", "japan_esg",
    "em", "em_esg", "pxj", "pxj_esg",
    "brent", "gold", "copper", "natural_gas",
    "us_treasuries", "euro_govt_bonds", "dxy",
]