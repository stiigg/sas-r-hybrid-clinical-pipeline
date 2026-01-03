/******************************************************************************
* Macro: DERIVE_SDIAM_BASIC
* Purpose: Derive basic SDIAM (Sum of Diameters) parameter for Mode 1
* Version: 1.0
* 
* PARAMETERS:
*   tr_ds          - TR dataset with classified lesions
*   outds          - Output ADTR dataset
*   baseline_method - Baseline definition (PRETREAT/FIRST, default: PRETREAT)
*   nadir_method   - Nadir calculation method (STANDARD/VITALE, default: VITALE)
*
* DERIVATIONS (Mode 1 - Basic Structure):
*   PARAMCD = 'SDIAM' - Sum of Target Lesion Diameters
*   PARAM = 'Sum of Target Lesion Diameters (mm)'
*   AVAL - Analysis value (sum at each visit)
*   BASE - Baseline value per baseline_method
*   BASEFL - Baseline flag
*   NADIR - Minimum post-baseline value per nadir_method
*   CHG - Change from baseline (AVAL - BASE)
*   PCHG - Percent change from baseline ((CHG/BASE)*100)
*
* BASELINE METHODS:
*   PRETREAT: ADY < 1 (all pre-treatment assessments)
*   FIRST: First available assessment
*
* NADIR METHODS:
*   STANDARD: Include baseline in nadir calculation
*   VITALE: Exclude baseline from nadir (post-baseline minimum only)
*
* REFERENCES:
*   - CDISC ADaM IG v1.3: BDS structure
*   - RECIST 1.1: Sum of diameters calculation
*   - Vitale 2025: Baseline censoring methodology
*
* EXAMPLE USAGE:
*   %derive_sdiam_basic(
*       tr_ds=work.tr_classified,
*       outds=work.adtr_mode1,
*       baseline_method=PRETREAT,
*       nadir_method=VITALE
*   );
*
* AUTHOR: Christian Baghai
* DATE: 2026-01-03
******************************************************************************/

%macro derive_sdiam_basic(
    tr_ds=,
    outds=,
    baseline_method=PRETREAT,
    nadir_method=VITALE
) / des="Derive basic SDIAM parameter for Mode 1";

    /* Parameter validation */
    %if %length(&tr_ds) = 0 or %length(&outds) = 0 %then %do;
        %put ERROR: [DERIVE_SDIAM_BASIC] Parameters TR_DS and OUTDS are required;
        %return;
    %end;
    
    %put NOTE: [DERIVE_SDIAM_BASIC] Starting SDIAM derivation (Mode 1 - Basic);
    %put NOTE: [DERIVE_SDIAM_BASIC] Baseline method: &baseline_method;
    %put NOTE: [DERIVE_SDIAM_BASIC] Nadir method: &nadir_method;
    
    /* Calculate sum of target lesion diameters by visit */
    proc sql;
        create table _sdiam_by_visit as
        select 
            STUDYID,
            USUBJID,
            VISIT,
            VISITNUM,
            ADT,
            ADY,
            sum(TRSTRESN) as AVAL,
            count(distinct TULINKID) as N_TARGET_LESIONS
        from &tr_ds
        where LESION_CLASS = 'TARGET'
          and TRTESTCD = 'LDIAM'
          and not missing(TRSTRESN)
        group by STUDYID, USUBJID, VISIT, VISITNUM, ADT, ADY
        order by USUBJID, VISITNUM;
    quit;
    
    /* Add PARAMCD and PARAM */
    data _sdiam_with_param;
        set _sdiam_by_visit;
        
        length PARAMCD $8 PARAM $200;
        PARAMCD = 'SDIAM';
        PARAM = 'Sum of Target Lesion Diameters (mm)';
        
        label 
            PARAMCD = "Parameter Code"
            PARAM = "Parameter"
            AVAL = "Analysis Value"
            N_TARGET_LESIONS = "Number of Target Lesions";
    run;
    
    /* Derive baseline */
    proc sort data=_sdiam_with_param;
        by USUBJID VISITNUM;
    run;
    
    data _sdiam_with_baseline;
        set _sdiam_with_param;
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
    
    /* Summary statistics */
    proc sql;
        title "SDIAM Parameter Derivation Summary (Mode 1)";
        
        select 
            count(distinct USUBJID) as N_Subjects,
            count(*) as N_Assessments,
            sum(case when BASEFL='Y' then 1 else 0 end) as N_Baseline,
            sum(case when ADY >= 1 then 1 else 0 end) as N_PostBaseline
        from &outds;
        
        title2 "Baseline and Nadir Statistics";
        select 
            count(*) as N,
            mean(BASE) as Mean_Baseline format=8.1,
            median(BASE) as Median_Baseline format=8.1,
            min(BASE) as Min_Baseline format=8.1,
            max(BASE) as Max_Baseline format=8.1,
            mean(NADIR) as Mean_Nadir format=8.1,
            median(NADIR) as Median_Nadir format=8.1
        from &outds
        where not missing(BASE);
    quit;
    
    %put NOTE: [DERIVE_SDIAM_BASIC] SDIAM derivation complete (Mode 1);
    
    /* Clean up */
    proc datasets library=work nolist;
        delete _sdiam_by_visit _sdiam_with_param _sdiam_with_baseline 
               _nadir_values _sdiam_with_nadir;
    quit;
    
    title;
    
%mend derive_sdiam_basic;