library(magrittr)
library(tidyverse)
library(mirai)

# ---------------------------------------------------------------------------
# 1. Identify packages NOT already checked in 002
# ---------------------------------------------------------------------------
already_checked <- read_csv("dev/002_inst_include_check.csv", show_col_types = FALSE)

cran_db <- tools::CRAN_package_db()
all_pkgs <- cran_db[["Package"]]

remaining <- setdiff(all_pkgs, already_checked$Package) %>% sort()
cat(sprintf(
  "Total CRAN packages: %d, already checked: %d, remaining: %d\n",
  length(all_pkgs), nrow(already_checked), length(remaining)
))

# ---------------------------------------------------------------------------
# 2. Build download URLs
# ---------------------------------------------------------------------------
ap <- available.packages(repos = "https://cloud.r-project.org")

remaining_info <- tibble(Package = remaining) %>%
  inner_join(
    as_tibble(ap) %>% select(Package, Version, Repository),
    by = "Package"
  ) %>%
  mutate(
    tarball = sprintf("%s_%s.tar.gz", Package, Version),
    url = sprintf("%s/%s", Repository, tarball)
  )

cat(sprintf("Will check %d remaining source tarballs\n", nrow(remaining_info)))

# ---------------------------------------------------------------------------
# 3. Download and check for inst/include in parallel
# ---------------------------------------------------------------------------
daemons(20)

results_remaining <- map2(
  remaining_info$Package,
  remaining_info$url,
  in_parallel(\(pkg, url) {
    tmp <- tempfile(fileext = ".tar.gz")
    on.exit(unlink(tmp))
    tryCatch({
      download.file(url, tmp, quiet = TRUE)
      files <- untar(tmp, list = TRUE)
      has_include <- any(grepl("/inst/include/", files, fixed = TRUE))
      include_files <- files[grepl("/inst/include/", files, fixed = TRUE)]
      n_headers <- sum(grepl("\\.(h|hpp|hh|hxx)$", include_files, ignore.case = TRUE))
      tibble::tibble(
        Package = pkg,
        has_inst_include = has_include,
        n_include_files = length(include_files),
        n_header_files = n_headers
      )
    }, error = \(e) {
      tibble::tibble(
        Package = pkg,
        has_inst_include = NA,
        n_include_files = NA_integer_,
        n_header_files = NA_integer_
      )
    })
  }),
  .progress = TRUE
) %>%
  list_rbind()

daemons(0)

# ---------------------------------------------------------------------------
# 4. Report new finds
# ---------------------------------------------------------------------------
new_finds <- results_remaining %>%
  filter(has_inst_include == TRUE) %>%
  arrange(desc(n_header_files))

n_failed <- sum(is.na(results_remaining$has_inst_include))
cat(sprintf(
  "\n%d / %d remaining packages have inst/include\n",
  nrow(new_finds), nrow(results_remaining)
))
if (n_failed > 0) {
  cat(sprintf("(%d packages failed to download)\n", n_failed))
}

if (nrow(new_finds) > 0) {
  cat("\nNewly found packages with inst/include:\n")
  new_finds %>% print(n = Inf, width = Inf)
}

# ---------------------------------------------------------------------------
# 5. Merge with previous results and save combined files
# ---------------------------------------------------------------------------
all_results <- bind_rows(already_checked, results_remaining) %>%
  arrange(Package)

all_with_include <- all_results %>%
  filter(has_inst_include == TRUE) %>%
  arrange(desc(n_header_files))

cat(sprintf(
  "\nCombined total: %d / %d CRAN packages have inst/include\n",
  nrow(all_with_include), nrow(all_results)
))

# Overwrite the combined files
all_results %>% write_csv("dev/002_inst_include_check.csv")
all_with_include %>% write_csv("dev/002_pkgs_with_inst_include.csv")

cat("Updated dev/002_inst_include_check.csv and dev/002_pkgs_with_inst_include.csv\n")
