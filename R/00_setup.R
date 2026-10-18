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
# BIC picks 1 lag but leaves autocorrelated residuals in every equation; 4 is the smallest
# order whose residuals pass the Ljung-Box test everywhere (VAR(1) kept as robustness)
var_lag <- 4
var_max_lag <- 4  # orders compared by information criteria and residual tests
resid_lb_lag <- 20
resid_lb_level <- 0.05
forecast_horizon <- 10  # 10 steps, as in Diebold and Yilmaz (2012)
robust_lags <- 1:4
robust_horizons <- c(5, 10, 20)  # 20 weeks ~ the 100-day horizon of Karkowska and Urjasz (2025)

# Block 2: residual-based moving block bootstrap (Brueggemann, Jentsch and Trenkler, 2016)
block_lengths <- c(10, 5, 20)  # first = main (~T^(1/3) weeks), others = sensitivity
n_boot <- 1999  # alpha * (B + 1) is an integer at 1%, 5% and 10% (Davidson and MacKinnon, 2000)
ci_level <- 0.95
bootstrap_seed <- 20261018

# Outputs
var_lag_selection_file <- "var_lag_selection_%s.csv"  # information criteria and residual tests by lag
dy_static_table_file <- "dy_static_table_%s.csv"  # full GFEVD table, in percent
dy_static_twins_file <- "dy_static_twins_%s.csv"  # FROM, twin share and FROM ex-twin of the 10 equity indices
dy_static_robustness_file <- "dy_static_robustness_%s.csv"  # same measures for every lag and horizon
bootstrap_twins_file <- "bootstrap_twins_%s.csv"  # ESG minus parent FROM ex-twin, with CI and p-values
bootstrap_cross_shares_file <- "bootstrap_cross_shares_%s.csv"  # ESG <- parent and parent <- ESG shares
