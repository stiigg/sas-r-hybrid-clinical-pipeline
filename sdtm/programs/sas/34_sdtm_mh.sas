/******************************************************************************
* Program: 34_sdtm_mh.sas
* Purpose: Generate SDTM MH (Medical History) domain
* Author:  Christian Baghai
* Date:    2025-12-24
* Input:   data/raw/medical_history_raw.csv
* Output:  outputs/sdtm/mh.xpt
* 
* Priority: HIGH - Baseline medical conditions
* Notes:   Medical coding (MedDRA) required for MHDECOD in production
******************************************************************************/

%let STUDYID = RECIST-DEMO-001;
%let DOMAIN = MH;

libname raw "../../data/raw";
libname sdtm "../../data/csv";

proc import datafile="../../data/raw/medical_history_raw.csv"
    out=raw_mh dbms=csv replace;
    guessingrows=max;
run;

proc sql noprint;
    create table dm_dates as
    select USUBJID, RFSTDTC, RFENDTC from sdtm.dm;
quit;

data mh;
    merge raw_mh(in=a) dm_dates(in=b);
    by USUBJID;
    if a;
    
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    MHSEQ = _N_;
    
    /* Medical history term */
    length MHTERM $200 MHDECOD $200;
    MHTERM = upcase(strip(MH_VERBATIM));
    if not missing(MEDDRA_PT) then 
        MHDECOD = upcase(strip(MEDDRA_PT));
    else 
        MHDECOD = MHTERM;
    
    /* Category */
    length MHCAT $40;
    MHCAT = case(upcase(strip(MH_TYPE)))
        when 'PRIMARY' then 'PRIMARY DIAGNOSIS'
        when 'SECONDARY' then 'SECONDARY DIAGNOSIS'
        when 'CANCER' then 'CANCER DIAGNOSIS'
        when 'GENERAL' then 'MEDICAL HISTORY'
        else 'MEDICAL HISTORY'
    end;
    
    /* Body system (if available) */
    length MHBODSYS $200;
    if not missing(BODY_SYSTEM) then
        MHBODSYS = upcase(strip(BODY_SYSTEM));
    
    /* Timing */
    length MHSTDTC $20 MHENDTC $20;
    if not missing(MH_START_DATE) then
        MHSTDTC = put(MH_START_DATE, yymmdd10.);
    if not missing(MH_END_DATE) then 
        MHENDTC = put(MH_END_DATE, yymmdd10.);
    
    /* Ongoing flag */
    length MHENRF $40;
    if not missing(MH_END_DATE) and not missing(input(RFSTDTC, yymmdd10.)) then do;
        if MH_END_DATE < input(RFSTDTC, yymmdd10.) then 
            MHENRF = "BEFORE";
        else if MH_END_DATE <= input(RFENDTC, yymmdd10.) then 
            MHENRF = "DURING";
        else 
            MHENRF = "AFTER";
    end;
    else if missing(MH_END_DATE) then 
        MHENRF = "ONGOING";
    
    /* Study Day */
    if not missing(MH_START_DATE) and not missing(input(RFSTDTC, yymmdd10.)) then do;
        if MH_START_DATE >= input(RFSTDTC, yymmdd10.) then 
            MHSTDY = MH_START_DATE - input(RFSTDTC, yymmdd10.) + 1;
        else 
            MHSTDY = MH_START_DATE - input(RFSTDTC, yymmdd10.);
    end;
    
    keep STUDYID DOMAIN USUBJID MHSEQ MHTERM MHDECOD 
         MHCAT MHBODSYS MHSTDTC MHENDTC MHSTDY MHENRF;
run;

proc sort data=mh; by USUBJID MHSEQ; run;

proc freq data=mh;
    tables MHCAT MHENRF / missing;
    title "MH Domain - Medical History Categories";
run;

proc export data=mh outfile="../../data/csv/mh.csv" dbms=csv replace; run;

libname xptout xport "../../data/xpt/mh.xpt";
data xptout.mh; set mh; run;
libname xptout clear;

%put NOTE: MH domain generation completed successfully;
