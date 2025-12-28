/******************************************************************************
* Program: validate_dflc_calculation.sas
* Purpose: QC validation of dFLC derivation in 42_sdtm_lb_nexicart2.sas
* Author:  Christian Baghai (QC Programmer - Independent)
* Date:    2025-12-28
* Version: 1.0
* 
* Method:  Independent calculation from raw kappa/lambda values
*          Comparison to production LB.DFLC records
*          Tolerance: ±0.1 mg/L (Freelite assay instrument precision)
* 
* QC Philosophy: Double Programming
*   - QC programmer writes code INDEPENDENTLY without reviewing production
*   - Validates production output against independent re-derivation
*   - Any discrepancy >tolerance triggers QC FAILURE
* 
* Regulatory Note: This validation supports 21 CFR Part 11 compliance
*                   for electronic records in clinical trials
******************************************************************************/

%let tolerance = 0.1; /* mg/L - acceptable difference (assay precision) */

libname prod "../../sdtm/data/csv";

title "NEXICART-2 QC VALIDATION: dFLC Calculation Verification";
title2 "Independent Re-Derivation vs Production Output";
title3 "Tolerance: ±&tolerance mg/L (Freelite Assay Precision)";

/* ========================================
   STEP 1: Extract Production dFLC Values
   ======================================== */

data prod_dflc;
    set prod.lb(where=(LBTESTCD='DFLC'));
    rename LBSTRESN=PROD_DFLC;
    keep USUBJID LBDTC LBDY PROD_DFLC;
run;

proc sort data=prod_dflc nodupkey; 
    by USUBJID LBDY; 
run;

/* ========================================
   STEP 2: Extract Raw Kappa/Lambda for QC
   ======================================== */

data raw_flc;
    set prod.lb(where=(LBTESTCD in ('KAPPA','LAMBDA')));
    keep USUBJID LBDTC LBDY LBTESTCD LBSTRESN;
run;

proc sort data=raw_flc; 
    by USUBJID LBDY LBTESTCD; 
run;

/* Get light chain type from DM domain */
proc sql noprint;
    create table dm_lc_type as
    select USUBJID, 
           case(upcase(strip(LIGHT_CHAIN_TYPE)))
               when 'LAMBDA' then 'λ'
               when 'KAPPA' then 'κ'
               else LIGHT_CHAIN_TYPE
           end as LC_TYPE
    from prod.dm;
quit;

/* ========================================
   STEP 3: QC RE-DERIVATION (INDEPENDENT)
   Critical: Must NOT reference production code logic
   ======================================== */

title "NEXICART-2 QC: Independent dFLC Re-Derivation";

data qc_dflc_calc;
    merge raw_flc
          dm_lc_type;
    by USUBJID;
    
    retain kappa_val lambda_val;
    
    if first.LBDY then do;
        kappa_val = .;
        lambda_val = .;
    end;
    
    /* Capture kappa and lambda values */
    if LBTESTCD = 'KAPPA' then kappa_val = LBSTRESN;
    if LBTESTCD = 'LAMBDA' then lambda_val = LBSTRESN;
    
    /* Calculate dFLC at last record of each timepoint */
    if last.LBDY then do;
        if not missing(kappa_val) and not missing(lambda_val) then do;
            
            /* QC LOGIC: involved - uninvolved */
            /* Lambda-involved: dFLC = lambda - kappa */
            /* Kappa-involved: dFLC = kappa - lambda */
            
            if LC_TYPE = 'λ' then do;
                QC_DFLC = lambda_val - kappa_val;
                QC_INVOLVED = 'LAMBDA';
            end;
            else if LC_TYPE = 'κ' then do;
                QC_DFLC = kappa_val - lambda_val;
                QC_INVOLVED = 'KAPPA';
            end;
            else do;
                put "WARNING: Unknown light chain type for " USUBJID= LC_TYPE=;
                QC_DFLC = .;
            end;
            
            output;
        end;
        else do;
            put "WARNING: Incomplete FLC pair for " USUBJID= LBDY= kappa_val= lambda_val=;
        end;
    end;
    
    keep USUBJID LBDTC LBDY QC_DFLC QC_INVOLVED kappa_val lambda_val;
run;

proc sort data=qc_dflc_calc nodupkey; 
    by USUBJID LBDY; 
run;

/* ========================================
   STEP 4: COMPARE PRODUCTION VS QC VALUES
   ======================================== */

title "NEXICART-2 QC: Production vs QC Comparison";

