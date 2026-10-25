# Block 3: weekly connectedness from the main TVP-VAR, with the twin-adjusted FROM and the ESG minus parent gap.

source("R/00_setup.R")
suppressPackageStartupMessages(library(ConnectednessApproach))

fit <- readRDS(file.path(processed_dir, sprintf(tvp_fit_file, main_level, tvp_main_lag)))
kept <- (tvp_prior_weeks + 1):dim(fit$Q_t)[3]

# Same generalized, row-normalized decomposition as Block 2, week by week
ct <- suppressMessages(TimeConnectedness(Phi = fit$B_t[, , kept, drop = FALSE], Sigma = fit$Q_t[, , kept, drop = FALSE],
                                         nfore = forecast_horizon))
theta <- 100 * ct$CT
dates <- dimnames(theta)[[3]]

esg <- names(twins)
parent <- unname(twins)
index <- c(esg, parent)
twin <- c(parent, esg)

own <- t(apply(theta, 3, diag))
from <- 100 - own[, index]
twin_share <- sapply(seq_along(index), function(j) theta[index[j], twin[j], ])
colnames(twin_share) <- index
from_ex_twin <- from - twin_share
delta <- from_ex_twin[, esg] - from_ex_twin[, parent]
colnames(delta) <- parent

measures <- data.frame(
  date = dates, tci = rowMeans(100 - own),
  setNames(as.data.frame(from), paste0("from_", index)),
  setNames(as.data.frame(twin_share), paste0("twin_", index)),
  setNames(as.data.frame(from_ex_twin), paste0("from_ex_twin_", index)),
  setNames(as.data.frame(twin_share / from), paste0("twin_ratio_", index)),
  setNames(as.data.frame(delta), paste0("delta_", parent)),
  delta_mean = rowMeans(delta), row.names = NULL, check.names = FALSE
)
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(measures, file.path(tables_dir, sprintf(tvp_measures_file, main_level, tvp_main_lag)), row.names = FALSE)

# Controls
cat(sprintf("%d weeks, %s to %s\n", length(dates), dates[1], dates[length(dates)]))
cat(sprintf("max |row sum - 100| over all weeks: %.1e\n", max(abs(apply(theta, 3, rowSums) - 100))))
cat(sprintf("max |TWIN + FROM ex-twin - FROM|: %.1e\n", max(abs(twin_share + from_ex_twin - from))))
cat(sprintf("max |TCI - package TCI|: %.1e | max |FROM - package FROM|: %.1e\n",
            max(abs(measures$tci - ct$TCI)), max(abs(from - ct$FROM[, index]))))

static <- read.csv(file.path(tables_dir, sprintf(dy_static_robustness_file, main_level)))
static_at <- function(p) static[static$lag == p & static$horizon == forecast_horizon, ]
comparison <- data.frame(
  measure = c("TCI", paste0("FROM ", index)),
  tvp_mean = c(mean(measures$tci), colMeans(from)),
  static_var1 = c(static_at(1)$tci[1], static_at(1)$from[match(index, static_at(1)$asset)]),
  static_var4 = c(static_at(var_lag)$tci[1], static_at(var_lag)$from[match(index, static_at(var_lag)$asset)]),
  row.names = NULL
)
cat("\nTime average of the TVP-VAR(1) measures vs static Block 2 values (H = 10)\n")
print(format(comparison, digits = 4), row.names = FALSE)
