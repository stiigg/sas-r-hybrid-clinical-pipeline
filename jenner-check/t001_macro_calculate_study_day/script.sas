/******************************************************************************
* Program: calculate_study_day caller (Jenner compatibility bundle)
* Purpose: Exercise the shared CALCULATE_STUDY_DAY utility macro
* Author:  Christian Baghai (caller adapted for Jenner self-contained run)
*
* Source:  sdtm/macros/study_day_calculation.sas
*
* CALCULATE_STUDY_DAY implements the SDTMIG 3.4 study-day rule
* (--DY relative to DM.RFSTDTC, never zero) as inline DATA-step code.
* This driver builds a small adverse-event-style fixture and uses the macro
* exactly as documented in its header:
*
*   data ae;
*       set raw_ae;
*       %calculate_study_day(date_var=AESTDT, rfstdtc_var=RFSTDTC,
*                            stdy_var=AESTDY, endy_var=AEENDY);
*   run;
******************************************************************************/

%put NOTE: ================================================;
%put NOTE: CALCULATE_STUDY_DAY utility - demonstration;
%put NOTE: ================================================;
%macro calculate_study_day(
    date_var=,      /* Source date variable (SAS date) */
    rfstdtc_var=,   /* Reference start date (ISO8601 char) */
    stdy_var=,      /* Output study day variable name */
    endy_var=       /* Optional end study day variable */
);

    /* Calculate start study day */
    if not missing(&date_var) and not missing(input(&rfstdtc_var, yymmdd10.)) then do;
        if &date_var >= input(&rfstdtc_var, yymmdd10.) then 
            &stdy_var = &date_var - input(&rfstdtc_var, yymmdd10.) + 1;
        else 
            &stdy_var = &date_var - input(&rfstdtc_var, yymmdd10.);
    end;
    
    /* Calculate end study day if variable specified */
    %if %length(&endy_var) > 0 %then %do;
        if not missing(&date_var) and not missing(input(&rfstdtc_var, yymmdd10.)) then do;
            if &date_var >= input(&rfstdtc_var, yymmdd10.) then 
                &endy_var = &date_var - input(&rfstdtc_var, yymmdd10.) + 1;
            else 
                &endy_var = &date_var - input(&rfstdtc_var, yymmdd10.);
        end;
    %end;

%mend calculate_study_day;

/* Adverse-event-style fixture: subject reference start (RFSTDTC, ISO8601
   character) plus AE start/end dates as SAS dates. */
data raw_ae;
    length USUBJID $12 AETERM $20 RFSTDTC $10;
    infile datalines dsd truncover;
    input USUBJID $ AETERM $ RFSTDTC $ AESTDT :yymmdd10. AEENDT :yymmdd10.;
    format AESTDT AEENDT yymmdd10.;
    datalines;
CX-301-001,HEADACHE,2024-01-15,2024-01-20,2024-01-22
CX-301-001,NAUSEA,2024-01-15,2024-01-15,2024-01-16
CX-301-002,FATIGUE,2024-02-01,2024-01-28,2024-02-05
CX-301-002,FEVER,2024-02-01,2024-02-10,2024-02-12
CX-301-003,RASH,2024-03-10,2024-03-10,.
;
run;

data ae;
    set raw_ae;
    %calculate_study_day(
        date_var=AESTDT,
        rfstdtc_var=RFSTDTC,
        stdy_var=AESTDY,
        endy_var=AEENDY
    );
    label AESTDY = "Study Day of AE Start"
          AEENDY = "Study Day of AE End";
run;

title "Adverse Events with Derived Study Days (SDTMIG 3.4)";
proc print data=ae label;
    var USUBJID AETERM RFSTDTC AESTDT AESTDY AEENDY;
run;
title;

%put NOTE: Study-day derivation complete. AESTDY must never be 0;
%put NOTE: (pre-reference dates negative, on/after positive starting at 1).;
