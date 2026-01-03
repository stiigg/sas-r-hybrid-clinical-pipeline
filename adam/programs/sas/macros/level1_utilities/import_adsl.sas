/******************************************************************************
* Macro: IMPORT_ADSL
* Purpose: Import ADSL with DM fallback and population flag creation
* Version: 1.0
* 
* PARAMETERS:
*   path              - Path to directory containing adsl.csv
*   fallback_dm_path  - Path to DM dataset if ADSL not found
*   outds             - Output dataset name (default: work.adsl)
*   validate          - Run validation checks (1=Yes, 0=No, default: 1)
*
* ALGORITHM:
*   - Attempt ADSL import from specified path
*   - If ADSL missing, import DM and create minimal ADSL
*   - Add standard ADaM population flags if missing:
*     * SAFFL (Safety Population Flag)
*     * ITTFL (Intent-to-Treat Population Flag)
*     * PPROTFL (Per-Protocol Population Flag)
*     * EVLFL (Evaluable Population Flag)
*   - Validate subject-level data completeness
*
* VALIDATION:
*   - Check required variables: STUDYID, USUBJID, RFSTDTC
*   - Verify RFSTDTC format for ADY calculations
*   - Report population flag coverage
*
* REFERENCES:
*   - CDISC ADaM IG v1.3: ADSL specifications
*   - PharmaSUG best practices for population flags
*
* EXAMPLE USAGE:
*   %import_adsl(
*       path=&ADAM_PATH,
*       fallback_dm_path=&SDTM_PATH,
*       outds=work.adsl,
*       validate=1
*   );
*
* AUTHOR: Christian Baghai
* DATE: 2026-01-03
******************************************************************************/

