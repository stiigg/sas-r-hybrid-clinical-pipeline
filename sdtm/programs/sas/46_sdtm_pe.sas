/******************************************************************************
* Program: 46_sdtm_pe.sas
* Purpose: Generate SDTM PE (Physical Examination) domain
* Author:  Christian Baghai
* Date:    2025-12-24
* Input:   data/raw/physical_exam_raw.csv
* Output:  outputs/sdtm/pe.xpt
* 
* Priority: MEDIUM - Physical assessment safety monitoring
* Notes:   Body system examinations (HEENT, CV, RESP, etc.)
******************************************************************************/

%let STUDYID = RECIST-DEMO-001;
%let DOMAIN = PE;

libname raw "../../data/raw";
libname sdtm "../../data/csv";

proc import datafile="../../data/raw/physical_exam_raw.csv"
    out=raw_pe dbms=csv replace;
    guessingrows=max;
run;

data pe;
    set raw_pe;
    
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    PESEQ = _N_;
    
    /* Body system examined */
    length PETESTCD $8 PETEST $40;
    if not missing(BODY_SYSTEM_CODE) then
        PETESTCD = upcase(strip(BODY_SYSTEM_CODE));
    if not missing(BODY_SYSTEM_NAME) then
        PETEST = upcase(strip(BODY_SYSTEM_NAME));
    else
        PETEST = case(PETESTCD)
            when 'HEENT' then 'Head, Ears, Eyes, Nose, Throat'
            when 'RESP' then 'Respiratory'
            when 'CV' then 'Cardiovascular'
            when 'GI' then 'Gastrointestinal'
            when 'MUSC' then 'Musculoskeletal'
            when 'SKIN' then 'Skin'
            when 'NEURO' then 'Neurological'
            else PETESTCD
        end;
    
    /* Finding */
    length PEORRES $200 PESTRESC $8;
    if not missing(FINDING_TEXT) then
        PEORRES = upcase(strip(FINDING_TEXT));
    
    PESTRESC = case(upcase(strip(FINDING)))
        when 'NORMAL' then 'NORMAL'
        when 'N' then 'NORMAL'
        when 'ABNORMAL' then 'ABNORMAL'
        when 'ABN' then 'ABNORMAL'
        when 'A' then 'ABNORMAL'
        when 'NOT DONE' then 'NOT DONE'
        when 'ND' then 'NOT DONE'
        else 'NORMAL'
    end;
    
    /* Category */
    length PECAT $40;
    PECAT = "PHYSICAL EXAMINATION";
    
    /* Timing */
    length PEDTC $20;
    if not missing(EXAM_DATE) then
        PEDTC = put(EXAM_DATE, yymmdd10.);
    
    /* Visit */
    length VISIT $40;
    if not missing(VISIT_NAME) then
        VISIT = upcase(strip(VISIT_NAME));
    VISITNUM = VISIT_NUMBER;
    
    keep STUDYID DOMAIN USUBJID PESEQ PETESTCD PETEST 
         PEORRES PESTRESC PECAT PEDTC VISIT VISITNUM;
run;

proc sort data=pe; by USUBJID PESEQ; run;

proc freq data=pe;
    tables PETESTCD PESTRESC / missing;
    title "PE Domain - Physical Examination Findings";
run;

proc export data=pe outfile="../../data/csv/pe.csv" dbms=csv replace; run;

libname xptout xport "../../data/xpt/pe.xpt";
data xptout.pe; set pe; run;
libname xptout clear;

%put NOTE: PE domain generation completed successfully;
