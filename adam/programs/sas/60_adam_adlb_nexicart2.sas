/******************************************************************************
* Program: 60_adam_adlb_nexicart2.sas
* Purpose: Generate ADaM ADLB with nadir tracking for AL amyloidosis
* Author:  Christian Baghai
* Date:    2025-12-28
* Version: 1.0 - NEXICART-2 implementation
* 
* Input:   sdtm/data/csv/lb.csv, sdtm/data/csv/dm.csv
* Output:  adam/data/adlb.csv, adam/data/xpt/adlb.xpt
* 
* Priority: CRITICAL - Nadir tracking required for IMWG PD assessment
* 
* Notes:   Implements cumulative nadir (running minimum) for dFLC
*          NADIR = lowest post-baseline value up to current timepoint
*          Progressive disease defined as ≥25% increase from NADIR
*          Reference: Palladini et al. Blood 2012 IMWG consensus criteria
******************************************************************************/

%let STUDYID = NEXICART2-AL-AMYLOIDOSIS;

libname sdtm "../../sdtm/data/csv";
libname adam "../../adam/data";

/* ========================================
   STEP 1: Import SDTM Datasets
   ======================================== */

title "NEXICART-2 ADLB: Import SDTM Source Datasets";

data dm;
    set sdtm.dm;
    keep USUBJID STUDYID SUBJID RFSTDTC RFENDTC ARM ACTARM;
run;

data lb;
    set sdtm.lb;
    
    /* Convert SDTM variables to ADaM naming */
    length ADTM $25;
    ADTM = LBDTC;
    
    /* Analysis day */
    ADY = LBDY;
    
    /* Analysis value */
    AVAL = LBSTRESN;
    
    /* Parameter coding */
    PARAM = LBTEST;
    PARAMCD = LBTESTCD;
    
    /* Category */
    PARAMCAT = LBCAT;
    
    /* Unit */
    AVALU = LBSTRESU;
    
    keep USUBJID ADTM ADY AVAL PARAM PARAMCD PARAMCAT AVALU 
         LBBLFL LBNRIND VISIT VISITNUM;
run;

proc sort data=lb; by USUBJID; run;
proc sort data=dm; by USUBJID; run;

/* ========================================
   STEP 2: Merge with Demographics
   ======================================== */

data adlb_base;
    merge lb(in=a) dm(in=b);
    by USUBJID;
    if a and b;
run;

proc sort data=adlb_base; by USUBJID PARAMCD ADY; run;

/* ========================================
   STEP 3: Derive Baseline Variables
   ======================================== */

title "NEXICART-2 ADLB: Derive Baseline Values";

data adlb_bl;
    set adlb_base;
    by USUBJID PARAMCD ADY;
    
    /* Baseline flag from SDTM */
    ABLFL = LBBLFL;
    
    /* Retain baseline value for each parameter */
    retain BASE;
    
    if first.PARAMCD then BASE = .;
    
    if ABLFL = 'Y' and not missing(AVAL) then BASE = AVAL;
    
    /* Carry forward baseline */
    if not missing(BASE) then output;
run;

/* Merge baseline back to all records */
proc sql;
    create table adlb_with_base as
    select a.*, b.BASE
    from adlb_base as a
    left join (select distinct USUBJID, PARAMCD, BASE 
               from adlb_bl where not missing(BASE)) as b
    on a.USUBJID = b.USUBJID and a.PARAMCD = b.PARAMCD
    order by USUBJID, PARAMCD, ADY;
quit;

/* ========================================
   STEP 4: Derive Change from Baseline
   ======================================== */

title "NEXICART-2 ADLB: Calculate Change from Baseline";

data adlb_chg;
    set adlb_with_base;
    
    /* Change from baseline */
    if not missing(AVAL) and not missing(BASE) then do;
        CHG = AVAL - BASE;
        
        /* Percent change from baseline */
        if BASE > 0 then PCHG = (CHG / BASE) * 100;
        else PCHG = .;
        
        /* Absolute reduction from baseline (for PR criteria) */
        if BASE > 0 then PCHGRED = -PCHG;
        else PCHGRED = .;
    end;
    
    label BASE = "Baseline Value"
          CHG = "Change from Baseline"
          PCHG = "Percent Change from Baseline (%)"
          PCHGRED = "Percent Reduction from Baseline (%)";
run;

/* ========================================
   STEP 5: CRITICAL - NADIR CALCULATION
   Purpose: Track cumulative minimum for PD assessment
   ======================================== */

