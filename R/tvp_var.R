# TVP-VAR with forgetting factors, adapted from ConnectednessApproach::TVPVAR (version 1.0.4).

suppressPackageStartupMessages({
  library(ConnectednessApproach)
  library(MASS)
  library(zoo)
})

# OLS prior on the training rows, as ConnectednessApproach::BayesPrior, but the constant is kept
ols_prior <- function(y, nlag) {
  rows <- (nlag + 1):nrow(y)
  ztz <- 0
  zty <- 0
  for (t in rows) {
    z <- regressors(y, t, nlag, constant = TRUE)
    ztz <- ztz + crossprod(z)
    zty <- zty + crossprod(z, y[t, ])
  }
  vbar <- ginv(ztz)
  aols <- vbar %*% zty
  sse <- Reduce(`+`, lapply(rows, function(t) tcrossprod(y[t, ] - regressors(y, t, nlag, TRUE) %*% aols)))
  list(bprior = as.vector(aols), Vprior = vbar, Q = sse / length(rows))
}

# Regressors of week t (r x m): [constant,] I (x) x_{t-1}', ..., I (x) x_{t-nlag}', as in the package
regressors <- function(x, t, nlag, constant) {
  r <- ncol(x)
  z <- do.call(cbind, lapply(seq_len(nlag), function(j) kronecker(diag(r), t(x[t - j, ]))))
  if (constant) cbind(diag(r), z) else z
}

# Lag coefficients (r x r nlag) from the state vector, in the package's ordering
lag_matrix <- function(beta, r, nlag) {
  do.call(cbind, lapply(seq_len(nlag), function(j) matrix(beta[(j - 1) * r^2 + seq_len(r^2)], r, r, byrow = TRUE)))
}

# Stability rule of the package: shrink last week's state by 0.99; the constant does not affect stability,
# and shrinking it would shift the mean level, so only the slopes are shrunk in mode "tv_constant"
shrink_unstable <- function(beta, r, constant) {
  if (constant) c(beta[seq_len(r)], 0.99 * beta[-seq_len(r)]) else 0.99 * beta
}

# mode = "tv_constant": no demeaning, time-varying constant in the state, prior on the first prior_weeks rows
# mode = "package": full-sample demeaning and no constant, exactly as ConnectednessApproach::TVPVAR
# Only the current coefficient covariance is stored, instead of one m x m matrix per week
tvp_var <- function(x, nlag, kappa1, kappa2, prior_weeks, mode = c("tv_constant", "package")) {
  mode <- match.arg(mode)
  constant <- mode == "tv_constant"
  names <- colnames(x)
  dates <- as.character(index(x))
  x <- coredata(x)
  r <- ncol(x)
  n <- nrow(x)

  if (constant) {
    prior <- ols_prior(x[seq_len(prior_weeks), , drop = FALSE], nlag)
  } else {
    prior <- BayesPrior(zoo(x[seq_len(prior_weeks), , drop = FALSE]), nlag = nlag)
    x <- scale(x, TRUE, FALSE)
  }

  B_t <- array(0, c(r, r * nlag, n))
  Q_t <- array(0, c(r, r, n), dimnames = list(names, names, dates))
  const_t <- matrix(0, n, r, dimnames = list(dates, names))
  errors <- matrix(NA_real_, n, r, dimnames = list(dates, names))
  unstable <- rep(FALSE, n)

  for (t in seq_len(n)) {
    # Covariance: one-step forecast error with the coefficients computed at t - 1 (unstable or not, as the package)
    if (t == 1) {
      Q <- prior$Q
    } else if (t <= nlag + 1) {
      # The package uses 0.1 x_t x_t' on demeaned data; on raw levels we keep the prior covariance instead
      if (!constant) Q <- kappa2 * Q + (1 - kappa2) * 0.1 * tcrossprod(x[t, ])
    } else {
      lags <- as.vector(t(x[(t - 1):(t - nlag), , drop = FALSE]))
      e <- x[t, ] - c_last - as.vector(lag_last %*% lags)
      errors[t, ] <- e
      Q <- kappa2 * Q + (1 - kappa2) * tcrossprod(e)
    }
    Q_t[, , t] <- Q

    # Coefficients: prediction, then Kalman update once nlag lags are available
    if (t <= nlag + 1) {
      beta_pred <- prior$bprior
      R <- prior$Vprior
    } else {
      beta_pred <- beta_prev
      R <- S / kappa1
    }
    beta <- beta_pred
    if (t >= nlag + 1) {
      z <- regressors(x, t, nlag, constant)
      Rz <- R %*% t(z)
      gain <- Rz %*% ginv(Q + z %*% Rz)
      beta <- beta_pred + as.vector(gain %*% (x[t, ] - z %*% beta_pred))
      S <- R - gain %*% (z %*% R)
    }

    # An explosive VAR keeps last week's coefficients
    lag_last <- lag_matrix(if (constant) beta[-seq_len(r)] else beta, r, nlag)
    c_last <- if (constant) beta[seq_len(r)] else 0
    companion <- rbind(lag_last, cbind(diag(r * (nlag - 1)), matrix(0, r * (nlag - 1), r)))
    if (t == 1 || max(abs(eigen(companion, only.values = TRUE)$values)) <= 1) {
      B_t[, , t] <- lag_last
      const_t[t, ] <- c_last
      beta_prev <- beta
    } else {
      B_t[, , t] <- B_t[, , t - 1]
      const_t[t, ] <- const_t[t - 1, ]
      beta_prev <- shrink_unstable(beta_prev, r, constant)
      unstable[t] <- TRUE
    }
  }

  list(B_t = B_t, Q_t = Q_t, constant = const_t, errors = errors,
       unstable = setNames(unstable, dates), n_unstable = sum(unstable))
}
