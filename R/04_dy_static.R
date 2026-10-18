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

main_lag <- unname(VARselect(as.matrix(x), lag.max = var_max_lag, type = "const")$selection["SC(n)"])
theta <- gfevd(x, main_lag, forecast_horizon)

robustness <- do.call(rbind, lapply(robust_lags, function(p) {
  modulus <- check_stable(x, p)
  do.call(rbind, lapply(robust_horizons, function(h) {
    th <- gfevd(x, p, h)
    data.frame(lag = p, horizon = h, max_root = modulus, tci = tci(th), twin_measures(th))
  }))
}))

dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(full_table(theta), file.path(tables_dir, sprintf(dy_static_table_file, main_level)), row.names = FALSE)
write.csv(twin_measures(theta), file.path(tables_dir, sprintf(dy_static_twins_file, main_level)), row.names = FALSE)
write.csv(robustness, file.path(tables_dir, sprintf(dy_static_robustness_file, main_level)), row.names = FALSE)

cat(sprintf("VAR lag chosen by BIC: %d | horizon: %d weeks | TCI: %.2f%%\n", main_lag, forecast_horizon, tci(theta)))
tci_range <- range(robustness$tci)
cat(sprintf("TCI over lags %s and horizons %s: %.2f to %.2f%%\n",
            paste(range(robust_lags), collapse = "-"), paste(robust_horizons, collapse = "/"), tci_range[1], tci_range[2]))
