/******************************************************************************
* Macro: IMPORT_TR
* Purpose: Import SDTM TR dataset with validation
* Version: 1.0
* 
* PARAMETERS:
*   path     - Path to directory containing tr.csv
*   outds    - Output dataset name (default: work.tr)
*   validate - Run validation checks (1=Yes, 0=No)
*
* VALIDATION:
*   - Checks for required variables (USUBJID, TRTESTCD, TRDTC, TRSTRESN)
*   - Validates numeric values in TRSTRESN
*   - Reports data quality issues
*
* AUTHOR: Christian Baghai
* DATE: 2026-01-03
******************************************************************************/

%macro import_tr(
    path=,
    outds=work.tr,
    validate=1
) / des="Import SDTM TR dataset with validation";

    %put NOTE: [IMPORT_TR] Importing TR from &path...;
    
    proc import datafile="&path/tr.csv"
        out=&outds
        dbms=csv
        replace;
        guessingrows=max;
    run;
    
    %if &validate = 1 %then %do;
        %put NOTE: [IMPORT_TR] Running validation checks...;
        
        /* Check required variables */
        proc contents data=&outds out=work._tr_vars(keep=name) noprint;
        run;
        
        %let required_vars = USUBJID TRTESTCD TRDTC TRSTRESN;
        
        data _null_;
            set work._tr_vars end=eof;
            retain has_usubjid has_trtestcd has_trdtc has_trstresn 0;
            
            if upcase(name) = 'USUBJID' then has_usubjid = 1;
            if upcase(name) = 'TRTESTCD' then has_trtestcd = 1;
            if upcase(name) = 'TRDTC' then has_trdtc = 1;
            if upcase(name) = 'TRSTRESN' then has_trstresn = 1;
            
            if eof then do;
                if has_usubjid = 0 then put 'ERROR: [IMPORT_TR] USUBJID not found';
                if has_trtestcd = 0 then put 'WARNING: [IMPORT_TR] TRTESTCD not found';
                if has_trdtc = 0 then put 'WARNING: [IMPORT_TR] TRDTC not found';
                if has_trstresn = 0 then put 'WARNING: [IMPORT_TR] TRSTRESN not found';
            end;
        run;
        
        /* Data quality summary */
        proc sql noprint;
            select count(*) into :n_records trimmed from &outds;
            select count(distinct USUBJID) into :n_subjects trimmed from &outds;
            select count(*) into :n_missing_result trimmed 
                from &outds where missing(TRSTRESN);
        quit;
        
        %put NOTE: [IMPORT_TR] Validation Summary:;
        %put NOTE: [IMPORT_TR]   Records: &n_records;
        %put NOTE: [IMPORT_TR]   Subjects: &n_subjects;
        %put NOTE: [IMPORT_TR]   Missing Results: &n_missing_result;
    %end;
    
    %put NOTE: [IMPORT_TR] Import complete: &outds;
    
%mend import_tr;
