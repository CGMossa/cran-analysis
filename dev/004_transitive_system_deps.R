library(magrittr)
library(tidyverse)

# The macOS "recipes" repo (https://github.com/R-macos/recipes) builds system
# C/C++ libraries. Each recipe declares Depends: on other recipes, so installing
# one library pulls in a whole closure. This computes that transitive closure
# per recipe, and joins it with the CRAN demand from 003 so we can read off the
# full set of system libraries a CRAN package's SystemRequirements really needs.
RECIPES_PATH <- "~/Documents/GitHub/R-macos-recipes/recipes"
stopifnot(dir.exists(path.expand(RECIPES_PATH)))

recipe_files <- list.files(path.expand(RECIPES_PATH), full.names = TRUE) %>%
  str_subset("\\.patch$", negate = TRUE)

# parse Depends: from each recipe DCF; "freetype (>= 2.1.9), libpng" -> c("freetype","libpng")
parse_deps <- function(file) {
  dcf <- read.dcf(file)
  field <- intersect(c("Depends", "Depends."), colnames(dcf))
  if (length(field) == 0) return(character(0))
  dcf[1, field[1]] %>%
    str_remove_all("\\([^)]*\\)") %>%       # drop version constraints
    str_split(",\\s*") %>%
    pluck(1) %>%
    str_trim() %>%
    keep(nzchar)
}

deps <- set_names(map(recipe_files, parse_deps), basename(recipe_files))

# transitive closure via iterative expansion (97 nodes, simple is fine)
# ponytail: O(V*E) fixpoint loop, no graph lib needed at this size
closure <- function(pkg, deps) {
  seen <- character(0)
  frontier <- deps[[pkg]] %||% character(0)
  while (length(frontier)) {
    new <- setdiff(frontier, seen)
    seen <- union(seen, new)
    frontier <- unlist(deps[intersect(new, names(deps))], use.names = FALSE)
  }
  sort(seen)
}

# warn about Depends pointing at a non-existent recipe (graph integrity)
all_named <- unique(unlist(deps, use.names = FALSE))
missing <- setdiff(all_named, names(deps))
if (length(missing)) {
  warning("Depends reference recipes with no file: ", paste(missing, collapse = ", "))
}

trans <- tibble(recipe = names(deps)) %>%
  mutate(
    direct = map(deps, identity),
    transitive = map(recipe, closure, deps = deps),
    n_direct = lengths(direct),
    n_transitive = lengths(transitive),
    direct_deps = map_chr(direct, str_flatten, collapse = ", "),
    transitive_closure = map_chr(transitive, str_flatten, collapse = ", ")
  ) %>%
  arrange(desc(n_transitive))

trans %>%
  select(recipe, n_direct, n_transitive, direct_deps, transitive_closure) %>%
  mutate(across(everything(), \(x) format(x, justify = "left"))) %>%
  write_tsv("dev/004_transitive_system_deps.tsv")

cat("Recipes by transitive system-dependency count (top 20):\n")
trans %>% select(recipe, n_direct, n_transitive) %>% print(n = 20)

# join with CRAN demand (003): for each demanded library, how big is the real
# install set once the recipe closure is expanded
demand_path <- "dev/003_recipe_demand.tsv"
if (file.exists(demand_path)) {
  demand <- read_tsv(demand_path, show_col_types = FALSE) %>%
    mutate(recipe = str_trim(recipe), n_packages = as.integer(n_packages)) %>%
    select(recipe, n_packages)

  demand_closure <- demand %>%
    left_join(select(trans, recipe, n_transitive, transitive_closure), by = "recipe") %>%
    filter(n_packages > 0) %>%
    arrange(desc(n_packages))

  demand_closure %>%
    mutate(across(everything(), \(x) format(x, justify = "left"))) %>%
    write_tsv("dev/004_demand_with_closure.tsv")

  cat("\nMost-demanded libraries and their full install closure (top 15):\n")
  demand_closure %>% select(recipe, n_packages, n_transitive) %>% print(n = 15)
}
