#' Performs PLRT test given the data for y on the null hypothesis H_0: m = m_0.
#' @export
#' @title mvnmixPLRT
#' @name mvnmixPLRT
#' @param y n by d matrix of data
#' @param m The number of components in the mixture defined by a null hypothesis, m_0
#' @param tauset A set of initial tau value candidates
#' @param an a term used for penalty function
#' @param ninits The number of randomly drawn initial values.
#' @param crit.method Method used to compute the variance-covariance matrix, one of \code{"none"},
#' \code{"asy"}, and \code{"boot"}. The default option is \code{"asy"}. When \code{method = "asy"},
#' the p-values are computed based on an asymptotic method. When \code{method = "OPG"},
#' the p-values are generated by bootstrapping.
#' @param nbtsp The number of bootstrap observations; by default, it is set to be 199
#' @param cl Cluster used for parallelization; if it is \code{NULL}, the system will automatically
#' create a new one for computation accordingly.
#' @param parallel Determines what percentage of available cores are used, 
#' represented by a double in [0,1]. 0.75 is default.
#' @param LRT.penalized Determines whether penalized likelihood is used in calculation of LRT
#' statistic for likelihood in an alternative hypothesis.
#' @return A list of class \code{mvnmix} with items:
#' \item{coefficients}{A vector of parameter estimates. Ordered as \eqn{\alpha_1,\ldots,\alpha_m,\mu_1,\ldots,\mu_m,\sigma_1,\ldots,\sigma_m,\gamma}.}
#' \item{parlist}{The parameter estimates as a list containing alpha, mu, and sigma (and gam if z is included in the model).}
#' \item{vcov}{The estimated variance-covariance matrix.}
#' \item{loglik}{The maximized value of the log-likelihood.}
#' \item{penloglik}{The maximized value of the penalized log-likelihood.}
#' \item{aic}{Akaike Information Criterion of the fitted model.}
#' \item{bic}{Bayesian Information Criterion of the fitted model.}
#' \item{postprobs}{n by m matrix of posterior probabilities for observations}
#' \item{components}{n by 1 vector of integers that indicates the indices of components
#' each observation belongs to based on computed posterior probabilities}
#' \item{call}{The matched call.}
#' \item{m}{The number of components in the mixture.}
#' @examples
#' data(faithful)
#' attach(faithful)
#' mvnmixPLRT(y = eruptions, m = 1, crit.method = "asy")
#' mvnmixPLRT(y = eruptions, m = 2, crit.method = "asy")
mvnmixPLRT <- function (y, m = 2, 
                        ninits = 10,
                        crit.method = c("asy", "boot", "none"), nbtsp = 199,
                        cl = NULL,
                        parallel = 0.75,
                        LRT.penalized = FALSE) {
  # Compute the modified EM test statistic for testing H_0 of m components
  # against H_1 of m+1 components for a univariate finite mixture of normals
  y   <- as.matrix(y)
  n   <- nrow(y)
  d   <- ncol(y)
  crit.method <- match.arg(crit.method)
  
  pmle.result    <- mvnmixPMLE(y=y, m=m, ninits=ninits)
  loglik0        <- pmle.result$loglik
  
  par1  <-   mvnmixPMLE(y=y, m=m+1, ninits=ninits)
  
  plrtstat  <- 2*(par1$loglik - loglik0)
  if (LRT.penalized) # use the penalized log-likelihood.
    plrtstat  <- 2*(par1$penloglik - loglik0)
  
  if (crit.method == "asy"){
    result  <- mvnmixCrit(y=y, parlist=pmle.result$parlist, values=emstat)
  } else if (crit.method == "boot") {
    result  <- PLRTCritBoot(y=y, parlist= pmle.result$parlist, values=plrtstat,
                            ninits=ninits, nbtsp=nbtsp, parallel = 0, cl=cl,
                            LRT.penalized = LRT.penalized)
  } else {
    result <- list()
    result$crit <- result$pvals <- rep(NA,3)
  }
  
  a <- list(plrtstat = plrtstat, pvals = result$pvals, crit = result$crit, crit.method = crit.method,
            parlist = pmle.result$parlist, ll0 = loglik0, ll1 = par1$loglik,
            call = match.call(), m = m, label = "MEMtest")
  
  class(a) <- "normalregMix"
  
  a
  
}  # end mvnmixPLRT

