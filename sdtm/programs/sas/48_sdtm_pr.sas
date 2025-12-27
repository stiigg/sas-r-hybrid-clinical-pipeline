/******************************************************************************
* Program: 48_sdtm_pr.sas (PRODUCTION VERSION 1.0)
* Purpose: Generate FDA-compliant SDTM PR (Procedures) domain for NEXICART-2
* Author:  Christian Baghai
* Date:    2025-12-27
* Input:   sdtm/data/raw/procedures_raw.csv
* Output:  sdtm/data/csv/pr.csv, sdtm/data/xpt/pr.xpt
* 
* Priority: CRITICAL - MRD assessment, cardiac response, CAR-T flow tracking
* Standards: SDTM IG v3.4, FDA Technical Conformance Guide v5.0
* Notes:   - MRD flow cytometry at 10^-5 and 10^-6 sensitivity
*          - Echocardiography for cardiac response (60% patients with cardiac involvement)
*          - Apheresis and CAR-T infusion procedure tracking
******************************************************************************/

%let STUDYID = NEXICART-2;
%let DOMAIN = PR;

%global validation_errors validation_warnings;
%let validation_errors = NO;
%let validation_warnings = NO;

libname raw "../../data/raw";
libname sdtm "../../data/csv";

proc printto log="../../logs/48_sdtm_pr.log" new;
run;

%put NOTE: ============================================================;
%put NOTE: Starting PR domain generation for NEXICART-2;
%put NOTE: Study: &STUDYID;
%put NOTE: Timestamp: %sysfunc(datetime(), datetime20.);
%put NOTE: ============================================================;

/******************************************************************************
* STEP 1: IMPORT RAW PROCEDURES DATA
******************************************************************************/
proc import datafile="../../data/raw/procedures_raw.csv"
    out=raw_pr
    dbms=csv
    replace;
    guessingrows=max;
run;

/******************************************************************************
* STEP 2: GET REFERENCE START DATE FROM DM DOMAIN
******************************************************************************/
proc sql noprint;
    create table dm_dates as
    select USUBJID, RFSTDTC
    from sdtm.dm;
    
    select count(*) into :dm_count trimmed from dm_dates;
quit;

%put NOTE: Retrieved reference dates for &dm_count subjects from DM;

