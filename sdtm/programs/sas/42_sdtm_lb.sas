/******************************************************************************
* Program: 42_sdtm_lb.sas
* Purpose: Generate SDTM LB (Laboratory Test Results) domain
* Author:  Christian Baghai
* Date:    2025-12-24
* Input:   data/raw/lab_results_raw.csv
* Output:  outputs/sdtm/lb.xpt
* 
* Priority: MEDIUM - Safety lab monitoring
* Notes:   Includes HEMATOLOGY, CHEMISTRY, URINALYSIS panels
******************************************************************************/

%let STUDYID = RECIST-DEMO-001;
%let DOMAIN = LB;

libname raw "../../data/raw";
libname sdtm "../../data/csv";

proc import datafile="../../data/raw/lab_results_raw.csv"
    out=raw_lb dbms=csv replace;
    guessingrows=max;
run;

proc sql noprint;
    create table dm_dates as
    select USUBJID, RFSTDTC from sdtm.dm;
quit;

data lb;
    merge raw_lb(in=a) dm_dates(in=b);
    by USUBJID;
    if a;
    
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    LBSEQ = _N_;
    
    /* Test identification */
    length LBTESTCD $8 LBTEST $40;
    LBTESTCD = upcase(strip(LAB_TEST_CODE));
    if not missing(LAB_TEST_NAME) then
        LBTEST = upcase(strip(LAB_TEST_NAME));
    
    /* Category */
    length LBCAT $40;
    LBCAT = case(upcase(strip(LAB_PANEL)))
        when 'HEM' then 'HEMATOLOGY'
        when 'HEMATOLOGY' then 'HEMATOLOGY'
        when 'CHEM' then 'CHEMISTRY'
        when 'CHEMISTRY' then 'CHEMISTRY'
        when 'URIN' then 'URINALYSIS'
        when 'URINALYSIS' then 'URINALYSIS'
        else upcase(strip(LAB_PANEL))
    end;
    
    /* Results as collected */
    length LBORRES $200 LBORRESU $8;
    if not missing(LAB_RESULT) then
        LBORRES = strip(put(LAB_RESULT, best.));
    if not missing(LAB_UNIT) then
        LBORRESU = upcase(strip(LAB_UNIT));
    
    /* Standardized results */
    length LBSTRESC $200 LBSTRESU $8;
    LBSTRESC = LBORRES;
    LBSTRESN = input(LBSTRESC, best.);
    LBSTRESU = LBORRESU;
    
    /* Reference ranges */
    LBSTNRLO = NORMAL_RANGE_LOW;
    LBSTNRHI = NORMAL_RANGE_HIGH;
    
    /* Normal range indicator */
    length LBNRIND $8;
    if not missing(LBSTRESN) and not missing(LBSTNRLO) and not missing(LBSTNRHI) then do;
        if LBSTRESN < LBSTNRLO then LBNRIND = "LOW";
        else if LBSTRESN > LBSTNRHI then LBNRIND = "HIGH";
        else LBNRIND = "NORMAL";
    end;
    
    /* Timing */
    length LBDTC $20;
    if not missing(COLLECTION_DATE) then do;
        if not missing(COLLECTION_TIME) then
            LBDTC = put(COLLECTION_DATE, yymmdd10.) || 'T' || 
                    put(COLLECTION_TIME, time8.);
        else
            LBDTC = put(COLLECTION_DATE, yymmdd10.);
    end;
    
    /* Study Day */
    if not missing(COLLECTION_DATE) and not missing(input(RFSTDTC, yymmdd10.)) then do;
        if COLLECTION_DATE >= input(RFSTDTC, yymmdd10.) then 
            LBDY = COLLECTION_DATE - input(RFSTDTC, yymmdd10.) + 1;
        else 
            LBDY = COLLECTION_DATE - input(RFSTDTC, yymmdd10.);
    end;
    
    /* Visit */
    length VISIT $40;
    if not missing(VISIT_NAME) then
        VISIT = upcase(strip(VISIT_NAME));
    VISITNUM = VISIT_NUMBER;
    
    keep STUDYID DOMAIN USUBJID LBSEQ LBTESTCD LBTEST LBCAT
         LBORRES LBORRESU LBSTRESC LBSTRESN LBSTRESU
         LBSTNRLO LBSTNRHI LBNRIND 
         LBDTC LBDY VISIT VISITNUM;
run;

/* Determine baseline flag */
proc sort data=lb; 
    by USUBJID LBTESTCD LBDY;
run;

data lb;
    set lb;
    by USUBJID LBTESTCD;
    
    length LBBLFL $1;
    if first.LBTESTCD and not missing(LBSTRESN) and LBDY <= 1 then 
        LBBLFL = 'Y';
run;

proc sort data=lb; by USUBJID LBSEQ; run;

proc freq data=lb;
    tables LBCAT LBNRIND / missing;
    title "LB Domain - Lab Categories and Normal Range";
run;

proc export data=lb outfile="../../data/csv/lb.csv" dbms=csv replace; run;

libname xptout xport "../../data/xpt/lb.xpt";
data xptout.lb; set lb; run;
libname xptout clear;

%put NOTE: LB domain generation completed successfully;
