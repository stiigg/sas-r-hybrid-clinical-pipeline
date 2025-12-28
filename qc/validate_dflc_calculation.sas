/******************************************************************************
* QC Program: validate_dflc_calculation.sas
* Purpose: Independent verification of dFLC derivation logic
* Author: QC Reviewer
* Date: 2025-12-28
* 
* Validation Method: Recalculate dFLC from source kappa/lambda values
*                    Compare to production LB.DFLC records
*                    Flag discrepancies >0.1 mg/L (instrument precision)
******************************************************************************/

libname prod "../../sdtm/data/csv";

/* Recreate dFLC calculation independently */
data qc_dflc_recalc;
    set prod.lb(where=(LBTESTCD in ('KAPPA','LAMBDA')));
    by USUBJID collection_dt;
    
    retain qc_kappa qc_lambda;
    
    if first.collection_dt then do;
        qc_kappa = .;
        qc_lambda = .;
    end;
    
    if LBTESTCD = 'KAPPA' then qc_kappa = LBSTRESN;
    if LBTESTCD = 'LAMBDA' then qc_lambda = LBSTRESN;
    
    if last.collection_dt and not missing(qc_kappa) and not missing(qc_lambda) then do;
        /* Determine involved LC from patient's light chain type */
        if LCLCTYPE = 'λ' then qc_dflc = qc_lambda - qc_kappa;
        else if LCLCTYPE = 'κ' then qc_dflc = qc_kappa - qc_lambda;
        
        output;
    end;
    
    keep USUBJID collection_dt LCLCTYPE qc_kappa qc_lambda qc_dflc;
run;

/* Merge with production dFLC values */
proc sql;
    create table qc_comparison as
    select a.USUBJID,
           a.collection_dt,
           a.LCLCTYPE,
           a.qc_kappa,
           a.qc_lambda,
           a.qc_dflc as QC_DERIVED_DFLC,
           b.LBSTRESN as PROD_DFLC,
           abs(a.qc_dflc - b.LBSTRESN) as DIFF,
           case 
               when abs(a.qc_dflc - b.LBSTRESN) <= 0.1 then 'PASS'
               else 'FAIL'
           end as QC_STATUS
    from qc_dflc_recalc as a
    left join prod.lb(where=(LBTESTCD='DFLC')) as b
        on a.USUBJID = b.USUBJID
        and a.collection_dt = b.collection_dt;
quit;

/* Generate QC report */
title "dFLC Calculation Validation Report";
title2 "Discrepancies >0.1 mg/L require investigation";

proc print data=qc_comparison(where=(QC_STATUS='FAIL'));
    var USUBJID collection_dt LCLCTYPE qc_kappa qc_lambda 
        QC_DERIVED_DFLC PROD_DFLC DIFF QC_STATUS;
    format QC_DERIVED_DFLC PROD_DFLC DIFF 8.2;
run;

/* Summary statistics */
proc means data=qc_comparison n nmiss mean median min max maxdec=3;
    var DIFF;
run;

proc freq data=qc_comparison;
    tables QC_STATUS / missing;
run;

/* Flag dataset for review if any failures */
%macro qc_flag_check;
    %let nfail=0;
    data _null_;
        set qc_comparison(where=(QC_STATUS='FAIL')) nobs=n;
        call symputx('nfail', n);
    run;
    
    %if &nfail > 0 %then %do;
        %put ERROR: &nfail dFLC calculation discrepancies detected;
        %put ERROR: Review qc_comparison dataset;
    %end;
    %else %put NOTE: *** QC PASSED: All dFLC calculations verified ***;
%mend;

%qc_flag_check;