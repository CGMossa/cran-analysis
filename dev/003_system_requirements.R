library(magrittr)
library(tidyverse)

# SystemRequirements is the DESCRIPTION field that names *system* libraries and
# tools a package needs to build (GDAL, libcurl, openssl, cmake, ...). Unlike
# LinkingTo (R-package -> R-package headers, see 001/002) this is what actually
# maps onto the macOS "recipes" build system. It is free-form text, so parsing
# is heuristic; we produce two views.

cran_db <- tools::CRAN_package_db() %>% as_tibble()

sysreq <- cran_db %>%
  select(Package, NeedsCompilation, SystemRequirements) %>%
  filter(!is.na(SystemRequirements), nzchar(str_trim(SystemRequirements)))

cat(sprintf(
  "%d / %d CRAN packages declare SystemRequirements (%d also NeedsCompilation)\n",
  nrow(sysreq), nrow(cran_db), sum(sysreq$NeedsCompilation == "yes", na.rm = TRUE)
))

# ---------------------------------------------------------------------------
# View 1: heuristic token frequency
# ---------------------------------------------------------------------------
# Split on separators, drop version constraints, distro-hint parentheticals,
# trailing URLs, and pure language/toolchain version tokens. Best-effort only.
lang_noise <- regex(
  "^(c\\+\\+|c|fortran|gnu make|make|gnu|java|rust|cargo|go|posix|iso)\\b",
  ignore_case = TRUE
)

tokens <- sysreq %>%
  mutate(
    tok = SystemRequirements %>%
      str_replace_all("\\s+", " ") %>%
      str_remove_all("https?://\\S+") %>%        # drop URLs
      str_remove_all("\\([^)]*\\)") %>%           # drop (>= x), (deb), (rpm) hints
      str_remove_all("\\[[^]]*\\]") %>%
      str_split("[,;]|\\bor\\b|\\band\\b|\\n")    # split alternatives/lists
  ) %>%
  unnest(tok) %>%
  mutate(
    tok = tok %>%
      str_remove(":.*$") %>%                      # "libcurl: libcurl-dev" -> "libcurl"
      str_remove("[<>=].*$") %>%                  # strip version operators onward
      str_remove("\\(.*$") %>%                    # strip stray "(" onward (leaked versions)
      str_remove("\\s+[0-9][0-9.x]*$") %>%        # strip trailing bare version "jags 4.x.y"
      str_remove("[[:space:][:punct:]]+$") %>%    # trailing punctuation/space
      str_trim() %>%
      str_to_lower()
  ) %>%
  filter(nzchar(tok), !str_detect(tok, lang_noise), str_length(tok) > 1)

token_counts <- tokens %>%
  summarise(
    n_packages = n_distinct(Package),
    packages = paste(sort(unique(Package)), collapse = ", "),
    .by = tok
  ) %>%
  arrange(desc(n_packages))

token_counts %>%
  mutate(across(everything(), \(x) format(x, justify = "left"))) %>%
  write_tsv("dev/003_system_requirements.tsv")

cat("\nTop 40 SystemRequirements tokens (heuristic):\n")
token_counts %>% select(tok, n_packages) %>% print(n = 40)

# ---------------------------------------------------------------------------
# View 2: demand for each library that the recipes repo already builds
# ---------------------------------------------------------------------------
# Seeded from recipe names so the output answers "how many CRAN packages need
# the library this recipe provides". Edit RECIPES_PATH to point at a checkout.
RECIPES_PATH <- "~/Documents/GitHub/R-macos-recipes/recipes"

if (dir.exists(path.expand(RECIPES_PATH))) {
  recipe_libs <- list.files(path.expand(RECIPES_PATH)) %>%
    str_subset("\\.patch$", negate = TRUE) %>%
    sort()

  # whole-word, case-insensitive match against the raw SystemRequirements text
  recipe_demand <- map(recipe_libs, \(lib) {
    hit <- str_detect(sysreq$SystemRequirements, regex(paste0("\\b", str_escape(lib), "\\b"), ignore_case = TRUE))
    tibble(
      recipe = lib,
      n_packages = sum(hit),
      packages = paste(sysreq$Package[hit], collapse = ", ")
    )
  }) %>%
    list_rbind() %>%
    arrange(desc(n_packages))

  recipe_demand %>%
    mutate(across(everything(), \(x) format(x, justify = "left"))) %>%
    write_tsv("dev/003_recipe_demand.tsv")

  cat("\nRecipe-library demand in CRAN SystemRequirements (top 30):\n")
  recipe_demand %>% select(recipe, n_packages) %>% print(n = 30)
} else {
  cat(sprintf("\nSkipped recipe-demand view: %s not found.\n", RECIPES_PATH))
}
