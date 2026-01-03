/******************************************************************************
 * Program: add_anl_flags.sas
 * Purpose: Add ANL01FL-04FL analysis subset flags per CDISC standards
 * Author: Clinical Programming Team
 * Date: 2026-01-03
 * 
 * Analysis Flags Logic:
 *   ANL01FL: Safety analysis set records (post-baseline + SAFFL)
 *   ANL02FL: Efficacy evaluable set records (ITT + baseline measurement)
 *   ANL03FL: Per-protocol set records (PPROTFL + baseline + post-baseline)
 *   ANL04FL: Best confirmed response records (minimum AVAL per subject-parameter)
 * 
 * Inputs:
 *   - adtr_in: ADTR dataset
 *   - adsl: ADSL with population flags (SAFFL, ITTFL, PPROTFL)
 * 
 * Outputs:
 *   - adtr_out: ADTR with ANL01FL, ANL02FL, ANL03FL, ANL04FL
 * 
 * Parameters:
 *   - input_ds: Input ADTR dataset
 *   - output_ds: Output ADTR dataset
 *   - adsl_ds: ADSL population dataset
 *****************************************************************************/

%macro add_anl_flags(
    input_ds=work.adtr,
    output_ds=work.adtr,
    adsl_ds=work.adsl
);

    %put %str(NOTE: [ADD_ANL_FLAGS] Adding analysis subset flags...);
    %put %str(NOTE: [ADD_ANL_FLAGS] Input dataset: &input_ds);
    %put %str(NOTE: [ADD_ANL_FLAGS] ADSL dataset: &adsl_ds);

    /* Step 1: Merge population flags from ADSL */
    proc sql;
        create table _anl_prep as
        select 
            a.*,
            b.SAFFL,
            b.ITTFL,
            b.PPROTFL
        from &input_ds as a
        left join &adsl_ds as b
            on a.USUBJID=b.USUBJID;
    quit;

    /* Step 2: Derive ANL flags */
    data _anl_step1;
        set _anl_prep;
        
        length ANL01FL ANL02FL ANL03FL ANL04FL $1;
        
        /* ANL01FL: Safety Analysis Set */
        /* Include if: Subject in safety pop AND has any post-baseline data */
        if SAFFL='Y' and ADY >= 1 then 
            ANL01FL = 'Y';
        else 
            ANL01FL = '';
            
        /* ANL02FL: Efficacy Evaluable Set (ITT with baseline) */
        /* Include if: ITT pop AND has baseline assessment */
        if ITTFL='Y' and not missing(BASE) then 
            ANL02FL = 'Y';
        else 
            ANL02FL = '';
            
        /* ANL03FL: Per-Protocol Set */
        /* Include if: PP pop AND has baseline AND post-baseline */
        if PPROTFL='Y' and not missing(BASE) and ADY >= 1 then 
            ANL03FL = 'Y';
        else 
            ANL03FL = '';
            
        /* ANL04FL: Best Confirmed Response Analysis */
        /* Will be set in post-processing step */
        ANL04FL = '';
            
        /* Add variable labels */
        label
            ANL01FL = 'Analysis Flag 01: Safety Analysis Set'
            ANL02FL = 'Analysis Flag 02: Efficacy Evaluable Set'
            ANL03FL = 'Analysis Flag 03: Per-Protocol Set'
            ANL04FL = 'Analysis Flag 04: Best Confirmed Response';
            
        /* Drop temporary ADSL flags */
        drop SAFFL ITTFL PPROTFL;
    run;

    /* Step 3: Derive ANL04FL - Best confirmed response */
    /* Find minimum AVAL (best response) per subject-parameter */
    proc sort data=_anl_step1;
        by USUBJID PARAMCD ADY;
    run;

    data &output_ds;
        set _anl_step1;
        by USUBJID PARAMCD;
        
        retain _best_aval;
        
        /* Track minimum AVAL within subject-parameter */
        if first.PARAMCD then _best_aval = .;
        
        if ADY >= 1 and not missing(AVAL) then do;
            if missing(_best_aval) or AVAL < _best_aval then 
                _best_aval = AVAL;
        end;
        
        /* Flag the record with best (minimum) AVAL */
        if ADY >= 1 and not missing(AVAL) and AVAL = _best_aval and 
           ANL02FL='Y' then  /* Must be in efficacy set */
            ANL04FL = 'Y';
            
        drop _best_aval;
    run;

    /* Step 4: QC Report - Analysis flag distribution */
    proc freq data=&output_ds;
        tables ANL01FL ANL02FL ANL03FL ANL04FL / missing;
        title "QC: Analysis Flag Distribution";
    run;
    
    /* Step 5: Subject counts by analysis set */
    proc sql;
        create table _anl_summary as
        select 
            PARAMCD,
            count(distinct case when ANL01FL='Y' then USUBJID else . end) as N_SAFETY,
            count(distinct case when ANL02FL='Y' then USUBJID else . end) as N_EFFICACY,
            count(distinct case when ANL03FL='Y' then USUBJID else . end) as N_PP,
            count(distinct case when ANL04FL='Y' then USUBJID else . end) as N_BEST_RESP
        from &output_ds
        group by PARAMCD;
    quit;
    
    proc print data=_anl_summary noobs;
        title "QC: Subject Counts by Analysis Set and Parameter";
    run;
    title;

    /* Step 6: Validation - ANL04FL should be unique per subject-parameter */
    proc sql;
        create table _anl_validation as
        select USUBJID, PARAMCD, 
               count(*) as N_BEST_RESP,
               'Multiple ANL04FL=Y per subject-parameter' as ISSUE
        from &output_ds
        where ANL04FL='Y'
        group by USUBJID, PARAMCD
        having count(*) > 1;
    quit;
    
    %let n_violations=&sqlobs;
    %if &n_violations > 0 %then %do;
        %put WARNING: [ADD_ANL_FLAGS] &n_violations subject-parameters have multiple ANL04FL=Y;
        proc print data=_anl_validation;
            title "WARNING: Multiple Best Response Flags";
        run;
    %end;
    %else %do;
        %put %str(NOTE: [ADD_ANL_FLAGS] ANL04FL validation PASSED);
    %end;
    title;

    /* Cleanup */
    proc datasets library=work nolist;
        delete _anl_prep _anl_step1 _anl_summary _anl_validation;
    quit;

    %put %str(NOTE: [ADD_ANL_FLAGS] Analysis flags complete.);

%mend add_anl_flags;
