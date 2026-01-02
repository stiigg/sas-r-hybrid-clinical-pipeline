/******************************************************************************
* Program: 81_adam_adrs_recist.sas
* Purpose: Response Analysis Dataset - RECIST 1.1 with Confirmation
* Author:  Christian Baghai
* Date:    2026-01-03
* Version: 1.0 - NEXICART-2 solid tumor implementation
* 
* Input:   sdtm/data/csv/rs.csv (from 54a_sdtm_rs_recist.sas output)
*          adam/data/adtr.csv (SLD percent changes)
*          sdtm/data/csv/dm.csv
* Output:  adam/data/adrs_recist.csv, adam/data/xpt/adrs_recist.xpt
* 
* Priority: CRITICAL - Primary efficacy endpoint (ORR, BOR)
* 
* Parameters Derived per RECIST 1.1:
*   - OVRLRESP: Overall response at each assessment
*   - BOR: Best Overall Response (confirmed)
* 
* NEW 2024-2025 Variables:
*   - CONFIRMED_FL: Confirmation status flag
*   - CONFIRM_DY: Days between initial and confirmatory assessment
*   - CONFIRM_TYPE: Pattern of confirmation (CR->CR, PR->PR/CR)
* 
* Reference: RECIST 1.1 - Eisenhauer et al. Eur J Cancer 2009
*            CDISC 2024 - BOR confirmation methods
*            PharmaSUG 2025-SA-287 - Dual review implementation
******************************************************************************/

%let STUDYID = NEXICART2-SOLID-TUMOR;

libname sdtm "../../sdtm/data/csv";
libname adam "../../adam/data";

/* ========================================
   STEP 1: Import Required Datasets
   ======================================== */

title "NEXICART-2 ADRS (RECIST): Import Source Datasets";

/* Import SDTM RS (Response Status from your 54a_sdtm_rs_recist.sas) */
proc import datafile="../../sdtm/data/csv/rs.csv"
    out=rs_raw dbms=csv replace;
    guessingrows=max;
run;

/* Import ADTR for SLD validation */
proc import datafile="../../adam/data/adtr.csv"
    out=adtr dbms=csv replace;
    guessingrows=max;
run;

/* Import DM */
data dm;
    set sdtm.dm;
    keep USUBJID STUDYID RFSTDTC ARM ACTARM;
run;

/* ========================================
   STEP 2: Extract Overall Response from RS Domain
   ======================================== */

title "NEXICART-2 ADRS (RECIST): Extract Overall Response per Assessment";

data rs_overall;
    set rs_raw;
    where RSTESTCD = 'OVRLRESP';  /* Overall response from your RS domain */
    
    keep USUBJID RSDTC RSDY RSSTRESC VISIT VISITNUM RSEVAL;
    
    rename RSDTC=ADTC RSDY=ADY RSSTRESC=AVALC VISIT=AVISIT VISITNUM=AVISITN;
run;

/* ========================================
   STEP 3: Create Numeric Response Values
   ======================================== */

title "NEXICART-2 ADRS (RECIST): Assign Numeric Response Hierarchy";

data adrs_timepoint;
    set rs_overall;
    
    length AVAL 8;
    
    /* RECIST 1.1 hierarchy: CR (4) > PR (3) > SD (2) > PD (1) */
    select (upcase(AVALC));
        when ('CR') AVAL = 4;
        when ('PR') AVAL = 3;
        when ('SD') AVAL = 2;
        when ('PD') AVAL = 1;
        when ('NE') AVAL = 0;  /* Not evaluable */
        otherwise AVAL = .;
    end;
    
    /* Analysis date */
    ADT = input(ADTC, yymmdd10.);
    format ADT date9.;
    
    label AVALC = "Overall Response (Character)"
          AVAL = "Overall Response (Numeric: 4=CR, 1=PD)";
run;

proc sort data=adrs_timepoint; by USUBJID ADY; run;

/* ========================================
   STEP 4: Derive Confirmation Status (2024-2025 ENHANCEMENT)
   Per CDISC 2024 and RECIST 1.1 Table 3
   ======================================== */

title "NEXICART-2 ADRS (RECIST): CRITICAL - Derive Confirmation (≥28 days)";
title2 "Per CDISC 2024 and RECIST 1.1 Table 3";

