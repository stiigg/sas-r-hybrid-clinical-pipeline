/******************************************************************************
* Program: 48_sdtm_pr.sas (PRODUCTION VERSION 1.0)
* Purpose: Generate FDA-compliant SDTM PR (Procedures) domain for NEXICART-2
* Author:  Christian Baghai
* Date:    2025-12-27
* Input:   sdtm/data/raw/procedures_raw.csv
* Output:  sdtm/data/csv/pr.csv, sdtm/data/xpt/pr.xpt
* 
* Priority: CRITICAL - MRD assessment, cardiac response, CAR-T flow tracking
* Standards: SDTM IG v3.4, FDA Technical Conformance Guide v5.0
* Notes:   - MRD flow cytometry at 10^-5 and 10^-6 sensitivity
*          - Echocardiography for cardiac response (60% patients with cardiac involvement)
*          - Apheresis and CAR-T infusion procedure tracking
******************************************************************************/

%let STUDYID = NEXICART-2;
%let DOMAIN = PR;

%global validation_errors validation_warnings;
%let validation_errors = NO;
%let validation_warnings = NO;

libname raw "../../data/raw";
libname sdtm "../../data/csv";

proc printto log="../../logs/48_sdtm_pr.log" new;
run;

%put NOTE: ============================================================;
%put NOTE: Starting PR domain generation for NEXICART-2;
%put NOTE: Study: &STUDYID;
%put NOTE: Timestamp: %sysfunc(datetime(), datetime20.);
%put NOTE: ============================================================;

/******************************************************************************
* STEP 1: IMPORT RAW PROCEDURES DATA
******************************************************************************/
proc import datafile="../../data/raw/procedures_raw.csv"
    out=raw_pr
    dbms=csv
    replace;
    guessingrows=max;
run;

/******************************************************************************
* STEP 2: GET REFERENCE START DATE FROM DM DOMAIN
******************************************************************************/
proc sql noprint;
    create table dm_dates as
    select USUBJID, RFSTDTC
    from sdtm.dm;
    
    select count(*) into :dm_count trimmed from dm_dates;
quit;

%put NOTE: Retrieved reference dates for &dm_count subjects from DM;