/******************************************************************************
* STEP 3: TRANSFORM RAW DATA TO SDTM PR STRUCTURE
******************************************************************************/
data pr_base;
    merge raw_pr(in=a)
          dm_dates(in=b);
    by USUBJID;
    
    if a;
    
    /* Convert RFSTDTC once for efficiency */
    if not missing(RFSTDTC) then RFSTDT = input(RFSTDTC, yymmdd10.);
    
    /*=========================================================================
    * IDENTIFIERS
    *========================================================================*/
    length STUDYID $20 DOMAIN $2 USUBJID $40;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    PRSEQ = _N_;
    
    /*=========================================================================
    * TOPIC VARIABLE - PROCEDURE TEST
    *========================================================================*/
    length PRTESTCD $8 PRTEST $200;
    PRTESTCD = upcase(strip(PROC_CODE));
    
    /* Standardize test names */
    select (PRTESTCD);
        when ('BMBIOPSY') PRTEST = 'BONE MARROW BIOPSY';
        when ('MRDFLOW5') PRTEST = 'MRD BY FLOW CYTOMETRY (10^-5 SENSITIVITY)';
        when ('MRDFLOW6') PRTEST = 'MRD BY FLOW CYTOMETRY (10^-6 SENSITIVITY)';
        when ('ECHO') PRTEST = 'ECHOCARDIOGRAM';
        when ('LVEF') PRTEST = 'LEFT VENTRICULAR EJECTION FRACTION';
        when ('WALLTHK') PRTEST = 'LEFT VENTRICULAR WALL THICKNESS';
        when ('STRAIN') PRTEST = 'GLOBAL LONGITUDINAL STRAIN';
        when ('APHERESIS') PRTEST = 'LEUKAPHERESIS';
        when ('CARTINF') PRTEST = 'CAR-T CELL INFUSION';
        when ('FISHCYT') PRTEST = 'FLUORESCENCE IN SITU HYBRIDIZATION';
        when ('T1114') PRTEST = 'T(11;14) TRANSLOCATION STATUS';
        when ('GAIN1Q') PRTEST = 'GAIN 1Q STATUS';
        when ('DEL17P') PRTEST = 'DEL(17P) STATUS';
        otherwise PRTEST = upcase(strip(PROC_NAME));
    end;
    
    /*=========================================================================
    * GROUPING QUALIFIERS - CATEGORY
    *========================================================================*/
    length PRCAT $40;
    
    if PRTESTCD in ('BMBIOPSY', 'MRDFLOW5', 'MRDFLOW6') then 
        PRCAT = 'BONE MARROW ASSESSMENT';
    else if PRTESTCD in ('ECHO', 'LVEF', 'WALLTHK', 'STRAIN') then 
        PRCAT = 'CARDIAC ASSESSMENT';
    else if PRTESTCD in ('APHERESIS', 'CARTINF') then 
        PRCAT = 'CAR-T THERAPY';
    else if PRTESTCD in ('FISHCYT', 'T1114', 'GAIN1Q', 'DEL17P') then 
        PRCAT = 'CYTOGENETICS';
    else PRCAT = upcase(strip(PROC_CATEGORY));
    
    /*=========================================================================
    * RESULT QUALIFIERS - ORIGINAL RESULTS
    *========================================================================*/
    length PRORRES $200 PRORRESU $20;
    
    /* Results as collected */
    if not missing(RESULT_VALUE) then do;
        /* Numeric results */
        if not missing(input(RESULT_VALUE, ?? best.)) then 
            PRORRES = strip(put(input(RESULT_VALUE, best.), best.));
        /* Character results (POSITIVE/NEGATIVE, PRESENT/ABSENT) */
        else PRORRES = upcase(strip(RESULT_VALUE));
    end;
    
    /* Original units */
    if not missing(RESULT_UNIT) then 
        PRORRESU = upcase(strip(RESULT_UNIT));
    
    /*=========================================================================
    * STANDARDIZED RESULTS
    *========================================================================*/
    length PRSTRESC $200 PRSTRESU $20;
    
    /* MRD Results - Convert to standardized format */
    if PRTESTCD in ('MRDFLOW5', 'MRDFLOW6') then do;
        if upcase(PRORRES) in ('NEGATIVE', 'NEG', 'NOT DETECTED') then do;
            PRSTRESC = 'NEGATIVE';
            PRSTRESN = .;  /* Below detection limit */
        end;
        else if upcase(PRORRES) in ('POSITIVE', 'POS', 'DETECTED') then do;
            PRSTRESC = 'POSITIVE';
            /* Store sensitivity level as numeric */
            if PRTESTCD = 'MRDFLOW5' then PRSTRESN = 0.00001;  /* 10^-5 */
            else if PRTESTCD = 'MRDFLOW6' then PRSTRESN = 0.000001;  /* 10^-6 */
        end;
        PRSTRESU = 'FRACTION';
    end;
    
    /* Echocardiography Results */
    else if PRTESTCD = 'LVEF' then do;
        PRSTRESC = strip(put(input(PRORRES, best.), best.));
        PRSTRESN = input(PRSTRESC, best.);
        PRSTRESU = 'PERCENT';
    end;
    
    else if PRTESTCD = 'WALLTHK' then do;
        PRSTRESC = strip(put(input(PRORRES, best.), best.));
        PRSTRESN = input(PRSTRESC, best.);
        PRSTRESU = 'mm';
    end;
    
    else if PRTESTCD = 'STRAIN' then do;
        PRSTRESC = strip(put(input(PRORRES, best.), best.));
        PRSTRESN = input(PRSTRESC, best.);
        PRSTRESU = 'PERCENT';
    end;
    
    /* Apheresis - CD34+ cell count */
    else if PRTESTCD = 'APHERESIS' then do;
        PRSTRESC = strip(put(input(PRORRES, best.), best.));
        PRSTRESN = input(PRSTRESC, best.);
        PRSTRESU = 'CELLS/uL';
    end;
    
    /* CAR-T Infusion - Dose */
    else if PRTESTCD = 'CARTINF' then do;
        PRSTRESC = strip(put(input(PRORRES, best.), best.));
        PRSTRESN = input(PRSTRESC, best.);
        PRSTRESU = 'CAR+ T CELLS';
    end;
    
    /* Cytogenetics - PRESENT/ABSENT */
    else if PRTESTCD in ('T1114', 'GAIN1Q', 'DEL17P') then do;
        if upcase(PRORRES) in ('PRESENT', 'POSITIVE', 'YES', 'Y') then 
            PRSTRESC = 'PRESENT';
        else if upcase(PRORRES) in ('ABSENT', 'NEGATIVE', 'NO', 'N') then 
            PRSTRESC = 'ABSENT';
        else PRSTRESC = upcase(PRORRES);
        PRSTRESU = '';
    end;
    
    /* Other results - pass through */
    else do;
        PRSTRESC = PRORRES;
        PRSTRESN = input(PRSTRESC, ?? best.);
        PRSTRESU = PRORRESU;
    end;
    
    /*=========================================================================
    * METHOD
    *========================================================================*/
    length PRMETHOD $200;
    
    if PRTESTCD = 'LVEF' then 
        PRMETHOD = 'BIPLANE SIMPSON METHOD';
    else if PRTESTCD = 'STRAIN' then 
        PRMETHOD = 'SPECKLE TRACKING ECHOCARDIOGRAPHY';
    else if PRTESTCD in ('MRDFLOW5', 'MRDFLOW6') then 
        PRMETHOD = 'MULTICOLOR FLOW CYTOMETRY';
    else if PRTESTCD in ('T1114', 'GAIN1Q', 'DEL17P') then 
        PRMETHOD = 'FLUORESCENCE IN SITU HYBRIDIZATION';
    else if not missing(METHOD) then 
        PRMETHOD = upcase(strip(METHOD));
    
    /*=========================================================================
    * TIMING VARIABLES
    *========================================================================*/
    length PRDTC $20;
    
    if not missing(PROC_DATE) then do;
        if not missing(PROC_TIME) then
            PRDTC = put(PROC_DATE, yymmdd10.) || 'T' || 
                    put(PROC_TIME, time8.);
        else
            PRDTC = put(PROC_DATE, yymmdd10.);
    end;
    
    /* Study Day Calculation */
    if not missing(PROC_DATE) and not missing(RFSTDT) then do;
        if PROC_DATE >= RFSTDT then 
            PRDY = PROC_DATE - RFSTDT + 1;
        else 
            PRDY = PROC_DATE - RFSTDT;
    end;
    
    /* Validate study day */
    if PRDY = 0 then do;
        put "ERROR: PRDY=0 (impossible) for" USUBJID= PRSEQ= PRTESTCD= PRDTC=;
        call symputx('validation_errors', 'YES');
    end;
    
    /*=========================================================================
    * VISIT INFORMATION
    *========================================================================*/
    length VISIT $40;
    if not missing(VISIT_NAME) then 
        VISIT = upcase(strip(VISIT_NAME));
    VISITNUM = VISIT_NUMBER;
    
    /*=========================================================================
    * REFERENCE RANGES FOR ECHO PARAMETERS
    *========================================================================*/
    if PRTESTCD = 'LVEF' then do;
        PRSTNRLO = 50;  /* Normal LVEF ≥50% */
        PRSTNRHI = .;
    end;
    else if PRTESTCD = 'WALLTHK' then do;
        PRSTNRLO = .;
        PRSTNRHI = 12;  /* Abnormal if >12mm (cardiac amyloidosis) */
    end;
    
    /* Normal range indicator */
    length PRNRIND $8;
    if not missing(PRSTRESN) and not missing(PRSTNRLO) and not missing(PRSTNRHI) then do;
        if PRSTRESN < PRSTNRLO then PRNRIND = "LOW";
        else if PRSTRESN > PRSTNRHI then PRNRIND = "HIGH";
        else PRNRIND = "NORMAL";
    end;
    else if not missing(PRSTRESN) and not missing(PRSTNRLO) and missing(PRSTNRHI) then do;
        if PRSTRESN < PRSTNRLO then PRNRIND = "LOW";
        else PRNRIND = "NORMAL";
    end;
    else if not missing(PRSTRESN) and missing(PRSTNRLO) and not missing(PRSTNRHI) then do;
        if PRSTRESN > PRSTNRHI then PRNRIND = "HIGH";
        else PRNRIND = "NORMAL";
    end;
    
    drop RFSTDT;