#' @description Computes the bootstrap critical values of the modified EM test.
#' @export
#' @title PLRTCritBoot
#' @name PLRTCritBoot
#' @param y n by d matrix of data
#' @param parlist The parameter estimates as a list containing alpha, mu, and sigma
#' in the form of (alpha = (alpha_1,...,alpha_m), mu = (mu_1',...,mu_m'),
#' sigma = (vech(sigma_1)',...,vech(sigma_m)')
#' @param values 3 by 1 Vector of length 3 (k = 1, 2, 3) at which the p-values are computed
#' @param ninits The number of initial candidates to be generated
#' @param nbtsp The number of bootstrap observations; by default, it is set to be 199.
#' @param parallel Determines what percentage of available cores are used, represented by a double in [0,1]. 0.75 is default.
#' @param cl Cluster used for parallelization (optional)
#' @return A list with the following items:
#' \item{crit}{3 by 3 matrix of (0.1, 0.05, 0.01 critical values), jth row corresponding to k=j}
#' \item{pvals}{A vector of p-values at k = 1, 2, 3}
PLRTCritBoot <- function (y, parlist, values = NULL, ninits = 10,
                          nbtsp = 199, parallel = 0, cl = NULL,
                          LRT.penalized = FALSE) {
  # if (normalregMix.test.on) # initial values controlled by normalregMix.test.on
  #   set.seed(normalregMix.test.seed)
  
  y   <- as.matrix(y)
  n   <- nrow(y)
  d   <- ncol(y)
  dsig <- d*(d+1)/2
  
  alpha <- parlist$alpha
  mu    <- parlist$mu
  sigma <- parlist$sigma
  m     <- length(alpha)
  an    <- 1
  # an    <- anFormula(parlist = parlist, m = m, n = n, LRT.penalized = LRT.penalized)
  
  mu.mat <- matrix(mu, nrow=d, ncol=m)
  sigma.mat <- matrix(0, nrow=d, ncol=d*m)
  for (j in 1:m){
    sigma.j <- sigma[((j-1)*dsig+1):(j*dsig)]
    sigma.mat[,((j-1)*d+1):(j*d)] <- sigmavec2mat(sigma.j,d)
  }
  
  pvals <- NULL
  
  # Generate bootstrap observations
  if (m==1){
    ybset <- rmvnorm(nbtsp*n, mu=mu, sigma = sigma.mat)
  } else {
    ybset <- rmvnmix(nbtsp*n, alpha=alpha, mu=mu.mat, sigma=sigma.mat)
  }
  ybset <- array(ybset, dim=c(n,d,nbtsp))
  
  # num.cores <- max(1,floor(detectCores()*parallel))
  # if (num.cores > 1) {
  #   if (is.null(cl))
  #     cl <- makeCluster(num.cores)
  #   registerDoParallel(cl)
  #   out <- foreach (i.btsp = 1:nbtsp) %dopar% {
  #     mvnmixMEMtest (ybset[,,i.btsp], m = m,
  #                       an = an, ninits = ninits, crit.method = "none", parallel=0) }
  #   on.exit(cl)
  # }
  # else
  out <- lapply(1:nbtsp, function(j) mvnmixPLRT(y=ybset[,,j], m = m, 
                                                ninits = ninits, crit.method="none"))
  
  plrtstat.b <- sapply(out, "[[", "plrtstat")  # 3 by nbstp matrix
  
  plrtstat.b <- sort(plrtstat.b)
  
  q <- ceiling(nbtsp*c(0.90,0.95,0.99))
  crit <- plrtstat.b[q]
  
  if (!is.null(values)) { pvals <- mean(plrtstat.b > values) }
  
  return(list(crit = crit, pvals = pvals))
}  # end function PLRTCritBoot


