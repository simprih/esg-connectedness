# Block 3: TVP-VAR forecast accuracy by lag order, and where the bias of the forecast errors comes from.

source("R/00_setup.R")
source("R/tvp_var.R")

df <- read.csv(file.path(processed_dir, sprintf(weekly_log_rv_file, main_level)), check.names = FALSE)
x <- zoo(as.matrix(df[, -1]), as.Date(df$date))
kept <- (tvp_prior_weeks + 1):nrow(x)
fits <- setNames(lapply(tvp_lags, function(p) readRDS(file.path(processed_dir, sprintf(tvp_fit_file, main_level, p)))),
                 tvp_lags)

# Log density of N(forecast, Q_{t-1}) at y_t, the covariance known before week t
log_score <- function(fit, t) {
  root <- chol(fit$Q_t[, , t - 1])
  z <- backsolve(root, fit$errors[t, ], transpose = TRUE)
  -0.5 * (length(z) * log(2 * pi) + 2 * sum(log(diag(root))) + sum(z^2))
}

standardized_errors <- function(fit, weeks) {
  fit$errors[weeks, ] / t(sapply(weeks, function(t) sqrt(diag(fit$Q_t[, , t - 1]))))
}

lb_rejections <- function(fit, weeks) {
  z <- standardized_errors(fit, weeks)
  sapply(tvp_lb_lags, function(h) sum(apply(z, 2, function(e) Box.test(e, lag = h, type = "Ljung-Box")$p.value) < resid_lb_level))
}

# 1. Forecast accuracy over the weeks after the prior training sample
mse <- sapply(fits, function(f) colMeans(f$errors[kept, ]^2))
lag_choice <- data.frame(
  nlag = tvp_lags, mse = colMeans(mse),
  log_score = sapply(fits, function(f) mean(sapply(kept, function(t) log_score(f, t)))), row.names = NULL
)
lag_choice_equations <- data.frame(asset = rownames(mse), setNames(as.data.frame(mse), paste0("mse_lag", tvp_lags)),
                                   row.names = NULL)

# 2a. Same bias diagnostics with the package's full-sample demeaning, one lag
bias_table <- function(fit, label) {
  e <- fit$errors[kept, ]
  rejected <- lb_rejections(fit, kept)
  data.frame(model = label, asset = colnames(e), mean_over_sd = colMeans(e) / apply(e, 2, sd),
             rejected_q4 = rejected[1], rejected_q10 = rejected[2], row.names = NULL)
}
package_fit <- tvp_var(x, 1, tvp_kappa1, tvp_kappa2, tvp_prior_weeks, mode = "package")
bias_package <- rbind(bias_table(fits[["1"]], "tv_constant_lag1"), bias_table(package_fit, "package_lag1"))

# 2b. Mean error in crisis and calm weeks, and in the weeks after a volatility spike, in units of the overall sd
labels <- read.csv(file.path(processed_dir, crisis_weeks_file))
labels <- labels[labels$window == crisis_window_main, ]
period <- labels$period[match(as.character(index(x)[kept]), labels$date)]
crisis <- !period %in% c("calm", description_only_crises)
calm <- period == "calm"

after_spike <- sapply(colnames(x), function(a) {
  rise <- diff(as.vector(x[, a]))[kept - 1]
  spikes <- kept[rise > spike_sd * sd(rise)]
  kept %in% unlist(lapply(spikes, function(s) s + seq_len(spike_horizon)))
})

bias_split <- do.call(rbind, lapply(names(fits), function(p) {
  e <- fits[[p]]$errors[kept, ]
  scale <- apply(e, 2, sd)
  data.frame(
    nlag = as.integer(p), asset = colnames(e),
    crisis = colMeans(e[crisis, ]) / scale, calm = colMeans(e[calm, ]) / scale,
    after_spike = sapply(colnames(e), function(a) mean(e[after_spike[, a], a])) / scale,
    other = sapply(colnames(e), function(a) mean(e[!after_spike[, a], a])) / scale,
    after_spike_weeks = colSums(after_spike), row.names = NULL
  )
}))

dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(lag_choice, file.path(tables_dir, sprintf(tvp_lag_choice_file, main_level)), row.names = FALSE)
write.csv(lag_choice_equations, file.path(tables_dir, sprintf(tvp_lag_choice_equations_file, main_level)), row.names = FALSE)
write.csv(bias_package, file.path(tables_dir, sprintf(tvp_bias_package_file, main_level)), row.names = FALSE)
write.csv(bias_split, file.path(tables_dir, sprintf(tvp_bias_split_file, main_level)), row.names = FALSE)

cat(sprintf("%d weeks after the prior: %d crisis weeks, %d calm weeks (%s windows)\n\n",
            length(kept), sum(crisis), sum(calm), crisis_window_main))
print(lag_choice, row.names = FALSE, digits = 4)
