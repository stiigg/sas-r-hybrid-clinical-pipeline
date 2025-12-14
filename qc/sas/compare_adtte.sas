/******************************************************************************
 * Program: compare_adtte.sas
 * Purpose: QC comparison of production vs QC ADTTE (Time-to-Event Dataset)
 * Author: Christian Baghai
 * Date: 2025-12-14
 *
 * Inputs:  
 *   - adam.adtte (production time-to-event derivations)
 *   - qc.adtte (QC programmer TTE derivations)
 *
 * Output:  
 *   - HTML comparison report with TTE-specific validation
 *   - Focus on event flags, censoring, and survival time calculations
 *
 * Validation: Critical for PFS/DoR/OS endpoints (UR-014)
 ******************************************************************************/

libname adam "outputs/adam";
libname qc "outputs/qc";

%let qc_report_dir = outputs/qc_reports;
x "mkdir -p &qc_report_dir";

/******************************************************************************
 * Macro: compare_adtte
 ******************************************************************************/
%macro compare_adtte(
    prod_lib=adam,
    qc_lib=qc,
    out_dir=outputs/qc_reports,
    tolerance=0.01  /* Slightly higher tolerance for time calculations */
);

    %put NOTE: ================================================================;
    %put NOTE: Starting ADTTE QC Comparison;
    %put NOTE: Focus: Time-to-event endpoints (PFS, DoR, OS);
    %put NOTE: ================================================================;

    /* Step 1: PROC COMPARE for time-to-event variables */
    proc compare 
        base=&prod_lib..adtte 
        compare=&qc_lib..adtte 
        out=work.adtte_diff
        outnoequal outbase outcomp
        method=absolute 
        criterion=&tolerance
        maxprint=(200,50)
        noprint;
        
        /* Key: Subject + Parameter */
        id USUBJID PARAMCD;
        
        /* Time-to-event critical variables */
        var 
            /* Analysis value (survival time in days/months) */
            AVAL 
            /* Start date */
            STARTDT 
            /* Analysis date (event/censor date) */
            ADT 
            /* Event flag (1=event, 0=censored) */
            CNSR 
            /* Event description */
            EVNTDESC
            /* Censoring description */
            CNSDTDSC
            /* Parameter-specific flags */
            PARAM;
    run;

    /* Step 2: TTE-specific summary */
    data work.adtte_summary;
        length Status $20 Message $200 Endpoint_Focus $500;
        
        if 0 then set work.adtte_diff nobs=n_diff;
        
        if n_diff = 0 then do;
            Status = "PASS";
            Message = "Production and QC ADTTE datasets are identical";
            Endpoint_Focus = "PFS, DoR, OS all verified";
        end;
        else do;
            Status = "FAIL";
            Message = cats("Found ", n_diff, " discrepancies in time-to-event calculations");
            Endpoint_Focus = "Check: AVAL (survival time), CNSR (event flag), ADT (event date)";
        end;
        
        Dataset = "ADTTE";
        Comparison_Date = today();
        Comparison_Time = time();
        Numeric_Tolerance = &tolerance;
        
        format Comparison_Date date9. Comparison_Time time8. Numeric_Tolerance 8.6;
        output;
        stop;
    run;

    /* Step 3: Log summary */
    data _null_;
        set work.adtte_summary;
        
        put "NOTE: ================================================================";
        put "NOTE: ADTTE (Time-to-Event) QC Comparison Summary";
        put "NOTE: ================================================================";
        put "NOTE: Dataset: " Dataset;
        put "NOTE: Status: " Status;
        put "NOTE: " Message;
        put "NOTE: Endpoints: " Endpoint_Focus;
        put "NOTE: Tolerance: " Numeric_Tolerance 8.6 " days";
        put "NOTE: Date: " Comparison_Date date9. " Time: " Comparison_Time time8.;
        put "NOTE: ================================================================";
        
        call symputx('adtte_status', Status);
        call symputx('n_tte_disc', n_diff);
    run;

    /* Step 4: HTML Report */
    %let report_file = &out_dir/adtte_compare_%sysfunc(today(),yymmddn8.).html;
    
    ods html file="&report_file" style=htmlblue;
    
    title1 "ADTTE QC Comparison Report";
    title2 "Time-to-Event Analysis Dataset - Production vs QC";
    title3 "Generated: %sysfunc(today(),date9.) at %sysfunc(time(),time8.)";
    title4 "Numeric Tolerance: &tolerance days";
    
    /* Summary */
    proc print data=work.adtte_summary noobs label;
        var Dataset Status Message Endpoint_Focus Numeric_Tolerance;
        label 
            Dataset = "Dataset"
            Status = "QC Status"
            Message = "Summary"
            Endpoint_Focus = "Validated Endpoints"
            Numeric_Tolerance = "Tolerance (days)";
    run;
    
    /* Detailed discrepancies */
    %if &adtte_status = FAIL %then %do;
        
        title5 "Time-to-Event Discrepancies by Subject and Parameter";
        
        proc print data=work.adtte_diff (obs=100) label;
            var USUBJID PARAMCD _TYPE_ _OBS_ 
                AVAL STARTDT ADT CNSR EVNTDESC;
            label 
                _TYPE_ = "Source"
                _OBS_ = "Obs"
                USUBJID = "Subject"
                PARAMCD = "Endpoint"
                AVAL = "Survival Time"
                STARTDT = "Start Date"
                ADT = "Event/Censor Date"
                CNSR = "Censored?"
                EVNTDESC = "Event Description";
        run;
        
        /* Endpoint-specific analysis */
        title5 "Discrepancies by Endpoint Type";
        
        proc freq data=work.adtte_diff;
            tables PARAMCD * _VAR_ / nocum norow nocol;
            label 
                PARAMCD = "Time-to-Event Endpoint"
                _VAR_ = "Variable with Discrepancy";
        run;
        
        /* Event vs Censoring discrepancies */
        title5 "Event/Censoring Status Discrepancies";
        
        proc freq data=work.adtte_diff;
            tables CNSR / missing;
            label CNSR = "Censoring Status (0=Event, 1=Censored)";
        run;
        
        /* PFS-specific (most critical endpoint) */
        title5 "Progression-Free Survival (PFS) Discrepancies";
        
        proc print data=work.adtte_diff (where=(PARAMCD="PFS")) label;
            var USUBJID _TYPE_ AVAL ADT CNSR EVNTDESC CNSDTDSC;
            label 
                USUBJID = "Subject ID"
                _TYPE_ = "Prod/QC"
                AVAL = "PFS Time (days)"
                ADT = "PFS Date"
                CNSR = "Censored?"
                EVNTDESC = "Event"
                CNSDTDSC = "Censor Reason";
        run;
        
    %end;
    %else %do;
        title5 "✓ All time-to-event calculations verified";
        
        proc print data=work.adtte_summary noobs;
            var Status Message Endpoint_Focus;
        run;
    %end;
    
    title;
    ods html close;
    
    %put NOTE: ================================================================;
    %put NOTE: ADTTE HTML report: &report_file;
    %put NOTE: ================================================================;
    
    /* Step 5: Status determination */
    %if &adtte_status = FAIL %then %do;
        %put ERROR: ADTTE QC comparison FAILED with &n_tte_disc discrepancies.;
        %put ERROR: Verify PFS/DoR/OS event dates and censoring logic.;
    %end;
    %else %do;
        %put NOTE: ✓ ADTTE QC comparison PASSED. Time-to-event endpoints verified.;
    %end;

%mend compare_adtte;

/******************************************************************************
 * Execute ADTTE QC comparison
 ******************************************************************************/
%compare_adtte();

proc datasets library=work nolist;
    delete adtte_summary;
quit;
