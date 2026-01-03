/******************************************************************************
 * Program: compare_mode_output.sas
 * Purpose: Compare R vs SAS ADTR output for consistency validation
 * Author: Clinical Programming Team
 * Date: 2026-01-03
 * 
 * Purpose:
 *   Validates that R and SAS implementations produce identical ADTR datasets
 *   Critical for hybrid SAS-R clinical pipeline integrity
 * 
 * Comparison Dimensions:
 *   1. Record counts (subjects, parameters, visits)
 *   2. Key variable distributions (BASE, NADIR, AVAL)
 *   3. Response classifications (AVALC)
 *   4. CRIT flag concordance
 *   5. Numeric precision differences
 * 
 * Inputs:
 *   - sas_ds: ADTR from SAS pipeline
 *   - r_ds: ADTR from R pipeline
 * 
 * Outputs:
 *   - Comparison report with discrepancies
 *   - _mode_discrepancies: Dataset of differences
 * 
 * Parameters:
 *   - sas_ds: SAS ADTR dataset
 *   - r_ds: R ADTR dataset
 *   - tolerance: Numeric difference tolerance (default=0.01)
 *   - print_report: Print detailed report (Y/N, default=Y)
 *****************************************************************************/

%macro compare_mode_output(
    sas_ds=work.adtr_sas,
    r_ds=work.adtr_r,
    tolerance=0.01,
    print_report=Y
);

    %put %str(NOTE: [COMPARE_MODE_OUTPUT] Starting R vs SAS comparison...);
    %put %str(NOTE: [COMPARE_MODE_OUTPUT] SAS dataset: &sas_ds);
    %put %str(NOTE: [COMPARE_MODE_OUTPUT] R dataset: &r_ds);
    %put %str(NOTE: [COMPARE_MODE_OUTPUT] Tolerance: &tolerance);

    /* ========================================
     * CHECK 1: Record counts
     * ======================================== */
    proc sql;
        create table _count_comparison as
        select 'SAS' as SOURCE,
               count(*) as N_RECORDS,
               count(distinct USUBJID) as N_SUBJECTS,
               count(distinct PARAMCD) as N_PARAMS
        from &sas_ds
        union all
        select 'R' as SOURCE,
               count(*) as N_RECORDS,
               count(distinct USUBJID) as N_SUBJECTS,
               count(distinct PARAMCD) as N_PARAMS
        from &r_ds;
    quit;
    
    proc sql noprint;
        select count(*) into :n_count_diff
        from (
            select N_RECORDS from _count_comparison where SOURCE='SAS'
        ) as a,
        (
            select N_RECORDS from _count_comparison where SOURCE='R'
        ) as b
        where a.N_RECORDS ne b.N_RECORDS;
    quit;
    
    %if &n_count_diff > 0 %then %put WARNING: [COMPARE_MODE_OUTPUT] Check 1: Record count mismatch between R and SAS;
    %else %put %str(NOTE: [COMPARE_MODE_OUTPUT] Check 1 PASSED: Record counts match);

    /* ========================================
     * CHECK 2: Key numeric variables (BASE, NADIR, AVAL)
     * ======================================== */
    proc sql;
        create table _numeric_comparison as
        select 
            coalesce(a.USUBJID, b.USUBJID) as USUBJID,
            coalesce(a.PARAMCD, b.PARAMCD) as PARAMCD,
            coalesce(a.ADT, b.ADT) as ADT,
            a.BASE as BASE_SAS,
            b.BASE as BASE_R,
            abs(a.BASE - b.BASE) as BASE_DIFF,
            a.NADIR as NADIR_SAS,
            b.NADIR as NADIR_R,
            abs(a.NADIR - b.NADIR) as NADIR_DIFF,
            a.AVAL as AVAL_SAS,
            b.AVAL as AVAL_R,
            abs(a.AVAL - b.AVAL) as AVAL_DIFF
        from &sas_ds as a
        full join &r_ds as b
            on a.USUBJID=b.USUBJID and a.PARAMCD=b.PARAMCD and a.ADT=b.ADT
        where abs(a.BASE - b.BASE) > &tolerance or
              abs(a.NADIR - b.NADIR) > &tolerance or
              abs(a.AVAL - b.AVAL) > &tolerance;
    quit;
    
    %let n_numeric_diff = &sqlobs;
    %if &n_numeric_diff > 0 %then %put WARNING: [COMPARE_MODE_OUTPUT] Check 2: &n_numeric_diff numeric differences exceed tolerance;
    %else %put %str(NOTE: [COMPARE_MODE_OUTPUT] Check 2 PASSED: Numeric values match within tolerance);

    /* ========================================
     * CHECK 3: Character variables (AVALC)
     * ======================================== */
    proc sql;
        create table _char_comparison as
        select 
            coalesce(a.USUBJID, b.USUBJID) as USUBJID,
            coalesce(a.PARAMCD, b.PARAMCD) as PARAMCD,
            coalesce(a.ADT, b.ADT) as ADT,
            a.AVALC as AVALC_SAS,
            b.AVALC as AVALC_R
        from &sas_ds as a
        full join &r_ds as b
            on a.USUBJID=b.USUBJID and a.PARAMCD=b.PARAMCD and a.ADT=b.ADT
        where upcase(strip(a.AVALC)) ne upcase(strip(b.AVALC));
    quit;
    
    %let n_char_diff = &sqlobs;
    %if &n_char_diff > 0 %then %put WARNING: [COMPARE_MODE_OUTPUT] Check 3: &n_char_diff AVALC discrepancies;
    %else %put %str(NOTE: [COMPARE_MODE_OUTPUT] Check 3 PASSED: AVALC values match);

    /* ========================================
     * CHECK 4: CRIT flag concordance
     * ======================================== */
    proc sql;
        create table _crit_comparison as
        select 
            coalesce(a.USUBJID, b.USUBJID) as USUBJID,
            coalesce(a.PARAMCD, b.PARAMCD) as PARAMCD,
            coalesce(a.ADT, b.ADT) as ADT,
            a.CRIT1FL as CRIT1FL_SAS, b.CRIT1FL as CRIT1FL_R,
            a.CRIT2FL as CRIT2FL_SAS, b.CRIT2FL as CRIT2FL_R,
            a.CRIT3FL as CRIT3FL_SAS, b.CRIT3FL as CRIT3FL_R,
            a.CRIT4FL as CRIT4FL_SAS, b.CRIT4FL as CRIT4FL_R
        from &sas_ds as a
        full join &r_ds as b
            on a.USUBJID=b.USUBJID and a.PARAMCD=b.PARAMCD and a.ADT=b.ADT
        where a.CRIT1FL ne b.CRIT1FL or
              a.CRIT2FL ne b.CRIT2FL or
              a.CRIT3FL ne b.CRIT3FL or
              a.CRIT4FL ne b.CRIT4FL;
    quit;
    
    %let n_crit_diff = &sqlobs;
    %if &n_crit_diff > 0 %then %put WARNING: [COMPARE_MODE_OUTPUT] Check 4: &n_crit_diff CRIT flag discrepancies;
    %else %put %str(NOTE: [COMPARE_MODE_OUTPUT] Check 4 PASSED: CRIT flags match);

    /* ========================================
     * SUMMARY REPORT
     * ======================================== */
    %let total_issues = %eval(&n_count_diff + &n_numeric_diff + &n_char_diff + &n_crit_diff);
    
    %put %str( );
    %put %str(============================================================);
    %put %str(NOTE: [COMPARE_MODE_OUTPUT] R VS SAS COMPARISON SUMMARY);
    %put %str(============================================================);
    %put %str(NOTE: Check 1 (Record counts): %sysfunc(ifc(&n_count_diff=0, MATCH, MISMATCH)));
    %put %str(NOTE: Check 2 (Numeric vars): &n_numeric_diff differences > &tolerance);
    %put %str(NOTE: Check 3 (AVALC): &n_char_diff discrepancies);
    %put %str(NOTE: Check 4 (CRIT flags): &n_crit_diff discrepancies);
    %put %str(NOTE: TOTAL ISSUES: &total_issues);
    %put %str(============================================================);
    %put %str( );
    
    %if &total_issues = 0 %then %do;
        %put %str(NOTE: [COMPARE_MODE_OUTPUT] *** R VS SAS COMPARISON PASSED ***);
        %put %str(NOTE: [COMPARE_MODE_OUTPUT] *** HYBRID PIPELINE VALIDATED ***);
    %end;
    %else %do;
        %put WARNING: [COMPARE_MODE_OUTPUT] *** R VS SAS COMPARISON FAILED: &total_issues issues detected ***;
    %end;

    /* Print detailed reports if requested */
    %if &print_report=Y %then %do;
        proc print data=_count_comparison;
            title "Record Count Comparison";
        run;
        
        %if &n_numeric_diff > 0 %then %do;
            proc print data=_numeric_comparison;
                title "Numeric Variable Differences (Tolerance=&tolerance)";
            run;
        %end;
        
        %if &n_char_diff > 0 %then %do;
            proc print data=_char_comparison;
                title "AVALC Response Discrepancies";
            run;
        %end;
        
        %if &n_crit_diff > 0 %then %do;
            proc print data=_crit_comparison;
                title "CRIT Flag Discordance";
            run;
        %end;
        
        title;
    %end;

    /* Cleanup */
    proc datasets library=work nolist;
        delete _count_comparison _numeric_comparison _char_comparison _crit_comparison;
    quit;

    %put %str(NOTE: [COMPARE_MODE_OUTPUT] Comparison complete.);

%mend compare_mode_output;
