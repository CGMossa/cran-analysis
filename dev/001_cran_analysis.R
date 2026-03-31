library(magrittr)
library(tidyverse)
library(mirai)
# data needed for awesome-extendr
columns <- c("Package", "Title", "LinkingTo")

# CRAN packages ----------------------------------------------------------
pkgs <- subset(
  tools::CRAN_package_db(),
  !is.na(LinkingTo)
  # grepl("rust", tolower(SystemRequirements))
)

linking_to_counts <- pkgs %>%
  as_tibble() %>%
  select(Package, LinkingTo) %>%
  mutate(
    linked_pkg = LinkingTo |>
      str_replace_all("\\s+", " ") |>
      str_remove_all(" ?\\([^)]*\\)") |>
      str_trim() |>
      str_remove_all("^,+|,+$") |>
      str_split(",\\s*")
  ) %>%
  unnest(linked_pkg) %>%
  summarise(
    n_packages = n(),
    packages = paste(Package, collapse = ", "),
    .by = linked_pkg
  ) %>%
  arrange(desc(n_packages))

linking_to_counts %>%
  # mutate(packages = str_trunc(packages, 80)) %>%
  mutate(across(everything(), \(x) format(x, justify = "left"))) %>%
  readr::write_tsv("dev/001_linked_pkgs_stats.tsv")

linking_to_counts %>%
  print(n = 50, width = Inf)

# Archived (removed) packages with LinkingTo -----------------------------------
archived_pkgs <- tools:::CRAN_archive_db()
current_pkgs <- tools::CRAN_package_db()

removed_pkg_names <- setdiff(names(archived_pkgs), current_pkgs[["Package"]])

# check for names that look like "pkg_1.0.0" (underscore + version)
has_version <- str_detect(removed_pkg_names, "_\\d+\\.\\d+")
if (any(has_version)) {
  warning("Some archive names contain version numbers: ",
    paste(removed_pkg_names[has_version], collapse = ", "))
}

# pre-compute URLs to avoid sending huge archived_pkgs to each daemon
latest_tarballs <- vapply(removed_pkg_names, \(pkg) {
  tail(rownames(archived_pkgs[[pkg]]), 1)
}, character(1))

removed_urls <- sprintf(
  "https://cran.r-project.org/src/contrib/Archive/%s", latest_tarballs
)

# fetch DESCRIPTION from latest archived tarball for each removed package
daemons(20)

removed_descriptions <- map2(
  removed_pkg_names, removed_urls,
  in_parallel(\(pkg, url) {
    tmp <- tempfile(fileext = ".tar.gz")
    on.exit(unlink(tmp))
    tryCatch({
      download.file(url, tmp, quiet = TRUE)
      desc_files <- untar(tmp, list = TRUE)
      desc_file <- grep("DESCRIPTION$", desc_files, value = TRUE)[1]
      untar(tmp, files = desc_file, exdir = tempdir())
      as.data.frame(read.dcf(
        file.path(tempdir(), desc_file),
        fields = c("Package", "LinkingTo")
      ))
    }, error = \(e) {
      tibble::tibble(Package = pkg, LinkingTo = NA_character_)
    })
  }),
  .progress = TRUE
) %>%
  list_rbind()

daemons(0)

removed_with_linking_to <- removed_descriptions %>%
  filter(!is.na(LinkingTo), nzchar(str_trim(LinkingTo)))

removed_linking_to_counts <- removed_with_linking_to %>%
  as_tibble() %>%
  mutate(
    linked_pkg = LinkingTo |>
      str_replace_all("\\s+", " ") |>
      str_remove_all(" ?\\([^)]*\\)") |>
      str_trim() |>
      str_remove_all("^,+|,+$") |>
      str_split(",\\s*")
  ) %>%
  unnest(linked_pkg) %>%
  summarise(
    n_packages = n(),
    packages = paste(Package, collapse = ", "),
    .by = linked_pkg
  ) %>%
  arrange(desc(n_packages))

removed_linking_to_counts %>%
  mutate(across(everything(), \(x) format(x, justify = "left"))) %>%
  readr::write_tsv("dev/001_removed_linked_pkgs_stats.tsv")

removed_linking_to_counts %>%
  print(n = 50, width = Inf)

# # downloads --------------------------------------------------------------
# pkgs <- rbind(pkgs, other_pkgs)

# all_downloads <- cranlogs::cran_downloads(
#   pkgs[["Package"]],
#   from = "2023-01-01",
#   to = Sys.Date()
# )

# pkg_downloads <- subset(all_downloads, count > 0)

# pkg_downloads <- aggregate(
#   count ~ package,
#   data = pkg_downloads,
#   FUN = sum
# )

# names(pkg_downloads) <- c("Package", "Count")

# pkgs <- merge(pkgs, pkg_downloads, all.x = TRUE)

# # Save -------------------------------------------------------------------
# write.csv(
#   pkgs,
#   "extendr-pkgs.csv",
#   row.names = FALSE
# )
