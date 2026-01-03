/******************************************************************************
* Macro: FORMAT_DATES
* Purpose: ISO 8601 date standardization and ADY/ADT derivation
* Version: 1.0
* 
* PARAMETERS:
*   inds           - Input dataset with date variables
*   outds          - Output dataset with formatted dates
*   date_var       - SDTM date variable (e.g., TRDTC)
*   rfstdtc_source - Reference start date source (ADSL dataset)
*   subjid_var     - Subject ID variable (default: USUBJID)
*
* DERIVATIONS:
*   - ADT: Analysis Date (numeric SAS date from TRDTC)
*   - ADY: Analysis Day (days from RFSTDTC)
*     * ADY = ADT - RFSTDT if ADT < RFSTDT
*     * ADY = ADT - RFSTDT + 1 if ADT >= RFSTDT
*     * No ADY = 0 per CDISC standards
*
* ALGORITHM:
*   - Parse ISO 8601 dates (YYYY-MM-DD, YYYY-MM-DDTHH:MM:SS)
*   - Handle partial dates (YYYY-MM, YYYY)
*   - Merge RFSTDTC from ADSL
*   - Calculate ADY with proper handling of pre/post reference dates
*   - Preserve original date strings
*
* REFERENCES:
*   - CDISC SDTM IG v3.4: ISO 8601 date formats
*   - CDISC ADaM IG v1.3: ADY derivation rules
*
* EXAMPLE USAGE:
*   %format_dates(
*       inds=work.tr_raw,
*       outds=work.tr_with_ady,
*       date_var=TRDTC,
*       rfstdtc_source=work.adsl
*   );
*
* AUTHOR: Christian Baghai
* DATE: 2026-01-03
******************************************************************************/

%macro format_dates(
    inds=,
    outds=,
    date_var=TRDTC,
    rfstdtc_source=,
    subjid_var=USUBJID
) / des="ISO 8601 date standardization and ADY/ADT derivation";

    /* Parameter validation */
    %if %length(&inds) = 0 or %length(&outds) = 0 %then %do;
        %put ERROR: [FORMAT_DATES] Parameters INDS and OUTDS are required;
        %return;
    %end;
    
    %if %length(&rfstdtc_source) = 0 %then %do;
        %put ERROR: [FORMAT_DATES] Parameter RFSTDTC_SOURCE is required for ADY derivation;
        %return;
    %end;
    
    %put NOTE: [FORMAT_DATES] Starting date formatting and ADY derivation;
    %put NOTE: [FORMAT_DATES] Date variable: &date_var;
    
    /* Extract RFSTDTC from source */
    proc sql;
        create table _rfstdtc_lookup as
        select distinct &subjid_var, RFSTDTC
        from &rfstdtc_source
        where not missing(RFSTDTC);
    quit;
    
    /* Merge and derive dates */
    data &outds;
        merge &inds(in=a)
              _rfstdtc_lookup(in=b);
        by &subjid_var;
        
        if a;  /* Keep all records from input dataset */
        
        /* Initialize ADT and ADY */
        length ADT 8;
        length ADY 8;
        format ADT date9.;
        
        /* Parse analysis date from SDTM date variable */
        if not missing(&date_var) then do;
            
            /* Extract date portion (handle both date and datetime formats) */
            _date_str = scan(&date_var, 1, 'T');  /* Split at 'T' for ISO 8601 datetime */
            
            /* Attempt to parse YYYY-MM-DD format */
            ADT = input(_date_str, yymmdd10.);
            
            /* If parsing failed, try other formats */
            if missing(ADT) then do;
                /* Try YYYY-MM format (use first day of month) */
                if length(_date_str) = 7 and substr(_date_str, 5, 1) = '-' then do;
                    ADT = input(cats(_date_str, '-01'), yymmdd10.);
                end;
                /* Try YYYY format (use first day of year) */
                else if length(_date_str) = 4 then do;
                    ADT = input(cats(_date_str, '-01-01'), yymmdd10.);
                end;
            end;
            
        end;
        
        /* Parse reference start date */
        if not missing(RFSTDTC) then do;
            _rfstdt_str = scan(RFSTDTC, 1, 'T');
            RFSTDT = input(_rfstdt_str, yymmdd10.);
            format RFSTDT date9.;
        end;
        
        /* Derive ADY per CDISC rules */
        if not missing(ADT) and not missing(RFSTDT) then do;
            
            /* Calculate day difference */
            _day_diff = ADT - RFSTDT;
            
            /* Apply CDISC rule: no ADY = 0 */
            if _day_diff >= 0 then ADY = _day_diff + 1;  /* Post-baseline: add 1 */
            else ADY = _day_diff;                        /* Pre-baseline: negative */
            
        end;
        
        /* Label variables */
        label ADT = "Analysis Date"
              ADY = "Analysis Relative Day"
              RFSTDT = "Reference Start Date";
        
        /* Clean up temporary variables */
        drop _date_str _rfstdt_str _day_diff;
        
    run;
    
    /* Validation summary */
    proc sql noprint;
        select count(*) into :n_records trimmed from &outds;
        select count(*) into :n_with_adt trimmed from &outds where not missing(ADT);
        select count(*) into :n_with_ady trimmed from &outds where not missing(ADY);
        select count(*) into :n_missing_rfstdt trimmed from &outds where missing(RFSTDT);
    quit;
    
    %put NOTE: [FORMAT_DATES] Date Derivation Summary:;
    %put NOTE: [FORMAT_DATES]   Total records: &n_records;
    %put NOTE: [FORMAT_DATES]   Records with ADT: &n_with_adt;
    %put NOTE: [FORMAT_DATES]   Records with ADY: &n_with_ady;
    %put NOTE: [FORMAT_DATES]   Missing RFSTDT: &n_missing_rfstdt;
    
    %if &n_missing_rfstdt > 0 %then %do;
        %put WARNING: [FORMAT_DATES] &n_missing_rfstdt records cannot derive ADY due to missing RFSTDT;
    %end;
    
    %let pct_ady = %sysevalf((&n_with_ady / &n_records) * 100);
    %put NOTE: [FORMAT_DATES] ADY derivation coverage: %sysfunc(putn(&pct_ady, 5.1))%;
    
    /* Clean up */
    proc datasets library=work nolist;
        delete _rfstdtc_lookup;
    quit;
    
    %put NOTE: [FORMAT_DATES] Date formatting complete;
    
%mend format_dates;