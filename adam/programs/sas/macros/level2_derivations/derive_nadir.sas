/******************************************************************************
* Macro: DERIVE_NADIR
* Purpose: Derive nadir (minimum post-baseline value) per Vitale et al. 2025
* Version: 1.0
* 
* PARAMETERS:
*   inds              - Input dataset with AVAL and BASE
*   outds             - Output dataset with NADIR variable
*   paramcd           - Parameter code to process
*   exclude_baseline  - Exclude baseline from nadir (1=Yes, 0=No)
*   method            - MINIMUM or MINIMUM_POSTBASE
*
* ALGORITHM:
*   Per Vitale et al. JNCI 2025 censoring transparency:
*   - EXCLUDE_BASELINE=1: Nadir = min(AVAL where ADY > 0)
*   - EXCLUDE_BASELINE=0: Nadir = min(AVAL where ADY >= 0)
*
* REFERENCES:
*   - Vitale et al. JNCI 2025: Censoring transparency in oncology trials
*   - PharmaSUG 2025-SA-287: Efficacy roadmap
*
* AUTHOR: Christian Baghai
* DATE: 2026-01-03
******************************************************************************/

%macro derive_nadir(
    inds=,
    outds=,
    paramcd=,
    exclude_baseline=1,
    method=MINIMUM_POSTBASE
) / des="Derive nadir (minimum post-baseline value)";

    %put NOTE: [DERIVE_NADIR] Starting nadir derivation;
    %put NOTE: [DERIVE_NADIR] Method: &method | Exclude Baseline: &exclude_baseline;
    
    /* Derive nadir value per subject */
    proc sql;
        create table work._nadir_values as
        select USUBJID,
               %if &exclude_baseline = 1 %then %do;
                   min(case when ADY > 0 then AVAL else . end) as NADIR
               %end;
               %else %do;
                   min(case when ADY >= 0 then AVAL else . end) as NADIR
               %end;
        from &inds
        %if %length(&paramcd) > 0 %then %do;
            where PARAMCD = "&paramcd"
        %end;
        group by USUBJID
        having not missing(calculated NADIR);
    quit;
    
    /* Merge nadir back to original data */
    proc sql;
        create table &outds as
        select a.*,
               b.NADIR,
               case when a.AVAL = b.NADIR and a.ADY > 0 then 'Y' 
                    else '' end as NADIRFL length=1
        from &inds as a
        left join work._nadir_values as b
            on a.USUBJID = b.USUBJID
        order by USUBJID, ADY;
    quit;
    
    /* Add labels */
    data &outds;
        set &outds;
        label NADIR = "Nadir Value"
              NADIRFL = "Nadir Record Flag";
    run;
    
    /* Validation */
    proc sql noprint;
        select count(distinct USUBJID) into :n_with_nadir trimmed
        from &outds
        where not missing(NADIR);
        
        select count(distinct USUBJID) into :n_total trimmed
        from &outds;
    quit;
    
    %put NOTE: [DERIVE_NADIR] Validation Results:;
    %put NOTE: [DERIVE_NADIR]   Total Subjects: &n_total;
    %put NOTE: [DERIVE_NADIR]   With Nadir: &n_with_nadir;
    %put NOTE: [DERIVE_NADIR] Nadir derivation complete;
    
    proc datasets library=work nolist;
        delete _nadir_values;
    quit;
    
%mend derive_nadir;
