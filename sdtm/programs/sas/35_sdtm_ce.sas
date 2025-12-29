/******************************************************************************
* Program: 35_sdtm_ce.sas
* Purpose: Generate SDTM CE (Clinical Events) domain for CRS/ICANS symptoms
* Author:  Christian Baghai
* Date:    2025-12-29
* Input:   data/raw/crs_icans_symptoms_raw.csv
* Output:  data/csv/ce.csv, data/csv/suppce.csv, data/xpt/ce.xpt, data/xpt/suppce.xpt
* 
* Priority: HIGH - Required for granular CAR-T toxicity analysis
* Standards: SDTM IG v3.3
* Reference: CE domain captures protocol-specified clinical endpoints
******************************************************************************/

%let STUDYID = CAR-T-DEMO-001;
%let DOMAIN = CE;

libname raw "../../data/raw";
libname sdtm "../../data/csv";

proc printto log="../../logs/35_sdtm_ce.log" new;
run;

%put NOTE: ============================================================;
%put NOTE: Starting CE domain generation for CAR-T symptoms;
%put NOTE: Study: &STUDYID;
%put NOTE: ============================================================;

/******************************************************************************
* STEP 1: READ RAW CRS/ICANS SYMPTOMS DATA
******************************************************************************/
proc import datafile="../../data/raw/crs_icans_symptoms_raw.csv"
    out=raw_symptoms
    dbms=csv
    replace;
    guessingrows=max;
run;

%put NOTE: Raw symptoms data imported;

/******************************************************************************
* STEP 2: GET REFERENCE DATES FROM DM DOMAIN
******************************************************************************/
proc sql noprint;
    create table dm_dates as
    select USUBJID, RFSTDTC
    from sdtm.dm;
quit;

/******************************************************************************
* STEP 3: TRANSFORM TO CE STRUCTURE
******************************************************************************/
data ce_base;
    merge raw_symptoms(in=a)
          dm_dates(in=b);
    by USUBJID;
    
    if a;
    
    /* Convert reference start date */
    if not missing(RFSTDTC) then RFSTDT = input(RFSTDTC, yymmdd10.);
    
    /*=========================================================================
    * IDENTIFIERS
    *========================================================================*/
    length STUDYID $20 DOMAIN $2 USUBJID $40;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    
    /* Sequence number */
    CESEQ = _N_;
    
    /*=========================================================================
    * TOPIC VARIABLE - Clinical Event Term
    *========================================================================*/
    length CETERM $200;
    CETERM = upcase(strip(SYMPTOM_NAME));
    
    /*=========================================================================
    * GROUPING QUALIFIERS
    *========================================================================*/
    length CECAT $200 CESCAT $200;
    
    /* Category based on parent toxicity */
    if upcase(strip(PARENT_TOXICITY_TYPE)) = 'CRS' then do;
        CECAT = 'CRS SIGN/SYMPTOM';
        CESCAT = upcase(strip(SYMPTOM_CATEGORY));  /* e.g., FEVER, HEMODYNAMIC, RESPIRATORY */
    end;
    else if upcase(strip(PARENT_TOXICITY_TYPE)) = 'ICANS' then do;
        CECAT = 'ICANS SIGN/SYMPTOM';
        CESCAT = upcase(strip(SYMPTOM_CATEGORY));  /* e.g., COGNITIVE, MOTOR, SEIZURE */
    end;
    
    /*=========================================================================
    * OCCURRENCE INDICATOR
    *========================================================================*/
    length CEOCCUR $1;
    CEOCCUR = 'Y';  /* All records in CE represent observed events */
    
    /*=========================================================================
    * TIMING VARIABLES
    *========================================================================*/
    length CESTDTC $20 CEENDTC $20;
    
    if not missing(SYMPTOM_START_DATE) then 
        CESTDTC = put(SYMPTOM_START_DATE, yymmdd10.);
    
    if not missing(SYMPTOM_END_DATE) then 
        CEENDTC = put(SYMPTOM_END_DATE, yymmdd10.);
    
    /* Study Day Calculation */
    if not missing(SYMPTOM_START_DATE) and not missing(RFSTDT) then do;
        if SYMPTOM_START_DATE >= RFSTDT then 
            CESTDY = SYMPTOM_START_DATE - RFSTDT + 1;
        else 
            CESTDY = SYMPTOM_START_DATE - RFSTDT;
    end;
    
    if not missing(SYMPTOM_END_DATE) and not missing(RFSTDT) then do;
        if SYMPTOM_END_DATE >= RFSTDT then 
            CEENDY = SYMPTOM_END_DATE - RFSTDT + 1;
        else 
            CEENDY = SYMPTOM_END_DATE - RFSTDT;
    end;
    
    /*=========================================================================
    * LINK TO PARENT AE - Store for RELREC generation
    *========================================================================*/
    length PARENT_AESEQ 8;
    PARENT_AESEQ = PARENT_AE_SEQUENCE;  /* From raw data */
    
    drop RFSTDT PARENT_TOXICITY_TYPE SYMPTOM_CATEGORY PARENT_AE_SEQUENCE;
