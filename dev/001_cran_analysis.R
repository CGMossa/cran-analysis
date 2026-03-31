library(magrittr)
library(tidyverse)
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

# tools:::CRAN_archive_db()

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
