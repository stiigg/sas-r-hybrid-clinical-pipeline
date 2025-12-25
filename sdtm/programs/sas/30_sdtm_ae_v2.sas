/******************************************************************************
* Program: 30_sdtm_ae_v2.sas (METADATA-DRIVEN v2.0)
* Purpose: Generate SDTM AE (Adverse Events) domain using transformation engine
* Author:  Christian Baghai
* Date:    2025-12-25
* Version: 2.0 - Metadata-Driven Framework
* 
* Input:   - sdtm/specs/sdtm_ae_spec_v2.csv (METADATA SPECIFICATION)
*          - data/raw/adverse_events_raw.csv (RAW SOURCE DATA)
*          - sdtm.dm (REQUIRED for RFSTDTC study day calculations)
*
* Output:  - data/csv/ae.csv
*          - data/xpt/ae.xpt (FDA-compliant transport file)
*          - logs/30_sdtm_ae_v2.log
* 
* Priority: HIGHEST - Required for FDA safety reporting
*
* Notes:   
*   This is the v2.0 refactored version using the universal transformation
*   engine. The original hard-coded version (30_sdtm_ae.sas) is preserved
*   for comparison and validation.
*
*   Framework Features:
*   - Metadata-driven transformations (17 rules, 8 transformation types)
*   - Automated QC validation
*   - Reusable macro components
*   - Industry-validated patterns (Eli Lilly, Roche, AbbVie)
*
*   MedDRA Coding:
*   Medical coding (MedDRA) required for AEDECOD in production submissions.
*   This demo uses verbatim fallback when MEDDRA_PT is not available.
*
* Dependencies:
*   - sdtm/macros/sdtm_transformation_engine.sas
*   - sdtm/macros/study_day_calculation.sas (loaded by engine)
*   - sdtm/macros/qc_report_generator.sas (loaded by engine)
*
* Validation:
*   Compare output with original 30_sdtm_ae.sas to verify 100% match:
*   proc compare base=ae_original compare=ae_v2; run;
******************************************************************************/

/* ========================================================================
   STEP 1: ENVIRONMENT SETUP
   ======================================================================== */

%let studyid = RECIST-DEMO-001;
%let domain = AE;

%put NOTE: ========================================================;
%put NOTE: Starting AE Domain Generation (v2.0 Metadata-Driven);
%put NOTE: Study: &studyid;
%put NOTE: Date: %sysfunc(datetime(), datetime20.);
%put NOTE: ========================================================;

/* Load universal transformation macros */
%include "../../sdtm/macros/sdtm_transformation_engine.sas";
%include "../../sdtm/macros/study_day_calculation.sas";
%include "../../sdtm/macros/qc_report_generator.sas";

/* Set library references */
libname raw "../../data/raw";
libname sdtm "../../data/csv";

/* ========================================================================
   STEP 2: PREPARE SOURCE DATA
   ======================================================================== */

%put NOTE: STEP 2 - Preparing source data...;

/* Import raw adverse events data */
proc import datafile="../../data/raw/adverse_events_raw.csv"
    out=raw_ae
    dbms=csv
    replace;
    guessingrows=max;
run;

%if &syserr ne 0 %then %do;
    %put ERROR: Failed to import adverse_events_raw.csv;
    %abort cancel;
%end;

/* Merge with DM to get RFSTDTC for study day calculations */
proc sql noprint;
    create table ae_with_dm as
    select a.*, b.RFSTDTC
    from raw_ae as a
    left join sdtm.dm as b
    on a.USUBJID = b.USUBJID;
quit;

%if &syserr ne 0 %then %do;
    %put ERROR: Failed to merge AE with DM domain;
    %put ERROR: Verify DM domain exists in sdtm library;
    %abort cancel;
%end;

/* ========================================================================
   STEP 3: EXECUTE TRANSFORMATION ENGINE
   ======================================================================== */

%put NOTE: STEP 3 - Executing metadata-driven transformations...;

%sdtm_transformation_engine(
    spec_file=../../sdtm/specs/sdtm_ae_spec_v2.csv,
    domain=&domain,
    source_data=ae_with_dm,
    output_data=ae_transformed,
    studyid=&studyid
);

/* ========================================================================
   STEP 4: POST-PROCESSING AND QUALITY CONTROL
   ======================================================================== */

%put NOTE: STEP 4 - Post-processing and QC validation...;

/* Sort by required key variables per SDTM */
proc sort data=ae_transformed out=sdtm.ae;
    by USUBJID AESEQ;
run;

/* Execute QC validation */
%qc_validator(
    input_data=sdtm.ae,
    spec_file=../../sdtm/specs/sdtm_ae_spec_v2.csv,
    domain=&domain
);

/* ========================================================================
   STEP 5: DESCRIPTIVE STATISTICS
   ======================================================================== */

%put NOTE: STEP 5 - Generating descriptive statistics...;

/* Frequency distributions for categorical variables */
proc freq data=sdtm.ae;
    tables AESEV AESER AEREL AEOUT / missing;
    title "AE Domain (v2.0) - Frequency Distributions";
    title2 "Controlled Terminology Compliance Check";
run;

/* Summary statistics for numeric variables */
proc means data=sdtm.ae n nmiss mean median min max;
    var AEDUR AESTDY AEENDY;
    title "AE Domain (v2.0) - Duration and Study Day Statistics";
run;

/* Overall domain summary */
proc sql;
    title "AE Domain (v2.0) - Overall Summary";
    select 
        count(distinct USUBJID) as Subjects,
        count(*) as Total_AEs,
        sum(AESER='Y') as Serious_AEs,
        sum(AETRTEM='Y') as Treatment_Emergent_AEs,
        calculated Serious_AEs / calculated Total_AEs * 100 as Pct_Serious format=5.1,
        calculated Treatment_Emergent_AEs / calculated Total_AEs * 100 as Pct_TEAE format=5.1
    from sdtm.ae;
quit;

title;

/* ========================================================================
   STEP 6: EXPORT TO CSV AND XPT
   ======================================================================== */

%put NOTE: STEP 6 - Exporting to CSV and XPT formats...;

/* Export to CSV */
proc export data=sdtm.ae
    outfile="../../data/csv/ae.csv"
    dbms=csv
    replace;
run;

/* Export to XPT v5 format for regulatory submission */
libname xptout xport "../../data/xpt/ae.xpt";
data xptout.ae;
    set sdtm.ae;
run;
libname xptout clear;

/* ========================================================================
   STEP 7: LOG COMPLETION AND CLEANUP
   ======================================================================== */

/* Redirect log to file */
proc printto log="../../logs/30_sdtm_ae_v2.log";
run;

/* Final summary */
proc sql noprint;
    select count(*) into :final_count trimmed
    from sdtm.ae;
quit;

%put NOTE: ========================================================;
%put NOTE: AE Domain Generation Complete (v2.0);
%put NOTE: Records Processed: &final_count;
%put NOTE: Output Files Created:;
%put NOTE:   - ../../data/csv/ae.csv;
%put NOTE:   - ../../data/xpt/ae.xpt;
%put NOTE:   - ../../logs/30_sdtm_ae_v2.log;
%put NOTE: ========================================================;
%put NOTE: Framework: Metadata-Driven Transformation Engine v2.0;
%put NOTE: Specification: sdtm_ae_spec_v2.csv (17 transformation rules);
%put NOTE: ========================================================;

/* Cleanup temporary datasets */
proc datasets library=work nolist;
    delete raw_ae ae_with_dm ae_transformed _qc_results _qc_temp;
quit;
