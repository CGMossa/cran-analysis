# LinkingTo Analysis Summary

## What is `LinkingTo`?

`LinkingTo` is a DESCRIPTION field that declares a compile-time dependency on another package's C/C++ headers. Almost all usage is about accessing compiled code libraries from R packages.

## Top linked-to packages (current CRAN)

| Package | n | Why it's linked against |
|---|---|---|
| Rcpp | 3033 | The bridge between R and C++. Provides the core API for passing R objects to/from C++ code. Nearly every C++-based R package depends on it. |
| RcppArmadillo | 1239 | Exposes the Armadillo C++ linear algebra library (matrix ops, decompositions, solvers). The go-to for numerical/statistical C++ code. |
| RcppEigen | 502 | Exposes the Eigen C++ template library for linear algebra. Alternative to Armadillo, often preferred for sparse matrices. |
| BH | 346 | Ships Boost C++ headers — a large collection of general-purpose C++ utilities (smart pointers, math functions, string algorithms, etc.). |
| RcppParallel | 234 | Provides threading primitives (TBB/tinythread) for parallelizing C++ code within R packages. |
| StanHeaders | 138 | C++ headers for the Stan probabilistic programming language's math library (automatic differentiation, distributions). |
| rstan | 132 | R interface to Stan. Packages link to it to embed/extend Stan models in C++. |
| RcppProgress | 102 | A progress bar that works inside C++ loops and is interruptible (respects Ctrl+C). |
| cpp11 | 92 | A modern, header-only alternative to Rcpp for R/C++ interop. Lighter weight, no compilation dependency. |
| RcppThread | 38 | Thread pool and parallel for-loops in C++, designed to cooperate with R's event loop. |
| TMB | 36 | Template Model Builder — automatic differentiation for fitting random-effect models. |
| testthat | 32 | Unit testing framework. Linked for its C-level test runner interface. |
| RcppGSL | 25 | Wraps GNU Scientific Library vectors/matrices for use via Rcpp. |
| RcppDist | 24 | Additional probability distributions (truncated normal, four-parameter beta, etc.) callable from C++. |
| RcppNumerical | 18 | Numerical integration and optimization routines callable from C++. |
| Matrix | 18 | Sparse/dense matrix classes — packages link to access C-level CHOLMOD/CSparse internals. |
| bigmemory | 17 | Shared-memory and memory-mapped matrices. Packages link to access big.matrix objects from C++. |
| progress | 14 | Terminal progress bars with a C-level API. |
| cli | 11 | CLI helpers — linked for C-level progress bar and formatting functions. |
| nloptr | 11 | R interface to the NLopt nonlinear optimization library. |

## Current vs removed packages

The rankings are nearly identical between current and removed CRAN packages. Rcpp and its ecosystem dominate both.

Notable differences:

- **cpp11** is proportionally smaller in removed packages (13 vs 92) — it's newer, so fewer packages using it have been removed yet.
- **RcppCGAL** is disproportionately high in removed packages (18 removed vs 4 current) — suggests CGAL-dependent packages frequently get removed, possibly due to compilation difficulties.

## Key takeaway

`LinkingTo` is overwhelmingly about the Rcpp ecosystem. The top 3 packages (Rcpp, RcppArmadillo, RcppEigen) account for the vast majority of all `LinkingTo` declarations. The remaining packages expose specific C/C++ libraries (Boost, GSL, Stan, Eigen) or utilities (threading, progress bars, RNG).
