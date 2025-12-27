/******************************************************************************
* Program: 50_sdtm_dd.sas (PRODUCTION VERSION 1.0)
* Purpose: Generate FDA-compliant SDTM DD (Death Details) domain for NEXICART-2
* Author:  Christian Baghai
* Date:    2025-12-27
* Input:   sdtm/data/raw/death_details_raw.csv
* Output:  sdtm/data/csv/dd.csv, sdtm/data/xpt/dd.xpt
* 
* Priority: MODERATE - Required for regulatory submission safety reporting
* Standards: SDTM IG v3.4, FDA Technical Conformance Guide v5.0
* Notes:   - Death causality assessment relative to CAR-T therapy
*          - Autopsy findings if performed
*          - Narrative text for fatal SAEs
******************************************************************************/

%let STUDYID = NEXICART-2;
%let DOMAIN = DD;

%global validation_errors validation_warnings;
%let validation_errors = NO;
%let validation_warnings = NO;

libname raw "../../data/raw";
libname sdtm "../../data/csv";

proc printto log="../../logs/50_sdtm_dd.log" new;
run;

%put NOTE: ============================================================;
%put NOTE: Starting DD domain generation for NEXICART-2;
%put NOTE: Study: &STUDYID;
%put NOTE: Timestamp: %sysfunc(datetime(), datetime20.);
%put NOTE: ============================================================;

/******************************************************************************
* STEP 1: IMPORT RAW DEATH DETAILS DATA
******************************************************************************/
proc import datafile="../../data/raw/death_details_raw.csv"
    out=raw_dd
    dbms=csv
    replace;
    guessingrows=max;
run;

/******************************************************************************
* STEP 2: CHECK IF ANY DEATHS OCCURRED
******************************************************************************/
proc sql noprint;
    select count(*) into :death_count trimmed from raw_dd;
quit;

%if &death_count = 0 %then %do;
    %put NOTE: No deaths reported in study - creating empty DD domain;
    
    data dd;
        length STUDYID $20 DOMAIN $2 USUBJID $40 DDSEQ 8
               DDTESTCD $8 DDTEST $200 DDORRES $200 DDDECOD $200
               DDSTRESC $200;
        
        /* Create empty dataset with proper structure */
        stop;
    run;
    
    %goto skip_processing;
%end;

%put NOTE: Processing &death_count death record(s);

/******************************************************************************
* STEP 3: TRANSFORM RAW DATA TO SDTM DD STRUCTURE
******************************************************************************/
data dd_base;
    set raw_dd;
    
    /*=========================================================================
    * IDENTIFIERS
    *========================================================================*/
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    DDSEQ = _N_;
    
    /*=========================================================================
    * DEATH CAUSE - VERBATIM
    *========================================================================*/
    length DDTESTCD $8 DDTEST $200;
    DDTESTCD = "DTHCAUS";
    DDTEST = "CAUSE OF DEATH";
    
    length DDORRES $200;
    if not missing(DEATH_CAUSE_VERBATIM) then
        DDORRES = strip(DEATH_CAUSE_VERBATIM);
    
    /*=========================================================================
    * DEATH CAUSE - MedDRA CODED
    *========================================================================*/
    length DDDECOD $200;
    if not missing(DEATH_CAUSE_PT) then
        DDDECOD = upcase(strip(DEATH_CAUSE_PT));
    else do;
        DDDECOD = DDORRES;  /* Use verbatim if not coded */
        put "WARNING: Death cause not MedDRA coded for" USUBJID=;
        call symputx('validation_warnings', 'YES');
    end;
    
    /*=========================================================================
    * STANDARDIZED RESULT - DISEASE CATEGORY
    *========================================================================*/
    length DDSTRESC $200;
    
    /* Categorize primary cause */
    if index(upcase(DDDECOD), 'PROGRESSIVE') or 
       index(upcase(DDDECOD), 'AMYLOIDOSIS') then 
        DDSTRESC = 'PROGRESSIVE AL AMYLOIDOSIS';
    else if index(upcase(DDDECOD), 'CARDIAC') or
            index(upcase(DDDECOD), 'HEART') then
        DDSTRESC = 'CARDIAC FAILURE';
    else if index(upcase(DDDECOD), 'RENAL') or
            index(upcase(DDDECOD), 'KIDNEY') then
        DDSTRESC = 'RENAL FAILURE';
    else if index(upcase(DDDECOD), 'INFECTION') or
            index(upcase(DDDECOD), 'SEPSIS') then
        DDSTRESC = 'INFECTION';
    else if index(upcase(DDDECOD), 'CRS') or
            index(upcase(DDDECOD), 'CYTOKINE RELEASE') then
        DDSTRESC = 'CYTOKINE RELEASE SYNDROME';
    else DDSTRESC = 'OTHER';
run;

