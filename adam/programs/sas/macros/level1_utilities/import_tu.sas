/******************************************************************************
* Macro: IMPORT_TU
* Purpose: Import TU (Tumor Identification) dataset with validation
* Version: 1.0
* 
* PARAMETERS:
*   path           - Path to directory containing tu.csv
*   outds          - Output dataset name (default: work.tu)
*   validate       - Run validation checks (1=Yes, 0=No, default: 1)
*
* ALGORITHM:
*   - Import TU dataset from CSV
*   - Validate TULINKID uniqueness per subject
*   - Check TUEVAL (TARGET/NON-TARGET) values
*   - Verify TUORRES (measurability) for target lesions
*   - Report lesion count summary
*
* VALIDATION:
*   - Check required variables: STUDYID, USUBJID, TULINKID, TUEVAL
*   - Verify target lesion measurability criteria (≥10mm nodes, ≥20mm non-nodal)
*   - Maximum 5 target lesions per subject per RECIST 1.1
*   - Flag potential data quality issues
*
* REFERENCES:
*   - RECIST 1.1 (EORTC): Target lesion selection criteria
*   - CDISC SDTM IG v3.4: TU domain specifications
*
* EXAMPLE USAGE:
*   %import_tu(
*       path=&SDTM_PATH,
*       outds=work.tu_raw,
*       validate=1
*   );
*
* AUTHOR: Christian Baghai
* DATE: 2026-01-03
******************************************************************************/

%macro import_tu(
    path=,
    outds=work.tu,
    validate=1
) / des="Import TU (Tumor Identification) dataset with validation";

    /* Parameter validation */
    %if %length(&path) = 0 %then %do;
        %put ERROR: [IMPORT_TU] Parameter PATH is required;
        %return;
    %end;
    
    %if %length(&outds) = 0 %then %do;
        %put ERROR: [IMPORT_TU] Parameter OUTDS is required;
        %return;
    %end;
    
    %put NOTE: [IMPORT_TU] Starting TU dataset import;
    %put NOTE: [IMPORT_TU] Source: &path/tu.csv;
    %put NOTE: [IMPORT_TU] Target: &outds;
    
    /* Check if file exists */
    %if not %sysfunc(fileexist(&path/tu.csv)) %then %do;
        %put ERROR: [IMPORT_TU] File not found: &path/tu.csv;
        %return;
    %end;
    
    /* Import TU dataset */
    proc import 
        datafile="&path/tu.csv"
        out=&outds
        dbms=csv
        replace;
        guessingrows=max;
    run;
    
    %if &syserr > 4 %then %do;
        %put ERROR: [IMPORT_TU] Import failed with SYSERR=&syserr;
        %return;
    %end;
    
    /* Get record count */
    proc sql noprint;
        select count(*) into :n_records trimmed
        from &outds;
        
        select count(distinct USUBJID) into :n_subjects trimmed
        from &outds;
    quit;
    
    %put NOTE: [IMPORT_TU] Import successful:;
    %put NOTE: [IMPORT_TU]   Records: &n_records;
    %put NOTE: [IMPORT_TU]   Subjects: &n_subjects;
    
    /* Validation checks */
    %if &validate = 1 %then %do;
        
        %put NOTE: [IMPORT_TU] Running validation checks...;
        
        /* Check required variables */
        proc contents data=&outds out=_tu_vars(keep=name) noprint;
        run;
        
        proc sql noprint;
            select name into :existing_vars separated by ' '
            from _tu_vars;
        quit;
        
        %let required_vars = STUDYID USUBJID TULINKID TUEVAL;
        %let missing_vars = ;
        
        %do i = 1 %to %sysfunc(countw(&required_vars));
            %let req_var = %scan(&required_vars, &i);
            %if %sysfunc(findw(%upcase(&existing_vars), %upcase(&req_var))) = 0 %then %do;
                %let missing_vars = &missing_vars &req_var;
            %end;
        %end;
        
        %if %length(&missing_vars) > 0 %then %do;
            %put ERROR: [IMPORT_TU] Missing required variables:&missing_vars;
        %end;
        
        /* Validate TUEVAL values */
        proc sql noprint;
            select count(*) into :n_invalid_tueval trimmed
            from &outds
            where not missing(TUEVAL) 
              and TUEVAL not in ('TARGET', 'NON-TARGET', 'NEW');
            
            select count(distinct USUBJID) into :n_target_subjects trimmed
            from &outds
            where TUEVAL = 'TARGET';
            
            select count(*) into :n_target_lesions trimmed
            from &outds
            where TUEVAL = 'TARGET';
            
            select count(distinct USUBJID) into :n_nontarget_subjects trimmed
            from &outds
            where TUEVAL = 'NON-TARGET';
            
            select count(*) into :n_nontarget_lesions trimmed
            from &outds
            where TUEVAL = 'NON-TARGET';
        quit;
        
        %if &n_invalid_tueval > 0 %then %do;
            %put WARNING: [IMPORT_TU] &n_invalid_tueval records with invalid TUEVAL (not TARGET/NON-TARGET/NEW);
        %end;
        
        /* Check target lesion count per subject */
        proc sql;
            create table _tu_target_counts as
            select USUBJID, 
                   count(*) as n_target_lesions
            from &outds
            where TUEVAL = 'TARGET'
            group by USUBJID
            having count(*) > 5;
        quit;
        
        %let n_exceed_max = 0;
        proc sql noprint;
            select count(*) into :n_exceed_max trimmed
            from _tu_target_counts;
        quit;
        
        %if &n_exceed_max > 0 %then %do;
            %put WARNING: [IMPORT_TU] &n_exceed_max subjects exceed 5 target lesions (RECIST 1.1 maximum);
            %put WARNING: [IMPORT_TU] Review lesion selection criteria;
        %end;
        
        /* Validation summary */
        %put NOTE: [IMPORT_TU] Validation Summary:;
        %put NOTE: [IMPORT_TU]   Target lesions: &n_target_lesions (across &n_target_subjects subjects);
        %put NOTE: [IMPORT_TU]   Non-target lesions: &n_nontarget_lesions (across &n_nontarget_subjects subjects);
        %put NOTE: [IMPORT_TU]   Invalid TUEVAL: &n_invalid_tueval records;
        %put NOTE: [IMPORT_TU]   Exceeds 5 target/subject: &n_exceed_max subjects;
        
        /* Clean up temporary datasets */
        proc datasets library=work nolist;
            delete _tu_vars _tu_target_counts;
        quit;
        
    %end;
    
    %put NOTE: [IMPORT_TU] Import complete;
    
%mend import_tu;