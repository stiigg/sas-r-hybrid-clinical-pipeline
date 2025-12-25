/******************************************************************************
* Macro: CALCULATE_STUDY_DAY
* Purpose: Calculate SDTM --DY variables relative to RFSTDTC from DM domain
* Author: Christian Baghai
* Date: 2025-12-25
* Version: 2.0
*
* Description:
*   Shared utility macro for calculating study day variables according to
*   SDTM Implementation Guide rules. Study day can never be zero - days
*   before reference start date are negative, days on or after are positive
*   starting at 1.
*
* SDTM Study Day Rules (SDTMIG 3.4):
*   - If date >= RFSTDTC: study_day = date - RFSTDTC + 1
*   - If date < RFSTDTC: study_day = date - RFSTDTC (negative)
*   - Study day can NEVER be zero
*
* Parameters:
*   DATE_VAR     - Source date variable name (SAS date format)
*   RFSTDTC_VAR  - Reference start date variable (ISO 8601 character format)
*   STDY_VAR     - Output study day variable name (e.g., AESTDY, VSSTDY)
*   ENDY_VAR     - Optional end study day variable (e.g., AEENDY, VSENDY)
*
* Usage:
*   Called within DATA step processing. Generates inline SAS code for
*   study day calculation.
*
* Example:
*   data ae;
*       set raw_ae;
*       %calculate_study_day(
*           date_var=AE_START_DATE,
*           rfstdtc_var=RFSTDTC,
*           stdy_var=AESTDY
*       );
*   run;
*
* Notes:
*   - RFSTDTC must be converted from ISO 8601 character to SAS date
*   - Missing dates result in missing study days
*   - Used across AE, VS, LB, EX, CM, DS, and other event domains
******************************************************************************/

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