run;

%put NOTE: PR transformation completed;

/******************************************************************************
* STEP 4: CREATE FINAL PR DOMAIN
******************************************************************************/
data pr;
    set pr_base;
    
    keep 
        /* Identifiers */
        STUDYID DOMAIN USUBJID PRSEQ
        /* Topic */
        PRTESTCD PRTEST
        /* Grouping Qualifiers */
        PRCAT
        /* Result Qualifiers */
        PRORRES PRORRESU PRSTRESC PRSTRESN PRSTRESU
        PRSTNRLO PRSTNRHI PRNRIND
        PRMETHOD
        /* Timing */
        PRDTC PRDY VISIT VISITNUM;
run;

proc sql noprint;
    select count(*) into :pr_count trimmed from pr;
    select count(distinct USUBJID) into :subj_count trimmed from pr;
quit;

%put NOTE: PR domain created with &pr_count records for &subj_count subjects;

/******************************************************************************
* STEP 5: SORT BY KEY VARIABLES
******************************************************************************/
proc sort data=pr;
    by USUBJID PRSEQ;
run;

/******************************************************************************
* STEP 6: DATA QUALITY CHECKS
******************************************************************************/

%put NOTE: ============================================================;
%put NOTE: Running data quality checks;
%put NOTE: ============================================================;

