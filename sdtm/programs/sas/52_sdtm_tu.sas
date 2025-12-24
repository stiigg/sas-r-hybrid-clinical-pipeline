/******************************************************************************
* Program: 52_sdtm_tu.sas
* Purpose: Generate SDTM TU (Tumor Identification) domain
* Author:  Christian Baghai
* Date:    2025-12-24
* Input:   data/raw/tumor_identification_raw.csv
* Output:  outputs/sdtm/tu.xpt
* 
* Priority: CRITICAL for oncology - Foundation for TR and RS domains
* Notes:   Establishes baseline tumor identification and RECIST classification
******************************************************************************/

%let STUDYID = RECIST-DEMO-001;
%let DOMAIN = TU;

libname raw "../../data/raw";
libname sdtm "../../data/csv";

proc import datafile="../../data/raw/tumor_identification_raw.csv"
    out=raw_tu dbms=csv replace;
    guessingrows=max;
run;

data tu;
    set raw_tu;
    
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    TUSEQ = _N_;
    
    /* Unique lesion identifier - CRITICAL for linking to TR domain */
    length TULINKID $8;
    TULINKID = cats("LES", put(LESION_NUMBER, z3.));
    /* Example: LES001, LES002, LES003 */
    
    /* Test identification */
    length TUTESTCD $8 TUTEST $40;
    TUTESTCD = "TUMIDENT";
    TUTEST = "Tumor Identification";
    
    /* Tumor location */
    length TULOC $200;
    if not missing(ANATOMICAL_LOCATION) then
        TULOC = upcase(strip(ANATOMICAL_LOCATION));
    /* Examples: LIVER, LUNG, LYMPH NODE, BONE */
    
    /* Laterality */
    length TULAT $8;
    if not missing(LATERALITY) then do;
        TULAT = case(upcase(strip(LATERALITY)))
            when 'L' then 'LEFT'
            when 'LEFT' then 'LEFT'
            when 'R' then 'RIGHT'
            when 'RIGHT' then 'RIGHT'
            when 'B' then 'BILATERAL'
            when 'BILATERAL' then 'BILATERAL'
            else ''
        end;
    end;
    
    /* Lesion description (verbatim) */
    length TUORRES $200;
    if not missing(LESION_DESCRIPTION) then
        TUORRES = upcase(strip(LESION_DESCRIPTION));
    
    /* RECIST classification - CRITICAL */
    length TUSTRESC $40;
    TUSTRESC = case(upcase(strip(LESION_TYPE)))
        when 'TARGET' then 'TARGET'
        when 'T' then 'TARGET'
        when 'NON-TARGET' then 'NON-TARGET'
        when 'NONTARGET' then 'NON-TARGET'
        when 'NT' then 'NON-TARGET'
        when 'N' then 'NON-TARGET'
        when 'NEW' then 'NEW'
        else 'TARGET'  /* Default to target if missing */
    end;
    
    /* Method of assessment */
    length TUMETHOD $40;
    if not missing(IMAGING_METHOD) then
        TUMETHOD = upcase(strip(IMAGING_METHOD));
    /* CT SCAN, MRI, PET SCAN, CHEST X-RAY, PHYSICAL EXAMINATION */
    
    /* Evaluator */
    length TUEVAL $40;
    if not missing(EVALUATOR) then
        TUEVAL = upcase(strip(EVALUATOR));
    else
        TUEVAL = "INVESTIGATOR";
    /* INVESTIGATOR, INDEPENDENT REVIEW COMMITTEE */
    
    /* Baseline identification date */
    length TUDTC $20;
    if not missing(BASELINE_SCAN_DATE) then
        TUDTC = put(BASELINE_SCAN_DATE, yymmdd10.);
    
    /* Visit - should be baseline/screening visit */
    length VISIT $40;
    if not missing(VISIT_NAME) then
        VISIT = upcase(strip(VISIT_NAME));
    else
        VISIT = "BASELINE";
    VISITNUM = coalesce(VISIT_NUMBER, 1);
    
    keep STUDYID DOMAIN USUBJID TUSEQ TULINKID 
         TUTESTCD TUTEST TULOC TULAT TUORRES TUSTRESC
         TUMETHOD TUEVAL TUDTC VISIT VISITNUM;
run;

proc sort data=tu; by USUBJID TUSEQ; run;

/* Validation: Check for duplicate TULINKID within subject */
proc sql;
    create table tu_check as
    select USUBJID, TULINKID, count(*) as n_records
    from tu
    group by USUBJID, TULINKID
    having n_records > 1;
quit;

%let n_duplicates = &sqlobs;
%if &n_duplicates > 0 %then %do;
    %put ERROR: &n_duplicates duplicate TULINKID found - check TU domain;
    proc print data=tu_check; run;
%end;
%else %do;
    %put NOTE: No duplicate TULINKID found - validation passed;
%end;

/* Summary statistics */
proc freq data=tu;
    tables TUSTRESC TULOC TUMETHOD TUEVAL / missing;
    title "TU Domain - Tumor Classification and Location";
run;

proc sql;
    select 
        TUSTRESC as Lesion_Type,
        count(*) as N_Lesions,
        count(distinct USUBJID) as N_Subjects
    from tu
    group by TUSTRESC;
quit;

proc export data=tu outfile="../../data/csv/tu.csv" dbms=csv replace; run;

libname xptout xport "../../data/xpt/tu.xpt";
data xptout.tu; set tu; run;
libname xptout clear;

%put NOTE: TU domain generation completed successfully;
%put NOTE: Output files created:;
%put NOTE:   - ../../data/csv/tu.csv;
%put NOTE:   - ../../data/xpt/tu.xpt;
