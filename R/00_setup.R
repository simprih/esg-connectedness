# Project-wide parameters for the R scripts: paths, input files and model settings.
# Every R script sources this file and is run from the project root.

# Paths
processed_dir <- file.path("data", "processed")
tables_dir <- file.path("output", "tables")

# Inputs written by python/02_build_weekly_series.py ("%s" = index level)
weekly_returns_file <- "weekly_returns_%s.csv"
weekly_log_rv_file <- "weekly_log_rv_%s.csv"
index_levels <- c("price", "net")  # price = main analysis, net = robustness
