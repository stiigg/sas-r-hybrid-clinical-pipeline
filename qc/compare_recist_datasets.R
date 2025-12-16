library(diffdf)
library(haven)
library(dplyr)

compare_recist_datasets <- function(prod_path, qc_path, dataset_name) {
    
    # Read SAS datasets
    prod <- read_sas(file.path(prod_path, paste0(dataset_name, ".sas7bdat")))
    qc <- read_sas(file.path(qc_path, paste0(dataset_name, ".sas7bdat")))
    
    # Perform comparison
    comp <- diffdf(
        base = prod,
        compare = qc,
        keys = c("USUBJID", "ADT", "PARAMCD"),
        suppress_warnings = FALSE
    )
    
    # Generate HTML report
    diffdf_html <- function(comp_obj, output_file) {
        sink(output_file)
        cat("<html><head><title>RECIST Dataset Comparison</title></head><body>")
        cat("<h1>Comparison Results:</h1>")
        print(comp_obj)
        cat("</body></html>")
        sink()
    }
    
    output_file <- file.path(
        "qc", "outputs",
        paste0("comparison_", dataset_name, "_", format(Sys.Date(), "%Y%m%d"), ".html")
    )
    diffdf_html(comp, output_file)
    
    # Return pass/fail status
    if(length(comp$ExtRowsBase) == 0 && length(comp$ExtRowsComp) == 0) {
        message("***** QC PASS: Datasets are identical *****")
        return(TRUE)
    } else {
        warning("***** QC FAIL: Discrepancies detected *****")
        return(FALSE)
    }
}

# Execute
compare_recist_datasets(
    prod_path = "outputs/adam",
    qc_path = "qc/datasets",
    dataset_name = "adrecist"
)