data adrs_with_confirm;
    set adrs_timepoint;
    by USUBJID ADY;
    
    retain prev_response prev_ady prev_aval;
    
    /* NEW 2024-2025 variables */
    length CONFIRMED_FL $1 CONFIRM_TYPE $10;
    CONFIRMED_FL = '';
    CONFIRM_DY = .;
    CONFIRM_TYPE = '';
    
    if first.USUBJID then do;
        prev_response = '';
        prev_ady = .;
        prev_aval = .;
    end;
    else do;
        /* Check for confirmation (CR or PR maintained ≥28 days) */
        if AVALC in ('CR','PR') and prev_response in ('CR','PR') then do;
            days_apart = ADY - prev_ady;
            
            /* Confirmation criteria per RECIST 1.1 */
            if days_apart >= 28 then do;
                if prev_response = 'CR' and AVALC = 'CR' then do;
                    CONFIRMED_FL = 'Y';
                    CONFIRM_DY = days_apart;
                    CONFIRM_TYPE = 'CR->CR';
                end;
                else if prev_response = 'PR' and AVALC in ('PR','CR') then do;
                    CONFIRMED_FL = 'Y';
                    CONFIRM_DY = days_apart;
                    if AVALC = 'CR' then CONFIRM_TYPE = 'PR->CR';
                    else CONFIRM_TYPE = 'PR->PR';
                end;
                else if prev_response = 'CR' and AVALC = 'PR' then do;
                    /* CR followed by PR at >=28 days confirms PR */
                    CONFIRMED_FL = 'Y';
                    CONFIRM_DY = days_apart;
                    CONFIRM_TYPE = 'CR->PR';
                end;
            end;
        end;
    end;
    
    /* Update previous values for next iteration */
    prev_response = AVALC;
    prev_ady = ADY;
    prev_aval = AVAL;
    
    drop days_apart;
    
    label CONFIRMED_FL = "Confirmation Status (Y if >=28 days apart)"
          CONFIRM_DY = "Days Between Initial and Confirmatory Assessment"
          CONFIRM_TYPE = "Confirmation Pattern per CDISC 2024";
run;

/* ========================================
   STEP 5: Derive Best Overall Response (BOR) - CRITICAL
   Per RECIST 1.1 Table 4 Hierarchy
   ======================================== */

title "NEXICART-2 ADRS (RECIST): Derive Best Overall Response (BOR)";
title2 "RECIST 1.1 Table 4 - Confirmation Required for CR/PR";

/* BOR = Highest CONFIRMED response */
proc sql;
    create table bor_derivation as
    select USUBJID,
           max(case when CONFIRMED_FL='Y' then AVAL else . end) as BOR_NUM,
           max(case when AVALC='PD' then 1 else 0 end) as PD_FLAG,
           min(case when CONFIRMED_FL='Y' and AVALC in ('CR','PR') 
                    then ADY else . end) as BOR_DAY,
           min(case when CONFIRMED_FL='Y' and AVALC in ('CR','PR')
                    then ADT else . end) as BOR_DATE format=date9.
    from adrs_with_confirm
    group by USUBJID;
quit;

/* Apply RECIST Table 4 logic */
data bor_final;
    set bor_derivation;
    
    length BOR $2;
    
    /* RECIST 1.1 Table 4 hierarchy */
    if not missing(BOR_NUM) then do;
        select (BOR_NUM);
            when (4) BOR = 'CR';
            when (3) BOR = 'PR';
            when (2) BOR = 'SD';
            when (1) BOR = 'PD';
            otherwise BOR = 'NE';
        end;
    end;
    else BOR = 'NE';  /* No confirmed response */
    
    /* Numeric BOR */
    BOR_AVAL = BOR_NUM;
    if missing(BOR_AVAL) then BOR_AVAL = 0;
    
    label BOR = "Best Overall Response per RECIST 1.1"
          BOR_AVAL = "Best Overall Response (Numeric)"
          BOR_DAY = "Study Day of Best Response"
          BOR_DATE = "Date of Best Response";
run;

/* ========================================
   STEP 6: Create BDS Structure with BOR Parameter
   ======================================== */

title "NEXICART-2 ADRS (RECIST): Create Final ADRS with BOR";

/* Append BOR as separate parameter */
data bor_records;
    set bor_final;
    
    length PARAMCD $8 PARAM $200;
    PARAMCD = 'BOR';
    PARAM = 'Best Overall Response (RECIST 1.1 - Confirmed)';
    
    AVALC = BOR;
    AVAL = BOR_AVAL;
    ADY = BOR_DAY;
    ADT = BOR_DATE;
    
    /* BOR is at patient level, not tied to specific visit */
    AVISIT = 'OVERALL';
    AVISITN = 99;
    
    keep USUBJID PARAMCD PARAM AVALC AVAL ADY ADT AVISIT AVISITN;
run;

/* Combine timepoint responses with BOR */
data adrs_timepoint_param;
    set adrs_with_confirm;
    
    length PARAMCD $8 PARAM $200;
    PARAMCD = 'OVRLRESP';
    PARAM = 'Overall Response per RECIST 1.1 (Investigator)';
