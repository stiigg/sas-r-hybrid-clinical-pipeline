# Example generation script for Table 14.1.1 (Demographics).
# The script writes a minimal RTF table summarising the mtcars dataset.

if (!exists("manifest_entry", inherits = FALSE)) {
  stop("manifest_entry not supplied. Generation scripts must be run via the batch orchestrator.")
}

source("r/tlf/config/load_config.R")
source("r/tlf/utils/tlf_logging.R")

output_path <- get_tlf_output_path(manifest_entry$out_file)

tlf_log(sprintf("Writing TLF output to %s", output_path), log_file = paste0(manifest_entry$tlf_id, "_generation.log"))

dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

summary_table <- aggregate(mtcars$mpg, by = list(Cylinders = mtcars$cyl), FUN = function(x) c(N = length(x), Mean = mean(x)))
summary_table <- do.call(data.frame, summary_table)

rtf_lines <- c(
  "{\\rtf1\\ansi",
  "{\\b Table 14.1.1: Demographics (mtcars demo)\\b0}\\line",
  paste("Population:", getOption("tlf.default_population", "Not specified")),
  "\\line",
  "Cylinders\\tab N\\tab Mean MPG\\line"
)

for (i in seq_len(nrow(summary_table))) {
  row <- summary_table[i, ]
  rtf_lines <- c(rtf_lines, sprintf("%s\\tab %s\\tab %.2f\\line", row$Cylinders, row$x.N, row$x.Mean))
}

rtf_lines <- c(rtf_lines, "}")

writeLines(rtf_lines, con = output_path)

invisible(output_path)
