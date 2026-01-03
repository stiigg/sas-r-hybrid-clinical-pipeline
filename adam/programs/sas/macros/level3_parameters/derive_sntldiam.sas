/******************************************************************************
* Macro: DERIVE_SNTLDIAM
* Purpose: Derive sum of non-target lesion diameters parameter (Mode 2)
* Version: 1.0
* 
* PARAMETERS:
*   ldiam_ds       - LDIAM dataset from derive_ldiam macro
*   outds          - Output dataset with SNTLDIAM parameter
*   baseline_method - Baseline definition (PRETREAT/FIRST, default: PRETREAT)
*   nadir_method   - Nadir calculation method (STANDARD/VITALE, default: VITALE)
*
* DERIVATIONS (Mode 2 - Non-Target Lesion Sum):
*   PARAMCD = 'SNTLDIAM' - Sum of Non-Target Lesion Diameters
*   PARAM = 'Sum of Non-Target Lesion Diameters (mm)'
*   AVAL - Sum of non-target lesion diameters at each visit
*   AVALC - Character response:
*     * 'PRESENT' - Non-target lesions present
*     * 'ABSENT' - Non-target lesions absent/disappeared
*     * 'UNEQUIVOCAL PROGRESSION' - Clear progression
*   PARCAT1 = 'SUM OF DIAMETERS'
*   PARCAT2 = 'NON-TARGET LESIONS'
*
* ALGORITHM:
*   - Aggregate LDIAM records where PARCAT3='NON-TARGET'
*   - Calculate visit-level sums
*   - Derive present/absent status
*   - Apply baseline/nadir calculations
*
* REFERENCES:
*   - RECIST 1.1: Non-target lesion assessment
*   - CDISC ADaM BDS: Character response variables
*
* EXAMPLE USAGE:
*   %derive_sntldiam(
*       ldiam_ds=work.ldiam_records,
*       outds=work.sntldiam_records,
*       baseline_method=PRETREAT,
*       nadir_method=VITALE
*   );
*
* AUTHOR: Christian Baghai
* DATE: 2026-01-03
******************************************************************************/

%macro derive_sntldiam(
    ldiam_ds=,
    outds=,
    baseline_method=PRETREAT,
    nadir_method=VITALE
) / des="Derive sum of non-target lesion diameters (Mode 2)";

    /* Parameter validation */
    %if %length(&ldiam_ds) = 0 or %length(&outds) = 0 %then %do;
        %put ERROR: [DERIVE_SNTLDIAM] Parameters LDIAM_DS and OUTDS are required;
        %return;
    %end;
    
    %put NOTE: [DERIVE_SNTLDIAM] Starting SNTLDIAM derivation (Mode 2);
    %put NOTE: [DERIVE_SNTLDIAM] Baseline method: &baseline_method;
    %put NOTE: [DERIVE_SNTLDIAM] Nadir method: &nadir_method;
    
    /* Aggregate non-target lesions */
    proc sql;
        create table _sntldiam_aggregated as
        select 
            STUDYID,
            USUBJID,
            VISIT,
            VISITNUM,
            ADT,
            ADY,
            sum(AVAL) as AVAL,
            count(distinct TULINKID) as N_NONTARGET_LESIONS
        from &ldiam_ds
        where PARCAT3 = 'NON-TARGET'
          and not missing(AVAL)
        group by STUDYID, USUBJID, VISIT, VISITNUM, ADT, ADY
        order by USUBJID, VISITNUM;
    quit;
    
    /* Add PARAMCD, PARAM, PARCAT, and AVALC */
    data _sntldiam_with_metadata;
        set _sntldiam_aggregated;
        
        length PARAMCD $8 PARAM $200 AVALC $40;
        length PARCAT1 PARCAT2 PARCAT3 $200;
        
        PARAMCD = 'SNTLDIAM';
        PARAM = 'Sum of Non-Target Lesion Diameters (mm)';
        
        PARCAT1 = 'SUM OF DIAMETERS';
        PARCAT2 = 'NON-TARGET LESIONS';
        PARCAT3 = '';
        
        /* Derive character response per RECIST 1.1 */
        if AVAL = 0 then AVALC = 'ABSENT';
        else if not missing(AVAL) and AVAL > 0 then AVALC = 'PRESENT';
        else AVALC = '';
        
        label 
            PARAMCD = "Parameter Code"
            PARAM = "Parameter"
            AVAL = "Analysis Value (Sum of Non-Target Diameters, mm)"
            AVALC = "Analysis Value Character (PRESENT/ABSENT/UNEQUIVOCAL PROGRESSION)"
            PARCAT1 = "Parameter Category 1"
            PARCAT2 = "Parameter Category 2"
            PARCAT3 = "Parameter Category 3"
            N_NONTARGET_LESIONS = "Number of Non-Target Lesions";
    run;
    
    /* Sort by subject and visit */
    proc sort data=_sntldiam_with_metadata;
        by USUBJID VISITNUM;
    run;
    
    /* Derive baseline */
    data _sntldiam_with_baseline;
        set _sntldiam_with_metadata;
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
        from _sntldiam_with_baseline
        where not missing(AVAL)
        group by USUBJID;
    quit;
    
    /* Merge nadir back */
    proc sql;
        create table _sntldiam_with_nadir as
        select 
            a.*,
            b.NADIR
        from _sntldiam_with_baseline as a
        left join _nadir_values as b
            on a.USUBJID = b.USUBJID;
    quit;
    
    /* Derive change variables */
    data &outds;
        set _sntldiam_with_nadir;
        
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
        title "SNTLDIAM Derivation Summary (Mode 2)";
        
        select 
            count(distinct USUBJID) as N_Subjects,
            count(*) as N_Assessments,
            sum(case when BASEFL='Y' then 1 else 0 end) as N_Baseline
        from &outds;
        
        title2 "Non-Target Lesion Status Distribution";
        select 
            AVALC as Status,
            count(*) as N_Assessments,
            count(distinct USUBJID) as N_Subjects
        from &outds
        where not missing(AVALC)
        group by AVALC;
    quit;
    
    %put NOTE: [DERIVE_SNTLDIAM] SNTLDIAM derivation complete (Mode 2);
    
    /* Clean up */
    proc datasets library=work nolist;
        delete _sntldiam_aggregated _sntldiam_with_metadata _sntldiam_with_baseline 
               _nadir_values _sntldiam_with_nadir;
    quit;
    
    title;
    
%mend derive_sntldiam;