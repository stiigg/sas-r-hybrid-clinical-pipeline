/******************************************************************************
* Program: 38_sdtm_ex.sas
* Purpose: Generate SDTM EX (Exposure) domain
* Author:  Christian Baghai
* Date:    2025-12-24
* Input:   data/raw/exposure_raw.csv
* Output:  outputs/sdtm/ex.xpt
* 
* Priority: HIGH - Documents study treatment administration
* Notes:   Records all doses of study drug administered
******************************************************************************/

%let STUDYID = RECIST-DEMO-001;
%let DOMAIN = EX;

libname raw "../../data/raw";
libname sdtm "../../data/csv";

proc import datafile="../../data/raw/exposure_raw.csv"
    out=raw_ex dbms=csv replace;
    guessingrows=max;
run;

proc sql noprint;
    create table dm_dates as
    select USUBJID, RFSTDTC from sdtm.dm;
quit;

data ex;
    merge raw_ex(in=a) dm_dates(in=b);
    by USUBJID;
    if a;
    
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    EXSEQ = _N_;
    
    /* Treatment name */
    length EXTRT $200;
    EXTRT = upcase(strip(TREATMENT_NAME));
    
    /* Dose information */
    EXDOSE = DOSE_AMOUNT;
    length EXDOSU $8;
    EXDOSU = upcase(strip(DOSE_UNIT));
    
    /* Dosing frequency */
    length EXDOSFRQ $12;
    EXDOSFRQ = upcase(strip(FREQUENCY));
    /* QD, BID, Q3W, Q4W for oncology, etc. */
    
    /* Route of administration */
    length EXROUTE $40;
    EXROUTE = upcase(strip(ROUTE));
    /* INTRAVENOUS, ORAL, SUBCUTANEOUS, etc. */
    
    /* Timing */
    length EXSTDTC $20 EXENDTC $20;
    if not missing(ADMIN_START_DATE) then
        EXSTDTC = put(ADMIN_START_DATE, yymmdd10.);
    if not missing(ADMIN_END_DATE) then
        EXENDTC = put(ADMIN_END_DATE, yymmdd10.);
    
    /* Study Day */
    if not missing(ADMIN_START_DATE) and not missing(input(RFSTDTC, yymmdd10.)) then do;
        if ADMIN_START_DATE >= input(RFSTDTC, yymmdd10.) then 
            EXSTDY = ADMIN_START_DATE - input(RFSTDTC, yymmdd10.) + 1;
        else 
            EXSTDY = ADMIN_START_DATE - input(RFSTDTC, yymmdd10.);
    end;
    
    if not missing(ADMIN_END_DATE) and not missing(input(RFSTDTC, yymmdd10.)) then do;
        if ADMIN_END_DATE >= input(RFSTDTC, yymmdd10.) then 
            EXENDY = ADMIN_END_DATE - input(RFSTDTC, yymmdd10.) + 1;
        else 
            EXENDY = ADMIN_END_DATE - input(RFSTDTC, yymmdd10.);
    end;
    
    /* Visit information */
    length VISIT $40;
    if not missing(VISIT_NAME) then VISIT = upcase(strip(VISIT_NAME));
    VISITNUM = VISIT_NUMBER;
    
    /* Epoch */
    length EPOCH $40;
    EPOCH = "TREATMENT";
    
    keep STUDYID DOMAIN USUBJID EXSEQ EXTRT 
         EXDOSE EXDOSU EXDOSFRQ EXROUTE 
         EXSTDTC EXENDTC EXSTDY EXENDY
         VISIT VISITNUM EPOCH;
run;

proc sort data=ex; by USUBJID EXSEQ; run;

proc freq data=ex;
    tables EXTRT EXDOSFRQ EXROUTE / missing;
    title "EX Domain - Exposure Frequencies";
run;

proc means data=ex n mean median min max;
    var EXDOSE;
    class EXTRT;
    title "EX Domain - Dose Statistics by Treatment";
run;

proc export data=ex outfile="../../data/csv/ex.csv" dbms=csv replace; run;

libname xptout xport "../../data/xpt/ex.xpt";
data xptout.ex; set ex; run;
libname xptout clear;

%put NOTE: EX domain generation completed successfully;
