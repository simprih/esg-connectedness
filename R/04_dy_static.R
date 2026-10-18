# Block 2: static Diebold-Yilmaz (2012) connectedness of weekly log realized volatility.

source("R/00_setup.R")
suppressPackageStartupMessages({
  library(ConnectednessApproach)
  library(vars)
  library(zoo)
})

read_log_rv <- function(level) {
  df <- read.csv(file.path(processed_dir, sprintf(weekly_log_rv_file, level)), check.names = FALSE)
  zoo(as.matrix(df[, -1]), as.Date(df$date))
}

# Stop on an explosive VAR: its variance decomposition would not converge with the horizon
check_stable <- function(x, p) {
  modulus <- max(roots(VAR(as.matrix(x), p = p, type = "const")))
  if (modulus >= 1) stop("VAR(", p, ") is not stable, largest root modulus ", round(modulus, 4))
  modulus
}

# Normalized generalized FEVD in percent: entry [i, j] is the share of i's forecast error variance due to j
gfevd <- function(x, p, h) {
  dca <- suppressMessages(ConnectednessApproach(x, nlag = p, nfore = h, model = "VAR"))
  theta <- 100 * dca$CT[, , 1]
  if (any(abs(rowSums(theta) - 100) > 1e-8)) stop("GFEVD rows do not sum to 100")
  theta
}

tci <- function(theta) mean(100 - diag(theta))

# Number of equations whose residuals still reject the Ljung-Box test of no autocorrelation
autocorrelated_equations <- function(x, p) {
  u <- resid(VAR(as.matrix(x), p = p, type = "const"))
  p_values <- apply(u, 2, function(e) Box.test(e, lag = resid_lb_lag, type = "Ljung-Box")$p.value)
  sum(p_values < resid_lb_level)
}

# FROM, share received from the twin, and FROM without the twin, for both members of each pair
twin_measures <- function(theta) {
  index <- c(names(twins), unname(twins))
  twin <- c(unname(twins), names(twins))
  from <- 100 - diag(theta)[index]
  twin_share <- theta[cbind(index, twin)]
  data.frame(
    pair = rep(unname(twins), 2), type = rep(c("esg", "parent"), each = length(twins)),
    asset = index, from = from, twin_share = twin_share, from_ex_twin = from - twin_share,
    row.names = NULL
  )
}

# GFEVD with the FROM column and the TO and NET rows, as in Table 2 of Diebold and Yilmaz (2012)
full_table <- function(theta) {
  off <- theta
  diag(off) <- 0
  table <- rbind(theta, to = colSums(off), net = colSums(off) - rowSums(off))
  data.frame(asset = rownames(table), table, from = c(rowSums(off), NA, NA), row.names = NULL, check.names = FALSE)
}

x <- read_log_rv(main_level)
stopifnot(all(c(names(twins), twins) %in% colnames(x)))

criteria <- VARselect(as.matrix(x), lag.max = var_max_lag, type = "const")$criteria
lag_selection <- data.frame(
  lag = seq_len(var_max_lag), aic = criteria["AIC(n)", ], bic = criteria["SC(n)", ],
  autocorrelated_equations = sapply(seq_len(var_max_lag), function(p) autocorrelated_equations(x, p)),
  max_root = sapply(seq_len(var_max_lag), function(p) check_stable(x, p)),
  main = seq_len(var_max_lag) == var_lag, row.names = NULL
)
if (lag_selection$autocorrelated_equations[var_lag] > 0) stop("VAR(", var_lag, ") residuals are still autocorrelated")

theta <- gfevd(x, var_lag, forecast_horizon)

robustness <- do.call(rbind, lapply(robust_lags, function(p) {
  do.call(rbind, lapply(robust_horizons, function(h) {
    th <- gfevd(x, p, h)
    data.frame(lag = p, horizon = h, max_root = check_stable(x, p), tci = tci(th), twin_measures(th))
  }))
}))

dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(lag_selection, file.path(tables_dir, sprintf(var_lag_selection_file, main_level)), row.names = FALSE)
write.csv(full_table(theta), file.path(tables_dir, sprintf(dy_static_table_file, main_level)), row.names = FALSE)
write.csv(twin_measures(theta), file.path(tables_dir, sprintf(dy_static_twins_file, main_level)), row.names = FALSE)
write.csv(robustness, file.path(tables_dir, sprintf(dy_static_robustness_file, main_level)), row.names = FALSE)

cat(sprintf("Lag by BIC: %d, by AIC: %d | autocorrelated equations by lag: %s\n",
            which.min(lag_selection$bic), which.min(lag_selection$aic),
            paste(lag_selection$autocorrelated_equations, collapse = "/")))
cat(sprintf("VAR(%d), horizon %d weeks | TCI: %.2f%%\n", var_lag, forecast_horizon, tci(theta)))
tci_range <- range(robustness$tci)
cat(sprintf("TCI over lags %s and horizons %s: %.2f to %.2f%%\n",
            paste(range(robust_lags), collapse = "-"), paste(robust_horizons, collapse = "/"), tci_range[1], tci_range[2]))
