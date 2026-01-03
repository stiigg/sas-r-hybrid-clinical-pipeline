/******************************************************************************
 * Program: test_level4_bds.sas
 * Purpose: Unit tests for Level 4 BDS structure macros
 * Author: Clinical Programming Team
 * Date: 2026-01-03
 * 
 * Test Coverage:
 *   1. add_parcat_vars: PARCAT assignment edge cases
 *   2. add_crit_flags: RECIST 1.1 and Enaworu rule boundaries
 *   3. add_anl_flags: Analysis population logic
 *   4. add_source_trace: Traceability completeness
 * 
 * Usage:
 *   %include "tests/test_level4_bds.sas";
 *****************************************************************************/

%put %str(============================================================);
%put %str(NOTE: Starting Level 4 BDS Structure Macro Unit Tests);
%put %str(============================================================);

/* Load Level 4 macros */
%include "adam/programs/sas/macros/level4_bds_structure/add_parcat_vars.sas";
%include "adam/programs/sas/macros/level4_bds_structure/add_crit_flags.sas";
%include "adam/programs/sas/macros/level4_bds_structure/add_anl_flags.sas";
%include "adam/programs/sas/macros/level4_bds_structure/add_source_trace.sas";

/* ========================================
 * TEST 1: PARCAT Variables
 * ======================================== */
%put %str( );
%put %str(NOTE: TEST 1: Testing add_parcat_vars...);

/* Create test data */
data test_adtr;
    length USUBJID $20 PARAMCD $8 TRLNKID $20;
    
    /* Individual lesion */
    USUBJID='TEST-001'; PARAMCD='LDIAM'; TRLNKID='T01'; ADT='01JAN2025'd; output;
    
    /* Sum of target lesions */
    USUBJID='TEST-001'; PARAMCD='SDIAM'; TRLNKID=''; ADT='01JAN2025'd; output;
    
    /* Sum of non-target lesions */
    USUBJID='TEST-001'; PARAMCD='SNTLDIAM'; TRLNKID=''; ADT='01JAN2025'd; output;
run;

data test_tu;
    length USUBJID $20 TULNKID $20 TULOCCAT $100 TULOC $100 TUTESTCD $8 TUSTRESC $20;
    
    USUBJID='TEST-001'; TULNKID='T01'; 
    TULOCCAT='LIVER'; TULOC='Right Lobe';
    TUTESTCD='TUMIDENT'; TUSTRESC='TARGET';
    output;
run;

%add_parcat_vars(
    input_ds=test_adtr,
    output_ds=test_parcat_out,
    tu_class=test_tu
);

/* Verify PARCAT1 */
proc sql;
    create table _test1_results as
    select PARAMCD, PARCAT1,
           case 
               when PARAMCD='LDIAM' and PARCAT1='INDIVIDUAL LESION' then 'PASS'
               when PARAMCD='SDIAM' and PARCAT1='SUM OF DIAMETERS' then 'PASS'
               when PARAMCD='SNTLDIAM' and PARCAT1='SUM OF DIAMETERS' then 'PASS'
               else 'FAIL'
           end as TEST_RESULT
    from test_parcat_out;
quit;

proc freq data=_test1_results;
    tables TEST_RESULT / nocum;
    title "TEST 1: PARCAT Assignment Results";
run;
title;

/* ========================================
 * TEST 2: CRIT Flags - RECIST 1.1 Boundaries
 * ======================================== */
%put %str( );
%put %str(NOTE: TEST 2: Testing add_crit_flags - RECIST 1.1 boundaries...);

/* Create test data with boundary conditions */
data test_adtr_crit;
    length USUBJID $20 PARAMCD $8;
    
    /* Edge case 1: Exactly 20% and 5mm (should be CRIT1FL=Y) */
    USUBJID='TEST-002'; PARAMCD='SDIAM'; ADY=30; 
    NADIR=25; AVAL=30; BASE=30; /* 20% increase, 5mm absolute */
    AVALC='PD'; output;
    
    /* Edge case 2: 19.9% and 5mm (should be CRIT1FL='') */
    USUBJID='TEST-003'; PARAMCD='SDIAM'; ADY=30;
    NADIR=25.1; AVAL=30; BASE=30; /* 19.5% increase, 4.9mm */
    AVALC='SD'; output;
    
    /* Edge case 3: Enaworu rule - Nadir=25mm exactly */
    USUBJID='TEST-004'; PARAMCD='SDIAM'; ADY=30;
    NADIR=25; AVAL=30; BASE=30; /* 20% increase, Nadir=25mm */
    AVALC='PD'; output;
    
    /* Edge case 4: Nadir=24.9mm */
    USUBJID='TEST-005'; PARAMCD='SDIAM'; ADY=30;
    NADIR=24.9; AVAL=30; BASE=30; /* 20.5% increase, 5.1mm, but Nadir<25 */
    AVALC='PD'; output;
