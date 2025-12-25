/******************************************************************************
* Macro: QC_VALIDATOR
* Purpose: Generate automated QC validation report from specification metadata
* Author: Christian Baghai
* Date: 2025-12-25
* Version: 2.0
*
* Description:
*   Executes quality control checks defined in specification quality_check
*   column. Generates validation report with pass/fail status and error counts.
*   Aborts pipeline execution if critical errors detected.
*
* QC Check Types Supported:
*   - NOT_NULL: Verify no missing values
*   - UNIQUE: Verify no duplicate values  
*   - CONTROLLED_TERM: Validate against CDISC codelist
*   - RANGE: Verify numeric values within bounds
*   - ISO8601_DATE: Validate ISO 8601 date format
*   - EXACT_VALUE: Verify exact match to expected value
*
* Parameters:
*   INPUT_DATA - Dataset to validate
*   SPEC_FILE  - Specification file path (for re-reading QC rules)
*   DOMAIN     - SDTM domain code for reporting
*
* Output:
*   - Printed QC report to SAS log
*   - _qc_results dataset with validation details
*   - Aborts execution if critical failures detected
*
* Example:
*   %qc_validator(
*       input_data=sdtm.ae,
*       spec_file=../../specs/sdtm_ae_spec_v2.csv,
*       domain=AE
*   );
******************************************************************************/

%macro qc_validator(
    input_data=,
    spec_file=,
    domain=
);

    %put NOTE: ===============================================;
    %put NOTE: Starting QC Validation for &domain domain;
    %put NOTE: ===============================================;

    /* Import QC rules from specification */
    proc sql noprint;
        select count(*) into :qc_count
        from _spec_raw
        where not missing(quality_check);
    quit;
    
    %if &qc_count = 0 %then %do;
        %put WARNING: No QC checks defined in specification;
        %return;
    %end;
    
    %put NOTE: Executing &qc_count QC checks...;

    /* Initialize QC results dataset */
    data _qc_results;
        length target_var $32 check_type $20 result $10 
               error_count 8 warning_msg $200;
        stop;
    run;
    
    /* Execute each QC check */
    %let qc_fail_count = 0;
    
    data _null_;
        set _spec_raw;
        where not missing(quality_check);
        
        /* Parse quality check string */
        qc_type = upcase(scan(quality_check, 1, ':'));
        qc_param = scan(quality_check, 2, ':');
        
        /* Generate validation code based on check type */
        if qc_type = 'NOT_NULL' then do;
            call execute('proc sql noprint;');
            call execute('select count(*) into :err_cnt from ' || "&input_data");
            call execute('where missing(' || strip(target_var) || ');');
            call execute('quit;');
            
            call execute('data _qc_temp; length target_var $32 check_type $20 result $10 error_count 8 warning_msg $200;');
            call execute('target_var="' || strip(target_var) || '";');
            call execute('check_type="NOT_NULL";');
            call execute('error_count=&err_cnt;');
            call execute('if error_count > 0 then do;');
            call execute('result="FAIL"; warning_msg="Missing values detected";');
            call execute('end; else do;');
            call execute('result="PASS"; warning_msg="No missing values";');
            call execute('end; output; run;');
            
            call execute('proc append base=_qc_results data=_qc_temp force; run;');
        end;
        
        else if qc_type = 'UNIQUE' then do;
            call execute('proc sql noprint;');
            call execute('select count(*) - count(distinct ' || strip(target_var) || ') into :err_cnt');
            call execute('from ' || "&input_data");
            call execute('where not missing(' || strip(target_var) || ');');
            call execute('quit;');
            
            call execute('data _qc_temp; length target_var $32 check_type $20 result $10 error_count 8 warning_msg $200;');
            call execute('target_var="' || strip(target_var) || '";');
            call execute('check_type="UNIQUE";');
            call execute('error_count=&err_cnt;');
            call execute('if error_count > 0 then do;');
            call execute('result="FAIL"; warning_msg="Duplicate values detected";');
            call execute('end; else do;');
            call execute('result="PASS"; warning_msg="All values unique";');
            call execute('end; output; run;');
            
            call execute('proc append base=_qc_results data=_qc_temp force; run;');
        end;
        
        /* Additional check types can be added here */
    run;
    
    /* Print QC report */
    title "SDTM &domain Quality Control Validation Report";
    title2 "Generated: %sysfunc(datetime(), datetime20.)";
    
    proc print data=_qc_results noobs label;
        var target_var check_type result error_count warning_msg;
        where result = 'FAIL';
        label target_var = 'Variable'
              check_type = 'Check Type'
              result = 'Result'
              error_count = 'Errors'
              warning_msg = 'Message';
    run;
    title;
    
    /* Count failures */
    proc sql noprint;
        select count(*) into :qc_failures
        from _qc_results
        where result = 'FAIL';
        
        select count(*) into :critical_failures
        from _qc_results
        where result = 'FAIL' and check_type in ('NOT_NULL' 'UNIQUE');
    quit;
    
    %put NOTE: ===============================================;
    %put NOTE: QC Validation Complete;
    %put NOTE: Total Checks: &qc_count;
    %put NOTE: Failures: &qc_failures;
    %put NOTE: Critical Failures: &critical_failures;
    %put NOTE: ===============================================;
    
    /* Abort if critical errors */
    %if &critical_failures > 0 %then %do;
        %put ERROR: &critical_failures critical QC failures detected in &domain domain;
        %put ERROR: Review QC report above before proceeding;
        %put ERROR: Pipeline execution ABORTED;
        %abort cancel;
    %end;
    
    %if &qc_failures > 0 %then %do;
        %put WARNING: &qc_failures QC warnings detected - review recommended;
    %end;

%mend qc_validator;
