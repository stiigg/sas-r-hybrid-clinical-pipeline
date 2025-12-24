/******************************************************************************
* Program: 50_sdtm_tr.sas
* Purpose: Generate SDTM TR (Tumor Results) domain
* Author:  Christian Baghai
* Date:    2025-12-24
* Input:   data/raw/tumor_measurements_raw.csv
* Output:  outputs/sdtm/tr.xpt
* 
* Priority: CRITICAL for oncology - Contains actual tumor measurements
* Notes:   Links to TU domain via TRLINKID; feeds into RS domain calculations
******************************************************************************/

%let STUDYID = RECIST-DEMO-001;
%let DOMAIN = TR;

libname raw "../../data/raw";
libname sdtm "../../data/csv";

proc import datafile="../../data/raw/tumor_measurements_raw.csv"
    out=raw_tr dbms=csv replace;
    guessingrows=max;
run;

/* Get TU domain for validation */
data tu_lesions;
    set sdtm.tu;
    keep USUBJID TULINKID TUSTRESC;
run;

data tr;
    set raw_tr;
    
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    TRSEQ = _N_;
    
    /* Link to TU domain - CRITICAL */
    length TRLINKID $8;
    TRLINKID = cats("LES", put(LESION_NUMBER, z3.));
    /* Must match TULINKID from TU domain */
    
    /* Test code - LDIAM for longest diameter */
    length TRTESTCD $8 TRTEST $40;
    if not missing(TEST_CODE) then
        TRTESTCD = upcase(strip(TEST_CODE));
    else
        TRTESTCD = "LDIAM";  /* Default to longest diameter */
    
    if not missing(TEST_NAME) then
        TRTEST = upcase(strip(TEST_NAME));
    else if TRTESTCD = "LDIAM" then
        TRTEST = "Longest Diameter";
    else if TRTESTCD = "RESPONSE" then
        TRTEST = "Response";
    
    /* Measurement results - for target lesions */
    length TRORRES $200 TRORRESU $8;
    if not missing(DIAMETER_VALUE) then do;
        TRORRES = strip(put(DIAMETER_VALUE, best.));
        if not missing(DIAMETER_UNIT) then
            TRORRESU = upcase(strip(DIAMETER_UNIT));
        else
            TRORRESU = "MM";  /* Default to millimeters */
    end;
    /* For non-target lesions - qualitative assessment */
    else if not missing(QUALITATIVE_ASSESSMENT) then do;
        TRORRES = upcase(strip(QUALITATIVE_ASSESSMENT));
        /* PRESENT, ABSENT, UNEQUIVOCAL PROGRESSION */
    end;
    
    /* Standardized results */
    length TRSTRESC $200 TRSTRESU $8;
    TRSTRESC = TRORRES;
    if not missing(DIAMETER_VALUE) then do;
        TRSTRESN = DIAMETER_VALUE;
        TRSTRESU = TRORRESU;
    end;
    
    /* Method */
    length TRMETHOD $40;
    if not missing(IMAGING_METHOD) then
        TRMETHOD = upcase(strip(IMAGING_METHOD));
    
    /* Evaluator */
    length TREVAL $40;
    if not missing(EVALUATOR) then
        TREVAL = upcase(strip(EVALUATOR));
    else
        TREVAL = "INVESTIGATOR";
    
    /* Assessment date */
    length TRDTC $20;
    if not missing(ASSESSMENT_DATE) then
        TRDTC = put(ASSESSMENT_DATE, yymmdd10.);
    
    /* Visit */
    length VISIT $40;
    if not missing(VISIT_NAME) then
        VISIT = upcase(strip(VISIT_NAME));
    VISITNUM = VISIT_NUMBER;
    
    /* Epoch */
    length EPOCH $40;
    if VISITNUM = 1 then EPOCH = "SCREENING";
    else EPOCH = "TREATMENT";
    
    keep STUDYID DOMAIN USUBJID TRSEQ TRLINKID
         TRTESTCD TRTEST TRORRES TRORRESU TRSTRESC TRSTRESN TRSTRESU
         TRMETHOD TREVAL TRDTC VISIT VISITNUM EPOCH;
run;

proc sort data=tr; by USUBJID TRSEQ; run;

/* Validation: Ensure all TRLINKID exist in TU domain */
proc sql;
    create table tr_orphans as
    select distinct a.USUBJID, a.TRLINKID
    from tr a
    where not exists (
        select 1 from tu_lesions b
        where a.USUBJID = b.USUBJID
          and a.TRLINKID = b.TULINKID
    );
quit;

%let n_orphans = &sqlobs;
%if &n_orphans > 0 %then %do;
    %put WARNING: &n_orphans TR records found without corresponding TU records;
    proc print data=tr_orphans; run;
%end;
%else %do;
    %put NOTE: All TR records have corresponding TU records - validation passed;
%end;

/* Summary statistics */
proc means data=tr n nmiss mean median min max std;
    where not missing(TRSTRESN);
    var TRSTRESN;
    class VISIT;
    title "TR Domain - Tumor Measurement Summary by Visit";
run;

proc freq data=tr;
    tables TREVAL TRMETHOD / missing;
    title "TR Domain - Evaluator and Method Frequencies";
run;

proc export data=tr outfile="../../data/csv/tr.csv" dbms=csv replace; run;

libname xptout xport "../../data/xpt/tr.xpt";
data xptout.tr; set tr; run;
libname xptout clear;

%put NOTE: TR domain generation completed successfully;
%put NOTE: Output files created:;
%put NOTE:   - ../../data/csv/tr.csv;
%put NOTE:   - ../../data/xpt/tr.xpt;