run;

data test_new_lesions;
    length USUBJID $20 NEW_LESION_FL $1;
    stop; /* No new lesions for this test */
run;

%add_crit_flags(
    input_ds=test_adtr_crit,
    output_ds=test_crit_out,
    new_lesion_ds=test_new_lesions,
    enaworu_rule=Y
);

/* Verify CRIT1FL and CRIT3FL logic */
proc print data=test_crit_out;
    var USUBJID NADIR AVAL CRIT1FL CRIT3FL;
    title "TEST 2: CRIT Flag Boundary Conditions";
run;
title;

/* ========================================
 * TEST 3: ANL Flags - Analysis Population Logic
 * ======================================== */
%put %str( );
%put %str(NOTE: TEST 3: Testing add_anl_flags...);

/* Create test ADSL */
data test_adsl;
    length USUBJID $20 SAFFL ITTFL PPROTFL $1;
    
    USUBJID='TEST-006'; SAFFL='Y'; ITTFL='Y'; PPROTFL='Y'; output;
    USUBJID='TEST-007'; SAFFL='Y'; ITTFL='Y'; PPROTFL=''; output;
    USUBJID='TEST-008'; SAFFL='Y'; ITTFL=''; PPROTFL=''; output;
run;

/* Create test ADTR with various scenarios */
data test_adtr_anl;
    length USUBJID $20 PARAMCD $8;
    
    /* TEST-006: Complete data */
    USUBJID='TEST-006'; PARAMCD='SDIAM'; ADY=1; BASE=30; AVAL=25; output;
    USUBJID='TEST-006'; PARAMCD='SDIAM'; ADY=30; BASE=30; AVAL=20; output; /* Best response */
    USUBJID='TEST-006'; PARAMCD='SDIAM'; ADY=60; BASE=30; AVAL=22; output;
    
    /* TEST-007: No per-protocol */
    USUBJID='TEST-007'; PARAMCD='SDIAM'; ADY=1; BASE=30; AVAL=28; output;
    
    /* TEST-008: No baseline */
    USUBJID='TEST-008'; PARAMCD='SDIAM'; ADY=1; BASE=.; AVAL=30; output;
run;

%add_anl_flags(
    input_ds=test_adtr_anl,
    output_ds=test_anl_out,
    adsl_ds=test_adsl
);

/* Verify ANL flags */
proc print data=test_anl_out;
    var USUBJID ADY BASE AVAL ANL01FL ANL02FL ANL03FL ANL04FL;
    title "TEST 3: Analysis Flag Assignment";
run;
title;

/* ========================================
 * TEST 4: Source Traceability
 * ======================================== */
%put %str( );
%put %str(NOTE: TEST 4: Testing add_source_trace...);

/* Create test data */
data test_adtr_src;
    length USUBJID $20 PARAMCD $8;
    
    USUBJID='TEST-009'; PARAMCD='LDIAM'; TRSEQ=1; output;
    USUBJID='TEST-009'; PARAMCD='SDIAM'; TRSEQ=.; output;
    USUBJID='TEST-009'; PARAMCD='BASE'; TRSEQ=.; output;
    USUBJID='TEST-009'; PARAMCD='NADIR'; TRSEQ=.; output;
run;

%add_source_trace(
    input_ds=test_adtr_src,
    output_ds=test_src_out,
    create_adrg_table=Y
);

/* Verify traceability variables */
proc print data=test_src_out;
    var USUBJID PARAMCD SRCDOM SRCVAR SRCSEQ;
    title "TEST 4: Source Traceability Variables";
run;
title;

/* ========================================
 * TEST SUMMARY
 * ======================================== */
%put %str( );
%put %str(============================================================);
%put %str(NOTE: Level 4 BDS Structure Macro Unit Tests Complete);
%put %str(NOTE: Review test outputs above for validation);
%put %str(============================================================);

/* Cleanup */
proc datasets library=work nolist;
    delete test_: _test:;
quit;
