# Hash helpers for pipeline change detection.

hash_file <- function(path) {
  if (!file.exists(path)) {
    return(NA_character_)
  }
  digest::digest(file = path, algo = "md5")
}

hash_dir_files <- function(dir, pattern = NULL) {
  if (!dir.exists(dir)) {
    return(structure(character(), names = character()))
  }
  files <- list.files(dir, pattern = pattern, full.names = TRUE)
  if (length(files) == 0) {
    return(structure(character(), names = character()))
  }
  hashes <- vapply(files, hash_file, character(1))
  names(hashes) <- basename(files)
  hashes
}