/* QC Check 1: Frequency distributions */
title "QC Check 1: Procedure Categories and Tests";
proc freq data=pr;
    tables PRCAT PRTESTCD*PRCAT / nocol nopercent missing;
run;
title;

/* QC Check 2: MRD Assessment Summary */
title "QC Check 2: MRD Negativity by Sensitivity Level";
proc sql;
    create table qc_mrd as
    select 
        PRTESTCD,
        PRSTRESC,
        count(distinct USUBJID) as N_PATIENTS,
        count(*) as N_ASSESSMENTS
    from pr
    where PRTESTCD in ('MRDFLOW5', 'MRDFLOW6')
    group by PRTESTCD, PRSTRESC;
    
    select * from qc_mrd;
quit;
title;

/* QC Check 3: Missing required variables */
data qc_missing_required;
    set pr;
    length error_type $100;
    
    if missing(STUDYID) then do;
        error_type = "Missing STUDYID";
        output;
    end;
    if missing(DOMAIN) then do;
        error_type = "Missing DOMAIN";
        output;
    end;
    if missing(USUBJID) then do;
        error_type = "Missing USUBJID";
        output;
    end;
    if missing(PRSEQ) then do;
        error_type = "Missing PRSEQ";
        output;
    end;
    if missing(PRTESTCD) then do;
        error_type = "Missing PRTESTCD";
        output;
    end;
run;

proc sql noprint;
    select count(*) into :missing_req trimmed from qc_missing_required;
quit;

%if &missing_req > 0 %then %do;
    %put ERROR: &missing_req records with missing required variables!;
    %let validation_errors = YES;
    
    title "ERROR: Missing Required Variables";
    proc print data=qc_missing_required (obs=50);
        var USUBJID PRSEQ PRTESTCD error_type;
    run;
    title;
%end;
%else %do;
    %put NOTE: All required variables populated;
%end;

%put NOTE: Data quality checks completed;

/******************************************************************************
* STEP 7: EXPORT TO CSV
******************************************************************************/
proc export data=pr
    outfile="../../data/csv/pr.csv"
    dbms=csv
    replace;
run;

%put NOTE: CSV file exported successfully;

/******************************************************************************
* STEP 8: EXPORT TO XPT v5 FORMAT
******************************************************************************/
libname xptout xport "../../data/xpt/pr.xpt";
data xptout.pr;
    set pr;
run;
libname xptout clear;

%put NOTE: XPT file exported successfully;

/******************************************************************************
* STEP 9: FINAL LOGGING AND VALIDATION STATUS
******************************************************************************/

%put NOTE: ============================================================;
%put NOTE: PR DOMAIN GENERATION COMPLETED;
%put NOTE: ============================================================;
%put NOTE: Output files created:;
%put NOTE:   CSV: ../../data/csv/pr.csv (&pr_count records);
%put NOTE:   XPT: ../../data/xpt/pr.xpt;
%put NOTE: ============================================================;
%put NOTE: Summary Statistics:;
%put NOTE:   Total PR records: &pr_count;
%put NOTE:   Subjects with procedures: &subj_count;
%put NOTE: ============================================================;

/* Validation Status Report */
%if &validation_errors = YES %then %do;
    %put ERROR: *** VALIDATION ERRORS DETECTED ***;
    %put ERROR: Review log and QC outputs before proceeding;
    %put ERROR: Program completed with ERRORS;
%end;
%else %if &validation_warnings = YES %then %do;
    %put WARNING: Validation warnings detected;
    %put WARNING: Review log for details;
    %put NOTE: Program completed with WARNINGS;
%end;
%else %do;
    %put NOTE: *** ALL VALIDATION CHECKS PASSED ***;
    %put NOTE: Program completed successfully;
%end;

%put NOTE: ============================================================;

proc printto;
run;
