/******************************************************************************
 * Program: validate_nadir.sas
 * Purpose: Validate nadir derivation per Vitale 2025 method (PMC12094296)
 * Author: Clinical Programming Team
 * Date: 2026-01-03
 * 
 * Research Citation:
 * - Vitale et al. Cureus 2025: NADIR = minimum on-treatment AVAL (ADY≥1)
 *   https://pmc.ncbi.nlm.nih.gov/articles/PMC12094296/
 * 
 * Validation Checks:
 *   1. NADIR = minimum post-baseline AVAL (ADY ≥ 1)
 *   2. NADIR ≤ AVAL for all post-baseline records
 *   3. NADIR missing only if no post-baseline data
 *   4. NADIR timing: must occur on or after first treatment date
 *   5. NADIR consistency across subject-parameter records
 * 
 * Inputs:
 *   - adtr_ds: ADTR dataset with NADIR, AVAL, ADY
 * 
 * Outputs:
 *   - Validation report with issues flagged
 *   - _nadir_issues: Dataset of validation failures
 *****************************************************************************/

%macro validate_nadir(
    adtr_ds=work.adtr,
    print_issues=Y
);

    %put %str(NOTE: [VALIDATE_NADIR] Starting nadir validation...);
    %put %str(NOTE: [VALIDATE_NADIR] Dataset: &adtr_ds);
    %put %str(NOTE: [VALIDATE_NADIR] Method: Vitale 2025 (PMC12094296));

    /* Initialize issue tracking */
    data _nadir_issues;
        length USUBJID $20 PARAMCD $8 ADT 8 ADY 8 AVAL 8 NADIR 8 ISSUE $200;
        stop;
    run;

    /* ========================================
     * CHECK 1: NADIR not equal to minimum post-baseline AVAL
     * ======================================== */
    proc sql;
        /* Calculate true minimum post-baseline AVAL */
        create table _true_nadir as
        select USUBJID, PARAMCD, 
               min(AVAL) as TRUE_NADIR,
               count(*) as N_POST_BL
        from &adtr_ds
        where ADY >= 1 and not missing(AVAL)
        group by USUBJID, PARAMCD;
        
        /* Compare NADIR to true minimum */
        insert into _nadir_issues
        select a.USUBJID, a.PARAMCD, a.ADT, a.ADY, a.AVAL, a.NADIR,
               catx(' ', 'NADIR inconsistent: NADIR=', put(a.NADIR, 8.2), 
                    'but min post-BL AVAL=', put(b.TRUE_NADIR, 8.2)) as ISSUE
        from &adtr_ds as a
        inner join _true_nadir as b
            on a.USUBJID=b.USUBJID and a.PARAMCD=b.PARAMCD
        where ADY >= 1 and not missing(a.NADIR) and not missing(b.TRUE_NADIR)
          and abs(a.NADIR - b.TRUE_NADIR) > 0.001;  /* Floating point tolerance */
    quit;
    
    %let n_check1 = &sqlobs;
    %if &n_check1 > 0 %then %put WARNING: [VALIDATE_NADIR] Check 1: &n_check1 records with NADIR not equal to minimum post-BL AVAL;
    %else %put %str(NOTE: [VALIDATE_NADIR] Check 1 PASSED: NADIR equals minimum post-baseline AVAL);

    /* ========================================
     * CHECK 2: NADIR > AVAL (impossible condition)
     * ======================================== */
    proc sql;
        insert into _nadir_issues
        select USUBJID, PARAMCD, ADT, ADY, AVAL, NADIR,
               catx(' ', 'NADIR > AVAL: NADIR=', put(NADIR, 8.2), 
                    'but current AVAL=', put(AVAL, 8.2)) as ISSUE
        from &adtr_ds
        where ADY >= 1 and not missing(NADIR) and not missing(AVAL)
          and NADIR > AVAL + 0.001;  /* Tolerance */
    quit;
    
    %let n_check2 = &sqlobs;
    %if &n_check2 > 0 %then %put WARNING: [VALIDATE_NADIR] Check 2: &n_check2 records with NADIR > AVAL;
    %else %put %str(NOTE: [VALIDATE_NADIR] Check 2 PASSED: NADIR always ≤ AVAL);

    /* ========================================
     * CHECK 3: Missing NADIR with post-baseline data
     * ======================================== */
    proc sql;
        insert into _nadir_issues
        select USUBJID, PARAMCD, ADT, ADY, AVAL, NADIR,
               'Missing NADIR despite post-baseline data' as ISSUE
        from &adtr_ds
        where ADY >= 1 and not missing(AVAL) and missing(NADIR);
    quit;
    
    %let n_check3 = &sqlobs;
    %if &n_check3 > 0 %then %put WARNING: [VALIDATE_NADIR] Check 3: &n_check3 post-baseline records missing NADIR;
    %else %put %str(NOTE: [VALIDATE_NADIR] Check 3 PASSED: All post-baseline records have NADIR);

    /* ========================================
     * CHECK 4: NADIR at baseline (ADY < 1)
     * ======================================== */
    proc sql;
        insert into _nadir_issues
        select USUBJID, PARAMCD, ADT, ADY, AVAL, NADIR,
               'NADIR should not exist at baseline (ADY < 1)' as ISSUE
        from &adtr_ds
        where ADY < 1 and not missing(NADIR);
    quit;
    
    %let n_check4 = &sqlobs;
    %if &n_check4 > 0 %then %put WARNING: [VALIDATE_NADIR] Check 4: &n_check4 baseline records incorrectly have NADIR;
    %else %put %str(NOTE: [VALIDATE_NADIR] Check 4 PASSED: NADIR only exists post-baseline);

    /* ========================================
     * CHECK 5: NADIR consistency within subject-parameter
     * ======================================== */
    proc sql;
        create table _nadir_variance as
        select USUBJID, PARAMCD,
               count(distinct NADIR) as N_DISTINCT_NADIR,
               'Inconsistent NADIR values within subject-parameter' as ISSUE
        from &adtr_ds
        where ADY >= 1 and not missing(NADIR)
        group by USUBJID, PARAMCD
        having calculated N_DISTINCT_NADIR > 1;
    quit;
    
    %let n_check5 = &sqlobs;
    %if &n_check5 > 0 %then %put WARNING: [VALIDATE_NADIR] Check 5: &n_check5 subject-parameters have inconsistent NADIR values;
    %else %put %str(NOTE: [VALIDATE_NADIR] Check 5 PASSED: NADIR consistent within subject-parameter);

    /* ========================================
     * SUMMARY REPORT
     * ======================================== */
    %let total_issues = %eval(&n_check1 + &n_check2 + &n_check3 + &n_check4 + &n_check5);
    
    %put %str( );
    %put %str(============================================================);
    %put %str(NOTE: [VALIDATE_NADIR] VALIDATION SUMMARY);
    %put %str(============================================================);
    %put %str(NOTE: Check 1 (NADIR ≠ min AVAL): &n_check1 issues);
    %put %str(NOTE: Check 2 (NADIR > AVAL): &n_check2 issues);
    %put %str(NOTE: Check 3 (Missing NADIR): &n_check3 issues);
    %put %str(NOTE: Check 4 (NADIR at baseline): &n_check4 issues);
    %put %str(NOTE: Check 5 (NADIR inconsistent): &n_check5 issues);
    %put %str(NOTE: TOTAL ISSUES: &total_issues);
    %put %str(============================================================);
    %put %str( );
    
    %if &total_issues = 0 %then %do;
        %put %str(NOTE: [VALIDATE_NADIR] *** NADIR VALIDATION PASSED ***);
    %end;
    %else %do;
        %put WARNING: [VALIDATE_NADIR] *** NADIR VALIDATION FAILED: &total_issues issues detected ***;
    %end;

    /* Print detailed issues if requested */
    %if &print_issues=Y and &total_issues > 0 %then %do;
        proc print data=_nadir_issues;
            title "Nadir Validation Issues";
            title2 "Method: Vitale 2025 (PMC12094296)";
        run;
        title;
        
        %if &n_check5 > 0 %then %do;
            proc print data=_nadir_variance;
                title "Inconsistent NADIR Values";
            run;
            title;
        %end;
    %end;

    /* Cleanup */
    proc datasets library=work nolist;
        delete _true_nadir _nadir_variance;
    quit;

    %put %str(NOTE: [VALIDATE_NADIR] Validation complete.);
    %put %str(NOTE: [VALIDATE_NADIR] Research citation: Vitale 2025, PMC12094296);

%mend validate_nadir;
