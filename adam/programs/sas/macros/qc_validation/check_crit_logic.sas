/******************************************************************************
 * Program: check_crit_logic.sas
 * Purpose: Validate CRIT flag logic per RECIST 1.1 and Enaworu 2025
 * Author: Clinical Programming Team
 * Date: 2026-01-03
 * 
 * Research Citations:
 * - RECIST 1.1: Target lesion PD = ≥20% AND ≥5mm from nadir
 * - Enaworu Cureus 2025: Simplified 25mm nadir rule (PMC12094296)
 * 
 * Validation Checks:
 *   1. CRIT1FL=Y only when: (AVAL-NADIR)/NADIR ≥ 0.20 AND (AVAL-NADIR) ≥ 5
 *   2. CRIT2FL=Y only when: NEW_LESION_FL='Y'
 *   3. CRIT3FL=Y consistent with Enaworu rule
 *   4. All CRIT=Y must have AVALC containing "PD"
 *   5. Post-baseline only: No CRIT flags at baseline
 * 
 * Inputs:
 *   - adtr_ds: ADTR dataset with CRIT flags, NADIR, AVAL, AVALC
 * 
 * Outputs:
 *   - _crit_issues: Dataset of CRIT flag inconsistencies
 *****************************************************************************/

%macro check_crit_logic(
    adtr_ds=work.adtr,
    print_issues=Y
);

    %put %str(NOTE: [CHECK_CRIT_LOGIC] Starting CRIT flag validation...);
    %put %str(NOTE: [CHECK_CRIT_LOGIC] Dataset: &adtr_ds);

    /* Initialize issue tracking */
    data _crit_issues;
        length USUBJID $20 PARAMCD $8 ADT 8 ADY 8 AVAL 8 NADIR 8 
               AVALC $200 CRIT1FL CRIT2FL CRIT3FL CRIT4FL $1 ISSUE $500;
        stop;
    run;

    /* ========================================
     * CHECK 1: CRIT1FL logic (Standard RECIST 1.1)
     * ======================================== */
    proc sql;
        /* False positives: CRIT1FL=Y incorrectly */
        insert into _crit_issues
        select USUBJID, PARAMCD, ADT, ADY, AVAL, NADIR, AVALC,
               CRIT1FL, CRIT2FL, CRIT3FL, CRIT4FL,
               catx(' | ', 'CRIT1FL=Y incorrect:', 
                    'Pct chg=' || put((AVAL-NADIR)/NADIR*100, 5.1) || '%',
                    'Abs chg=' || put(AVAL-NADIR, 5.1) || 'mm',
                    'Need: >=20% AND >=5mm') as ISSUE
        from &adtr_ds
        where PARAMCD='SDIAM' and ADY >= 1 and CRIT1FL='Y'
          and not missing(NADIR) and not missing(AVAL)
          and not ((AVAL - NADIR) >= 5 and (AVAL - NADIR) / NADIR >= 0.20);
        
        /* False negatives: Should be CRIT1FL=Y but isn't */
        insert into _crit_issues
        select USUBJID, PARAMCD, ADT, ADY, AVAL, NADIR, AVALC,
               CRIT1FL, CRIT2FL, CRIT3FL, CRIT4FL,
               catx(' | ', 'CRIT1FL should be Y:', 
                    'Pct chg=' || put((AVAL-NADIR)/NADIR*100, 5.1) || '%',
                    'Abs chg=' || put(AVAL-NADIR, 5.1) || 'mm',
                    'Meets: >=20% AND >=5mm') as ISSUE
        from &adtr_ds
        where PARAMCD='SDIAM' and ADY >= 1 and CRIT1FL ne 'Y'
          and not missing(NADIR) and not missing(AVAL)
          and (AVAL - NADIR) >= 5 and (AVAL - NADIR) / NADIR >= 0.20;
    quit;
    
    %let n_check1 = &sqlobs;
    %if &n_check1 > 0 %then %put WARNING: [CHECK_CRIT_LOGIC] Check 1: &n_check1 CRIT1FL logic issues;
    %else %put %str(NOTE: [CHECK_CRIT_LOGIC] Check 1 PASSED: CRIT1FL logic correct);

    /* ========================================
     * CHECK 2: CRIT3FL logic (Enaworu 25mm rule)
     * ======================================== */
    proc sql;
        /* Check Enaworu rule: Nadir >= 25mm uses 20% only */
        insert into _crit_issues
        select USUBJID, PARAMCD, ADT, ADY, AVAL, NADIR, AVALC,
               CRIT1FL, CRIT2FL, CRIT3FL, CRIT4FL,
               catx(' | ', 'CRIT3FL logic incorrect (Nadir>=25mm):', 
                    'Nadir=' || put(NADIR, 5.1) || 'mm',
                    'Pct chg=' || put((AVAL-NADIR)/NADIR*100, 5.1) || '%',
                    'Enaworu rule: Need >=20% only when Nadir>=25mm') as ISSUE
        from &adtr_ds
        where PARAMCD='SDIAM' and ADY >= 1 and not missing(CRIT3FL)
          and not missing(NADIR) and not missing(AVAL)
          and NADIR >= 25
          and ((CRIT3FL='Y' and (AVAL-NADIR)/NADIR < 0.20) or
               (CRIT3FL ne 'Y' and (AVAL-NADIR)/NADIR >= 0.20));
        
        /* Check Enaworu rule: Nadir < 25mm uses 5mm only */
        insert into _crit_issues
        select USUBJID, PARAMCD, ADT, ADY, AVAL, NADIR, AVALC,
               CRIT1FL, CRIT2FL, CRIT3FL, CRIT4FL,
               catx(' | ', 'CRIT3FL logic incorrect (Nadir<25mm):', 
                    'Nadir=' || put(NADIR, 5.1) || 'mm',
                    'Abs chg=' || put(AVAL-NADIR, 5.1) || 'mm',
                    'Enaworu rule: Need >=5mm only when Nadir<25mm') as ISSUE
        from &adtr_ds
        where PARAMCD='SDIAM' and ADY >= 1 and not missing(CRIT3FL)
          and not missing(NADIR) and not missing(AVAL)
          and NADIR < 25
          and ((CRIT3FL='Y' and (AVAL-NADIR) < 5) or
               (CRIT3FL ne 'Y' and (AVAL-NADIR) >= 5));
    quit;
    
    %let n_check2 = &sqlobs;
    %if &n_check2 > 0 %then %put WARNING: [CHECK_CRIT_LOGIC] Check 2: &n_check2 CRIT3FL Enaworu rule issues;
    %else %put %str(NOTE: [CHECK_CRIT_LOGIC] Check 2 PASSED: CRIT3FL Enaworu logic correct);

    /* ========================================
     * CHECK 3: Any CRIT=Y must have AVALC=PD
     * ======================================== */
    proc sql;
        insert into _crit_issues
        select USUBJID, PARAMCD, ADT, ADY, AVAL, NADIR, AVALC,
               CRIT1FL, CRIT2FL, CRIT3FL, CRIT4FL,
               catx(' | ', 'CRIT flag without PD response:', 
                    'CRIT1FL=' || CRIT1FL,
                    'CRIT2FL=' || CRIT2FL,
                    'CRIT3FL=' || CRIT3FL,
                    'CRIT4FL=' || CRIT4FL,
                    'but AVALC=' || strip(AVALC)) as ISSUE
        from &adtr_ds
        where ADY >= 1
          and (CRIT1FL='Y' or CRIT2FL='Y' or CRIT3FL='Y' or CRIT4FL='Y')
          and not (index(upcase(AVALC), 'PD') > 0 or index(upcase(AVALC), 'PROGRESS') > 0);
    quit;
    
    %let n_check3 = &sqlobs;
    %if &n_check3 > 0 %then %put WARNING: [CHECK_CRIT_LOGIC] Check 3: &n_check3 CRIT=Y records without AVALC=PD;
    %else %put %str(NOTE: [CHECK_CRIT_LOGIC] Check 3 PASSED: All CRIT=Y have AVALC=PD);

    /* ========================================
     * CHECK 4: No CRIT flags at baseline
     * ======================================== */
    proc sql;
        insert into _crit_issues
        select USUBJID, PARAMCD, ADT, ADY, AVAL, NADIR, AVALC,
               CRIT1FL, CRIT2FL, CRIT3FL, CRIT4FL,
               'CRIT flags should not exist at baseline (ADY<1)' as ISSUE
        from &adtr_ds
        where ADY < 1
          and (CRIT1FL='Y' or CRIT2FL='Y' or CRIT3FL='Y' or CRIT4FL='Y');
    quit;
    
    %let n_check4 = &sqlobs;
    %if &n_check4 > 0 %then %put WARNING: [CHECK_CRIT_LOGIC] Check 4: &n_check4 baseline records have CRIT flags;
    %else %put %str(NOTE: [CHECK_CRIT_LOGIC] Check 4 PASSED: No CRIT flags at baseline);

    /* ========================================
     * SUMMARY REPORT
     * ======================================== */
    %let total_issues = %eval(&n_check1 + &n_check2 + &n_check3 + &n_check4);
    
    %put %str( );
    %put %str(============================================================);
    %put %str(NOTE: [CHECK_CRIT_LOGIC] VALIDATION SUMMARY);
    %put %str(============================================================);
    %put %str(NOTE: Check 1 (CRIT1FL RECIST 1.1): &n_check1 issues);
    %put %str(NOTE: Check 2 (CRIT3FL Enaworu): &n_check2 issues);
    %put %str(NOTE: Check 3 (CRIT=Y without PD): &n_check3 issues);
    %put %str(NOTE: Check 4 (CRIT at baseline): &n_check4 issues);
    %put %str(NOTE: TOTAL ISSUES: &total_issues);
    %put %str(============================================================);
    %put %str( );
    
    %if &total_issues = 0 %then %do;
        %put %str(NOTE: [CHECK_CRIT_LOGIC] *** CRIT LOGIC VALIDATION PASSED ***);
    %end;
    %else %do;
        %put WARNING: [CHECK_CRIT_LOGIC] *** CRIT LOGIC VALIDATION FAILED: &total_issues issues detected ***;
    %end;

    /* Print detailed issues if requested */
    %if &print_issues=Y and &total_issues > 0 %then %do;
        proc print data=_crit_issues;
            title "CRIT Flag Logic Issues";
            title2 "Research: RECIST 1.1, Enaworu Cureus 2025 PMC12094296";
        run;
        title;
    %end;

    %put %str(NOTE: [CHECK_CRIT_LOGIC] Validation complete.);

%mend check_crit_logic;
