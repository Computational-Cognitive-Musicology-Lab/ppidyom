# PPIDyOM — Developer Guide

This document covers the developer workflow: first-time setup, building, and running tests.
For the package overview and algorithm description, see [README.md](README.md).

---

## Prerequisites

- **R ≥ 4.5** (see `DESCRIPTION`)
- **RStudio** (recommended) or any R IDE with project support
- **devtools** — the standard R package development toolkit

---

## 1. First-Time Setup

### 1.1 Install devtools

```r
install.packages("devtools")
```

### 1.2 Install package dependencies

`ppidyom` depends on `data.table` (CRAN) and `ppm` (GitHub):

```r
install.packages("data.table")
devtools::install_github("pmcharrison/ppm")
```

### 1.3 Install testthat (for running tests)

```r
install.packages("testthat")
```

### 1.4 Open the project

Open `ppidyom.Rproj` in RStudio — this sets the working directory and activates the project environment automatically.

---

## 2. Build

### Active development (recommended)

`load_all()` sources every file in `R/` into the current session without a full install. Use this during development — it's fast and reflects your edits immediately:

```r
devtools::load_all()
```

### Regenerate documentation

After editing roxygen2 comments (`#'` blocks) in any `R/` file, regenerate `NAMESPACE` and the `man/` pages:

```r
devtools::document()
```

### Install the package

Performs a full build and install into your R library. Use this when you want the package available outside this project, or to test it as an end user would:

```r
devtools::install()
```

### Run R CMD CHECK

Runs the full CRAN-style check suite (build, tests, documentation completeness):

```r
devtools::check()
```

---

## 3. Running Tests

Tests live in `tests/testthat/`. The test suite uses the **testthat** framework.

### Run all tests

```r
devtools::test()
```

This is the standard command. It loads the package first (equivalent to `load_all()`), then runs every `test-*.R` file under `tests/testthat/`.

### Run a specific test file

```r
devtools::test(filter = "counts")    # runs test-counts.R
devtools::test(filter = "escape")    # runs test-escape.R
devtools::test(filter = "invariants") # runs test-invariants.R
devtools::test(filter = "ppidyom")   # runs test-ppidyom.R
```

Or use `testthat::test_file()` directly after `load_all()`:

```r
devtools::load_all()
testthat::test_file("tests/testthat/test-counts.R")
```

### Run scalability / timing tests

Scalability tests are disabled by default (they are slow). Enable them with an environment variable before running:

```r
Sys.setenv(RUN_SCALABILITY_TESTS = "true")
devtools::test(filter = "scalability")
```

---

## Typical Development Loop

```
# Once per session
devtools::load_all()

# Edit R/*.R files ...

# Reload and run relevant tests
devtools::load_all()
devtools::test(filter = "counts")

# Before committing
devtools::document()   # if you changed roxygen comments
devtools::check()      # full check (optional but recommended)
```
