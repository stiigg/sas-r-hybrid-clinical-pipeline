/******************************************************************************
 Program: 38_sdtm_ex_v2.sas
 Purpose: Generate SDTM EX (Exposure) domain using metadata framework v2
 Author: Clinical Programming Portfolio
 Date: December 25, 2025

 Description:
   This program generates the SDTM EX (Exposure) domain using the universal
   metadata-driven transformation engine. It reads the specification from
   sdtm_ex_spec_v2.csv and applies all transformations automatically.

 Inputs:
   - sdtm/data/raw/exposure_raw.csv (or test data)
   - sdtm/specs/sdtm_ex_spec_v2.csv
   - sdtm.dm (for RFSTDTC reference date)

 Outputs:
   - sdtm.ex (SDTM Exposure domain)

 Dependencies:
   - sdtm_transformation_engine.sas
   - study_day_calculation.sas
   - qc_report_generator.sas

 Modification History:
   Date        Author      Description
   ----------  ----------  --------------------------------------------------
   2025-12-25  Portfolio   Initial v2 implementation using metadata framework
******************************************************************************/

%let pgm = 38_sdtm_ex_v2;
%let version = 2.0;

*-----------------------------------------------------------------------------
* 1. ENVIRONMENT SETUP
*-----------------------------------------------------------------------------;

options mprint mlogic symbolgen;
libname sdtm '../data/sdtm';
libname raw '../data/raw';

* Load universal macros;
%include '../macros/sdtm_transformation_engine.sas';
%include '../macros/study_day_calculation.sas';
%include '../macros/qc_report_generator.sas';

*-----------------------------------------------------------------------------
* 2. IMPORT RAW EXPOSURE DATA
*-----------------------------------------------------------------------------;

proc import datafile='../data/raw/exposure_raw.csv'
    out=raw.exposure
    dbms=csv
    replace;
    getnames=yes;
    guessingrows=max;
run;

* Log import status;
proc sql noprint;
    select count(*) into :n_raw_records from raw.exposure;
quit;

%put NOTE: Imported &n_raw_records raw exposure records;

*-----------------------------------------------------------------------------
* 3. MERGE WITH DM FOR REFERENCE DATE (RFSTDTC)
*-----------------------------------------------------------------------------;

* Ensure DM exists;
%if %sysfunc(exist(sdtm.dm)) = 0 %then %do;
    %put ERROR: SDTM.DM does not exist. Run 20_sdtm_dm_v2.sas first.;
    %abort cancel;
%end;

* Merge exposure data with DM to get RFSTDTC;
proc sql;
    create table work.exposure_with_dm as
    select 
        e.*,
        d.RFSTDTC,
        d.STUDYID
    from raw.exposure as e
    left join sdtm.dm as d
        on e.SUBJID = d.SUBJID
    order by e.SUBJID, e.START_DATE;
quit;

* Validation: Check for missing RFSTDTC;
proc sql noprint;
    select count(*) into :n_missing_rfst from work.exposure_with_dm
    where missing(RFSTDTC);
quit;

%if &n_missing_rfst > 0 %then %do;
    %put WARNING: &n_missing_rfst exposure records have missing RFSTDTC.;
    %put WARNING: These records will have missing study days.;
%end;

*-----------------------------------------------------------------------------
* 4. CALL UNIVERSAL TRANSFORMATION ENGINE
*-----------------------------------------------------------------------------;

%put NOTE: Calling universal transformation engine for EX domain;

%sdtm_transformation_engine(
    spec_file = ../specs/sdtm_ex_spec_v2.csv,
    input_data = work.exposure_with_dm,
    output_data = work.ex_transformed,
    domain = EX,
    debug = Y
);

*-----------------------------------------------------------------------------
* 5. APPLY STUDY DAY CALCULATIONS
*-----------------------------------------------------------------------------;

%put NOTE: Calculating study days for EX domain;

data work.ex_with_studyday;
    set work.ex_transformed;
    
    * Call study day calculation macro for start date;
    if not missing(EXSTDTC) and not missing(RFSTDTC) then do;
        %study_day_calc(
            event_date = EXSTDTC,
            reference_date = RFSTDTC,
            output_var = EXSTDY
        );
    end;
    
    * Call study day calculation macro for end date;
    if not missing(EXENDTC) and not missing(RFSTDTC) then do;
        %study_day_calc(
            event_date = EXENDTC,
            reference_date = RFSTDTC,
            output_var = EXENDY
        );
    end;
    
    * Derive EPOCH based on study day;
    if missing(EXSTDY) then EPOCH = '';
    else if EXSTDY < 0 then EPOCH = 'SCREENING';
    else if EXSTDY >= 1 and EXSTDY <= 84 then EPOCH = 'TREATMENT';
    else EPOCH = 'FOLLOW-UP';
    
    format EXSTDTC EXENDTC $20.;
run;

*-----------------------------------------------------------------------------
* 6. FINAL SORTING AND SELECTION
*-----------------------------------------------------------------------------;

proc sort data=work.ex_with_studyday out=sdtm.ex;
    by STUDYID USUBJID EXSEQ;
run;

* Keep only required SDTM variables (drop intermediate variables);
data sdtm.ex;
    retain STUDYID DOMAIN USUBJID EXSEQ EXTRT EXDOSE EXDOSU EXDOSFRM 
           EXROUTE EXDOSFRQ EXSTDTC EXENDTC EXSTDY EXENDY EPOCH;
    set sdtm.ex;
    keep STUDYID DOMAIN USUBJID EXSEQ EXTRT EXDOSE EXDOSU EXDOSFRM 
         EXROUTE EXDOSFRQ EXSTDTC EXENDTC EXSTDY EXENDY EPOCH;
run;

*-----------------------------------------------------------------------------
* 7. QC CHECKS AND REPORTING
*-----------------------------------------------------------------------------;

%put NOTE: Running QC checks for EX domain;

* Generate QC report using universal macro;
%qc_report_generator(
    dataset = sdtm.ex,
    domain = EX,
    spec_file = ../specs/sdtm_ex_spec_v2.csv,
    output_file = ../qc/reports/ex_qc_report.html
);

* Basic record count validation;
proc sql noprint;
    select count(*) into :n_final_records from sdtm.ex;
quit;

%put NOTE: ============================================;
%put NOTE: EX Domain Generation Complete;
%put NOTE: Input records: &n_raw_records;
%put NOTE: Output records: &n_final_records;
%put NOTE: Missing RFSTDTC: &n_missing_rfst;
%put NOTE: Output: sdtm.ex;
%put NOTE: ============================================;

*-----------------------------------------------------------------------------
* 8. OPTIONAL: PRINT SAMPLE RECORDS
*-----------------------------------------------------------------------------;

title "SDTM EX Domain - First 10 Records";
proc print data=sdtm.ex(obs=10) noobs;
run;
title;

* Clean up temporary datasets;
proc datasets library=work nolist;
    delete exposure_with_dm ex_transformed ex_with_studyday;
quit;

/*** END OF PROGRAM ***/