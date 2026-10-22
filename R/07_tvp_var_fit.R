# Block 3: TVP-VAR estimates on weekly log realized volatility, with one-step forecast error diagnostics.

source("R/00_setup.R")
source("R/tvp_var.R")

df <- read.csv(file.path(processed_dir, sprintf(weekly_log_rv_file, main_level)), check.names = FALSE)
x <- zoo(as.matrix(df[, -1]), as.Date(df$date))
stopifnot(!anyNA(x), all(c(names(twins), twins) %in% colnames(x)))
kept <- (tvp_prior_weeks + 1):nrow(x)

# Q_t already contains e_t, so errors are standardized by the covariance known at t - 1
standardized_errors <- function(fit, weeks) {
  sd_prev <- t(sapply(weeks, function(t) sqrt(diag(fit$Q_t[, , t - 1]))))
  fit$errors[weeks, ] / sd_prev
}

summary_rows <- list()
equation_rows <- list()
unstable_rows <- list()
for (p in tvp_lags) {
  t0 <- Sys.time()
  fit <- tvp_var(x, p, tvp_kappa1, tvp_kappa2, tvp_prior_weeks, mode = "tv_constant")
  seconds <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  saveRDS(fit, file.path(processed_dir, sprintf(tvp_fit_file, main_level, p)))

  z <- standardized_errors(fit, kept)
  lb <- sapply(tvp_lb_lags, function(h) apply(z, 2, function(e) Box.test(e, lag = h, type = "Ljung-Box")$p.value))
  colnames(lb) <- paste0("lb", tvp_lb_lags, "_p")
  e <- fit$errors[kept, ]
  equation_rows[[length(equation_rows) + 1]] <- data.frame(
    nlag = p, asset = colnames(x), mean_error = colMeans(e), sd_error = apply(e, 2, sd), lb, row.names = NULL
  )

  unstable_dates <- index(x)[kept][fit$unstable[kept]]
  if (length(unstable_dates) > 0) unstable_rows[[length(unstable_rows) + 1]] <- data.frame(nlag = p, week = unstable_dates)
  summary_rows[[length(summary_rows) + 1]] <- data.frame(
    nlag = p, unstable_weeks = length(unstable_dates),
    rejected_q4 = sum(lb[, 1] < resid_lb_level), rejected_q10 = sum(lb[, 2] < resid_lb_level), seconds = round(seconds, 1)
  )
}

summary_table <- do.call(rbind, summary_rows)
equation_table <- do.call(rbind, equation_rows)
unstable_table <- if (length(unstable_rows) > 0) do.call(rbind, unstable_rows) else data.frame(nlag = integer(), week = as.Date(character()))

dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(summary_table, file.path(tables_dir, sprintf(tvp_diag_summary_file, main_level)), row.names = FALSE)
write.csv(equation_table, file.path(tables_dir, sprintf(tvp_diag_equations_file, main_level)), row.names = FALSE)
write.csv(unstable_table, file.path(tables_dir, sprintf(tvp_diag_unstable_file, main_level)), row.names = FALSE)

cat(sprintf("%d weeks after the %d prior weeks: %s to %s\n\n", length(kept), tvp_prior_weeks,
            index(x)[kept[1]], index(x)[kept[length(kept)]]))
print(summary_table, row.names = FALSE)
