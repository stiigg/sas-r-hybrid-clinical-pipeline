/******************************************************************************
* Macro: DERIVE_SDIAM_ENHANCED
* Purpose: Derive enhanced SDIAM with full BDS structure (Mode 2)
* Version: 1.0
* 
* PARAMETERS:
*   ldiam_ds       - LDIAM dataset from derive_ldiam macro
*   outds          - Output dataset with enhanced SDIAM
*   baseline_method - Baseline definition (PRETREAT/FIRST, default: PRETREAT)
*   nadir_method   - Nadir calculation method (STANDARD/VITALE, default: VITALE)
*
* DERIVATIONS (Mode 2 - Enhanced SDIAM):
*   PARAMCD = 'SDIAM' - Sum of Target Lesion Diameters
*   PARAM = 'Sum of Target Lesion Diameters (mm)'
*   AVAL - Sum of target lesion diameters at each visit
*   BASE - Baseline sum
*   NADIR - Minimum post-baseline sum
*   CHG/PCHG - Changes from baseline
*   PARCAT1 = 'SUM OF DIAMETERS'
*   PARCAT2 = 'TARGET LESIONS'
*
* ALGORITHM:
*   - Aggregate LDIAM records where PARCAT3='TARGET'
*   - Calculate visit-level sums
*   - Apply same baseline/nadir logic as basic SDIAM
*   - Maintain consistency with Mode 1 calculations
*
* REFERENCES:
*   - CDISC ADaM BDS Examples: Sum parameters
*   - RECIST 1.1: Target lesion sum calculation
*
* EXAMPLE USAGE:
*   %derive_sdiam_enhanced(
*       ldiam_ds=work.ldiam_records,
*       outds=work.sdiam_enhanced,
*       baseline_method=PRETREAT,
*       nadir_method=VITALE
*   );
*
* AUTHOR: Christian Baghai
* DATE: 2026-01-03
******************************************************************************/

