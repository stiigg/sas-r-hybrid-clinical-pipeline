/******************************************************************************
* Program: 32_sdtm_cm.sas
* Purpose: Generate SDTM CM (Concomitant Medications) domain
* Author:  Christian Baghai
* Date:    2025-12-24
* Input:   data/raw/concomitant_meds_raw.csv
* Output:  outputs/sdtm/cm.xpt
* 
* Priority: HIGH - Safety context for adverse events
* Notes:   Medical coding (WHODrug) required for CMDECOD in production
******************************************************************************/

%let STUDYID = RECIST-DEMO-001;
%let DOMAIN = CM;

libname raw "../../data/raw";
libname sdtm "../../data/csv";

proc import datafile="../../data/raw/concomitant_meds_raw.csv"
    out=raw_cm dbms=csv replace;
    guessingrows=max;
run;

proc sql noprint;
    create table dm_dates as
    select USUBJID, RFSTDTC, RFENDTC from sdtm.dm;
quit;

data cm;
    merge raw_cm(in=a) dm_dates(in=b);
    by USUBJID;
    if a;
    
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    CMSEQ = _N_;
    
    /* Medication name - verbatim and coded */
    length CMTRT $200 CMDECOD $200;
    CMTRT = upcase(strip(MED_VERBATIM));
    if not missing(WHODRUG_NAME) then 
        CMDECOD = upcase(strip(WHODRUG_NAME));
    else 
        CMDECOD = CMTRT;
    
    /* Category: PRIOR vs CONCOMITANT */
    length CMCAT $40;
    if not missing(MED_START_DATE) and not missing(input(RFSTDTC, yymmdd10.)) then do;
        if MED_START_DATE < input(RFSTDTC, yymmdd10.) then 
            CMCAT = "PRIOR MEDICATION";
        else 
            CMCAT = "CONCOMITANT MEDICATION";
    end;
    else CMCAT = "CONCOMITANT MEDICATION";
    
    /* Indication */
    length CMINDC $200;
    if not missing(INDICATION) then
        CMINDC = upcase(strip(INDICATION));
    
    /* Dose information */
    CMDOSE = DOSE_VALUE;
    length CMDOSU $8;
    if not missing(DOSE_UNIT) then
        CMDOSU = upcase(strip(DOSE_UNIT));
    
    /* Frequency */
    length CMDOSFRQ $12;
    if not missing(FREQUENCY) then
        CMDOSFRQ = upcase(strip(FREQUENCY));
    
    /* Route */
    length CMROUTE $40;
    if not missing(ROUTE) then
        CMROUTE = upcase(strip(ROUTE));
    
    /* Timing */
    length CMSTDTC $20 CMENDTC $20;
    if not missing(MED_START_DATE) then
        CMSTDTC = put(MED_START_DATE, yymmdd10.);
    if not missing(MED_END_DATE) then
        CMENDTC = put(MED_END_DATE, yymmdd10.);
    
    /* Ongoing flag */
    length CMENRTPT $40;
    if missing(MED_END_DATE) or upcase(strip(ONGOING)) = 'Y' then 
        CMENRTPT = "ONGOING";
    
    /* Study Day */
    if not missing(MED_START_DATE) and not missing(input(RFSTDTC, yymmdd10.)) then do;
        if MED_START_DATE >= input(RFSTDTC, yymmdd10.) then 
            CMSTDY = MED_START_DATE - input(RFSTDTC, yymmdd10.) + 1;
        else 
            CMSTDY = MED_START_DATE - input(RFSTDTC, yymmdd10.);
    end;
    
    keep STUDYID DOMAIN USUBJID CMSEQ CMTRT CMDECOD CMCAT CMINDC
         CMDOSE CMDOSU CMDOSFRQ CMROUTE 
         CMSTDTC CMENDTC CMSTDY CMENRTPT;
run;

proc sort data=cm; by USUBJID CMSEQ; run;

proc freq data=cm;
    tables CMCAT CMROUTE / missing;
    title "CM Domain - Medication Categories";
run;

proc export data=cm outfile="../../data/csv/cm.csv" dbms=csv replace; run;

libname xptout xport "../../data/xpt/cm.xpt";
data xptout.cm; set cm; run;
libname xptout clear;

%put NOTE: CM domain generation completed successfully;
