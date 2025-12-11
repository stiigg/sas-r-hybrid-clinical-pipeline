/******************************************************************************
Program: simple_recist_demo.sas
Purpose: Demonstrate RECIST 1.1 core derivations with synthetic test data
Author: Christian Baghai
Date: December 2025

Description:
End-to-end demonstration of RECIST 1.1 derivation macros:
1. Target lesion response (SLD calculation, PR/CR/PD thresholds)
2. Overall timepoint response integration
3. Best Overall Response with confirmation logic

Test Subjects:
- 001-001: PR response (baseline 55mm → 33mm → 22mm, -60% from baseline)
- 001-002: CR response (baseline 75mm → 0mm, complete disappearance)
- 001-003: PD response (baseline 95mm → 126mm, +33% progression)
******************************************************************************/

/* Setup paths - adjust as needed for your system */
%let repo_root = %sysfunc(getoption(SYSIN));
%let repo_root = %substr(&repo_root, 1, %length(&repo_root)-%length(%scan(&repo_root,-1,/)));

libname demo "&repo_root/demo/data";

%put NOTE: ========================================;
%put NOTE: RECIST 1.1 Core Derivation Demo;
%put NOTE: Repository: &repo_root;
%put NOTE: ========================================;

/* Import test data */
proc import datafile="&repo_root/demo/data/test_sdtm_rs.csv"
    out=work.rs
    dbms=csv
    replace;
    getnames=yes;
run;

%put NOTE: Test data loaded. Checking contents...;
proc contents data=work.rs short;
run;

proc print data=work.rs (obs=10);
    title "Sample SDTM RS Data";
run;
title;

/* Include RECIST macros */
%put NOTE: Loading RECIST 1.1 core macros...;
%include "&repo_root/etl/adam_program_library/oncology_response/recist_11_core/derive_target_lesion_response.sas";
%include "&repo_root/etl/adam_program_library/oncology_response/recist_11_core/derive_non_target_lesion_response.sas";
%include "&repo_root/etl/adam_program_library/oncology_response/recist_11_core/derive_overall_timepoint_response.sas";
%include "&repo_root/etl/adam_program_library/oncology_response/recist_11_core/derive_best_overall_response.sas";

%put NOTE: ========================================;
%put NOTE: Step 1: Deriving Target Lesion Responses;
%put NOTE: ========================================;

/* Step 1: Derive target lesion responses */
%derive_target_lesion_response(
    inds=work.rs,
    outds=work.adrs_tl,
    usubjid_var=USUBJID,
    visit_var=VISIT,
    adt_var=RSDTC,
    ldiam_var=RSSTRESC,
    baseline_flag=ABLFL
);

proc print data=work.adrs_tl label;
    var USUBJID VISIT TL_SLD TL_BASE_SLD TL_NADIR_SLD TL_PCHG_BASE TL_PCHG_NAD TL_RESP;
    title "Target Lesion Responses by Visit";
run;
title;

%put NOTE: ========================================;
%put NOTE: Step 2: Deriving Overall Timepoint Responses;
%put NOTE: ========================================;

/* Step 2: Derive overall timepoint responses */
/* Note: No non-target or new lesions in this simple demo */
%derive_overall_timepoint_response(
    tl_ds=work.adrs_tl,
    ntl_ds=,  /* No non-target data */
    nl_ds=,   /* No new lesions */
    outds=work.adrs_timepoint,
    usubjid_var=USUBJID,
    adt_var=RSDTC
);

proc print data=work.adrs_timepoint label;
    var USUBJID VISIT OVR_RESP OVR_RESP_LOGIC;
    title "Overall Responses by Visit";
run;
title;

%put NOTE: ========================================;
%put NOTE: Step 3: Deriving Best Overall Response;
%put NOTE: ========================================;

/* Step 3: Derive Best Overall Response */
%derive_best_overall_response(
    inds=work.adrs_timepoint,
    outds=work.adrs_bor,
    usubjid_var=USUBJID,
    ady_var=RSDY,
    dtc_var=RSDTC,
    ovr_var=OVR_RESP,
    conf_win_lo=28,
    conf_win_hi=84,
    sd_min_dur=42
);

%put NOTE: ========================================;
%put NOTE: Demo Results
%put NOTE: ========================================;

/* Generate demo report */
title "RECIST 1.1 Derivation Demo - Best Overall Response";
proc print data=work.adrs_bor label;
    var USUBJID BOR BORDT BORCONF BOR_SRC;
run;

proc freq data=work.adrs_bor;
    tables BOR BORCONF / missing;
    title2 "BOR Distribution";
run;
title;

/* Save output to demo library */
data demo.adrs_bor;
    set work.adrs_bor;
run;

%put NOTE: ========================================;
%put NOTE: Demo completed successfully!
%put NOTE: Output dataset: demo.adrs_bor
%put NOTE: ========================================;
%put NOTE:;
%put NOTE: Expected Results:;
%put NOTE: - Subject 001-001: BOR=PR (confirmed);
%put NOTE: - Subject 001-002: BOR=CR (confirmed);
%put NOTE: - Subject 001-003: BOR=PD (unconfirmed);
%put NOTE:;
%put NOTE: Compare with expected results in demo/data/expected_bor.csv;