proc sql;
    create table dflc_comparison as
    select a.USUBJID, 
           a.LBDY as ADY,
           a.LBDTC as DATE_TIME,
           a.PROD_DFLC format=8.2,
           b.QC_DFLC format=8.2,
           b.kappa_val format=8.2 label="Kappa (mg/L)",
           b.lambda_val format=8.2 label="Lambda (mg/L)",
           b.QC_INVOLVED label="Involved LC Type",
           abs(a.PROD_DFLC - b.QC_DFLC) as DIFF format=8.3 label="Absolute Difference",
           case when calculated DIFF <= &tolerance then 'PASS'
                when missing(calculated DIFF) then 'MISSING'
                else 'FAIL' end as QC_STATUS length=10
    from prod_dflc as a
    full join qc_dflc_calc as b
    on a.USUBJID = b.USUBJID and a.LBDY = b.LBDY
    order by USUBJID, ADY;
quit;

/* ========================================
   STEP 5: QC REPORTS
   ======================================== */

title "NEXICART-2 QC VALIDATION REPORT: dFLC Comparison";
title2 "All Records - Production vs Independent QC";

proc print data=dflc_comparison label;
    var USUBJID ADY kappa_val lambda_val QC_INVOLVED PROD_DFLC QC_DFLC DIFF QC_STATUS;
run;

title "NEXICART-2 QC: FAILED VALIDATIONS (DIFF >&tolerance mg/L)";

proc print data=dflc_comparison(where=(QC_STATUS='FAIL'));
    var USUBJID ADY DATE_TIME PROD_DFLC QC_DFLC DIFF QC_STATUS;
run;

title "NEXICART-2 QC: Validation Summary Statistics";

proc freq data=dflc_comparison;
    tables QC_STATUS / nocum;
run;

proc means data=dflc_comparison(where=(QC_STATUS ne 'MISSING')) 
           n mean median min max maxdec=3;
    var DIFF;
    title "NEXICART-2 QC: Distribution of Differences (Production - QC)";
run;

/* ========================================
   STEP 6: AUTOMATED PASS/FAIL DETERMINATION
   ======================================== */

%macro evaluate_qc_status;
    %let nfail=0;
    %let nmissing=0;
    %let npass=0;
    
    proc sql noprint;
        select count(*) into :nfail trimmed
        from dflc_comparison
        where QC_STATUS = 'FAIL';
        
        select count(*) into :nmissing trimmed
        from dflc_comparison
        where QC_STATUS = 'MISSING';
        
        select count(*) into :npass trimmed
        from dflc_comparison
        where QC_STATUS = 'PASS';
    quit;
    
    %put ;
    %put ========================================================;
    %put QC VALIDATION SUMMARY: dFLC Calculation;
    %put ========================================================;
    %put QC PASS:    &npass record(s) within tolerance (±&tolerance mg/L);
    %put QC FAIL:    &nfail record(s) exceed tolerance;
    %put QC MISSING: &nmissing record(s) with missing values;
    %put ========================================================;
    
    %if &nfail > 0 %then %do;
        %put ;
        %put ERROR: ========================================;
        %put ERROR: QC VALIDATION FAILED;
        %put ERROR: &nfail dFLC CALCULATION DISCREPANCIES DETECTED;
        %put ERROR: Differences exceed tolerance of &tolerance mg/L;
        %put ERROR: Review dflc_comparison dataset for details;
        %put ERROR: ACTION REQUIRED: Investigate production code logic;
        %put ERROR: ========================================;
        %put ;
    %end;
    %else %if &nmissing > 0 %then %do;
        %put ;
        %put WARNING: ========================================;
        %put WARNING: QC VALIDATION INCOMPLETE;
        %put WARNING: &nmissing record(s) have missing production or QC values;
        %put WARNING: Review dflc_comparison dataset for details;
        %put WARNING: ========================================;
        %put ;
    %end;
    %else %do;
        %put ;
        %put NOTE: ============================================;
        %put NOTE: ✓✓✓ QC VALIDATION PASSED ✓✓✓;
        %put NOTE: ============================================;
        %put NOTE: All dFLC calculations validated successfully;
        %put NOTE: Production values match QC re-derivation;
        %put NOTE: Maximum difference: within ±&tolerance mg/L tolerance;
        %put NOTE: ============================================;
        %put NOTE: Production code: 42_sdtm_lb_nexicart2.sas APPROVED;
        %put NOTE: QC Programmer: Christian Baghai;
        %put NOTE: QC Date: %sysfunc(today(), yymmdd10.);
        %put NOTE: ============================================;
        %put ;
    %end;
%mend;

%evaluate_qc_status;

/* ========================================
   STEP 7: EXPORT QC VALIDATION DATASET
   ======================================== */

proc export data=dflc_comparison 
            outfile="../../qc/dflc_validation_results.csv" 
            dbms=csv replace; 
run;

%put NOTE: QC validation results exported to qc/dflc_validation_results.csv;
