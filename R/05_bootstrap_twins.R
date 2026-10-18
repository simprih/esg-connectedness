# Block 2: residual-based moving block bootstrap of the twin-adjusted FROM gap (ESG minus parent).

source("R/00_setup.R")
suppressPackageStartupMessages({
  library(ConnectednessApproach)
  library(zoo)
})

# OLS estimate of a VAR(p) with a constant; phi = [Phi_1 ... Phi_p] (K x Kp)
fit_var <- function(y, p) {
  n <- nrow(y)
  lags <- do.call(cbind, lapply(seq_len(p), function(i) y[(p + 1 - i):(n - i), , drop = FALSE]))
  X <- cbind(1, lags)
  Y <- y[(p + 1):n, , drop = FALSE]
  coef <- qr.coef(qr(X), Y)
  resid <- Y - X %*% coef
  list(const = coef[1, ], phi = t(coef[-1, , drop = FALSE]), resid = resid, sigma = crossprod(resid) / nrow(resid))
}

# Normalized generalized FEVD in percent (Pesaran and Shin, 1998), MA terms 0 to h - 1
gfevd <- function(phi, sigma, h) {
  K <- nrow(sigma)
  p <- ncol(phi) / K
  A <- vector("list", h)
  A[[1]] <- diag(K)
  for (s in seq_len(h - 1)) {
    A[[s + 1]] <- matrix(0, K, K)
    for (i in seq_len(min(s, p))) A[[s + 1]] <- A[[s + 1]] + phi[, (i - 1) * K + 1:K] %*% A[[s + 1 - i]]
  }
  num <- Reduce(`+`, lapply(A, function(a) (a %*% sigma)^2))
  den <- Reduce(`+`, lapply(A, function(a) rowSums((a %*% sigma) * a)))
  theta <- sweep(num, 2, diag(sigma), "/") / den
  theta <- 100 * theta / rowSums(theta)
  dimnames(theta) <- dimnames(sigma)
  theta
}

# Twin measures per pair and averaged over pairs, flattened as "measure.pair"
twin_stats <- function(theta) {
  esg <- names(twins)
  parent <- unname(twins)
  from_ex_twin <- function(i, twin) 100 - diag(theta)[i] - theta[cbind(i, twin)]
  m <- list(
    from_esg = from_ex_twin(esg, parent),
    from_parent = from_ex_twin(parent, esg),
    esg_from_parent = theta[cbind(esg, parent)],
    parent_from_esg = theta[cbind(parent, esg)]
  )
  m$gap <- m$from_esg - m$from_parent
  m$lead <- m$esg_from_parent - m$parent_from_esg
  unlist(lapply(m, function(v) c(setNames(v, parent), mean = mean(v))))
}

# Blocks of l consecutive residual vectors drawn with replacement; each position within a block is
# centered on its mean over all possible blocks, so that the bootstrap innovations have mean zero
mbb_residuals <- function(u, l) {
  n <- nrow(u)
  starts <- sample.int(n - l + 1, ceiling(n / l), replace = TRUE)
  idx <- as.vector(outer(0:(l - 1), starts, "+"))[seq_len(n)]
  centers <- t(sapply(seq_len(l), function(s) colMeans(u[s:(n - l + s), , drop = FALSE])))
  u[idx, , drop = FALSE] - centers[rep_len(seq_len(l), n), , drop = FALSE]
}

# Recursive design: rebuild the series from the observed initial values and the estimated VAR
simulate_var <- function(fit, y0, u) {
  p <- nrow(y0)
  y <- rbind(y0, matrix(0, nrow(u), ncol(u)))
  for (t in p + seq_len(nrow(u))) {
    lagged <- as.vector(t(y[(t - 1):(t - p), , drop = FALSE]))
    y[t, ] <- fit$const + fit$phi %*% lagged + u[t - p, ]
  }
  y
}

