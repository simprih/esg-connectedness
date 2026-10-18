# Project-wide parameters for the R scripts: paths, input files and model settings.
# Every R script sources this file and is run from the project root.

# Paths
processed_dir <- file.path("data", "processed")
tables_dir <- file.path("output", "tables")

# Inputs written by python/02_build_weekly_series.py ("%s" = index level)
weekly_returns_file <- "weekly_returns_%s.csv"
weekly_log_rv_file <- "weekly_log_rv_%s.csv"
index_levels <- c("price", "net")  # price = main analysis, net = robustness
main_level <- "price"

# Each ESG index and its parent: the "twin" removed from FROM in the twin-adjusted measure
twins <- c(usa_esg = "usa", europe_esg = "europe", japan_esg = "japan", em_esg = "em", pxj_esg = "pxj")

# Block 2: static DY-2012 connectedness on weekly log realized volatility
var_max_lag <- 4  # lag order chosen by BIC among 1 to 4, as in Antonakakis et al. (2020)
forecast_horizon <- 10  # 10 steps, as in Diebold and Yilmaz (2012)
robust_lags <- 1:4
robust_horizons <- c(5, 10, 20)  # 20 weeks ~ the 100-day horizon of Karkowska and Urjasz (2025)

# Outputs
dy_static_table_file <- "dy_static_table_%s.csv"  # full GFEVD table, in percent
dy_static_twins_file <- "dy_static_twins_%s.csv"  # FROM, twin share and FROM ex-twin of the 10 equity indices
dy_static_robustness_file <- "dy_static_robustness_%s.csv"  # same measures for every lag and horizon
