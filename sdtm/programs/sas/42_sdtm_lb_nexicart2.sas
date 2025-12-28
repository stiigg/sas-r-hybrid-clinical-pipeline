/******************************************************************************
* Program: 42_sdtm_lb_nexicart2.sas
* Purpose: Generate SDTM LB domain with AL amyloidosis biomarkers
* Author:  Christian Baghai
* Date:    2025-12-28
* Version: 2.0 - NEXICART-2 enhancements
* 
* Input:   sdtm/data/raw/lab_results_nexicart2.csv
* Output:  sdtm/data/csv/lb.csv, sdtm/data/xpt/lb.xpt
* 
* Priority: CRITICAL - Primary efficacy endpoint (dFLC)
* Validation: QC against manual dFLC calculation (3 subjects minimum)
* 
* Notes:   Implements ISA 2012 consensus criteria for hematologic response
*          Includes cardiac biomarkers (NT-proBNP, troponin) for organ response
*          Tracks cytokine panel for CRS grading algorithm
******************************************************************************/

%let STUDYID = NEXICART2-AL-AMYLOIDOSIS;
%let DOMAIN = LB;

libname raw "../../data/raw";
libname sdtm "../../data/csv";

/* ========================================
   STEP 1: Import and Validate Raw Data
   ======================================== */

proc import datafile="../../data/raw/lab_results_nexicart2.csv"
    out=raw_lb dbms=csv replace;
    guessingrows=max;
run;

/* Data Quality Check: Ensure light chain type consistency */
proc sql;
    create table lc_type_check as
    select USUBJID, count(distinct LIGHT_CHAIN_TYPE) as n_lc_types
    from raw_lb
    where not missing(LIGHT_CHAIN_TYPE)
    group by USUBJID
    having calculated n_lc_types > 1;
quit;

%macro check_lc_consistency;
    %let nobs=0;
    data _null_;
        set lc_type_check nobs=n;
        call symputx('nobs', n);
    run;
    
    %if &nobs > 0 %then %do;
        %put ERROR: Inconsistent light chain type assignments detected;
        %put ERROR: Check USUBJID values in lc_type_check dataset;
        %abort cancel;
    %end;
    %else %put NOTE: Light chain type consistency check passed;
%mend;

%check_lc_consistency;

/* Merge with demographics for study day calculation */
proc sql noprint;
    create table dm_dates as
    select USUBJID, RFSTDTC,
           case(upcase(strip(LIGHT_CHAIN_TYPE)))
               when 'LAMBDA' then 'λ'
               when 'KAPPA' then 'κ'
               else LIGHT_CHAIN_TYPE
           end as LC_TYPE_STANDARD
    from sdtm.dm;
quit;

/* ========================================
   STEP 2: Create Base LB Records
   ======================================== */

