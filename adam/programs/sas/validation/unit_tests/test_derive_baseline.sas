/******************************************************************************
* Test: DERIVE_BASELINE Macro Unit Tests
* Purpose: Validate baseline derivation logic
* Author: Christian Baghai
* Date: 2026-01-03
*
* Description:
*   Unit tests for derive_baseline macro covering PRETREAT and FIRST methods.
*   Validates baseline flag assignment, BASE value carry-forward, and
*   coverage checking.
*
* Usage:
*   %include "validation/unit_tests/test_derive_baseline.sas";
*
* Expected Results:
*   - Test 1 (PRETREAT): 2 baselines (SUB001, SUB002 with ADY<1)
*   - Test 2 (FIRST): 3 baselines (all subjects, first assessment)
******************************************************************************/

%put NOTE: ================================================;
%put NOTE: Starting DERIVE_BASELINE Unit Tests;
%put NOTE: ================================================;

/* Load configuration and macros */
%include "&PROJ_ROOT/adam/programs/sas/config/global_parameters.sas";
%include "&PROJ_ROOT/adam/programs/sas/macros/level2_derivations/derive_baseline.sas";

/* Create test data */
data test_data;
    input USUBJID $ ADY AVAL AVISITN;
    datalines;
SUB001 -7  50.5 0
SUB001  1  52.0 1
SUB001 15  48.5 2
SUB002 -3  45.0 0
SUB002  8  47.5 1
SUB003  1  60.0 1
SUB003 22  58.0 2
;
run;

data test_data;
    set test_data;
    PARAMCD = 'SDIAM';
    length USUBJID $20 PARAMCD $8;
run;

proc sort data=test_data;
    by USUBJID ADY;
run;

/* ========================================
   TEST 1: PRETREAT METHOD
   ======================================== */

%put NOTE: ------------------------------------------------;
%put NOTE: Test 1: PRETREAT Method;
%put NOTE: ------------------------------------------------;

%derive_baseline(
    inds=test_data,
    outds=test_pretreat,
    method=PRETREAT,
    paramcd=SDIAM
);

/* Verify: Should have 2 baselines (SUB001 and SUB002 with ADY<1) */
proc sql;
    title "Test 1: PRETREAT Method - Baseline Records";
    select USUBJID, ADY, AVAL, BASE, BASEFL
    from test_pretreat
    where BASEFL='Y'
    order by USUBJID;
quit;

proc sql;
    title "Test 1: PRETREAT Method - All Records with BASE Carried Forward";
    select USUBJID, ADY, AVAL, BASE, BASEFL
    from test_pretreat
    order by USUBJID, ADY;
quit;

/* Validate Test 1 Results */
proc sql noprint;
    select count(*) into :test1_baseline_count trimmed
    from test_pretreat
    where BASEFL='Y';
    
    select count(distinct USUBJID) into :test1_subjects_with_base trimmed
    from test_pretreat
    where not missing(BASE);
quit;

%put NOTE: Test 1 Results:;
%put NOTE:   Baseline records: &test1_baseline_count (Expected: 2);
%put NOTE:   Subjects with BASE: &test1_subjects_with_base (Expected: 2);

%if &test1_baseline_count = 2 and &test1_subjects_with_base = 2 %then %do;
    %put NOTE: Test 1 PASSED;
%end;
%else %do;
    %put ERROR: Test 1 FAILED - Check baseline derivation logic;
%end;

/* ========================================
   TEST 2: FIRST METHOD
   ======================================== */

%put NOTE: ------------------------------------------------;
%put NOTE: Test 2: FIRST Method;
%put NOTE: ------------------------------------------------;

%derive_baseline(
    inds=test_data,
    outds=test_first,
    method=FIRST,
    paramcd=SDIAM
);

/* Verify: Should have 3 baselines (all subjects, first assessment) */
proc sql;
    title "Test 2: FIRST Method - Baseline Records";
    select USUBJID, ADY, AVAL, BASE, BASEFL
    from test_first
    where BASEFL='Y'
    order by USUBJID;
quit;

proc sql;
    title "Test 2: FIRST Method - All Records with BASE Carried Forward";
    select USUBJID, ADY, AVAL, BASE, BASEFL
    from test_first
    order by USUBJID, ADY;
quit;

/* Validate Test 2 Results */
proc sql noprint;
    select count(*) into :test2_baseline_count trimmed
    from test_first
    where BASEFL='Y';
    
    select count(distinct USUBJID) into :test2_subjects_with_base trimmed
    from test_first
    where not missing(BASE);
quit;

%put NOTE: Test 2 Results:;
%put NOTE:   Baseline records: &test2_baseline_count (Expected: 3);
%put NOTE:   Subjects with BASE: &test2_subjects_with_base (Expected: 3);

%if &test2_baseline_count = 3 and &test2_subjects_with_base = 3 %then %do;
    %put NOTE: Test 2 PASSED;
%end;
%else %do;
    %put ERROR: Test 2 FAILED - Check baseline derivation logic;
%end;

/* ========================================
   SUMMARY
   ======================================== */

%put NOTE: ================================================;
%put NOTE: Unit Tests Complete;
%put NOTE: Review output above for validation;
%put NOTE: ================================================;

title;