run;

/******************************************************************************
* STEP 4: CREATE SUPPCE FOR ADDITIONAL SYMPTOM DETAILS
******************************************************************************/
data suppce;
    set ce_base;
    
    length STUDYID $20 RDOMAIN $2 USUBJID $40;
    length IDVAR $8 IDVARVAL $200;
    length QNAM $8 QLABEL $40 QVAL $200 QORIG $8 QEVAL $40;
    
    STUDYID = "&STUDYID";
    RDOMAIN = "CE";
    IDVAR = "CESEQ";
    IDVARVAL = strip(put(CESEQ, best.));
    
    /* Severity/Grade of symptom */
    if not missing(SYMPTOM_SEVERITY) then do;
        QNAM = "CESEV";
        QLABEL = "Symptom Severity";
        QVAL = upcase(strip(SYMPTOM_SEVERITY));
        QORIG = "ASSIGNED";
        QEVAL = "INVESTIGATOR";
        output;
    end;
    
    /* Numeric value for quantifiable symptoms (e.g., temperature, BP) */
    if not missing(SYMPTOM_VALUE) then do;
        QNAM = "CEVAL";
        QLABEL = "Symptom Numeric Value";
        QVAL = strip(put(SYMPTOM_VALUE, best.));
        QORIG = "REPORTED";
        QEVAL = "";
        output;
    end;
    
    /* Unit for numeric value */
    if not missing(SYMPTOM_UNIT) then do;
        QNAM = "CEUNIT";
        QLABEL = "Symptom Value Unit";
        QVAL = upcase(strip(SYMPTOM_UNIT));
        QORIG = "REPORTED";
        QEVAL = "";
        output;
    end;
    
    keep STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG QEVAL;
run;

/******************************************************************************
* STEP 5: CREATE FINAL CE DOMAIN
******************************************************************************/
data ce;
    set ce_base;
    
    keep STUDYID DOMAIN USUBJID CESEQ
         CETERM CECAT CESCAT CEOCCUR
         CESTDTC CEENDTC CESTDY CEENDY
         PARENT_AESEQ;  /* Keep for RELREC generation */
run;

proc sort data=ce;
    by USUBJID CESEQ;
run;

proc sql noprint;
    select count(*) into :ce_count trimmed from ce;
quit;

%put NOTE: CE domain created with &ce_count symptom records;

/******************************************************************************
* STEP 6: VALIDATION CHECKS
******************************************************************************/

/* Check: Orphan CE records (no parent AE) */
title "Validation: CE Records Without Parent AE";
proc sql;
    create table qc_orphan_ce as
    select ce.USUBJID, ce.CESEQ, ce.CETERM, ce.CECAT
    from ce
    where missing(PARENT_AESEQ);
    
    select count(*) into :orphan_count trimmed from qc_orphan_ce;
quit;

%if &orphan_count > 0 %then %do;
    %put WARNING: &orphan_count CE records without parent AE linkage;
    proc print data=qc_orphan_ce;
    run;
%end;
%else %do;
    %put NOTE: All CE records linked to parent AE;
%end;
title;

/* Check: CRS symptoms distribution */
title "Validation: CRS Symptom Distribution";
proc freq data=ce;
    where CECAT = 'CRS SIGN/SYMPTOM';
    tables CETERM CESCAT / missing;
run;
title;

/* Check: ICANS symptoms distribution */
title "Validation: ICANS Symptom Distribution";
proc freq data=ce;
    where CECAT = 'ICANS SIGN/SYMPTOM';
    tables CETERM CESCAT / missing;
run;
title;

/******************************************************************************
* STEP 7: EXPORT TO CSV AND XPT
******************************************************************************/
proc export data=ce
    outfile="../../data/csv/ce.csv"
    dbms=csv
    replace;
run;

proc export data=suppce
    outfile="../../data/csv/suppce.csv"
    dbms=csv
    replace;
run;

/* XPT export */
libname xptout xport "../../data/xpt/ce.xpt";
data xptout.ce;
    set ce;
run;
libname xptout clear;

libname xptout xport "../../data/xpt/suppce.xpt";
data xptout.suppce;
    set suppce;
run;
libname xptout clear;

%put NOTE: ============================================================;
%put NOTE: CE DOMAIN GENERATION COMPLETED;
%put NOTE: Total symptom records: &ce_count;
%put NOTE: ============================================================;

proc printto;
run;