data lb_base;
    merge raw_lb(in=a) dm_dates(in=b);
    by USUBJID;
    if a;
    
    length STUDYID $50 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    LBSEQ = .; /* Renumbered after dFLC derivation */
    
    /* Test identification */
    length LBTESTCD $8 LBTEST $200;
    LBTESTCD = upcase(strip(LAB_TEST_CODE));
    
    /* Expand test names per CDISC controlled terminology */
    if LBTESTCD = 'KAPPA' then LBTEST = 'Immunoglobulin Kappa Free Light Chain';
    else if LBTESTCD = 'LAMBDA' then LBTEST = 'Immunoglobulin Lambda Free Light Chain';
    else if LBTESTCD = 'DFLC' then LBTEST = 'Difference in Free Light Chains';
    else if LBTESTCD = 'FLCRATIO' then LBTEST = 'Kappa/Lambda Free Light Chain Ratio';
    else if LBTESTCD = 'NTPROBNP' then LBTEST = 'N-Terminal proBNP';
    else if LBTESTCD = 'TROPHS' then LBTEST = 'High-Sensitivity Cardiac Troponin';
    else if LBTESTCD = 'PROT24H' then LBTEST = '24-Hour Urine Protein';
    else if LBTESTCD = 'EGFR' then LBTEST = 'Estimated Glomerular Filtration Rate';
    else if LBTESTCD = 'SIF' then LBTEST = 'Serum Immunofixation Electrophoresis';
    else if LBTESTCD = 'UIF' then LBTEST = 'Urine Immunofixation Electrophoresis';
    else if LBTESTCD = 'IL6' then LBTEST = 'Interleukin-6';
    else if LBTESTCD = 'IL10' then LBTEST = 'Interleukin-10';
    else if LBTESTCD = 'IFNGAMMA' then LBTEST = 'Interferon Gamma';
    else if LBTESTCD = 'CD19' then LBTEST = 'CD19 Positive B Lymphocytes';
    else if LBTESTCD = 'CART' then LBTEST = 'CAR-T Cell Copies';
    else if LBTESTCD = 'CREAT' then LBTEST = 'Serum Creatinine';
    else if not missing(LAB_TEST_NAME) then LBTEST = upcase(strip(LAB_TEST_NAME));
    
    /* Category with AL amyloidosis-specific panels */
    length LBCAT $50;
    LBCAT = case(upcase(strip(LAB_PANEL)))
        when 'SERUM FREE LIGHT CHAINS' then 'SERUM FREE LIGHT CHAINS'
        when 'CARDIAC BIOMARKERS' then 'CARDIAC BIOMARKERS'
        when 'RENAL FUNCTION' then 'RENAL FUNCTION'
        when 'IMMUNOFIXATION' then 'IMMUNOFIXATION'
        when 'CYTOKINE PANEL' then 'CYTOKINE PANEL'
        when 'B-CELL RECOVERY' then 'B-CELL RECOVERY'
        when 'CAR-T PHARMACOKINETICS' then 'CAR-T PHARMACOKINETICS'
        when 'HEMATOLOGY' then 'HEMATOLOGY'
        when 'CHEMISTRY' then 'CHEMISTRY'
        else upcase(strip(LAB_PANEL))
    end;
    
    /* Sub-category for CRS monitoring */
    length LBSCAT $50;
    if LBTESTCD in ('IL6','IL10','IFNGAMMA') then
        LBSCAT = 'CRS MONITORING';
    else if LBTESTCD in ('CD19','CD3') then
        LBSCAT = 'IMMUNE RECONSTITUTION';
    
    /* Method tracking */
    length LBMETHOD $50;
    if not missing(LAB_METHOD) then
        LBMETHOD = upcase(strip(LAB_METHOD));
    
    /* Results as collected */
    length LBORRES $200 LBORRESU $20;
    if not missing(LAB_RESULT) then
        LBORRES = strip(LAB_RESULT);
    if not missing(LAB_UNIT) then
        LBORRESU = upcase(strip(LAB_UNIT));
    
    /* Standardized results */
    length LBSTRESC $200 LBSTRESU $20;
    LBSTRESC = LBORRES;
    
    /* Handle qualitative results */
    if LBTESTCD in ('SIF','UIF') then do;
        if upcase(LBSTRESC) in ('POSITIVE','POS','+') then LBSTRESC = 'POSITIVE';
        else if upcase(LBSTRESC) in ('NEGATIVE','NEG','-') then LBSTRESC = 'NEGATIVE';
        LBSTRESN = .;
    end;
    else do;
        LBSTRESN = input(LBSTRESC, best.);
    end;
    
    LBSTRESU = LBORRESU;
    
    /* Reference ranges */
    if not missing(NORMAL_RANGE_LOW) then
        LBSTNRLO = input(strip(NORMAL_RANGE_LOW), best.);
    if not missing(NORMAL_RANGE_HIGH) then
        LBSTNRHI = input(strip(NORMAL_RANGE_HIGH), best.);
    
    /* Normal range indicator with clinical interpretation */
    length LBNRIND $20;
    if LBTESTCD in ('SIF','UIF') then do;
        if LBSTRESC = 'NEGATIVE' then LBNRIND = 'NORMAL';
        else if LBSTRESC = 'POSITIVE' then LBNRIND = 'ABNORMAL';
    end;
    else if not missing(LBSTRESN) and not missing(LBSTNRLO) and not missing(LBSTNRHI) then do;
        if LBSTRESN < LBSTNRLO then do;
            LBNRIND = 'LOW';
            if LBTESTCD = 'CD19' and LBSTRESN < 10 then LBNRIND = 'LOW, CS';
            if LBTESTCD = 'EGFR' and LBSTRESN < 30 then LBNRIND = 'LOW, CS';
        end;
        else if LBSTRESN > LBSTNRHI then do;
            LBNRIND = 'HIGH';
            if LBTESTCD = 'NTPROBNP' and LBSTRESN > 8500 then LBNRIND = 'HIGH, CS';
            if LBTESTCD = 'TROPHS' and LBSTRESN > 0.05 then LBNRIND = 'HIGH, CS';
            if LBTESTCD = 'IL6' and LBSTRESN > 100 then LBNRIND = 'HIGH, CS';
            if LBTESTCD = 'PROT24H' and LBSTRESN > 5 then LBNRIND = 'HIGH, CS';
        end;
        else LBNRIND = 'NORMAL';
    end;
    
    /* Timing variables */
    length LBDTC $25;
    if not missing(COLLECTION_DATE) then do;
        if not missing(COLLECTION_TIME) then
            LBDTC = put(input(COLLECTION_DATE, yymmdd10.), yymmdd10.) || 'T' || 
                    put(input(COLLECTION_TIME, time5.), time8.);
        else
            LBDTC = put(input(COLLECTION_DATE, yymmdd10.), yymmdd10.);
    end;
    
    /* Study Day calculation */
    if not missing(COLLECTION_DATE) and not missing(RFSTDTC) then do;
        collection_dt = input(COLLECTION_DATE, yymmdd10.);
        rfst_dt = input(scan(RFSTDTC, 1, 'T'), yymmdd10.);
        
        if collection_dt >= rfst_dt then 
            LBDY = collection_dt - rfst_dt + 1;
        else 
            LBDY = collection_dt - rfst_dt;
    end;
    
    /* Visit mapping */
    length VISIT $200;
    if not missing(VISIT_NAME) then
        VISIT = upcase(strip(VISIT_NAME));
    if not missing(VISIT_NUMBER) then
        VISITNUM = input(strip(VISIT_NUMBER), best.);
    
    /* Light chain type */
    length LCLCTYPE $10;
    if not missing(LC_TYPE_STANDARD) then
        LCLCTYPE = LC_TYPE_STANDARD;
    label LCLCTYPE = "Light Chain Type (κ or λ)";
    
    keep STUDYID DOMAIN USUBJID LBTESTCD LBTEST LBCAT LBSCAT LBMETHOD
         LBORRES LBORRESU LBSTRESC LBSTRESN LBSTRESU
         LBSTNRLO LBSTNRHI LBNRIND 
         LBDTC LBDY VISIT VISITNUM LCLCTYPE
         collection_dt;
