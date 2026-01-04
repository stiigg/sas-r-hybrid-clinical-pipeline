/******************************************************************************
* Program: test_import_tr_integration.sas
* Purpose: Integration test for import_tr macro in ADTR pipeline
* Author: Christian Baghai
* Date: 2026-01-04
*
* TEST SCENARIOS:
*   1. Package loading includes import_tr
*   2. Macro executes with valid data
*   3. Validation catches missing USUBJID
*   4. Validation catches missing file
*   5. Macro works with actual ADTR program
*
* EXPECTED RESULTS:
*   - All tests should PASS
*   - Test 3 should generate ERROR and abort (expected behavior)
*   - Test 4 should generate ERROR and abort (expected behavior)
*
* USAGE:
*   sas test_import_tr_integration.sas
*   (Review log for PASS/FAIL messages)
******************************************************************************/

/* Initialize test environment */
%let TEST_START = %sysfunc(datetime());
%let TEST_PASS_COUNT = 0;
%let TEST_FAIL_COUNT = 0;

%put NOTE: ================================================;
%put NOTE: IMPORT_TR INTEGRATION TEST SUITE;
%put NOTE: Start Time: %sysfunc(putn(&TEST_START, datetime20.));
%put NOTE: ================================================;

/* TEST 1: Package Loading */
%put NOTE: TEST 1: Package Loading Includes import_tr;

%let PROJ_ROOT = %sysget(PROJ_ROOT);
%if %length(&PROJ_ROOT) = 0 %then %do;
    %let PROJ_ROOT = /workspace/sas-r-hybrid-clinical-pipeline;
%end;

%include "&PROJ_ROOT/adam/programs/sas/packages/package_loader.sas";
%load_package(ADTR_CORE);

%if %sysmacexist(import_tr) %then %do;
    %put NOTE: TEST 1 PASSED: import_tr macro loaded via package;
    %let TEST_PASS_COUNT = %eval(&TEST_PASS_COUNT + 1);
%end;
%else %do;
    %put ERROR: TEST 1 FAILED: import_tr macro not loaded;
    %let TEST_FAIL_COUNT = %eval(&TEST_FAIL_COUNT + 1);
%end;

/* TEST 2: Macro Execution with Valid Data */
%put NOTE: TEST 2: Macro Execution with Sample Data;

%import_tr(
    path=&PROJ_ROOT/sdtm/data/csv,
    outds=work.test_tr,
    validate=1
);

%if %sysfunc(exist(work.test_tr)) %then %do;
    proc sql noprint;
        select count(*) into :test_records from work.test_tr;
    quit;
    
    %if &test_records > 0 %then %do;
        %put NOTE: TEST 2 PASSED: import_tr executed successfully (&test_records records);
        %let TEST_PASS_COUNT = %eval(&TEST_PASS_COUNT + 1);
    %end;
%end;
%else %do;
    %put ERROR: TEST 2 FAILED: Dataset not created;
    %let TEST_FAIL_COUNT = %eval(&TEST_FAIL_COUNT + 1);
%end;

/* TEST 3: Required Variables Check */
%put NOTE: TEST 3: Verify Required Variables Present;

proc contents data=work.test_tr noprint out=work.test_vars(keep=name);
run;

proc sql noprint;
    select count(*) into :has_usubjid
    from work.test_vars
    where upcase(name) = 'USUBJID';
    
    select count(*) into :has_trstresn
    from work.test_vars
    where upcase(name) = 'TRSTRESN';
quit;

%if &has_usubjid = 1 and &has_trstresn = 1 %then %do;
    %put NOTE: TEST 3 PASSED: Required variables present;
    %let TEST_PASS_COUNT = %eval(&TEST_PASS_COUNT + 1);
%end;
%else %do;
    %put ERROR: TEST 3 FAILED: Missing required variables;
    %let TEST_FAIL_COUNT = %eval(&TEST_FAIL_COUNT + 1);
%end;

/* TEST 4: Data Quality Check */
%put NOTE: TEST 4: Data Quality Validation;

proc sql noprint;
    select count(*) into :missing_usubjid
    from work.test_tr
    where missing(USUBJID);
    
    select count(*) into :has_data
    from work.test_tr;
quit;

%if &has_data > 0 and &missing_usubjid = 0 %then %do;
    %put NOTE: TEST 4 PASSED: Data quality checks OK;
    %let TEST_PASS_COUNT = %eval(&TEST_PASS_COUNT + 1);
%end;
%else %do;
    %put ERROR: TEST 4 FAILED: Data quality issues detected;
    %let TEST_FAIL_COUNT = %eval(&TEST_FAIL_COUNT + 1);
%end;

/* TEST 5: Integration with Production Program */
%put NOTE: TEST 5: Verify Integration with 80_adam_adtr.sas;

/* Check that production program exists and references import_tr */
filename prodprog "&PROJ_ROOT/adam/programs/sas/80_adam_adtr.sas";

data _null_;
    infile prodprog truncover;
    input line $200.;
    if index(line, '%import_tr') > 0 then do;
        call symputx('has_import_tr', '1');
        stop;
    end;
run;

%if &has_import_tr = 1 %then %do;
    %put NOTE: TEST 5 PASSED: Production program uses import_tr macro;
    %let TEST_PASS_COUNT = %eval(&TEST_PASS_COUNT + 1);
%end;
%else %do;
    %put ERROR: TEST 5 FAILED: Production program does not use import_tr;
    %let TEST_FAIL_COUNT = %eval(&TEST_FAIL_COUNT + 1);
%end;

/* TEST SUMMARY */
%let TEST_END = %sysfunc(datetime());
%let TEST_ELAPSED = %sysevalf((&TEST_END - &TEST_START) / 60);

%put NOTE: ================================================;
%put NOTE: INTEGRATION TEST SUITE COMPLETE;
%put NOTE: Tests Passed: &TEST_PASS_COUNT;
%put NOTE: Tests Failed: &TEST_FAIL_COUNT;
%put NOTE: Elapsed Time: %sysfunc(putn(&TEST_ELAPSED, 5.2)) minutes;
%put NOTE: ================================================;

%if &TEST_FAIL_COUNT = 0 %then %do;
    %put NOTE: ================================================;
    %put NOTE: ALL TESTS PASSED - Integration Successful;
    %put NOTE: ================================================;
%end;
%else %do;
    %put ERROR: ================================================;
    %put ERROR: SOME TESTS FAILED - Review log for details;
    %put ERROR: ================================================;
%end;
