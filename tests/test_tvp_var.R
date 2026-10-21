# Tests of tvp_var() on simulated data with the dimensions of the project (17 series, 840 weeks).

source("R/tvp_var.R")

simulate_levels <- function(k = 17, n = 840, mu = -4, seed = 1) {
  set.seed(seed)
  A <- 0.5 * diag(k) + matrix(rnorm(k * k, 0, 0.02), k)
  c0 <- as.vector((diag(k) - A) %*% rep(mu, k))
  y <- matrix(mu, n, k, dimnames = list(NULL, paste0("v", seq_len(k))))
  for (t in 2:n) y[t, ] <- c0 + A %*% y[t - 1, ] + rnorm(k, 0, 0.5)
  zoo(y, as.Date("2010-09-09") + 7 * (seq_len(n) - 1))
}

max_diff <- function(a, b) max(abs(unname(a) - unname(b)))
x <- simulate_levels()

cat("a. Reproduction of ConnectednessApproach::TVPVAR in mode 'package'\n")
for (p in 1:2) {
  ours <- tvp_var(x, nlag = p, kappa1 = 0.99, kappa2 = 0.96, prior_weeks = 104, mode = "package")
  pkg <- suppressMessages(TVPVAR(x, configuration = list(l = c(0.99, 0.96), nlag = p,
                                                         prior = BayesPrior(x[1:104, ], nlag = p))))
  cat(sprintf("   nlag = %d: max |B_t diff| = %.1e, max |Q_t diff| = %.1e, unstable weeks = %d\n",
              p, max_diff(ours$B_t, pkg$B_t), max_diff(ours$Q_t, pkg$Q_t), ours$n_unstable))
  stopifnot(max_diff(ours$B_t, pkg$B_t) < 1e-10, max_diff(ours$Q_t, pkg$Q_t) < 1e-10)
}
slopes <- ols_prior(coredata(x[1:104, ]), 1)$bprior[-(1:17)]
cat(sprintf("   prior slopes with the constant kept vs BayesPrior: max diff = %.1e\n",
            max_diff(slopes, BayesPrior(x[1:104, ], nlag = 1)$bprior)))

cat("b. No future information in mode 'tv_constant' (data after week 300 multiplied by 10)\n")
x10 <- x
x10[301:nrow(x10), ] <- x10[301:nrow(x10), ] * 10
base <- tvp_var(x, 1, 0.99, 0.96, 104, "tv_constant")
shocked <- tvp_var(x10, 1, 0.99, 0.96, 104, "tv_constant")
up_to <- 1:300
d <- c(B_t = max_diff(base$B_t[, , up_to], shocked$B_t[, , up_to]),
       Q_t = max_diff(base$Q_t[, , up_to], shocked$Q_t[, , up_to]),
       constant = max_diff(base$constant[up_to, ], shocked$constant[up_to, ]),
       errors = max_diff(base$errors[3:300, ], shocked$errors[3:300, ]))
cat(sprintf("   weeks 1-300, max diff: B_t %.1e, Q_t %.1e, constant %.1e, errors %.1e\n", d[1], d[2], d[3], d[4]))
stopifnot(all(d == 0))
cat(sprintf("   week 301 changes as expected: max |B_t diff| = %.2f\n",
            max_diff(base$B_t[, , 301], shocked$B_t[, , 301])))
implied <- sapply(3:nrow(x), function(t) max_diff((base$Q_t[, , t] - 0.96 * base$Q_t[, , t - 1]) / 0.04,
                                                  tcrossprod(base$errors[t, ])))
cat(sprintf("   errors consistent with the Q_t recursion: max diff = %.1e\n", max(implied)))
# Constant and slopes trade off, so the level they imply, (I - B_t)^-1 c_t, is what should match
level <- sapply(105:nrow(x), function(t) solve(diag(ncol(x)) - base$B_t[, , t], base$constant[t, ]))
cat(sprintf("   implied level after week 104: %.3f (true -4)\n", mean(level)))

cat("c. Stability rule: only the slopes are shrunk in mode 'tv_constant'\n")
# Mildly explosive regime in weeks 401-520 to trigger unstable weeks
set.seed(3)
y <- matrix(-4, 840, 17)
for (t in 2:840) {
  a <- if (t > 400 && t <= 520) 1.01 else 0.9
  y[t, ] <- (1 - a) * (-4) + a * y[t - 1, ] + rnorm(17, 0, 0.5)
}
x_unstable <- zoo(y, as.Date("2010-09-09") + 7 * (0:839))
shrinks <- list()
original_shrink <- shrink_unstable
shrink_unstable <- function(beta, r, constant) {
  out <- original_shrink(beta, r, constant)
  shrinks[[length(shrinks) + 1]] <<- list(before = beta, after = out, r = r)
  out
}
fit_u <- tvp_var(x_unstable, 1, 0.99, 0.96, 104, "tv_constant")
shrink_unstable <- original_shrink
const_kept <- sapply(shrinks, function(s) max_diff(s$after[1:s$r], s$before[1:s$r]))
slopes_shrunk <- sapply(shrinks, function(s) max_diff(s$after[-(1:s$r)], 0.99 * s$before[-(1:s$r)]))
cat(sprintf("   unstable weeks: %d | constant change: %.1e | slopes vs 0.99 x slopes: %.1e\n",
            fit_u$n_unstable, max(const_kept), max(slopes_shrunk)))
stopifnot(fit_u$n_unstable >= 1, all(const_kept == 0), all(slopes_shrunk < 1e-15))
ours_u <- tvp_var(x_unstable, 1, 0.99, 0.96, 104, "package")
pkg_u <- suppressMessages(TVPVAR(x_unstable, configuration = list(l = c(0.99, 0.96), nlag = 1,
                                                                  prior = BayesPrior(x_unstable[1:104, ], nlag = 1))))
cat(sprintf("   mode 'package' on the same data: %d unstable weeks, max |B_t diff| = %.1e, max |Q_t diff| = %.1e\n",
            ours_u$n_unstable, max_diff(ours_u$B_t, pkg_u$B_t), max_diff(ours_u$Q_t, pkg_u$Q_t)))
stopifnot(max_diff(ours_u$B_t, pkg_u$B_t) < 1e-10, max_diff(ours_u$Q_t, pkg_u$Q_t) < 1e-10)

cat("d. Time in mode 'tv_constant' (peak memory: run with `/usr/bin/time -l Rscript -e ...`, one process per nlag)\n")
for (p in c(1, 2, 4)) {
  t0 <- Sys.time()
  fit <- tvp_var(x, p, 0.99, 0.96, 104, "tv_constant")
  m <- 17 + p * 17^2
  cat(sprintf("   nlag = %d: %.1f s | state size %d: our filter keeps one %.0f MB covariance, the package two arrays of %.1f GB\n",
              p, as.numeric(difftime(Sys.time(), t0, units = "secs")), m, m^2 * 8 / 1e6, m^2 * 840 * 8 / 1e9))
}