run;

data adrs_combined;
    set adrs_timepoint_param
        bor_records;
run;

proc sort data=adrs_combined; by USUBJID PARAMCD ADY; run;

/* ========================================
   STEP 7: Derive Efficacy Endpoint Flags
   ======================================== */

title "NEXICART-2 ADRS (RECIST): Derive Efficacy Endpoint Flags";

data adrs_with_flags;
    merge adrs_combined
          bor_final(keep=USUBJID BOR rename=(BOR=BOR_VALUE))
          dm;
    by USUBJID;
    
    /* Complete Response Flag */
    length CRFL $1;
    if BOR_VALUE = 'CR' then CRFL = 'Y';
    else CRFL = 'N';
    
    /* Overall Response Rate Flag (CR + PR) */
    length ORRFL $1;
    if BOR_VALUE in ('CR','PR') then ORRFL = 'Y';
    else ORRFL = 'N';
    
    /* Disease Control Rate Flag (CR + PR + SD) */
    length DCRFL $1;
    if BOR_VALUE in ('CR','PR','SD') then DCRFL = 'Y';
    else DCRFL = 'N';
    
    /* Progressive Disease Flag */
    length PDFL $1;
    if BOR_VALUE = 'PD' then PDFL = 'Y';
    else PDFL = 'N';
    
    label CRFL = "Complete Response Flag"
          ORRFL = "Overall Response Rate Flag (CR+PR)"
          DCRFL = "Disease Control Rate Flag (CR+PR+SD)"
          PDFL = "Progressive Disease Flag";
run;

/* ========================================
   STEP 8: Add Analysis Flags and Sequence
   ======================================== */

data adrs;
    set adrs_with_flags;
    
    length ANL01FL $1;
    if not missing(AVALC) then ANL01FL = 'Y';
    else ANL01FL = '';
    
    ASEQ = _N_;
    
    label ANL01FL = "Analysis Flag 01"
          ASEQ = "Analysis Sequence Number";
run;

/* ========================================
   STEP 9: QC VALIDATION & SUMMARY REPORTS
   ======================================== */

title "NEXICART-2 ADRS (RECIST) QC: Patient Response Trajectory";
title2 "Verify: Confirmation logic, BOR derivation per RECIST Table 4";

proc print data=adrs(where=(PARAMCD='OVRLRESP') obs=100);
    by USUBJID;
    id USUBJID;
    var AVISIT ADY AVALC AVAL CONFIRMED_FL CONFIRM_DY CONFIRM_TYPE;
run;

title "NEXICART-2 ADRS (RECIST) Summary: Best Overall Response Distribution";
title2 "Primary Endpoint: ORR = CR + PR (confirmed responses only)";

proc freq data=adrs(where=(PARAMCD='BOR'));
    tables AVALC*ORRFL / nocol nopercent;
    tables CRFL ORRFL DCRFL PDFL / nocum;
run;

title "NEXICART-2 ADRS (RECIST) Summary: Overall Response Rate";

proc sql;
    select count(distinct USUBJID) as N_PATIENTS label="Total Patients",
           sum(ORRFL='Y') as ORR_N label="ORR (n)",
           calculated ORR_N / calculated N_PATIENTS * 100 as ORR_PCT format=5.1 label="ORR (%)",
           sum(CRFL='Y') as CR_N label="CR (n)",
           calculated CR_N / calculated N_PATIENTS * 100 as CR_PCT format=5.1 label="CR (%)"
    from adrs
    where PARAMCD = 'BOR';
quit;

/* ========================================
   STEP 10: EXPORT DATASETS
   ======================================== */

title "NEXICART-2 ADRS (RECIST): Export Final Dataset";

proc export data=adrs 
            outfile="../../adam/data/adrs_recist.csv" 
            dbms=csv replace; 
run;

libname xptout xport "../../adam/data/xpt/adrs_recist.xpt";
data xptout.adrs_recist;
    set adrs;
run;

proc contents data=adrs varnum;
    title "NEXICART-2 ADRS (RECIST): Dataset Contents";
run;

%put NOTE: ============================================;
%put NOTE: ADRS (RECIST 1.1) dataset created successfully;
%put NOTE: Enhancement per 2024-2025 standards:;
%put NOTE:   - CONFIRMED_FL: Confirmation status;
%put NOTE:   - CONFIRM_DY: Days between assessments;
%put NOTE:   - CONFIRM_TYPE: Confirmation pattern;
%put NOTE: BOR derived per RECIST Table 4 hierarchy;
%put NOTE: Key endpoints: ORR (CR+PR), DCR (CR+PR+SD);
%put NOTE: Output: adam/data/adrs_recist.csv;
%put NOTE: ============================================;
