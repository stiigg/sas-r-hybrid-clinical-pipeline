/******************************************************************************
* Program: 44_sdtm_eg.sas
* Purpose: Generate SDTM EG (ECG Test Results) domain  
* Author:  Christian Baghai
* Date:    2025-12-24
* Input:   data/raw/ecg_results_raw.csv
* Output:  outputs/sdtm/eg.xpt
* 
* Priority: MEDIUM - Cardiac safety monitoring
* Notes:   Includes HR, QT, QTC, RR intervals
******************************************************************************/

%let STUDYID = RECIST-DEMO-001;
%let DOMAIN = EG;

libname raw "../../data/raw";
libname sdtm "../../data/csv";

proc import datafile="../../data/raw/ecg_results_raw.csv"
    out=raw_eg dbms=csv replace;
    guessingrows=max;
run;

proc sql noprint;
    create table dm_dates as
    select USUBJID, RFSTDTC from sdtm.dm;
quit;

data eg;
    merge raw_eg(in=a) dm_dates(in=b);
    by USUBJID;
    if a;
    
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    EGSEQ = _N_;
    
    /* Test code */
    length EGTESTCD $8 EGTEST $40;
    EGTESTCD = upcase(strip(ECG_PARAM));
    EGTEST = case(EGTESTCD)
        when 'HR' then 'Heart Rate'
        when 'QT' then 'QT Duration'
        when 'QTC' then 'QT Corrected'
        when 'QTCF' then 'QT Corrected by Fridericia'
        when 'RR' then 'RR Duration'
        else upcase(strip(ECG_PARAM_NAME))
    end;
    
    /* Position */
    length EGPOS $12;
    if not missing(POSITION) then
        EGPOS = upcase(strip(POSITION));
    
    /* Results */
    length EGORRES $200 EGORRESU $8;
    if not missing(ECG_VALUE) then
        EGORRES = strip(put(ECG_VALUE, best.));
    if not missing(ECG_UNIT) then
        EGORRESU = upcase(strip(ECG_UNIT));
    
    /* Standardized */
    length EGSTRESC $200 EGSTRESU $8;
    EGSTRESC = EGORRES;
    EGSTRESN = input(EGSTRESC, best.);
    EGSTRESU = EGORRESU;
    
    /* Timing */
    length EGDTC $20;
    if not missing(ECG_DATE) then do;
        if not missing(ECG_TIME) then
            EGDTC = put(ECG_DATE, yymmdd10.) || 'T' || 
                   put(ECG_TIME, time8.);
        else
            EGDTC = put(ECG_DATE, yymmdd10.);
    end;
    
    /* Study Day */
    if not missing(ECG_DATE) and not missing(input(RFSTDTC, yymmdd10.)) then do;
        if ECG_DATE >= input(RFSTDTC, yymmdd10.) then 
            EGDY = ECG_DATE - input(RFSTDTC, yymmdd10.) + 1;
        else 
            EGDY = ECG_DATE - input(RFSTDTC, yymmdd10.);
    end;
    
    /* Visit */
    length VISIT $40;
    if not missing(VISIT_NAME) then
        VISIT = upcase(strip(VISIT_NAME));
    VISITNUM = VISIT_NUMBER;
    
    keep STUDYID DOMAIN USUBJID EGSEQ EGTESTCD EGTEST EGPOS
         EGORRES EGORRESU EGSTRESC EGSTRESN EGSTRESU
         EGDTC EGDY VISIT VISITNUM;
run;

/* Determine baseline flag */
proc sort data=eg; 
    by USUBJID EGTESTCD EGDY;
run;

data eg;
    set eg;
    by USUBJID EGTESTCD;
    
    length EGBLFL $1;
    if first.EGTESTCD and not missing(EGSTRESN) and EGDY <= 1 then 
        EGBLFL = 'Y';
run;

proc sort data=eg; by USUBJID EGSEQ; run;

proc means data=eg n mean std median min max;
    var EGSTRESN;
    class EGTESTCD;
    title "EG Domain - ECG Parameter Statistics";
run;

proc export data=eg outfile="../../data/csv/eg.csv" dbms=csv replace; run;

libname xptout xport "../../data/xpt/eg.xpt";
data xptout.eg; set eg; run;
libname xptout clear;

%put NOTE: EG domain generation completed successfully;
