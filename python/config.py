"""Project-wide parameters: paths, raw file formats and asset names."""

from pathlib import Path

# Paths
ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "data" / "raw"  # read-only
PROCESSED_DIR = ROOT / "data" / "processed"
BLOOMBERG_FILE = RAW_DIR / "bloomberg_daily.xlsx"
DAILY_PRICES_FILE = "daily_prices_{level}.csv"  # written by 01, read by 02
WEEKLY_RETURNS_FILE = "weekly_returns_{level}.csv"
WEEKLY_LOG_RV_FILE = "weekly_log_rv_{level}.csv"
TABLES_DIR = ROOT / "output" / "tables"
TABLE1_STATS_FILE = "table1_stats_{level}.csv"  # every statistic and p-value, unrounded
TABLE1_FILE = "table1_{level}.csv"  # paper layout, with significance stars
CRISIS_FILE = ROOT / "config" / "crisis_periods.csv"
CRISIS_COUNTS_FILE = "crisis_week_counts.csv"

# MSCI exports: 6 metadata rows above the header, dates stored as text ("Sep 1, 2010")
MSCI_HEADER_ROW = 6
MSCI_DATE_FORMAT = "%b %d, %Y"
MSCI_LOTS = ("esg", "parents")
MSCI_N_CHUNKS = 4  # the MSCI site only allows short daily downloads

# Bloomberg BDH export: Excel serial dates, one block of 3 columns per asset (date, price, empty)
EXCEL_ORIGIN = "1899-12-30"
BLOOMBERG_BLOCK_WIDTH = 3

LEVELS = ("price", "net")  # price = main analysis, net = robustness

# Weeks run Friday to Thursday and are labelled by their Thursday close
WEEK_RULE = "W-THU"
DAYS_PER_WEEK = 5

# Table 1: descriptive statistics
RETURNS_SCALE = 100  # returns shown in percent
ADF_MAX_LAG = 20  # Schwert (1989) rule, 12 * (T / 100)^(1/4) with T = 840 weeks
ERS_LAGS = 4  # as in ConnectednessApproach::SummaryStatistics
PORTMANTEAU_LAG = 20  # Q(20) and Q2(20), as in Antonakakis et al. (2020)
SIGNIF_LEVELS = (0.01, 0.05, 0.10)  # ***, **, *
TABLE_DIGITS = 3

# Block 3: the TVP-VAR prior is trained on the first weeks, which are then excluded from every measure
TVP_PRIOR_WEEKS = 104
DESCRIPTION_ONLY_CRISES = ("euro_debt",)  # falls inside the prior training period

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