title "NEXICART-2 ADLB: CRITICAL - Derive Nadir (Cumulative Minimum)";

/* Isolate post-baseline records for nadir tracking */
data adlb_postbl;
    set adlb_chg;
    where ABLFL ne 'Y' and not missing(AVAL) and ADY > 0;
run;

proc sort data=adlb_postbl; by USUBJID PARAMCD ADY; run;

/* Calculate cumulative minimum (running nadir) using RETAIN */
data adlb_nadir;
    set adlb_postbl;
    by USUBJID PARAMCD ADY;
    
    retain NADIR NADIRDY;
    
    /* Initialize nadir at first post-baseline record */
    if first.PARAMCD then do;
        NADIR = AVAL;
        NADIRDY = ADY;
    end;
    else do;
        /* Update nadir if current value is lower */
        if AVAL < NADIR then do;
            NADIR = AVAL;
            NADIRDY = ADY;
        end;
    end;
    
    /* Flag if current record IS the nadir */
    length NADIRF $1;
    if abs(AVAL - NADIR) < 0.001 and ADY = NADIRDY then NADIRF = 'Y';
    else NADIRF = '';
    
    label NADIR = "Nadir Value (Lowest Post-Baseline)"
          NADIRDY = "Study Day of Nadir"
          NADIRF = "Nadir Record Flag (Y=Nadir Timepoint)";
run;

/* ========================================
   STEP 6: Derive Change from Nadir
   Purpose: Required for IMWG PD criteria
   ======================================== */

title "NEXICART-2 ADLB: Calculate Change from Nadir (for PD assessment)";

data adlb_nadir_chg;
    set adlb_nadir;
    
    /* Change from nadir */
    if not missing(AVAL) and not missing(NADIR) then do;
        CHGNADIR = AVAL - NADIR;
        
        /* Percent change from nadir */
        if NADIR > 0 then PCHGNADIR = (CHGNADIR / NADIR) * 100;
        else PCHGNADIR = .;
        
        /* Percent reduction from nadir (negative for improvement) */
        PCHGREDNADIR = -PCHGNADIR;
    end;
    
    label CHGNADIR = "Change from Nadir"
          PCHGNADIR = "Percent Change from Nadir (%)"
          PCHGREDNADIR = "Percent Reduction from Nadir (%)";
run;

/* ========================================
   STEP 7: Combine Baseline and Post-Baseline
   ======================================== */

data adlb_combined;
    set adlb_chg(where=(ABLFL='Y'))  /* Baseline records without nadir */
        adlb_nadir_chg;               /* Post-baseline with nadir */
run;

proc sort data=adlb_combined; by USUBJID PARAMCD ADY; run;

/* ========================================
   STEP 8: Analysis Flags and Final Variables
   ======================================== */

title "NEXICART-2 ADLB: Derive Analysis Flags";

data adlb;
    set adlb_combined;
    
    /* ANL01FL: General analysis flag */
    length ANL01FL $1;
    if not missing(AVAL) then ANL01FL = 'Y';
    else ANL01FL = '';
    
    /* ANL02FL: Post-baseline analysis flag */
    length ANL02FL $1;
    if ADY > 0 and not missing(AVAL) then ANL02FL = 'Y';
    else ANL02FL = '';
    
    /* ANL03FL: Baseline and post-baseline (for CFB analysis) */
    length ANL03FL $1;
    if ANL01FL = 'Y' and not missing(BASE) then ANL03FL = 'Y';
    else ANL03FL = '';
    
    /* DTYPE: Derivation type for derived parameters */
    length DTYPE $20;
    if PARAMCD in ('DFLC','FLCRATIO') then DTYPE = 'DERIVED';
    else DTYPE = '';
    
    /* AVISIT: Analysis visit (same as VISIT) */
    length AVISIT $200;
    AVISIT = VISIT;
    AVISITN = VISITNUM;
    
    /* Sequence number */
    ASEQ = _N_;
    
    label ANL01FL = "Analysis Flag 01 (All Valid Records)"
          ANL02FL = "Analysis Flag 02 (Post-Baseline Only)"
          ANL03FL = "Analysis Flag 03 (With Baseline for CFB)"
          DTYPE = "Derivation Type"
          AVISIT = "Analysis Visit"
          AVISITN = "Analysis Visit (N)"
          ASEQ = "Analysis Sequence Number";
run;

/* ========================================
   STEP 9: QC VALIDATION - Verify Nadir Logic
   ======================================== */