run;

/* ========================================
   STEP 3: Calculate Derived dFLC Values
   ======================================== */

proc sort data=lb_base; 
    by USUBJID collection_dt LBTESTCD;
run;

data flc_paired;
    set lb_base(where=(LBCAT = 'SERUM FREE LIGHT CHAINS' and 
                       LBTESTCD in ('KAPPA','LAMBDA') and
                       not missing(LBSTRESN)));
    by USUBJID collection_dt;
    
    retain kappa_val lambda_val kappa_unit kappa_method;
    
    if first.collection_dt then do;
        kappa_val = .;
        lambda_val = .;
        kappa_unit = '';
        kappa_method = '';
    end;
    
    if LBTESTCD = 'KAPPA' then do;
        kappa_val = LBSTRESN;
        kappa_unit = LBSTRESU;
        kappa_method = LBMETHOD;
    end;
    
    if LBTESTCD = 'LAMBDA' then do;
        lambda_val = LBSTRESN;
    end;
    
    if last.collection_dt then do;
        if not missing(kappa_val) and not missing(lambda_val) then output;
        else put "WARNING: Incomplete FLC pair for " USUBJID= collection_dt=;
    end;
    
    keep USUBJID collection_dt LBDTC LBDY VISIT VISITNUM LCLCTYPE
         kappa_val lambda_val kappa_unit kappa_method;
run;

/* Derive dFLC and FLC ratio */
data lb_dflc_derived;
    set flc_paired;
    
    length STUDYID $50 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    
    /* Determine involved vs uninvolved */
    if LCLCTYPE = 'λ' then do;
        involved_flc = lambda_val;
        uninvolved_flc = kappa_val;
    end;
    else if LCLCTYPE = 'κ' then do;
        involved_flc = kappa_val;
        uninvolved_flc = lambda_val;
    end;
    
    /* Calculate dFLC = involved - uninvolved */
    dflc_value = involved_flc - uninvolved_flc;
    
    /* Calculate FLC ratio (kappa/lambda) */
    if lambda_val > 0 then
        flc_ratio = kappa_val / lambda_val;
    
    output;
run;

