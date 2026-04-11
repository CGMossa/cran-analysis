library(magrittr)
library(tidyverse)
library(mirai)

# ---------------------------------------------------------------------------
# 1. Identify candidate packages
# ---------------------------------------------------------------------------
cran_db <- tools::CRAN_package_db()

# Packages that appear in someone's LinkingTo — very likely to have inst/include
linking_to_all <- cran_db %>%
  as_tibble() %>%
  filter(!is.na(LinkingTo)) %>%
  pull(LinkingTo) %>%
  str_replace_all("\\s+", " ") %>%
  str_remove_all(" ?\\([^)]*\\)") %>%
  str_trim() %>%
  str_remove_all("^,+|,+$") %>%
  str_split(",\\s*") %>%
  unlist() %>%
  unique() %>%
  sort()

# Packages with compiled code that might also have inst/include
compiled_pkgs <- cran_db %>%
  as_tibble() %>%
  filter(NeedsCompilation == "yes") %>%
  pull(Package)

candidates <- union(linking_to_all, compiled_pkgs) %>%
  # keep only packages actually on CRAN right now
  intersect(cran_db[["Package"]]) %>%
  sort()

cat(sprintf(
  "Candidates: %d (%d from LinkingTo, %d compiled, %d total unique)\n",
  length(candidates), length(linking_to_all), length(compiled_pkgs),
  length(candidates)
))

# ---------------------------------------------------------------------------
# 2. Build download URLs from available.packages()
# ---------------------------------------------------------------------------
ap <- available.packages(repos = "https://cloud.r-project.org")

# Match candidates to their tarball filenames
candidate_info <- tibble(Package = candidates) %>%
  inner_join(
    as_tibble(ap) %>% select(Package, Version, Repository),
    by = "Package"
  ) %>%
  mutate(
    tarball = sprintf("%s_%s.tar.gz", Package, Version),
    url = sprintf("%s/%s", Repository, tarball)
  )

cat(sprintf("Will check %d source tarballs\n", nrow(candidate_info)))

# ---------------------------------------------------------------------------
# 3. Download and check for inst/include in parallel
# ---------------------------------------------------------------------------
daemons(20)

results <- map2(
  candidate_info$Package,
  candidate_info$url,
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
# 4. Summarise results
# ---------------------------------------------------------------------------
has_include <- results %>%
  filter(has_inst_include == TRUE) %>%
  arrange(desc(n_header_files))

cat(sprintf(
  "\n%d / %d checked packages have inst/include\n",
  nrow(has_include), nrow(results)
))

# How many failed to download?
n_failed <- sum(is.na(results$has_inst_include))
if (n_failed > 0) {
  cat(sprintf("(%d packages failed to download)\n", n_failed))
}

# Save full results
results %>%
  arrange(Package) %>%
  write_csv("dev/002_inst_include_check.csv")

# Save just the packages with inst/include
has_include %>%
  write_csv("dev/002_pkgs_with_inst_include.csv")

# Print summary
cat("\nPackages with inst/include (sorted by number of header files):\n")
has_include %>%
  print(n = Inf, width = Inf)
