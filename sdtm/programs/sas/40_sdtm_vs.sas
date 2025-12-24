/******************************************************************************
* Program: 40_sdtm_vs.sas
* Purpose: Generate SDTM VS (Vital Signs) domain
* Author:  Christian Baghai
* Date:    2025-12-24
* Input:   data/raw/vital_signs_raw.csv
* Output:  outputs/sdtm/vs.xpt
* 
* Priority: MEDIUM - Standard safety monitoring
* Notes:   Includes HEIGHT, WEIGHT, SYSBP, DIABP, PULSE, TEMP, RESP
******************************************************************************/

%let STUDYID = RECIST-DEMO-001;
%let DOMAIN = VS;

libname raw "../../data/raw";
libname sdtm "../../data/csv";

proc import datafile="../../data/raw/vital_signs_raw.csv"
    out=raw_vs dbms=csv replace;
    guessingrows=max;
run;

proc sql noprint;
    create table dm_dates as
    select USUBJID, RFSTDTC from sdtm.dm;
quit;

data vs;
    merge raw_vs(in=a) dm_dates(in=b);
    by USUBJID;
    if a;
    
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    VSSEQ = _N_;
    
    /* Test code and name - Controlled terminology */
    length VSTESTCD $8 VSTEST $40;
    VSTESTCD = upcase(strip(TEST_CODE));
    VSTEST = case(VSTESTCD)
        when 'HEIGHT' then 'Height'
        when 'WEIGHT' then 'Weight'
        when 'SYSBP' then 'Systolic Blood Pressure'
        when 'DIABP' then 'Diastolic Blood Pressure'
        when 'PULSE' then 'Pulse Rate'
        when 'TEMP' then 'Temperature'
        when 'RESP' then 'Respiratory Rate'
        else upcase(strip(TEST_NAME))
    end;
    
    /* Position during measurement */
    length VSPOS $12;
    if not missing(POSITION) then
        VSPOS = upcase(strip(POSITION));
    /* STANDING, SUPINE, SITTING */
    
    /* Results as collected */
    length VSORRES $200 VSORRESU $8;
    VSORRES = strip(put(RESULT_VALUE, best.));
    if not missing(RESULT_UNIT) then
        VSORRESU = upcase(strip(RESULT_UNIT));
    
    /* Standardized results */
    length VSSTRESC $200 VSSTRESU $8;
    VSSTRESC = VSORRES;
    VSSTRESN = input(VSSTRESC, best.);
    VSSTRESU = VSORRESU;
    
    /* Baseline flag - first non-missing result on or before RFSTDTC */
    length VSBLFL $1;
    /* Set by subsequent sorting and first. logic */
    
    /* Timing */
    length VSDTC $20;
    if not missing(MEASUREMENT_DATE) then do;
        if not missing(MEASUREMENT_TIME) then
            VSDTC = put(MEASUREMENT_DATE, yymmdd10.) || 'T' || 
                    put(MEASUREMENT_TIME, time8.);
        else
            VSDTC = put(MEASUREMENT_DATE, yymmdd10.);
    end;
    
    /* Study Day */
    if not missing(MEASUREMENT_DATE) and not missing(input(RFSTDTC, yymmdd10.)) then do;
        if MEASUREMENT_DATE >= input(RFSTDTC, yymmdd10.) then 
            VSDY = MEASUREMENT_DATE - input(RFSTDTC, yymmdd10.) + 1;
        else 
            VSDY = MEASUREMENT_DATE - input(RFSTDTC, yymmdd10.);
    end;
    
    /* Visit */
    length VISIT $40;
    if not missing(VISIT_NAME) then
        VISIT = upcase(strip(VISIT_NAME));
    VISITNUM = VISIT_NUMBER;
    
    /* Epoch */
    length EPOCH $40;
    if VISITNUM = 1 then EPOCH = "SCREENING";
    else EPOCH = "TREATMENT";
    
    keep STUDYID DOMAIN USUBJID VSSEQ VSTESTCD VSTEST VSPOS
         VSORRES VSORRESU VSSTRESC VSSTRESN VSSTRESU 
         VSDTC VSDY VISIT VISITNUM EPOCH;
run;

/* Determine baseline flag */
proc sort data=vs; 
    by USUBJID VSTESTCD VSDY;
run;

data vs;
    set vs;
    by USUBJID VSTESTCD;
    
    length VSBLFL $1;
    if first.VSTESTCD and not missing(VSSTRESN) and VSDY <= 1 then 
        VSBLFL = 'Y';
run;

proc sort data=vs; by USUBJID VSSEQ; run;

proc means data=vs n nmiss mean std median min max;
    var VSSTRESN;
    class VSTESTCD;
    title "VS Domain - Vital Signs Summary Statistics";
run;

proc export data=vs outfile="../../data/csv/vs.csv" dbms=csv replace; run;

libname xptout xport "../../data/xpt/vs.xpt";
data xptout.vs; set vs; run;
libname xptout clear;

%put NOTE: VS domain generation completed successfully;