/******************************************************************************
* STEP 4: CREATE RELATIONSHIP TO CAR-T RECORDS
******************************************************************************/
data dd_relationship;
    set raw_dd;
    
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    DDSEQ = _N_ + 1000;  /* Offset to avoid collision with cause records */
    
    length DDTESTCD $8 DDTEST $200;
    DDTESTCD = "DTHREL";
    DDTEST = "RELATIONSHIP TO CAR-T THERAPY";
    
    length DDORRES $200 DDSTRESC $200;
    if not missing(RELATIONSHIP_TO_CART) then do;
        DDORRES = upcase(strip(RELATIONSHIP_TO_CART));
        DDSTRESC = DDORRES;
    end;
    
    /* Validate relationship values */
    if DDSTRESC not in ('NOT RELATED' 'UNLIKELY RELATED' 'POSSIBLY RELATED'
                        'PROBABLY RELATED' 'RELATED' '') then do;
        put "WARNING: Non-standard death relationship value: " DDSTRESC= "for" USUBJID=;
        call symputx('validation_warnings', 'YES');
    end;
    
    keep STUDYID DOMAIN USUBJID DDSEQ DDTESTCD DDTEST DDORRES DDSTRESC;
run;

/******************************************************************************
* STEP 5: CREATE AUTOPSY RECORDS
******************************************************************************/
data dd_autopsy;
    set raw_dd;
    where not missing(AUTOPSY_DONE);
    
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    DDSEQ = _N_ + 2000;  /* Offset for autopsy records */
    
    /* Autopsy performed */
    length DDTESTCD $8 DDTEST $200;
    DDTESTCD = "AUTOPSYP";
    DDTEST = "AUTOPSY PERFORMED";
    
    length DDORRES $200 DDSTRESC $200;
    if upcase(strip(AUTOPSY_DONE)) in ('YES', 'Y') then do;
        DDORRES = 'YES';
        DDSTRESC = 'Y';
    end;
    else if upcase(strip(AUTOPSY_DONE)) in ('NO', 'N') then do;
        DDORRES = 'NO';
        DDSTRESC = 'N';
    end;
    
    keep STUDYID DOMAIN USUBJID DDSEQ DDTESTCD DDTEST DDORRES DDSTRESC;
    
    /* Output autopsy performed record */
    output;
    
    /* If autopsy performed, create findings record */
    if DDSTRESC = 'Y' and not missing(AUTOPSY_FINDINGS) then do;
        DDSEQ = DDSEQ + 1;
        DDTESTCD = "AUTOPSYF";
        DDTEST = "AUTOPSY FINDINGS";
        DDORRES = strip(AUTOPSY_FINDINGS);
        DDSTRESC = DDORRES;
        output;
    end;
run;

/******************************************************************************
* STEP 6: COMBINE ALL DD RECORDS
******************************************************************************/
data dd;
    set dd_base dd_relationship dd_autopsy;
run;

proc sort data=dd;
    by USUBJID DDSEQ;
run;

proc sql noprint;
    select count(*) into :dd_count trimmed from dd;
    select count(distinct USUBJID) into :death_subj trimmed from dd;
quit;

%put NOTE: DD domain created with &dd_count records for &death_subj deceased subject(s);

/******************************************************************************
* STEP 7: DATA QUALITY CHECKS
******************************************************************************/

title "QC Check 1: Death Cause Distribution";
proc freq data=dd;
    where DDTESTCD = 'DTHCAUS';
    tables DDSTRESC / nocol nopercent;
run;
title;

title "QC Check 2: Relationship to CAR-T Distribution";
proc freq data=dd;
    where DDTESTCD = 'DTHREL';
    tables DDSTRESC / nocol nopercent;
run;
title;

title "QC Check 3: Autopsy Performed";
proc freq data=dd;
    where DDTESTCD = 'AUTOPSYP';
    tables DDSTRESC / nocol nopercent;
run;
title;

/******************************************************************************
* STEP 8: EXPORT TO CSV AND XPT
******************************************************************************/

%skip_processing:

proc export data=dd
    outfile="../../data/csv/dd.csv"
    dbms=csv
    replace;
run;

libname xptout xport "../../data/xpt/dd.xpt";
data xptout.dd;
    set dd;
run;
libname xptout clear;

%put NOTE: ============================================================;
%put NOTE: DD DOMAIN GENERATION COMPLETED;
%put NOTE: ============================================================;
%put NOTE: Output files created:;
%put NOTE:   CSV: ../../data/csv/dd.csv (&dd_count records);
%put NOTE:   XPT: ../../data/xpt/dd.xpt;
%put NOTE: ============================================================;
%if &death_count = 0 %then %put NOTE: No deaths in study - empty domain created;
%else %put NOTE: Deaths processed: &death_subj subject(s);
%put NOTE: ============================================================;

proc printto;
run;
