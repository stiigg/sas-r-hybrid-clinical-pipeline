/******************************************************************************
 * Program: compare_adrs.sas
 * Purpose: QC comparison of production vs QC ADRS (Response Analysis Dataset)
 * Author: Christian Baghai
 * Date: 2025-12-14
 *
 * Inputs:  
 *   - adam.adrs (production RECIST derivations)
 *   - qc.adrs (QC programmer RECIST derivations)
 *
 * Output:  
 *   - HTML comparison report with response-specific discrepancies
 *   - Focus on BOR, confirmation flags, and percent change calculations
 *
 * Validation: Critical for RECIST 1.1 accuracy (UR-014)
 ******************************************************************************/

libname adam "outputs/adam";
libname qc "outputs/qc";

%let qc_report_dir = outputs/qc_reports;
x "mkdir -p &qc_report_dir";

/******************************************************************************
 * Macro: compare_adrs
 ******************************************************************************/
%macro compare_adrs(
    prod_lib=adam,
    qc_lib=qc,
    out_dir=outputs/qc_reports,
    tolerance=0.001
);

    %put NOTE: ================================================================;
    %put NOTE: Starting ADRS QC Comparison;
    %put NOTE: Focus: RECIST response classifications and derived variables;
    %put NOTE: ================================================================;

    /* Step 1: PROC COMPARE with response-specific variables */
    proc compare 
        base=&prod_lib..adrs 
        compare=&qc_lib..adrs 
        out=work.adrs_diff
        outnoequal outbase outcomp
        method=absolute 
        criterion=&tolerance
        maxprint=(200,50)
        noprint;
        
        /* Composite key: Subject + Parameter + Visit */
        id USUBJID PARAMCD AVISIT;
        
        /* Critical response variables */
        var 
            /* Numeric response value */
            AVAL 
            /* Character response value */
            AVALC 
            /* Change from baseline */
            CHG 
            /* Percent change from baseline */
            PCHG 
            /* Baseline value */
            BASE 
            /* Confirmation flag */
            CONFFL
            /* Derived response category */
            DTYPE
            /* Analysis day */
            ADY
            /* Analysis date */
            ADT;
    run;

    /* Step 2: Enhanced summary with response-specific analysis */
    data work.adrs_summary;
        length Status $20 Message $200 Critical_Vars $500;
        
        if 0 then set work.adrs_diff nobs=n_diff;
        
        /* Overall status */
        if n_diff = 0 then do;
            Status = "PASS";
            Message = "Production and QC ADRS datasets match perfectly";
            Critical_Vars = "N/A - No discrepancies";
        end;
        else do;
            Status = "FAIL";
            Message = cats("Found ", n_diff, " discrepancies in ADRS comparison");
            
            /* Flag if critical response variables differ */
            if n_diff > 0 then do;
                Critical_Vars = "Check: AVALC (response), CONFFL (confirmation), PCHG (% change)";
            end;
        end;
        
        Dataset = "ADRS";
        Comparison_Date = today();
        Comparison_Time = time();
        Numeric_Tolerance = &tolerance;
        
        format Comparison_Date date9. Comparison_Time time8. Numeric_Tolerance 8.6;
        output;
        stop;
    run;

    /* Step 3: Log summary */
    data _null_;
        set work.adrs_summary;
        
        put "NOTE: ================================================================";
        put "NOTE: ADRS (Response Analysis) QC Comparison Summary";
        put "NOTE: ================================================================";
        put "NOTE: Dataset: " Dataset;
        put "NOTE: Status: " Status;
        put "NOTE: " Message;
        put "NOTE: Critical Variables: " Critical_Vars;
        put "NOTE: Numeric Tolerance: " Numeric_Tolerance 8.6;
        put "NOTE: Date: " Comparison_Date date9. " Time: " Comparison_Time time8.;
        put "NOTE: ================================================================";
        
        call symputx('adrs_status', Status);
        call symputx('n_discrepancies', n_diff);
    run;

    /* Step 4: HTML Report Generation */
    %let report_file = &out_dir/adrs_compare_%sysfunc(today(),yymmddn8.).html;
    
    ods html file="&report_file" style=htmlblue;
    
    title1 "ADRS QC Comparison Report";
    title2 "Response Analysis Dataset - Production vs QC";
    title3 "Generated: %sysfunc(today(),date9.) at %sysfunc(time(),time8.)";
    title4 "Numeric Tolerance: &tolerance";
    
    /* Summary */
    proc print data=work.adrs_summary noobs label;
        var Dataset Status Message Critical_Vars Numeric_Tolerance;
        label 
            Dataset = "Dataset Name"
            Status = "QC Status"
            Message = "Summary"
            Critical_Vars = "Focus Areas"
            Numeric_Tolerance = "Tolerance";
    run;
    
    /* Detailed discrepancies */
    %if &adrs_status = FAIL %then %do;
        
        title5 "Discrepancies by Subject and Parameter";
        
        proc print data=work.adrs_diff (obs=100) label;
            var USUBJID PARAMCD AVISIT _TYPE_ _OBS_ 
                AVAL AVALC CHG PCHG BASE CONFFL;
            label 
                _TYPE_ = "Source"
                _OBS_ = "Obs"
                USUBJID = "Subject"
                PARAMCD = "Parameter"
                AVISIT = "Visit"
                AVALC = "Response"
                CONFFL = "Confirmed?";
        run;
        
        /* Response-specific discrepancy analysis */
        title5 "Discrepancies by Response Parameter";
        
        proc freq data=work.adrs_diff;
            tables PARAMCD * _VAR_ / nocum norow nocol;
            label 
                PARAMCD = "Response Parameter"
                _VAR_ = "Variable with Discrepancy";
        run;
        
        /* Focus on BOR discrepancies (most critical) */
        title5 "Best Overall Response (BOR) Discrepancies";
        
        proc print data=work.adrs_diff (where=(PARAMCD="BOR")) label;
            var USUBJID _TYPE_ AVALC CONFFL ADT;
            label 
                USUBJID = "Subject ID"
                _TYPE_ = "Production/QC"
                AVALC = "Response Category"
                CONFFL = "Confirmation Flag"
                ADT = "Response Date";
        run;
        
    %end;
    %else %do;
        title5 "✓ All RECIST response derivations match between Production and QC";
        
        proc print data=work.adrs_summary noobs;
            var Status Message;
        run;
    %end;
    
    title;
    ods html close;
    
    %put NOTE: ================================================================;
    %put NOTE: ADRS HTML report: &report_file;
    %put NOTE: ================================================================;
    
    /* Step 5: Return appropriate status */
    %if &adrs_status = FAIL %then %do;
        %put ERROR: ADRS QC comparison FAILED with &n_discrepancies discrepancies.;
        %put ERROR: Review BOR classifications and confirmation flags carefully.;
    %end;
    %else %do;
        %put NOTE: ✓ ADRS QC comparison PASSED. RECIST derivations verified.;
    %end;

%mend compare_adrs;

/******************************************************************************
 * Execute ADRS QC comparison
 ******************************************************************************/
%compare_adrs();

proc datasets library=work nolist;
    delete adrs_summary;
quit;
