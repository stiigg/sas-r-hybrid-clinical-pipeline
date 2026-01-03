/******************************************************************************
 * Program: validate_baseline.sas
 * Purpose: Validate baseline derivation per CDISC ADaM standards
 * Author: Clinical Programming Team
 * Date: 2026-01-03
 * 
 * Validation Checks:
 *   1. BASE exists for all subjects with baseline assessments
 *   2. BASE = last non-missing AVAL where ADY < 1
 *   3. No duplicate baseline records per subject-parameter
 *   4. Baseline timing: within screening/pre-treatment window
 *   5. BASE non-missing for all post-baseline records
 * 
 * Inputs:
 *   - adtr_ds: ADTR dataset with BASE, AVAL, ADY
 * 
 * Outputs:
 *   - Validation report with issues flagged
 *   - _baseline_issues: Dataset of validation failures
 * 
 * Parameters:
 *   - adtr_ds: ADTR dataset to validate
 *   - print_issues: Print detailed issues (Y/N, default=Y)
 *****************************************************************************/

%macro validate_baseline(
    adtr_ds=work.adtr,
    print_issues=Y
);

    %put %str(NOTE: [VALIDATE_BASELINE] Starting baseline validation...);
    %put %str(NOTE: [VALIDATE_BASELINE] Dataset: &adtr_ds);

    /* Initialize issue tracking */
    data _baseline_issues;
        length USUBJID $20 PARAMCD $8 ADT 8 ADY 8 AVAL 8 BASE 8 ISSUE $200;
        stop;
    run;

    /* ========================================
     * CHECK 1: Missing BASE for baseline records
     * ======================================== */
    proc sql;
        insert into _baseline_issues
        select USUBJID, PARAMCD, ADT, ADY, AVAL, BASE,
               'Missing BASE despite baseline assessment (ADY<1)' as ISSUE
        from &adtr_ds
        where ADY < 1 and not missing(AVAL) and missing(BASE);
    quit;
    
    %let n_check1 = &sqlobs;
    %if &n_check1 > 0 %then %put WARNING: [VALIDATE_BASELINE] Check 1: &n_check1 baseline records missing BASE;
    %else %put %str(NOTE: [VALIDATE_BASELINE] Check 1 PASSED: All baseline records have BASE);

    /* ========================================
     * CHECK 2: BASE not equal to baseline AVAL
     * ======================================== */
    proc sql;
        /* Find last pre-treatment AVAL */
        create table _last_baseline as
        select USUBJID, PARAMCD, 
               max(ADT) as LAST_BL_DT format=date9.,
               ADY
        from &adtr_ds
        where ADY < 1 and not missing(AVAL)
        group by USUBJID, PARAMCD;
        
        /* Compare BASE to last pre-treatment AVAL */
        insert into _baseline_issues
        select a.USUBJID, a.PARAMCD, a.ADT, a.ADY, a.AVAL, a.BASE,
               catx(' ', 'BASE inconsistent: BASE=', put(a.BASE, 8.2), 
                    'but last pre-treatment AVAL=', put(a.AVAL, 8.2)) as ISSUE
        from &adtr_ds as a
        inner join _last_baseline as b
            on a.USUBJID=b.USUBJID and a.PARAMCD=b.PARAMCD and a.ADT=b.LAST_BL_DT
        where not missing(a.BASE) and not missing(a.AVAL)
          and abs(a.BASE - a.AVAL) > 0.001;  /* Allow floating point tolerance */
    quit;
    
    %let n_check2 = &sqlobs;
    %if &n_check2 > 0 %then %put WARNING: [VALIDATE_BASELINE] Check 2: &n_check2 records with BASE inconsistent with last pre-treatment AVAL;
    %else %put %str(NOTE: [VALIDATE_BASELINE] Check 2 PASSED: BASE matches last pre-treatment AVAL);

    /* ========================================
     * CHECK 3: Duplicate baseline per subject-parameter
     * ======================================== */
    proc sql;
        create table _dup_baseline as
        select USUBJID, PARAMCD, 
               count(*) as N_BASELINE,
               'Multiple baseline records per subject-parameter' as ISSUE
        from &adtr_ds
        where ADY < 1 and not missing(AVAL)
        group by USUBJID, PARAMCD
        having count(*) > 1;
    quit;
    
    %let n_check3 = &sqlobs;
    %if &n_check3 > 0 %then %put WARNING: [VALIDATE_BASELINE] Check 3: &n_check3 subject-parameters have duplicate baselines;
    %else %put %str(NOTE: [VALIDATE_BASELINE] Check 3 PASSED: No duplicate baselines);

    /* ========================================
     * CHECK 4: Baseline timing validation
     * ======================================== */
    proc sql;
        insert into _baseline_issues
        select USUBJID, PARAMCD, ADT, ADY, AVAL, BASE,
               catx(' ', 'Baseline timing issue: ADY=', put(ADY, 8.), '(should be <1)') as ISSUE
        from &adtr_ds
        where not missing(BASE) and ADY >= 1;
    quit;
    
    %let n_check4 = &sqlobs;
    %if &n_check4 > 0 %then %put WARNING: [VALIDATE_BASELINE] Check 4: &n_check4 post-baseline records incorrectly have BASE assignment;
    %else %put %str(NOTE: [VALIDATE_BASELINE] Check 4 PASSED: Baseline timing correct);

    /* ========================================
     * CHECK 5: Post-baseline records missing BASE
     * ======================================== */
    proc sql;
        insert into _baseline_issues
        select USUBJID, PARAMCD, ADT, ADY, AVAL, BASE,
               'Post-baseline record missing BASE' as ISSUE
        from &adtr_ds
        where ADY >= 1 and not missing(AVAL) and missing(BASE);
    quit;
    
    %let n_check5 = &sqlobs;
    %if &n_check5 > 0 %then %put WARNING: [VALIDATE_BASELINE] Check 5: &n_check5 post-baseline records missing BASE;
    %else %put %str(NOTE: [VALIDATE_BASELINE] Check 5 PASSED: All post-baseline records have BASE);

    /* ========================================
     * SUMMARY REPORT
     * ======================================== */
    %let total_issues = %eval(&n_check1 + &n_check2 + &n_check3 + &n_check4 + &n_check5);
    
    %put %str( );
    %put %str(============================================================);
    %put %str(NOTE: [VALIDATE_BASELINE] VALIDATION SUMMARY);
    %put %str(============================================================);
    %put %str(NOTE: Check 1 (Missing BASE): &n_check1 issues);
    %put %str(NOTE: Check 2 (BASE inconsistent): &n_check2 issues);
    %put %str(NOTE: Check 3 (Duplicate baseline): &n_check3 issues);
    %put %str(NOTE: Check 4 (Baseline timing): &n_check4 issues);
    %put %str(NOTE: Check 5 (Post-BL missing BASE): &n_check5 issues);
    %put %str(NOTE: TOTAL ISSUES: &total_issues);
    %put %str(============================================================);
    %put %str( );
    
    %if &total_issues = 0 %then %do;
        %put %str(NOTE: [VALIDATE_BASELINE] *** BASELINE VALIDATION PASSED ***);
    %end;
    %else %do;
        %put WARNING: [VALIDATE_BASELINE] *** BASELINE VALIDATION FAILED: &total_issues issues detected ***;
    %end;

    /* Print detailed issues if requested */
    %if &print_issues=Y and &total_issues > 0 %then %do;
        proc print data=_baseline_issues;
            title "Baseline Validation Issues";
        run;
        title;
        
        %if &n_check3 > 0 %then %do;
            proc print data=_dup_baseline;
                title "Duplicate Baseline Records";
            run;
            title;
        %end;
    %end;

    /* Cleanup */
    proc datasets library=work nolist;
        delete _last_baseline _dup_baseline;
    quit;

    %put %str(NOTE: [VALIDATE_BASELINE] Validation complete.);

%mend validate_baseline;
