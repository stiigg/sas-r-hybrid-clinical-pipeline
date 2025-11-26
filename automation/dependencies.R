# Utilities for reasoning about SDTM/ADaM/TLF dependencies using the new
# metadata assets that live under specs/.
#
# This file is intentionally side-effect free: it reads manifests/configuration
# and expands sets of changed SDTM or ADaM identifiers into the full set of
# impacted ADaM datasets and TLF IDs. Change detection lives elsewhere
# (automation/change_detection.R) and passes in the seed vectors
# `changed_sdtm` and `changed_adam`.

safely_read_yaml <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("Dependency metadata missing at %s", path), call. = FALSE)
  }
  yaml::read_yaml(path)
}

read_adam_manifest <- function(path = "specs/etl/adam_manifest.yml") {
  safely_read_yaml(path)
}

read_tlf_dependency_config <- function(path = "specs/tlf/tlf_config.yml") {
  cfg <- safely_read_yaml(path)
  cfg$shells %||% list()
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

get_impacted_adam_from_sdtm <- function(changed_sdtm, manifest = read_adam_manifest()) {
  if (length(changed_sdtm) == 0) {
    return(character())
  }
  entries <- manifest$adam %||% list()
  impacted <- character()
  for (name in names(entries)) {
    entry <- entries[[name]]
    sources <- entry$source_sdtm %||% character()
    if (length(intersect(sources, changed_sdtm)) > 0) {
      impacted <- c(impacted, name)
    }
  }
  unique(impacted)
}

get_impacted_adam_from_adam <- function(changed_adam, manifest = read_adam_manifest()) {
  if (length(changed_adam) == 0) {
    return(character())
  }
  entries <- manifest$adam %||% list()
  impacted <- changed_adam
  repeat {
    new_hits <- character()
    for (name in names(entries)) {
      entry <- entries[[name]]
      deps <- entry$depends_on_adam %||% character()
      if (length(intersect(deps, impacted)) > 0 && !(name %in% impacted)) {
        new_hits <- c(new_hits, name)
      }
    }
    new_hits <- setdiff(unique(new_hits), impacted)
    if (length(new_hits) == 0) break
    impacted <- unique(c(impacted, new_hits))
  }
  sort(unique(impacted))
}

get_allowed_tlf_categories <- function(mode, study_cfg) {
  mode_cfg <- study_cfg$modes[[mode]]
  cats <- mode_cfg$tlf_categories %||% character()
  unname(cats)
}

get_tlf_catalog <- function(mode, study_cfg, tlf_shells = read_tlf_dependency_config()) {
  allowed_cats <- get_allowed_tlf_categories(mode, study_cfg)
  catalog <- lapply(tlf_shells, function(entry) {
    list(
      tlf_id = entry$tlf_id %||% entry$id %||% NA_character_,
      category = entry$category %||% "core",
      depends_on_adam = entry$depends_on_adam %||% character()
    )
  })
  catalog <- Filter(function(x) !is.na(x$tlf_id), catalog)
  if (length(allowed_cats) == 0) {
    return(catalog)
  }
  Filter(function(x) x$category %in% allowed_cats, catalog)
}

get_impacted_tlfs <- function(changed_adam, mode, study_cfg, tlf_shells = read_tlf_dependency_config()) {
  if (length(changed_adam) == 0) {
    return(character())
  }
  catalog <- get_tlf_catalog(mode, study_cfg, tlf_shells)
  impacted <- vapply(catalog, function(entry) {
    length(intersect(entry$depends_on_adam, changed_adam)) > 0
  }, logical(1))
  unique(vapply(catalog[impacted], function(entry) entry$tlf_id, character(1)))
}