/* Create dFLC records */
data lb_dflc_records;
    set lb_dflc_derived;
    
    /* dFLC record */
    LBTESTCD = 'DFLC';
    LBTEST = 'Difference in Free Light Chains';
    LBCAT = 'SERUM FREE LIGHT CHAINS';
    LBMETHOD = 'DERIVED FROM ' || strip(kappa_method);
    
    LBSTRESN = dflc_value;
    LBSTRESC = strip(put(dflc_value, 8.1));
    LBORRES = LBSTRESC;
    
    LBSTRESU = kappa_unit;
    LBORRESU = kappa_unit;
    
    LBSTNRHI = 40;
    LBSTNRLO = .;
    
    if LBSTRESN < 40 then LBNRIND = 'NORMAL';
    else LBNRIND = 'HIGH';
    
    if LBSTRESN >= 180 then LBNRIND = 'HIGH, CS';
    
    keep STUDYID DOMAIN USUBJID LBTESTCD LBTEST LBCAT LBMETHOD
         LBORRES LBORRESU LBSTRESC LBSTRESN LBSTRESU
         LBSTNRLO LBSTNRHI LBNRIND 
         LBDTC LBDY VISIT VISITNUM LCLCTYPE;
    
    output;
    
    /* FLC ratio record */
    LBTESTCD = 'FLCRATIO';
    LBTEST = 'Kappa/Lambda Free Light Chain Ratio';
    LBMETHOD = 'DERIVED FROM ' || strip(kappa_method);
    
    LBSTRESN = flc_ratio;
    LBSTRESC = strip(put(flc_ratio, 8.3));
    LBORRES = LBSTRESC;
    
    LBSTRESU = '';
    LBORRESU = '';
    
    LBSTNRLO = 0.26;
    LBSTNRHI = 1.65;
    
    if LBSTRESN >= 0.26 and LBSTRESN <= 1.65 then LBNRIND = 'NORMAL';
    else LBNRIND = 'ABNORMAL';
    
    output;
run;

/* ========================================
   STEP 4: Merge Base + Derived Records
   ======================================== */

data lb_combined;
    set lb_base(where=(LBTESTCD not in ('DFLC','FLCRATIO') or LBTESTCD=''))
        lb_dflc_records;
run;

proc sort data=lb_combined; 
    by USUBJID LBTESTCD collection_dt LBDY;
run;

/* ========================================
   STEP 5: Baseline Flag Derivation
   ======================================== */

data lb;
    set lb_combined;
    by USUBJID LBTESTCD;
    
    length LBBLFL $1;
    
    if first.LBTESTCD and not missing(LBSTRESN) and LBDY <= 1 then 
        LBBLFL = 'Y';
    
    if first.LBTESTCD and missing(LBSTRESN) and not missing(LBSTRESC) and LBDY <= 1 then
        LBBLFL = 'Y';
run;

/* Renumber LBSEQ */
data lb;
    set lb;
    LBSEQ = _N_;
run;

proc sort data=lb; by USUBJID LBSEQ; run;

/* ========================================
   STEP 6: Quality Control Reports
   ======================================== */

title "NEXICART-2 QC: dFLC Calculation Verification";
title2 "Manual Check: Lambda=involved → dFLC = Lambda - Kappa";
proc print data=lb(where=(LBTESTCD in ('KAPPA','LAMBDA','DFLC','FLCRATIO') and 
                          USUBJID in ('NEXICART2-001','NEXICART2-002','NEXICART2-003')));
    by USUBJID VISIT;
    id USUBJID;
    var VISIT LBTESTCD LBSTRESN LBSTRESU LBNRIND LBBLFL LCLCTYPE;
    format LBSTRESN 8.1;
run;

title "NEXICART-2 QC: Baseline Biomarker Summary";
proc means data=lb(where=(LBBLFL='Y' and not missing(LBSTRESN))) n mean median min max maxdec=1;
    class LBTESTCD;
    var LBSTRESN;
run;

title "NEXICART-2 QC: Biomarker Completeness by Visit";
proc freq data=lb;
    tables VISIT*LBCAT / missing nocol nopercent;
run;

title "NEXICART-2 QC: High-Risk Cardiac Patients";
proc print data=lb(where=(LBTESTCD='NTPROBNP' and LBBLFL='Y' and LBSTRESN > 8500));
    var USUBJID LBSTRESN LBNRIND VISIT;
run;

/* ========================================
   STEP 7: Export
   ======================================== */

proc export data=lb outfile="../../data/csv/lb.csv" dbms=csv replace; run;

libname xptout xport "../../data/xpt/lb.xpt";
data xptout.lb; 
    set lb;
    length STUDYID $12 DOMAIN $2 USUBJID $20 LBSEQ 8
           LBTESTCD $8 LBTEST $40 LBCAT $200 LBSCAT $200
           LBMETHOD $200 LBORRES $200 LBORRESU $8
           LBSTRESC $200 LBSTRESN 8 LBSTRESU $8
           LBSTNRLO 8 LBSTNRHI 8 LBNRIND $20
           LBBLFL $1 LBDTC $20 LBDY 8
           VISIT $200 VISITNUM 8;
run;
libname xptout clear;

%put NOTE: ====================================;
%put NOTE: LB domain generation completed;
%put NOTE: Total records created;
%put NOTE: Check QC reports for validation;
%put NOTE: ====================================;