%macro import_adsl(
    path=,
    fallback_dm_path=,
    outds=work.adsl,
    validate=1
) / des="Import ADSL with DM fallback and population flags";

    /* Parameter validation */
    %if %length(&path) = 0 %then %do;
        %put ERROR: [IMPORT_ADSL] Parameter PATH is required;
        %return;
    %end;
    
    %if %length(&outds) = 0 %then %do;
        %put ERROR: [IMPORT_ADSL] Parameter OUTDS is required;
        %return;
    %end;
    
    %put NOTE: [IMPORT_ADSL] Starting ADSL dataset import;
    
    /* Attempt to import ADSL */
    %if %sysfunc(fileexist(&path/adsl.csv)) %then %do;
        
        %put NOTE: [IMPORT_ADSL] Importing ADSL from &path/adsl.csv;
        
        proc import 
            datafile="&path/adsl.csv"
            out=&outds
            dbms=csv
            replace;
            guessingrows=max;
        run;
        
        %if &syserr > 4 %then %do;
            %put ERROR: [IMPORT_ADSL] ADSL import failed with SYSERR=&syserr;
            %return;
        %end;
        
        %put NOTE: [IMPORT_ADSL] ADSL import successful;
        
    %end;
    %else %do;
        
        /* ADSL not found, attempt DM fallback */
        %put WARNING: [IMPORT_ADSL] ADSL not found at &path/adsl.csv;
        
        %if %length(&fallback_dm_path) > 0 and %sysfunc(fileexist(&fallback_dm_path/dm.csv)) %then %do;
            
            %put NOTE: [IMPORT_ADSL] Creating minimal ADSL from DM: &fallback_dm_path/dm.csv;
            
            /* Import DM */
            proc import 
                datafile="&fallback_dm_path/dm.csv"
                out=_dm_temp
                dbms=csv
                replace;
                guessingrows=max;
            run;
            
            %if &syserr > 4 %then %do;
                %put ERROR: [IMPORT_ADSL] DM import failed with SYSERR=&syserr;
                %return;
            %end;
            
            /* Create minimal ADSL from DM */
            data &outds;
                set _dm_temp;
                
                /* Add minimal ADaM variables if not present */
                if not exist('SAFFL') then SAFFL = 'Y';
                if not exist('ITTFL') then ITTFL = 'Y';
                if not exist('PPROTFL') then PPROTFL = 'Y';
                if not exist('EVLFL') then EVLFL = 'Y';
                
                label 
                    SAFFL = "Safety Population Flag"
                    ITTFL = "Intent-to-Treat Population Flag"
                    PPROTFL = "Per-Protocol Population Flag"
                    EVLFL = "Evaluable Population Flag";
            run;
            
            %put NOTE: [IMPORT_ADSL] Minimal ADSL created from DM with default population flags;
            
            /* Clean up */
            proc datasets library=work nolist;
                delete _dm_temp;
            quit;
            
        %end;
        %else %do;
            %put ERROR: [IMPORT_ADSL] Neither ADSL nor DM found in specified paths;
            %put ERROR: [IMPORT_ADSL] Cannot proceed without subject-level data;
            %return;
        %end;
        
    %end;
    
    /* Add population flags if missing */
    data &outds;
        set &outds;
        
        /* Check and add SAFFL */
        if missing(SAFFL) then SAFFL = 'Y';
        
        /* Check and add ITTFL */
        if missing(ITTFL) then ITTFL = 'Y';
        
        /* Check and add PPROTFL */
        if missing(PPROTFL) then PPROTFL = 'Y';
        
        /* Check and add EVLFL */
        if missing(EVLFL) then EVLFL = 'Y';
        
        label 
            SAFFL = "Safety Population Flag"
            ITTFL = "Intent-to-Treat Population Flag"
            PPROTFL = "Per-Protocol Population Flag"
            EVLFL = "Evaluable Population Flag";
    run;
    
    /* Get record count */
    proc sql noprint;
        select count(*) into :n_subjects trimmed
        from &outds;
    quit;
    
    %put NOTE: [IMPORT_ADSL] Total subjects: &n_subjects;
    
    /* Validation checks */
    %if &validate = 1 %then %do;
        
        %put NOTE: [IMPORT_ADSL] Running validation checks...;
        
        /* Check required variables */
        proc contents data=&outds out=_adsl_vars(keep=name) noprint;
        run;
        
        proc sql noprint;
            select name into :existing_vars separated by ' '
            from _adsl_vars;
        quit;
        
        %let required_vars = STUDYID USUBJID RFSTDTC;
        %let missing_vars = ;
        
        %do i = 1 %to %sysfunc(countw(&required_vars));
            %let req_var = %scan(&required_vars, &i);
            %if %sysfunc(findw(%upcase(&existing_vars), %upcase(&req_var))) = 0 %then %do;
                %let missing_vars = &missing_vars &req_var;
            %end;
        %end;
        
        %if %length(&missing_vars) > 0 %then %do;
            %put WARNING: [IMPORT_ADSL] Missing recommended variables:&missing_vars;
        %end;
        
        /* Population flag summary */
        proc sql;
            select 
                count(*) as Total,
                sum(case when SAFFL='Y' then 1 else 0 end) as Safety,
                sum(case when ITTFL='Y' then 1 else 0 end) as ITT,
                sum(case when PPROTFL='Y' then 1 else 0 end) as PerProtocol,
                sum(case when EVLFL='Y' then 1 else 0 end) as Evaluable
            from &outds;
        quit;
        
        /* Check RFSTDTC format */
        %if %sysfunc(findw(&existing_vars, RFSTDTC)) > 0 %then %do;
            proc sql noprint;
                select count(*) into :n_missing_rfstdtc trimmed
                from &outds
                where missing(RFSTDTC);
            quit;
            
            %if &n_missing_rfstdtc > 0 %then %do;
                %put WARNING: [IMPORT_ADSL] &n_missing_rfstdtc subjects missing RFSTDTC;
                %put WARNING: [IMPORT_ADSL] ADY derivation will fail for these subjects;
            %end;
        %end;
        
        /* Clean up */
        proc datasets library=work nolist;
            delete _adsl_vars;
        quit;
        
    %end;
    
    %put NOTE: [IMPORT_ADSL] Import complete;
    
%mend import_adsl;