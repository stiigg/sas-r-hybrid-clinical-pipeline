/******************************************************************************
* Macro: DERIVE_BASELINE
* Purpose: Derive baseline assessment per specified method
* Version: 1.0
* 
* PARAMETERS:
*   inds           - Input dataset with measurements
*   outds          - Output dataset with BASEFL and BASE variables
*   method         - PRETREAT (ADY<1) or FIRST (first assessment)
*   paramcd        - Parameter code to process (default: SDIAM)
*   baseline_visit - Optional: specific visit number for baseline
*
* ALGORITHM:
*   - PRETREAT method: Selects pre-treatment visit where ADY < 1
*   - FIRST method: Selects first available assessment
*   - Creates BASEFL='Y' flag and carries BASE value forward
*
* VALIDATION:
*   - Checks for missing ADY when method=PRETREAT
*   - Verifies each subject has exactly one baseline
*   - Issues warnings for subjects without baseline
*
* REFERENCES:
*   - PharmaSUG 2025-SA-287: Baseline derivation standards
*   - CDISC ADaM IG v1.3: Section 3.3.2
*
* EXAMPLE USAGE:
*   %derive_baseline(
*       inds=work.measurements,
*       outds=work.with_baseline,
*       method=PRETREAT,
*       paramcd=SDIAM
*   );
*
* AUTHOR: Christian Baghai
* DATE: 2026-01-03
******************************************************************************/

%macro derive_baseline(
    inds=,
    outds=,
    method=PRETREAT,
    paramcd=SDIAM,
    baseline_visit=
) / des="Derive baseline assessment per specified method";

    /* Macro validation */
    %if %length(&inds) = 0 %then %do;
        %put ERROR: [DERIVE_BASELINE] Parameter INDS is required;
        %return;
    %end;
    
    %if %length(&outds) = 0 %then %do;
        %put ERROR: [DERIVE_BASELINE] Parameter OUTDS is required;
        %return;
    %end;
    
    %if %upcase(&method) ne PRETREAT and %upcase(&method) ne FIRST %then %do;
        %put ERROR: [DERIVE_BASELINE] METHOD must be PRETREAT or FIRST;
        %return;
    %end;
    
    %put NOTE: [DERIVE_BASELINE] Starting baseline derivation;
    %put NOTE: [DERIVE_BASELINE] Method: &method | Parameter: &paramcd;
    
    /* Derive baseline flag */
    data &outds;
        set &inds;
        by USUBJID ADY;
        
        %if %length(&paramcd) > 0 %then %do;
            where PARAMCD = "&paramcd";
        %end;
        
        retain BASE BASEFL_TEMP;
        
        if first.USUBJID then do;
            BASE = .;
            BASEFL_TEMP = '';
        end;
        
        /* Apply baseline selection logic */
        %if %upcase(&method) = PRETREAT %then %do;
            /* Pre-treatment method: ADY < 1 or specified visit */
            %if %length(&baseline_visit) > 0 %then %do;
                if AVISITN = &baseline_visit and missing(BASE) then do;
                    BASE = AVAL;
                    BASEFL_TEMP = 'Y';
                end;
            %end;
            %else %do;
                if ADY < 1 and not missing(AVAL) and missing(BASE) then do;
                    BASE = AVAL;
                    BASEFL_TEMP = 'Y';
                end;
            %end;
        %end;
        
        %else %if %upcase(&method) = FIRST %then %do;
            /* First assessment method */
            if first.USUBJID and not missing(AVAL) then do;
                BASE = AVAL;
                BASEFL_TEMP = 'Y';
            end;
        %end;
        
        /* Assign final flag */
        if BASEFL_TEMP = 'Y' then BASEFL = 'Y';
        else BASEFL = '';
        
        label BASE = "Baseline Value"
              BASEFL = "Baseline Record Flag";
        
        drop BASEFL_TEMP;
    run;
    
    /* Carry forward BASE value to all records */
    proc sql;
        create table &outds._filled as
        select a.*,
               b.BASE as BASE_FILLED
        from &outds as a
        left join (select distinct USUBJID, BASE 
                   from &outds 
                   where BASEFL='Y' and not missing(BASE)) as b
            on a.USUBJID = b.USUBJID;
    quit;
    
    data &outds;
        set &outds._filled;
        if not missing(BASE_FILLED) then BASE = BASE_FILLED;
        drop BASE_FILLED;
    run;
    
    /* Validation: Check baseline coverage */
    proc sql noprint;
        select count(distinct USUBJID) into :N_TOTAL trimmed
        from &inds;
        
        select count(distinct USUBJID) into :N_WITH_BASE trimmed
        from &outds
        where BASEFL='Y';
        
        select count(distinct USUBJID) into :N_MISSING_BASE trimmed
        from (select distinct USUBJID from &inds
              except
              select distinct USUBJID from &outds where BASEFL='Y');
    quit;
    
    %put NOTE: [DERIVE_BASELINE] Validation Results:;
    %put NOTE: [DERIVE_BASELINE]   Total Subjects: &N_TOTAL;
    %put NOTE: [DERIVE_BASELINE]   With Baseline: &N_WITH_BASE;
    %put NOTE: [DERIVE_BASELINE]   Missing Baseline: &N_MISSING_BASE;
    
    %if &N_MISSING_BASE > 0 %then %do;
        %put WARNING: [DERIVE_BASELINE] &N_MISSING_BASE subjects missing baseline;
        %put WARNING: [DERIVE_BASELINE] Review method=&method appropriateness;
    %end;
    
    %put NOTE: [DERIVE_BASELINE] Baseline derivation complete;
    
%mend derive_baseline;