title "NEXICART-2 ADLB QC: Nadir Verification for dFLC (Primary Endpoint)";
title2 "Patient-Level Detail: Verify NADIR = min(post-baseline AVAL)";

proc print data=adlb(where=(PARAMCD='DFLC' and 
                            USUBJID in ('NEXICART2-001','NEXICART2-002','NEXICART2-003')));
    by USUBJID;
    id USUBJID;
    var AVISIT ADY AVAL BASE CHG PCHG NADIR NADIRDY NADIRF CHGNADIR PCHGNADIR;
    format AVAL BASE NADIR 8.1 PCHG PCHGNADIR 8.1;
run;

/* QC Check: Validate that NADIR matches true minimum */
proc sql;
    create table nadir_validation as
    select USUBJID, PARAMCD, 
           min(AVAL) as TRUE_MIN label="True Minimum (Post-Baseline)",
           max(NADIR) as RECORDED_NADIR label="Recorded NADIR",
           abs(calculated TRUE_MIN - calculated RECORDED_NADIR) as DIFF,
           case when calculated DIFF <= 0.001 then 'PASS' 
                else 'FAIL' end as QC_STATUS
    from adlb
    where ANL02FL = 'Y' and not missing(AVAL) and not missing(NADIR)
    group by USUBJID, PARAMCD;
quit;

title "NEXICART-2 ADLB QC: Nadir Calculation Validation";
title2 "Expected: NADIR = min(post-baseline AVAL) for each patient-parameter";

proc print data=nadir_validation;
    var USUBJID PARAMCD TRUE_MIN RECORDED_NADIR DIFF QC_STATUS;
    format TRUE_MIN RECORDED_NADIR DIFF 8.2;
run;

/* Flag QC failures */
%macro check_nadir_qc;
    %let nfail=0;
    proc sql noprint;
        select count(*) into :nfail trimmed
        from nadir_validation
        where QC_STATUS = 'FAIL';
    quit;
    
    %if &nfail > 0 %then %do;
        %put ERROR: ========================================;
        %put ERROR: &nfail NADIR CALCULATION DISCREPANCIES DETECTED;
        %put ERROR: Review nadir_validation dataset for details;
        %put ERROR: QC VALIDATION FAILED;
        %put ERROR: ========================================;
    %end;
    %else %do;
        %put NOTE: ============================================;
        %put NOTE: ✓ QC VALIDATION PASSED;
        %put NOTE: ✓ All nadir calculations validated;
        %put NOTE: ✓ NADIR = min(post-baseline AVAL) confirmed;
        %put NOTE: ============================================;
    %end;
%mend;

%check_nadir_qc;

/* ========================================
   STEP 10: Summary Statistics
   ======================================== */

title "NEXICART-2 ADLB Summary: Baseline Biomarker Values";
title2 "Key AL Amyloidosis Markers: dFLC, Cardiac Biomarkers, Renal Function";

proc means data=adlb(where=(ABLFL='Y' and PARAMCD in ('DFLC','NTPROBNP','TROPHS','EGFR','PROT24H'))) 
           n mean median min max stddev maxdec=1;
    class PARAMCD AVALU;
    var AVAL;
run;

title "NEXICART-2 ADLB Summary: Nadir Achievement by Parameter";
title2 "Count of Patients Achieving Nadir for Each Biomarker";

proc freq data=adlb(where=(NADIRF='Y'));
    tables PARAMCD*AVISIT / nocol nopercent;
run;

/* ========================================
   STEP 11: Export Datasets
   ======================================== */

title "NEXICART-2 ADLB: Export Final Dataset";

proc export data=adlb 
            outfile="../../adam/data/adlb.csv" 
            dbms=csv replace; 
run;

libname xptout xport "../../adam/data/xpt/adlb.xpt";
data xptout.adlb;
    set adlb;
run;

proc contents data=adlb varnum;
    title "NEXICART-2 ADLB: Dataset Contents";
run;

%put NOTE: ============================================;
%put NOTE: ADLB dataset created successfully;
%put NOTE: Key features:;
%put NOTE:   - Baseline values (BASE, ABLFL);
%put NOTE:   - Change from baseline (CHG, PCHG);
%put NOTE:   - Nadir tracking (NADIR, NADIRDY, NADIRF);
%put NOTE:   - Change from nadir (CHGNADIR, PCHGNADIR);
%put NOTE:   - Analysis flags (ANL01FL-ANL03FL);
%put NOTE: Output: adam/data/adlb.csv, adam/data/xpt/adlb.xpt;
%put NOTE: ============================================;