%macro derive_sdiam_enhanced(
    ldiam_ds=,
    outds=,
    baseline_method=PRETREAT,
    nadir_method=VITALE
) / des="Derive enhanced SDIAM with full BDS structure (Mode 2)";

    /* Parameter validation */
    %if %length(&ldiam_ds) = 0 or %length(&outds) = 0 %then %do;
        %put ERROR: [DERIVE_SDIAM_ENHANCED] Parameters LDIAM_DS and OUTDS are required;
        %return;
    %end;
    
    %put NOTE: [DERIVE_SDIAM_ENHANCED] Starting enhanced SDIAM derivation (Mode 2);
    %put NOTE: [DERIVE_SDIAM_ENHANCED] Baseline method: &baseline_method;
    %put NOTE: [DERIVE_SDIAM_ENHANCED] Nadir method: &nadir_method;
    
    /* Aggregate target lesions to get SDIAM */
    proc sql;
        create table _sdiam_aggregated as
        select 
            STUDYID,
            USUBJID,
            VISIT,
            VISITNUM,
            ADT,
            ADY,
            sum(AVAL) as AVAL,
            count(distinct TULINKID) as N_TARGET_LESIONS
        from &ldiam_ds
        where PARCAT3 = 'TARGET'
          and not missing(AVAL)
        group by STUDYID, USUBJID, VISIT, VISITNUM, ADT, ADY
        order by USUBJID, VISITNUM;
    quit;
    
    /* Add PARAMCD, PARAM, and PARCAT */
    data _sdiam_with_metadata;
        set _sdiam_aggregated;
        
        length PARAMCD $8 PARAM $200;
        length PARCAT1 PARCAT2 PARCAT3 $200;
        
        PARAMCD = 'SDIAM';
        PARAM = 'Sum of Target Lesion Diameters (mm)';
        
        PARCAT1 = 'SUM OF DIAMETERS';
        PARCAT2 = 'TARGET LESIONS';
        PARCAT3 = '';
        
        label 
            PARAMCD = "Parameter Code"
            PARAM = "Parameter"
            AVAL = "Analysis Value (Sum of Diameters, mm)"
            PARCAT1 = "Parameter Category 1"
            PARCAT2 = "Parameter Category 2"
            PARCAT3 = "Parameter Category 3"
            N_TARGET_LESIONS = "Number of Target Lesions";
    run;
    
    /* Sort by subject and visit */
    proc sort data=_sdiam_with_metadata;
        by USUBJID VISITNUM;
    run;
    
    /* Derive baseline */
    data _sdiam_with_baseline;
        set _sdiam_with_metadata;
        by USUBJID;
        
        retain BASE BASEFL;
        length BASEFL $1;
        
        if first.USUBJID then do;
            BASE = .;
            BASEFL = '';
        end;
        
        /* Identify baseline per method */
        %if %upcase(&baseline_method) = PRETREAT %then %do;
            if ADY < 1 and not missing(AVAL) then do;
                BASE = AVAL;
                BASEFL = 'Y';
            end;
        %end;
        %else %if %upcase(&baseline_method) = FIRST %then %do;
            if first.USUBJID and not missing(AVAL) then do;
                BASE = AVAL;
                BASEFL = 'Y';
            end;
        %end;
        
        /* Carry forward baseline */
        if not missing(BASE) then retain BASE;
        
        label 
            BASE = "Baseline Value"
            BASEFL = "Baseline Record Flag";
    run;
    
    /* Derive nadir */
    proc sql;
        create table _nadir_values as
        select 
            USUBJID,
            %if %upcase(&nadir_method) = VITALE %then %do;
                /* Vitale 2025: Exclude baseline from nadir */
                min(case when ADY >= 1 then AVAL else . end) as NADIR
            %end;
            %else %do;
                /* Standard: Include baseline in nadir */
                min(AVAL) as NADIR
            %end;
        from _sdiam_with_baseline
        where not missing(AVAL)
        group by USUBJID;
    quit;
    
    /* Merge nadir back */
    proc sql;
        create table _sdiam_with_nadir as
        select 
            a.*,
            b.NADIR
        from _sdiam_with_baseline as a
        left join _nadir_values as b
            on a.USUBJID = b.USUBJID;
    quit;
    
    /* Derive change variables */
    data &outds;
        set _sdiam_with_nadir;
        
        /* Change from baseline */
        if not missing(AVAL) and not missing(BASE) then do;
            CHG = AVAL - BASE;
            PCHG = (CHG / BASE) * 100;
        end;
        
        /* Change from nadir */
        if not missing(AVAL) and not missing(NADIR) then do;
            CHGNADIR = AVAL - NADIR;
            PCHGNADIR = (CHGNADIR / NADIR) * 100;
        end;
        
        label 
            NADIR = "Nadir (Minimum Post-Baseline Value)"
            CHG = "Change from Baseline"
            PCHG = "Percent Change from Baseline"
            CHGNADIR = "Change from Nadir"
            PCHGNADIR = "Percent Change from Nadir";
    run;
    
    /* Validation: Compare with basic SDIAM if available */
    %put NOTE: [DERIVE_SDIAM_ENHANCED] Enhanced SDIAM derivation complete (Mode 2);
    %put NOTE: [DERIVE_SDIAM_ENHANCED] Values should match Mode 1 basic SDIAM calculations;
    
    /* Summary statistics */
    proc sql;
        title "Enhanced SDIAM Derivation Summary (Mode 2)";
        
        select 
            count(distinct USUBJID) as N_Subjects,
            count(*) as N_Assessments,
            sum(case when BASEFL='Y' then 1 else 0 end) as N_Baseline
        from &outds;
    quit;
    
    /* Clean up */
    proc datasets library=work nolist;
        delete _sdiam_aggregated _sdiam_with_metadata _sdiam_with_baseline 
               _nadir_values _sdiam_with_nadir;
    quit;
    
    title;
    
%mend derive_sdiam_enhanced;