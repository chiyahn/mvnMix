% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mvn_funcs.R
\name{mvnmixPhiInit}
\alias{mvnmixPhiInit}
\title{mvnmixPhiInit}
\usage{
mvnmixPhiInit(y, parlist, h, tau, ninits = 1)
}
\arguments{
\item{y}{n by d matrix of data}

\item{parlist}{The parameter estimates as a list containing alpha, mu, and sigma
in the form of (alpha = (alpha_1,...,alpha_m),
mu = (mu_1',...,mu_m'), sigma = (vech(sigma_1)',...,vech(sigma_m)')}

\item{h}{h used as index for pivoting}

\item{tau}{Tau used to split the h-th component}

\item{ninits}{number of initial values to be generated}
}
\value{
A list with the following items:
\item{alpha}{m+1 by ninits matrix for alpha}
\item{mu}{d*(m+1) by ninits matrix for mu}
\item{sigma}{d*(d+1)/2*(m+1) by ninits matrix for sigma}
}
\description{
Generates lists of parameters for initial candidates used by
the modified EM test for mixture of multivariate normals.
}
