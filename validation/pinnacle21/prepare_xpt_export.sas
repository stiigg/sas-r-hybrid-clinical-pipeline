/******************************************************************************
 * Program: prepare_xpt_export.sas
 * Purpose: Export ADaM datasets to SAS V5 Transport (XPT) format for 
 *          Pinnacle 21 Community validation
 * Author: Christian Baghai
 * Date: 2025-12-14
 *
 * Note: Pinnacle 21 requires XPT format, NOT native SAS7BDAT files
 *
 * Inputs:  adam.adsl, adam.adrs, adam.adtte (native SAS datasets)
 * Outputs: XPT files in validation/pinnacle21/xpt_files/
 *
 * Validation: Part of CDISC compliance verification (UR-015)
 ******************************************************************************/

/* Define library references */
libname adam "outputs/adam";

/* Create output directory for XPT files */
x "mkdir -p validation/pinnacle21/xpt_files";

/******************************************************************************
 * Macro: export_to_xpt
 * 
 * Exports a single dataset to SAS V5 Transport format
 *
 * Parameters:
 *   dataset - Name of dataset to export (e.g., adsl, adrs, adtte)
 *   lib     - Source library (default: adam)
 ******************************************************************************/
%macro export_to_xpt(dataset=, lib=adam);

    %put NOTE: ================================================================;
    %put NOTE: Exporting &dataset to XPT format for Pinnacle 21 validation;
    %put NOTE: ================================================================;

    /* Check if source dataset exists */
    %if %sysfunc(exist(&lib..&dataset)) %then %do;
        
        /* Define XPT library pointing to output file */
        libname xptout xport "validation/pinnacle21/xpt_files/&dataset..xpt";
        
        /* Copy dataset to XPT format */
        data xptout.&dataset;
            set &lib..&dataset;
        run;
        
        /* Clear XPT library */
        libname xptout clear;
        
        %put NOTE: ✓ Successfully exported &dataset..xpt;
        %put NOTE: Location: validation/pinnacle21/xpt_files/&dataset..xpt;
        
    %end;
    %else %do;
        %put ERROR: Source dataset &lib..&dataset does not exist;
        %put ERROR: Skipping export for &dataset;
    %end;
    
    %put NOTE: ================================================================;
    %put;

%mend export_to_xpt;

/******************************************************************************
 * Main Execution: Export all ADaM datasets
 ******************************************************************************/

%put NOTE: ================================================================;
%put NOTE: Pinnacle 21 XPT Export Utility;
%put NOTE: Date: %sysfunc(today(),date9.);
%put NOTE: Time: %sysfunc(time(),time8.);
%put NOTE: ================================================================;
%put;

/* Export subject-level analysis dataset */
%export_to_xpt(dataset=adsl, lib=adam);

/* Export response analysis dataset */
%export_to_xpt(dataset=adrs, lib=adam);

/* Export time-to-event analysis dataset */
%export_to_xpt(dataset=adtte, lib=adam);

/******************************************************************************
 * Generate dataset list file for Pinnacle 21
 ******************************************************************************/

filename dslist "validation/pinnacle21/dataset_list.txt";

data _null_;
    file dslist;
    put "adsl.xpt";
    put "adrs.xpt";
    put "adtte.xpt";
run;

%put NOTE: ================================================================;
%put NOTE: XPT Export Summary;
%put NOTE: ================================================================;
%put NOTE: Exported datasets:;
%put NOTE:   - adsl.xpt (Subject-Level Analysis Dataset);
%put NOTE:   - adrs.xpt (Response Analysis Dataset);
%put NOTE:   - adtte.xpt (Time-to-Event Analysis Dataset);
%put NOTE:;
%put NOTE: Dataset list: validation/pinnacle21/dataset_list.txt;
%put NOTE:;
%put NOTE: Next Steps:;
%put NOTE:   1. Verify XPT files created in validation/pinnacle21/xpt_files/;
%put NOTE:   2. Prepare define.xml metadata file;
%put NOTE:   3. Open Pinnacle 21 Community application;
%put NOTE:   4. Load XPT files and define.xml;
%put NOTE:   5. Execute ADaM validation;
%put NOTE:   6. Review validation report for errors/warnings;
%put NOTE: ================================================================;

/******************************************************************************
 * Verification: Check XPT file sizes and record counts
 ******************************************************************************/

%macro verify_xpt_export(dataset=);
    
    libname xptin xport "validation/pinnacle21/xpt_files/&dataset..xpt";
    
    proc contents data=xptin.&dataset noprint out=work.contents_&dataset;
    run;
    
    data _null_;
        set work.contents_&dataset end=eof;
        if eof then do;
            put "Dataset: &dataset..xpt";
            put "  Observations: " nobs comma10.;
            put "  Variables: " nvar;
            put;
        end;
    run;
    
    libname xptin clear;
    
%mend verify_xpt_export;

%put NOTE: ================================================================;
%put NOTE: XPT File Verification;
%put NOTE: ================================================================;
%put;

%verify_xpt_export(dataset=adsl);
%verify_xpt_export(dataset=adrs);
%verify_xpt_export(dataset=adtte);

%put NOTE: ================================================================;
%put NOTE: XPT export process complete;
%put NOTE: Files ready for Pinnacle 21 Community validation;
%put NOTE: ================================================================;
