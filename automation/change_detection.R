# Change detection helpers for SDTM domains, ADaM specs/code, and TLF specs/code.
#
# These utilities track lightweight file signatures (size + mtime, optionally
# an MD5 hash) in YAML state files under logs/. They return the identifiers that
# have changed since the previous successful run, plus the new state snapshot via
# the "state" attribute. The caller is responsible for persisting state only
# after a successful pipeline run.

suppressWarnings({
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package 'yaml' is required for change detection.", call. = FALSE)
  }
})

read_state_file <- function(path) {
  if (!file.exists(path)) return(list())
  yaml::read_yaml(path)
}

write_state_file <- function(state, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  yaml::write_yaml(state, path)
}

file_signature <- function(path, mode = c("mtime", "hash")) {
  mode <- match.arg(mode)
  info <- file.info(path)
  if (is.na(info$mtime) || !is.finite(info$size)) return(NULL)

  sig <- list(
    path = normalizePath(path),
    size = info$size,
    mtime = as.character(info$mtime)
  )

  if (mode == "hash" && requireNamespace("digest", quietly = TRUE)) {
    sig$hash <- digest::digest(file = path, algo = "md5")
  }

  sig
}

# ---- SDTM change detection ----------------------------------------------------

collect_sdtm_files <- function(root) {
  list.files(
    root,
    pattern = "\\.(xpt|XPT|sas7bdat|SAS7BDAT)$",
    full.names = TRUE
  )
}

detect_changed_sdtm <- function(root = "data/sdtm",
                                state_file = "logs/sdtm_state.yml",
                                mode = c("mtime", "hash")) {
  mode <- match.arg(mode)
  old_state <- read_state_file(state_file)

  if (!dir.exists(root)) {
    warning(sprintf("SDTM directory '%s' not found; assuming no changes.", root))
    return(structure(character(), state = NULL))
  }

  paths <- collect_sdtm_files(root)
  new_state <- list()
  changed <- character()

  for (p in paths) {
    sig <- file_signature(p, mode = mode)
    if (is.null(sig)) next

    key <- basename(p)
    prev <- old_state[[key]]

    if (is.null(prev) ||
        !identical(prev$mtime, sig$mtime) ||
        (!is.null(prev$hash) && !is.null(sig$hash) && prev$hash != sig$hash)) {
      dom <- sub("\\..*$", "", key)
      changed <- c(changed, toupper(dom))
    }

    new_state[[key]] <- sig
  }

  attr(changed, "state") <- new_state
  changed
}

commit_sdtm_state <- function(new_state, state_file = "logs/sdtm_state.yml") {
  write_state_file(new_state, state_file)
}

# ---- ADaM spec/code change detection -----------------------------------------

adam_file_map <- function() {
  list(
    ADSL = c(
      "etl/sas/30_adam_adsl.sas",
      "qc/r/adam/qc_adsl.R",
      "qc/r/qc_parity_adsl.R"
    )
  )
}

detect_changed_adam_specs <- function(state_file = "logs/adam_spec_state.yml",
                                      mode = c("mtime", "hash")) {
  mode <- match.arg(mode)
  old_state <- read_state_file(state_file)
  mapping <- adam_file_map()

  new_state <- list()
  changed <- character()

  for (adam_name in names(mapping)) {
    files <- mapping[[adam_name]]
    sigs <- list()

    for (f in files) {
      if (!file.exists(f)) next
      s <- file_signature(f, mode = mode)
      if (!is.null(s)) sigs[[f]] <- s
    }

    prev <- old_state[[adam_name]]

    if (is.null(prev) || !identical(prev, sigs)) {
      changed <- c(changed, adam_name)
    }

    new_state[[adam_name]] <- sigs
  }

  attr(changed, "state") <- new_state
  changed
}

commit_adam_spec_state <- function(new_state, state_file = "logs/adam_spec_state.yml") {
  write_state_file(new_state, state_file)
}

# ---- TLF spec/code change detection ------------------------------------------

tlf_file_map <- function() {
  list(
    "T14.1.1" = c(
      "outputs/tlf/r/gen/gen_tlf_t14_1_1_demog.R",
      "qc/r/tlf/qc_tlf_t14_1_1_demog.R",
      "specs/tlf/tlf_config.yml",
      "specs/tlf/tlf_shell_map.csv"
    )
  )
}

detect_changed_tlfs_specs <- function(state_file = "logs/tlf_spec_state.yml",
                                      mode = c("mtime", "hash")) {
  mode <- match.arg(mode)
  old_state <- read_state_file(state_file)
  mapping <- tlf_file_map()

  new_state <- list()
  changed <- character()

  for (tlf_id in names(mapping)) {
    files <- mapping[[tlf_id]]
    sigs <- list()

    for (f in files) {
      if (!file.exists(f)) next
      s <- file_signature(f, mode = mode)
      if (!is.null(s)) sigs[[f]] <- s
    }

    prev <- old_state[[tlf_id]]

    if (is.null(prev) || !identical(prev, sigs)) {
      changed <- c(changed, tlf_id)
    }

    new_state[[tlf_id]] <- sigs
  }

  attr(changed, "state") <- new_state
  changed
}

commit_tlf_spec_state <- function(new_state, state_file = "logs/tlf_spec_state.yml") {
  write_state_file(new_state, state_file)
}
