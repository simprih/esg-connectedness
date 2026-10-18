# Project-wide parameters for the R scripts, sourced from the project root.

# Paths
processed_dir <- file.path("data", "processed")
tables_dir <- file.path("output", "tables")

# Inputs written by python/02_build_weekly_series.py
weekly_returns_file <- "weekly_returns_%s.csv"
weekly_log_rv_file <- "weekly_log_rv_%s.csv"
index_levels <- c("price", "net")  # price = main analysis, net = robustness
main_level <- "price"

twins <- c(usa_esg = "usa", europe_esg = "europe", japan_esg = "japan", em_esg = "em", pxj_esg = "pxj")

# Block 2: BIC picks 1 lag but leaves autocorrelated residuals; 4 is the smallest order without
var_lag <- 4
var_max_lag <- 4
resid_lb_lag <- 20
resid_lb_level <- 0.05
forecast_horizon <- 10
robust_lags <- 1:4
robust_horizons <- c(5, 10, 20)

# Block 2: moving block bootstrap, the first block length is the main one
block_lengths <- c(10, 5, 20)
n_boot <- 1999  # alpha * (B + 1) is an integer at 1%, 5% and 10%
ci_level <- 0.95
bootstrap_seed <- 20261018

# Outputs
var_lag_selection_file <- "var_lag_selection_%s.csv"
dy_static_table_file <- "dy_static_table_%s.csv"
dy_static_twins_file <- "dy_static_twins_%s.csv"
dy_static_robustness_file <- "dy_static_robustness_%s.csv"
bootstrap_twins_file <- "bootstrap_twins_%s.csv"
bootstrap_cross_shares_file <- "bootstrap_cross_shares_%s.csv"
