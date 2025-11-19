write_run_manifest <- function(
  manifest_path,
  git_commit,
  pipeline_mode,
  analysis_cut,
  data_root,
  sdtm_hashes,
  adam_hashes,
  spec_hashes,
  steps_ran
) {
  manifest <- list(
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    git_commit = git_commit,
    pipeline_mode = pipeline_mode,
    analysis_cut = analysis_cut,
    data_root = data_root,
    sdtm_hashes = sdtm_hashes,
    adam_hashes = adam_hashes,
    spec_hashes = spec_hashes,
    steps_ran = steps_ran
  )
  dir.create(dirname(manifest_path), recursive = TRUE, showWarnings = FALSE)
  yaml::write_yaml(manifest, manifest_path)
  manifest_path
}