# Percentile interval, and two-sided p-value of H0: statistic = 0 (smallest level whose interval excludes 0)
summarize_draws <- function(estimate, draws) {
  alpha <- 1 - ci_level
  below <- colSums(draws <= 0)
  above <- colSums(draws >= 0)
  out <- data.frame(
    stat = names(estimate), estimate = estimate, boot_mean = colMeans(draws), boot_sd = apply(draws, 2, sd),
    ci_low = apply(draws, 2, quantile, alpha / 2), ci_high = apply(draws, 2, quantile, 1 - alpha / 2),
    p_value = pmin(1, 2 * (1 + pmin(below, above)) / (nrow(draws) + 1)), row.names = NULL
  )
  out$bias <- out$boot_mean - out$estimate
  parts <- do.call(rbind, strsplit(out$stat, ".", fixed = TRUE))
  cbind(measure = parts[, 1], pair = parts[, 2], out[, -1])
}

# Holm adjustment across the five pairs; the average row is a single test and keeps its own p-value
holm <- function(p, pair) ifelse(pair == "mean", NA, p.adjust(ifelse(pair == "mean", NA, p), method = "holm"))

df <- read.csv(file.path(processed_dir, sprintf(weekly_log_rv_file, main_level)), check.names = FALSE)
x <- as.matrix(df[, -1])
stopifnot(all(c(names(twins), twins) %in% colnames(x)))

fit <- fit_var(x, var_lag)
theta_hat <- gfevd(fit$phi, fit$sigma, forecast_horizon)
reference <- suppressMessages(ConnectednessApproach(zoo(x, as.Date(df$date)), nlag = var_lag,
                                                    nfore = forecast_horizon, model = "VAR"))
if (max(abs(theta_hat - 100 * reference$CT[, , 1])) > 1e-8) stop("fast GFEVD differs from ConnectednessApproach")
estimate <- twin_stats(theta_hat)
y0 <- x[seq_len(var_lag), , drop = FALSE]

twins_out <- list()
cross_out <- list()
for (l in block_lengths) {
  set.seed(bootstrap_seed)
  draws <- t(replicate(n_boot, {
    fit_star <- fit_var(simulate_var(fit, y0, mbb_residuals(fit$resid, l)), var_lag)
    twin_stats(gfevd(fit_star$phi, fit_star$sigma, forecast_horizon))
  }))
  s <- summarize_draws(estimate, draws)
  pick <- function(m) s[s$measure == m, ]

  gap <- pick("gap")
  twins_out[[length(twins_out) + 1]] <- data.frame(
    block_length = l, pair = gap$pair,
    from_ex_twin_esg = pick("from_esg")$estimate, from_ex_twin_parent = pick("from_parent")$estimate,
    gap[, c("estimate", "ci_low", "ci_high", "boot_sd", "bias", "p_value")],
    p_holm = holm(gap$p_value, gap$pair), row.names = NULL
  )

  lead <- pick("lead")
  cross_out[[length(cross_out) + 1]] <- data.frame(
    block_length = l, pair = lead$pair,
    esg_from_parent = pick("esg_from_parent")$estimate,
    esg_from_parent_ci_low = pick("esg_from_parent")$ci_low, esg_from_parent_ci_high = pick("esg_from_parent")$ci_high,
    parent_from_esg = pick("parent_from_esg")$estimate,
    parent_from_esg_ci_low = pick("parent_from_esg")$ci_low, parent_from_esg_ci_high = pick("parent_from_esg")$ci_high,
    lead = lead$estimate, lead_ci_low = lead$ci_low, lead_ci_high = lead$ci_high,
    lead_p_value = lead$p_value, lead_p_holm = holm(lead$p_value, lead$pair), row.names = NULL
  )
}

twins_table <- do.call(rbind, twins_out)
names(twins_table)[names(twins_table) == "estimate"] <- "gap"
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(twins_table, file.path(tables_dir, sprintf(bootstrap_twins_file, main_level)), row.names = FALSE)
write.csv(do.call(rbind, cross_out), file.path(tables_dir, sprintf(bootstrap_cross_shares_file, main_level)),
          row.names = FALSE)

main <- twins_table[twins_table$block_length == block_lengths[1], ]
cat(sprintf("VAR(%d), H = %d, B = %d, blocks of %d weeks: ESG minus parent FROM ex-twin\n",
            var_lag, forecast_horizon, n_boot, block_lengths[1]))
print(format(main[, c("pair", "gap", "ci_low", "ci_high", "p_value", "p_holm")], digits = 3), row.names = FALSE)
