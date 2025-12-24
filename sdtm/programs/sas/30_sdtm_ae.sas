/******************************************************************************
* Program: 30_sdtm_ae.sas
* Purpose: Generate SDTM AE (Adverse Events) domain
* Author:  Christian Baghai
* Date:    2025-12-24
* Input:   data/raw/adverse_events_raw.csv
* Output:  outputs/sdtm/ae.xpt
* 
* Priority: HIGHEST - Required for FDA safety reporting
* Notes:   Medical coding (MedDRA) required for AEDECOD in production
******************************************************************************/

%let STUDYID = RECIST-DEMO-001;
%let DOMAIN = AE;

/* Set library references */
libname raw "../../data/raw";
libname sdtm "../../data/csv";

/* Read raw adverse events data */
proc import datafile="../../data/raw/adverse_events_raw.csv"
    out=raw_ae
    dbms=csv
    replace;
    guessingrows=max;
run;

/* Get reference start date from DM domain */
proc sql noprint;
    create table dm_dates as
    select USUBJID, RFSTDTC
    from sdtm.dm;
quit;

/* Map raw data to SDTM AE structure */
data ae;
    merge raw_ae(in=a)
          dm_dates(in=b);
    by USUBJID;
    
    if a;
    
    /* Study Identifiers */
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    
    /* Sequence Variable - REQUIRED */
    AESEQ = _N_;
    
    /* Topic Variable - Verbatim term as collected */
    length AETERM $200;
    AETERM = upcase(strip(AE_VERBATIM));
    
    /* Synonym Qualifier - MedDRA Preferred Term (from medical coding) */
    length AEDECOD $200;
    if not missing(MEDDRA_PT) then 
        AEDECOD = upcase(strip(MEDDRA_PT));
    else 
        AEDECOD = AETERM;  /* Use verbatim if not coded */
    
    /* Timing Variables - ISO 8601 format YYYY-MM-DD */
    length AESTDTC $20 AEENDTC $20;
    if not missing(AE_START_DATE) then
        AESTDTC = put(AE_START_DATE, yymmdd10.);
    if not missing(AE_END_DATE) then
        AEENDTC = put(AE_END_DATE, yymmdd10.);
    
    /* Duration in days */
    if not missing(AE_END_DATE) and not missing(AE_START_DATE) then
        AEDUR = AE_END_DATE - AE_START_DATE + 1;
    
    /* Study Day Calculation (relative to RFSTDTC from DM) */
    if not missing(AE_START_DATE) and not missing(input(RFSTDTC, yymmdd10.)) then do;
        if AE_START_DATE >= input(RFSTDTC, yymmdd10.) then 
            AESTDY = AE_START_DATE - input(RFSTDTC, yymmdd10.) + 1;
        else 
            AESTDY = AE_START_DATE - input(RFSTDTC, yymmdd10.);
    end;
    
    if not missing(AE_END_DATE) and not missing(input(RFSTDTC, yymmdd10.)) then do;
        if AE_END_DATE >= input(RFSTDTC, yymmdd10.) then 
            AEENDY = AE_END_DATE - input(RFSTDTC, yymmdd10.) + 1;
        else 
            AEENDY = AE_END_DATE - input(RFSTDTC, yymmdd10.);
    end;
    
    /* Severity - Controlled Terminology (MILD, MODERATE, SEVERE) */
    length AESEV $8;
    AESEV = upcase(strip(SEVERITY));
    
    /* Serious Event Flag - Y/N */
    length AESER $1;
    if upcase(strip(SERIOUS_FLAG)) in ('Y' 'YES' '1') then AESER = 'Y';
    else if upcase(strip(SERIOUS_FLAG)) in ('N' 'NO' '0') then AESER = 'N';
    
    /* Causality Assessment - Relationship to Study Drug */
    length AEREL $40;
    AEREL = upcase(strip(RELATIONSHIP));
    /* Expected values: RELATED, NOT RELATED, PROBABLY RELATED, POSSIBLY RELATED */
    
    /* Action Taken with Study Treatment */
    length AEACN $40;
    AEACN = upcase(strip(ACTION_TAKEN));
    /* Examples: DOSE NOT CHANGED, DOSE REDUCED, DRUG WITHDRAWN, etc. */
    
    /* Outcome of Adverse Event */
    length AEOUT $40;
    AEOUT = upcase(strip(OUTCOME));
    /* Examples: RECOVERED/RESOLVED, RECOVERING/RESOLVING, NOT RECOVERED/NOT RESOLVED, etc. */
    
    /* Treatment Emergent Flag (post-RFSTDTC) */
    length AETRTEM $1;
    if not missing(AE_START_DATE) and not missing(input(RFSTDTC, yymmdd10.)) then do;
        if AE_START_DATE >= input(RFSTDTC, yymmdd10.) then AETRTEM = 'Y';
        else AETRTEM = '';
    end;
    
    /* Keep only SDTM variables in correct order */
    keep STUDYID DOMAIN USUBJID AESEQ 
         AETERM AEDECOD 
         AESTDTC AEENDTC AEDUR AESTDY AEENDY
         AESEV AESER AEREL AEACN AEOUT AETRTEM;
run;

/* Sort by key variables */
proc sort data=ae;
    by USUBJID AESEQ;
run;

/* Create descriptive statistics */
proc freq data=ae;
    tables AESEV AESER AEREL AEOUT / missing;
    title "AE Domain - Frequency Distributions";
run;

proc means data=ae n nmiss mean median min max;
    var AEDUR AESTDY;
    title "AE Domain - Duration and Study Day Statistics";
run;

/* Save to CSV */
proc export data=ae
    outfile="../../data/csv/ae.csv"
    dbms=csv
    replace;
run;

/* Export to XPT v5 format for regulatory submission */
libname xptout xport "../../data/xpt/ae.xpt";
data xptout.ae;
    set ae;
run;
libname xptout clear;

proc printto log="../../logs/30_sdtm_ae.log";
run;

%put NOTE: AE domain generation completed successfully;
%put NOTE: Output files created:;
%put NOTE:   - ../../data/csv/ae.csv;
%put NOTE:   - ../../data/xpt/ae.xpt;
%put NOTE: Total AE records: %sysfunc(countw(&SQLOBS));
