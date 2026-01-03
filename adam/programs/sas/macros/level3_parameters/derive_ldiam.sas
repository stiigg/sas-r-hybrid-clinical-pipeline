/******************************************************************************
* Macro: DERIVE_LDIAM
* Purpose: Derive individual lesion diameter parameters (Mode 2)
* Version: 1.0
* 
* PARAMETERS:
*   tr_ds          - TR dataset with classified lesions
*   outds          - Output dataset with LDIAM parameters
*   baseline_method - Baseline definition (PRETREAT/FIRST, default: PRETREAT)
*   nadir_method   - Nadir calculation method (STANDARD/VITALE, default: VITALE)
*
* DERIVATIONS (Mode 2 - Individual Lesions):
*   PARAMCD = 'LDIAM' - Longest Diameter of Individual Lesion
*   PARAM = 'Longest Diameter of Lesion [TULINKID] (mm)'
*   AVAL - Lesion diameter at each visit
*   BASE - Baseline diameter per lesion
*   NADIR - Minimum post-baseline diameter per lesion
*   CHG - Change from baseline per lesion
*   PCHG - Percent change from baseline per lesion
*
* STRUCTURE:
*   - One record per subject-lesion-visit combination
*   - PARCAT1 = 'INDIVIDUAL LESION'
*   - PARCAT2 = Organ/location (from TULOCCAT)
*   - PARCAT3 = 'TARGET' or 'NON-TARGET'
*
* REFERENCES:
*   - CDISC ADaM BDS: Individual lesion tracking
*   - PharmaSUG 2025-SD-116: Modular ADaM development
*
* EXAMPLE USAGE:
*   %derive_ldiam(
*       tr_ds=work.tr_classified,
*       outds=work.ldiam_records,
*       baseline_method=PRETREAT,
*       nadir_method=VITALE
*   );
*
* AUTHOR: Christian Baghai
* DATE: 2026-01-03
******************************************************************************/

%macro derive_ldiam(
    tr_ds=,
    outds=,
    baseline_method=PRETREAT,
    nadir_method=VITALE
) / des="Derive individual lesion diameter parameters (Mode 2)";

    /* Parameter validation */
    %if %length(&tr_ds) = 0 or %length(&outds) = 0 %then %do;
        %put ERROR: [DERIVE_LDIAM] Parameters TR_DS and OUTDS are required;
        %return;
    %end;
    
    %put NOTE: [DERIVE_LDIAM] Starting LDIAM derivation (Mode 2 - Individual Lesions);
    %put NOTE: [DERIVE_LDIAM] Baseline method: &baseline_method;
    %put NOTE: [DERIVE_LDIAM] Nadir method: &nadir_method;
    
    /* Extract individual lesion measurements */
    data _ldiam_records;
        set &tr_ds;
        where TRTESTCD = 'LDIAM' and not missing(TULINKID);
        
        /* Create PARAMCD and PARAM */
        length PARAMCD $8 PARAM $200;
        PARAMCD = 'LDIAM';
        PARAM = cats('Longest Diameter of Lesion ', TULINKID, ' (mm)');
        
        /* AVAL from TRSTRESN */
        AVAL = TRSTRESN;
        
        /* PARCAT variables */
        length PARCAT1 PARCAT2 PARCAT3 $200;
        PARCAT1 = 'INDIVIDUAL LESION';
        PARCAT2 = TULOCCAT;
        
        if LESION_CLASS = 'TARGET' then PARCAT3 = 'TARGET';
        else if LESION_CLASS = 'NON-TARGET' then PARCAT3 = 'NON-TARGET';
        else PARCAT3 = '';
        
        label 
            PARAMCD = "Parameter Code"
            PARAM = "Parameter"
            AVAL = "Analysis Value (Lesion Diameter, mm)"
            PARCAT1 = "Parameter Category 1"
            PARCAT2 = "Parameter Category 2 (Organ/Location)"
            PARCAT3 = "Parameter Category 3 (Target/Non-Target)";
    run;
    
    /* Sort by subject, lesion, visit */
    proc sort data=_ldiam_records;
        by USUBJID TULINKID VISITNUM;
    run;
    
    /* Derive baseline per lesion */
    data _ldiam_with_baseline;
        set _ldiam_records;
        by USUBJID TULINKID;
        
        retain BASE BASEFL;
        length BASEFL $1;
        
        if first.TULINKID then do;
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
            if first.TULINKID and not missing(AVAL) then do;
                BASE = AVAL;
                BASEFL = 'Y';
            end;
        %end;
        
        /* Carry forward baseline */
        if not missing(BASE) then retain BASE;
        
        label 
            BASE = "Baseline Value (Lesion Diameter)"
            BASEFL = "Baseline Record Flag";
    run;
    
    /* Derive nadir per lesion */
    proc sql;
        create table _nadir_per_lesion as
        select 
            USUBJID,
            TULINKID,
            %if %upcase(&nadir_method) = VITALE %then %do;
                /* Vitale 2025: Exclude baseline from nadir */
                min(case when ADY >= 1 then AVAL else . end) as NADIR
            %end;
            %else %do;
                /* Standard: Include baseline in nadir */
                min(AVAL) as NADIR
            %end;
        from _ldiam_with_baseline
        where not missing(AVAL)
        group by USUBJID, TULINKID;
    quit;
    
    /* Merge nadir back */
    proc sql;
        create table _ldiam_with_nadir as
        select 
            a.*,
            b.NADIR
        from _ldiam_with_baseline as a
        left join _nadir_per_lesion as b
            on a.USUBJID = b.USUBJID
           and a.TULINKID = b.TULINKID;
    quit;
    
    /* Derive change variables */
    data &outds;
        set _ldiam_with_nadir;
        
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
            NADIR = "Nadir (Minimum Post-Baseline Diameter)"
            CHG = "Change from Baseline"
            PCHG = "Percent Change from Baseline"
            CHGNADIR = "Change from Nadir"
            PCHGNADIR = "Percent Change from Nadir";
    run;
    
    /* Summary statistics */
    proc sql;
        title "LDIAM Parameter Derivation Summary (Mode 2)";
        
        select 
            count(distinct USUBJID) as N_Subjects,
            count(distinct TULINKID) as N_Lesions,
            count(*) as N_Assessments,
            sum(case when BASEFL='Y' then 1 else 0 end) as N_Baseline
        from &outds;
        
        title2 "Lesion Count by Classification";
        select 
            PARCAT3 as Classification,
            count(distinct TULINKID) as N_Lesions,
            count(distinct USUBJID) as N_Subjects
        from &outds
        where BASEFL='Y'
        group by PARCAT3;
        
        title3 "Lesion Count by Organ";
        select 
            PARCAT2 as Organ,
            count(distinct TULINKID) as N_Lesions
        from &outds
        where BASEFL='Y'
        group by PARCAT2
        order by calculated N_Lesions desc;
    quit;
    
    %put NOTE: [DERIVE_LDIAM] LDIAM derivation complete (Mode 2);
    %put NOTE: [DERIVE_LDIAM] Individual lesion tracking enabled;
    
    /* Clean up */
    proc datasets library=work nolist;
        delete _ldiam_records _ldiam_with_baseline _nadir_per_lesion _ldiam_with_nadir;
    quit;
    
    title;
    
%mend derive_ldiam;