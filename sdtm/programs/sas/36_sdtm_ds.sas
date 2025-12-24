/******************************************************************************
* Program: 36_sdtm_ds.sas
* Purpose: Generate SDTM DS (Disposition) domain
* Author:  Christian Baghai
* Date:    2025-12-24
* Input:   data/raw/disposition_raw.csv
* Output:  outputs/sdtm/ds.xpt
* 
* Priority: HIGH - Required for subject accountability (FDA requirement)
* Notes:   Tracks screening, enrollment, completion, withdrawal events
******************************************************************************/

%let STUDYID = RECIST-DEMO-001;
%let DOMAIN = DS;

/* Set library references */
libname raw "../../data/raw";
libname sdtm "../../data/csv";

/* Read raw disposition data */
proc import datafile="../../data/raw/disposition_raw.csv"
    out=raw_ds
    dbms=csv
    replace;
    guessingrows=max;
run;

/* Get reference dates from DM domain */
proc sql noprint;
    create table dm_dates as
    select USUBJID, RFSTDTC
    from sdtm.dm;
quit;

/* Map raw data to SDTM DS structure */
data ds;
    merge raw_ds(in=a)
          dm_dates(in=b);
    by USUBJID;
    
    if a;
    
    /* Study Identifiers */
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    
    /* Sequence Variable */
    DSSEQ = _N_;
    
    /* Disposition Event - Verbatim */
    length DSTERM $200;
    DSTERM = upcase(strip(DISP_EVENT));
    
    /* Standardized Disposition Term - Controlled Terminology */
    length DSDECOD $200;
    DSDECOD = case(upcase(strip(DISP_EVENT)))
        when 'SCREENED' then 'SCREEN'
        when 'SCREENING' then 'SCREEN'
        when 'ENROLLED' then 'ENROLLED'
        when 'RANDOMIZED' then 'RANDOMIZED'
        when 'COMPLETED' then 'COMPLETED'
        when 'WITHDRAWN' then 'SCREEN FAILURE'
        when 'SCREEN FAILURE' then 'SCREEN FAILURE'
        when 'DISCONTINUED' then 'DISCONTINUED'
        when 'EARLY TERMINATION' then 'DISCONTINUED'
        else upcase(strip(DISP_EVENT))
    end;
    
    /* Category */
    length DSCAT $40;
    DSCAT = "DISPOSITION EVENT";
    
    /* Subcategory - Reason for discontinuation/withdrawal */
    length DSSCAT $200;
    if not missing(REASON) then 
        DSSCAT = upcase(strip(REASON));
    /* Examples: ADVERSE EVENT, LOST TO FOLLOW-UP, PROTOCOL VIOLATION, 
                 PHYSICIAN DECISION, SUBJECT DECISION, DEATH, etc. */
    
    /* Timing - Date of disposition event */
    length DSSTDTC $20;
    if not missing(DISP_DATE) then
        DSSTDTC = put(DISP_DATE, yymmdd10.);
    
    /* Study Day */
    if not missing(DISP_DATE) and not missing(input(RFSTDTC, yymmdd10.)) then do;
        if DISP_DATE >= input(RFSTDTC, yymmdd10.) then 
            DSSTDY = DISP_DATE - input(RFSTDTC, yymmdd10.) + 1;
        else 
            DSSTDY = DISP_DATE - input(RFSTDTC, yymmdd10.);
    end;
    
    /* Epoch - Study phase when disposition occurred */
    length EPOCH $40;
    if DSDECOD = 'SCREEN' then EPOCH = 'SCREENING';
    else if DSDECOD in ('ENROLLED' 'RANDOMIZED') then EPOCH = 'TREATMENT';
    else if DSDECOD = 'COMPLETED' then EPOCH = 'FOLLOW-UP';
    else if not missing(EPOCH_RAW) then EPOCH = upcase(strip(EPOCH_RAW));
    
    /* Keep only SDTM variables */
    keep STUDYID DOMAIN USUBJID DSSEQ 
         DSTERM DSDECOD DSCAT DSSCAT 
         DSSTDTC DSSTDY EPOCH;
run;

/* Sort by key variables */
proc sort data=ds;
    by USUBJID DSSEQ;
run;

/* Create frequency tables */
proc freq data=ds;
    tables DSDECOD DSSCAT EPOCH / missing;
    title "DS Domain - Disposition Event Frequencies";
run;

/* Subject accountability summary */
proc sql;
    create table disposition_summary as
    select 
        DSDECOD as Disposition_Status,
        count(distinct USUBJID) as N_Subjects,
        calculated N_Subjects / (select count(distinct USUBJID) from ds) * 100 
            as Percent format=5.1
    from ds
    group by DSDECOD
    order by N_Subjects desc;
quit;

proc print data=disposition_summary noobs;
    title "Subject Accountability Summary";
run;

/* Save to CSV */
proc export data=ds
    outfile="../../data/csv/ds.csv"
    dbms=csv
    replace;
run;

/* Export to XPT v5 format */
libname xptout xport "../../data/xpt/ds.xpt";
data xptout.ds;
    set ds;
run;
libname xptout clear;

proc printto log="../../logs/36_sdtm_ds.log";
run;

%put NOTE: DS domain generation completed successfully;
%put NOTE: Output files created:;
%put NOTE:   - ../../data/csv/ds.csv;
%put NOTE:   - ../../data/xpt/ds.xpt;
