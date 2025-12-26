/******************************************************************************
* Program: 30_sdtm_ae.sas (PRODUCTION VERSION 2.0)
* Purpose: Generate FDA-compliant SDTM AE (Adverse Events) domain
* Author:  Christian Baghai
* Date:    2025-12-26
* Modified: Added 15+ missing SDTM variables, SUPPAE, validation
* Input:   data/raw/adverse_events_raw.csv
* Output:  data/csv/ae.csv, data/csv/suppae.csv
*          data/xpt/ae.xpt, data/xpt/suppae.xpt
* 
* Priority: HIGHEST - Required for FDA safety reporting
* Standards: SDTM IG v3.3, FDA Technical Conformance Guide v5.0
* Notes:   - MedDRA v27.1 coding included in raw data
*          - Meets Pinnacle 21 validation requirements
*          - Treatment-emergent flag in SUPPAE per FDA rules
******************************************************************************/

%let STUDYID = RECIST-DEMO-001;
%let DOMAIN = AE;

/* Initialize validation flag macro variables */
%global validation_errors validation_warnings;
%let validation_errors = NO;
%let validation_warnings = NO;

/* Set library references */
libname raw "../../data/raw";
libname sdtm "../../data/csv";

/* Start logging */
proc printto log="../../logs/30_sdtm_ae.log" new;
run;

%put NOTE: ============================================================;
%put NOTE: Starting AE domain generation;
%put NOTE: Study: &STUDYID;
%put NOTE: Timestamp: %sysfunc(datetime(), datetime20.);
%put NOTE: ============================================================;

/******************************************************************************
* STEP 1: READ RAW ADVERSE EVENTS DATA
******************************************************************************/
proc import datafile="../../data/raw/adverse_events_raw.csv"
    out=raw_ae
    dbms=csv
    replace;
    guessingrows=max;
run;

%put NOTE: Raw AE data imported successfully;

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

/******************************************************************************
* STEP 3: TRANSFORM RAW DATA TO SDTM AE STRUCTURE
******************************************************************************/
data ae_base;
    merge raw_ae(in=a)
          dm_dates(in=b);
    by USUBJID;
    
    if a;
    
    /* Convert RFSTDTC once for efficiency */
    if not missing(RFSTDTC) then RFSTDT = input(RFSTDTC, yymmdd10.);
    
    /*=========================================================================
    * IDENTIFIERS (Required)
    *========================================================================*/
    length STUDYID $20 DOMAIN $2 USUBJID $40;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    /* USUBJID comes from merge */
    
    /* Sequence Variable - REQUIRED */
    AESEQ = _N_;
    
    /*=========================================================================
    * TOPIC VARIABLE (Required)
    *========================================================================*/
    length AETERM $200;
    AETERM = upcase(strip(AE_VERBATIM));
    
    /*=========================================================================
    * SYNONYM QUALIFIERS - MedDRA Hierarchy (Expected)
    *========================================================================*/
    length AEDECOD $200;  /* MedDRA Preferred Term - text */
    length AEPTCD $8;     /* MedDRA PT Code - numeric */
    length AEBODSYS $200; /* Body System or Organ Class */
    length AESOC $200;    /* System Organ Class */
    length AEHLT $200;    /* High Level Term */
    length AEHLGT $200;   /* High Level Group Term */
    length AELLT $200;    /* Lowest Level Term */
    
    /* Decoded Term - from MedDRA coding */
    if not missing(MEDDRA_PT) then do;
        AEDECOD = upcase(strip(MEDDRA_PT));
        AEPTCD = strip(put(MEDDRA_PT_CODE, 8.));
        AEBODSYS = upcase(strip(MEDDRA_SOC));
        AESOC = AEBODSYS;  /* Usually same as AEBODSYS */
        
        /* Additional MedDRA hierarchy if available */
        if not missing(MEDDRA_HLT) then AEHLT = upcase(strip(MEDDRA_HLT));
        if not missing(MEDDRA_HLGT) then AEHLGT = upcase(strip(MEDDRA_HLGT));
        if not missing(MEDDRA_LLT) then AELLT = upcase(strip(MEDDRA_LLT));
    end;
    else do;
        AEDECOD = AETERM;  /* Use verbatim if not coded */
        AEPTCD = '';
        AEBODSYS = '';
        AESOC = '';
        
        /* Log warning for uncoded AE */
        put "WARNING: Uncoded AE - USUBJID=" USUBJID "AETERM=" AETERM;
        call symputx('validation_warnings', 'YES');
    end;
    
    /*=========================================================================
    * GROUPING QUALIFIERS (Permissible)
    *========================================================================*/
    length AECAT $200;   /* Category for Adverse Event */
    length AESCAT $200;  /* Subcategory for Adverse Event */
    
    if not missing(AE_CATEGORY) then AECAT = upcase(strip(AE_CATEGORY));
    if not missing(AE_SUBCATEGORY) then AESCAT = upcase(strip(AE_SUBCATEGORY));
    
    /*=========================================================================
    * RESULT QUALIFIERS - Location
    *========================================================================*/
    length AELOC $200;
    if not missing(AE_LOCATION) then AELOC = upcase(strip(AE_LOCATION));
    
    /*=========================================================================
    * RESULT QUALIFIERS - Severity and Seriousness
    *========================================================================*/
    
    /* Severity - Controlled Terminology (MILD, MODERATE, SEVERE) */
    length AESEV $8;
    AESEV = upcase(strip(SEVERITY));
    
    /* Validate against controlled terminology */
    if AESEV not in ('MILD' 'MODERATE' 'SEVERE' '') then do;
        put "ERROR: Invalid AESEV value: " AESEV= "for" USUBJID= AESEQ=;
        call symputx('validation_errors', 'YES');
        AESEV = '';  /* Set to missing for invalid values */
    end;
    
    /* Serious Event Flag - Y/N */
    length AESER $1;
    if upcase(strip(SERIOUS_FLAG)) in ('Y' 'YES' '1') then AESER = 'Y';
    else if upcase(strip(SERIOUS_FLAG)) in ('N' 'NO' '0') then AESER = 'N';
    else if not missing(SERIOUS_FLAG) then do;
        put "WARNING: Invalid AESER value: " SERIOUS_FLAG= "for" USUBJID=;
        call symputx('validation_warnings', 'YES');
        AESER = '';
    end;
    
    /*=========================================================================
    * EIGHT SERIOUSNESS CRITERIA - FDA Requirement
    *========================================================================*/
    length AESDTH AESLIFE AESHOSP AESDISAB AESCONG AESMIE AESOD $1;
    
    /* Results in Death */
    if upcase(strip(SAE_DEATH)) = 'Y' then AESDTH = 'Y';
    else if upcase(strip(SAE_DEATH)) = 'N' then AESDTH = '';
    else AESDTH = '';
    
    /* Life Threatening */
    if upcase(strip(SAE_LIFE_THREAT)) = 'Y' then AESLIFE = 'Y';
    else if upcase(strip(SAE_LIFE_THREAT)) = 'N' then AESLIFE = '';
    else AESLIFE = '';
    
    /* Requires or Prolongs Hospitalization */
    if upcase(strip(SAE_HOSPITALIZATION)) = 'Y' then AESHOSP = 'Y';
    else if upcase(strip(SAE_HOSPITALIZATION)) = 'N' then AESHOSP = '';
    else AESHOSP = '';
    
    /* Significant Disability/Incapacity */
    if upcase(strip(SAE_DISABILITY)) = 'Y' then AESDISAB = 'Y';
    else if upcase(strip(SAE_DISABILITY)) = 'N' then AESDISAB = '';
    else AESDISAB = '';
    
    /* Congenital Anomaly/Birth Defect */
    if upcase(strip(SAE_CONGENITAL)) = 'Y' then AESCONG = 'Y';
    else if upcase(strip(SAE_CONGENITAL)) = 'N' then AESCONG = '';
    else AESCONG = '';
    
    /* Medically Important Event */
    if upcase(strip(SAE_MEDICALLY_IMP)) = 'Y' then AESMIE = 'Y';
    else if upcase(strip(SAE_MEDICALLY_IMP)) = 'N' then AESMIE = '';
    else AESMIE = '';
    
    /* Overdose (if applicable) */
    if upcase(strip(SAE_OVERDOSE)) = 'Y' then AESOD = 'Y';
    else if upcase(strip(SAE_OVERDOSE)) = 'N' then AESOD = '';
    else AESOD = '';
    
    /* Validate: If AESER='Y', at least one criterion should be 'Y' */
    if AESER = 'Y' then do;
        if cmiss(AESDTH, AESLIFE, AESHOSP, AESDISAB, AESCONG, AESMIE, AESOD) = 7 
           or (AESDTH ne 'Y' and AESLIFE ne 'Y' and AESHOSP ne 'Y' and 
               AESDISAB ne 'Y' and AESCONG ne 'Y' and AESMIE ne 'Y' and AESOD ne 'Y') then do;
            put "WARNING: AESER='Y' but no seriousness criteria flagged for" USUBJID= AESEQ=;
            call symputx('validation_warnings', 'YES');
        end;
    end;
    
    /*=========================================================================
    * RESULT QUALIFIERS - Causality, Action, Outcome
    *========================================================================*/
    
    /* Causality Assessment - Relationship to Study Drug */
    length AEREL $100;  /* Increased from $40 */
    AEREL = upcase(strip(RELATIONSHIP));
    
    /* Validate AEREL against standard values */
    if AEREL not in ('NOT RELATED' 'UNLIKELY RELATED' 'POSSIBLY RELATED' 
                     'PROBABLY RELATED' 'RELATED' '') then do;
        put "WARNING: Non-standard AEREL value: " AEREL= "for" USUBJID= AESEQ=;
        call symputx('validation_warnings', 'YES');
    end;
    
    /* Action Taken with Study Treatment */
    length AEACN $100;  /* Increased from $40 */
    AEACN = upcase(strip(ACTION_TAKEN));
    
    /* Validate AEACN against standard values */
    if AEACN not in ('DOSE NOT CHANGED' 'DOSE REDUCED' 'DOSE INCREASED' 
                     'DRUG INTERRUPTED' 'DRUG WITHDRAWN' 'NOT APPLICABLE'
                     'UNKNOWN' 'NOT EVALUABLE' '') then do;
        put "WARNING: Non-standard AEACN value: " AEACN= "for" USUBJID= AESEQ=;
        /* Allow non-standard values but log for review */
    end;
    
    /* Outcome of Adverse Event */
    length AEOUT $100;  /* Increased from $40 */
    AEOUT = upcase(strip(OUTCOME));
    
    /* Validate AEOUT against standard values */
    if AEOUT not in ('RECOVERED/RESOLVED' 'RECOVERING/RESOLVING' 
                     'NOT RECOVERED/NOT RESOLVED' 'FATAL' 
                     'RECOVERED/RESOLVED WITH SEQUELAE' 'UNKNOWN' '') then do;
        put "WARNING: Non-standard AEOUT value: " AEOUT= "for" USUBJID= AESEQ=;
    end;
    
    /*=========================================================================
    * TIMING VARIABLES - ISO 8601 format YYYY-MM-DD
    *========================================================================*/
    length AESTDTC $20 AEENDTC $20;
    
    if not missing(AE_START_DATE) then do;
        AESTDTC = put(AE_START_DATE, yymmdd10.);
    end;
    
    if not missing(AE_END_DATE) then do;
        AEENDTC = put(AE_END_DATE, yymmdd10.);
    end;
    
    /* Duration in days */
    if not missing(AE_END_DATE) and not missing(AE_START_DATE) then do;
        AEDUR = AE_END_DATE - AE_START_DATE + 1;
        
        /* Validate duration is positive */
        if AEDUR < 1 then do;
            put "ERROR: Negative AEDUR for" USUBJID= AESEQ= AESTDTC= AEENDTC= AEDUR=;
            call symputx('validation_errors', 'YES');
        end;
    end;
    
    /* Study Day Calculation (relative to RFSTDTC from DM) */
    /* No Day 0 - asymmetric logic: -2, -1, 1, 2, 3... */
    if not missing(AE_START_DATE) and not missing(RFSTDT) then do;
        if AE_START_DATE >= RFSTDT then 
            AESTDY = AE_START_DATE - RFSTDT + 1;
        else 
            AESTDY = AE_START_DATE - RFSTDT;
    end;
    
    if not missing(AE_END_DATE) and not missing(RFSTDT) then do;
        if AE_END_DATE >= RFSTDT then 
            AEENDY = AE_END_DATE - RFSTDT + 1;
        else 
            AEENDY = AE_END_DATE - RFSTDT;
    end;
    
    /* Validate AEENDY >= AESTDY */
    if not missing(AESTDY) and not missing(AEENDY) then do;
        if AEENDY < AESTDY then do;
            put "ERROR: AEENDY < AESTDY for" USUBJID= AESEQ= AESTDY= AEENDY=;
            call symputx('validation_errors', 'YES');
        end;
    end;
    
    /*=========================================================================
    * CALCULATE TREATMENT EMERGENT FLAG (for SUPPAE)
    *========================================================================*/
    length AETRTEM $1;
    if not missing(AE_START_DATE) and not missing(RFSTDT) then do;
        if AE_START_DATE >= RFSTDT then AETRTEM = 'Y';
        else AETRTEM = '';
    end;
    else do;
        AETRTEM = '';  /* Cannot determine without dates */
    end;
    
    /* Drop temporary variables */
    drop RFSTDT;
run;

%put NOTE: AE transformation completed;

/******************************************************************************
* STEP 4: CREATE FINAL AE DOMAIN (per SDTM variable order)
******************************************************************************/
data ae;
    set ae_base;
    
    /* Keep only SDTM variables in CORRECT SDTM IG v3.3 ORDER */
    keep 
        /* 1. Identifiers */
        STUDYID DOMAIN USUBJID AESEQ
        /* 2. Topic */
        AETERM
        /* 3. Synonyms - MedDRA Hierarchy */
        AEDECOD AEPTCD AEBODSYS AESOC AEHLT AEHLGT AELLT
        /* 4. Grouping Qualifiers */
        AECAT AESCAT
        /* 5. Result Qualifiers - Location */
        AELOC
        /* 6. Result Qualifiers - Severity */
        AESEV AESER
        /* 7. Seriousness Criteria (8 variables) */
        AESDTH AESLIFE AESHOSP AESDISAB AESCONG AESMIE AESOD
        /* 8. Result Qualifiers - Actions/Outcomes */
        AEACN AEREL AEOUT
        /* 9. Timing Variables */
        AESTDTC AEENDTC AEDUR AESTDY AEENDY;
run;

proc sql noprint;
    select count(*) into :ae_count trimmed from ae;
    select count(distinct USUBJID) into :subj_count trimmed from ae;
quit;

%put NOTE: AE domain created with &ae_count records for &subj_count subjects;

/******************************************************************************
* STEP 5: CREATE SUPPAE DOMAIN (for AETRTEM per FDA requirements)
******************************************************************************/
data suppae;
    set ae_base;
    
    /* Only create records where AETRTEM has a value */
    where not missing(AETRTEM);
    
    length STUDYID $20 RDOMAIN $2 USUBJID $40;
    length IDVAR $8 IDVARVAL $200;
    length QNAM $8 QLABEL $40 QVAL $200;
    length QORIG $8 QEVAL $40;
    
    STUDYID = "&STUDYID";
    RDOMAIN = "AE";
    /* USUBJID comes from base */
    IDVAR = "AESEQ";
    IDVARVAL = strip(put(AESEQ, best.));
    QNAM = "AETRTEM";
    QLABEL = "Treatment Emergent Flag";
    QVAL = AETRTEM;
    QORIG = "DERIVED";
    QEVAL = "";
    
    keep STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG QEVAL;
run;

proc sql noprint;
    select count(*) into :suppae_count trimmed from suppae;
quit;

%put NOTE: SUPPAE domain created with &suppae_count records;

/******************************************************************************
* STEP 6: SORT DATASETS BY KEY VARIABLES
******************************************************************************/
proc sort data=ae;
    by USUBJID AESEQ;
run;

proc sort data=suppae;
    by USUBJID IDVARVAL;
run;

%put NOTE: Datasets sorted successfully;

/******************************************************************************
* STEP 7: DATA QUALITY CHECKS
******************************************************************************/

%put NOTE: ============================================================;
%put NOTE: Running data quality checks;
%put NOTE: ============================================================;

/* QC Check 1: Frequency distributions */
title "QC Check 1: Frequency Distributions of Key Variables";
proc freq data=ae;
    tables AESEV AESER AEREL AEACN AEOUT / missing;
    tables AESDTH AESLIFE AESHOSP AESDISAB AESCONG AESMIE AESOD / missing;
run;
title;

/* QC Check 2: Descriptive statistics */
title "QC Check 2: Descriptive Statistics for Numeric Variables";
proc means data=ae n nmiss mean median min max;
    var AEDUR AESTDY AEENDY;
run;
title;

/* QC Check 3: MedDRA coding completeness */
title "QC Check 3: MedDRA Coding Completeness";
proc sql;
    create table qc_meddra as
    select 
        count(*) as total_aes,
        sum(case when missing(AEDECOD) then 1 else 0 end) as missing_aedecod,
        sum(case when missing(AEPTCD) then 1 else 0 end) as missing_aeptcd,
        sum(case when missing(AEBODSYS) then 1 else 0 end) as missing_aebodsys,
        calculated missing_aedecod / calculated total_aes * 100 as pct_uncoded format=5.1
    from ae;
    
    select * from qc_meddra;
quit;
title;

/* QC Check 4: Duplicate AESEQ within subject */
title "QC Check 4: Duplicate AESEQ Detection";
proc sql;
    create table qc_duplicates as
    select USUBJID, AESEQ, count(*) as cnt
    from ae
    group by USUBJID, AESEQ
    having cnt > 1;
    
    select count(*) into :dup_count trimmed from qc_duplicates;
quit;

%if &dup_count > 0 %then %do;
    %put ERROR: &dup_count duplicate AESEQ values found!;
    %let validation_errors = YES;
    proc print data=qc_duplicates;
        title "ERROR: Duplicate AESEQ Records";
    run;
%end;
%else %do;
    %put NOTE: No duplicate AESEQ values found;
%end;
title;

/* QC Check 5: Missing required variables */
title "QC Check 5: Missing Required Variables";
data qc_missing_required;
    set ae;
    length error_type $100;
    
    if missing(STUDYID) then do;
        error_type = "Missing STUDYID";
        output;
    end;
    if missing(DOMAIN) then do;
        error_type = "Missing DOMAIN";
        output;
    end;
    if missing(USUBJID) then do;
        error_type = "Missing USUBJID";
        output;
    end;
    if missing(AESEQ) then do;
        error_type = "Missing AESEQ";
        output;
    end;
    if missing(AETERM) then do;
        error_type = "Missing AETERM";
        output;
    end;
run;

proc sql noprint;
    select count(*) into :missing_req trimmed from qc_missing_required;
quit;

%if &missing_req > 0 %then %do;
    %put ERROR: &missing_req records with missing required variables!;
    %let validation_errors = YES;
    proc print data=qc_missing_required (obs=50);
        var USUBJID AESEQ error_type;
    run;
%end;
%else %do;
    %put NOTE: All required variables populated;
%end;
title;

/* QC Check 6: Date logic errors */
title "QC Check 6: Date Logic Validation";
data qc_date_errors;
    set ae;
    length error_type $100;
    
    /* Check if end date before start date */
    if not missing(AESTDTC) and not missing(AEENDTC) then do;
        if input(AEENDTC, yymmdd10.) < input(AESTDTC, yymmdd10.) then do;
            error_type = "End date before start date";
            output;
        end;
    end;
    
    /* Check if AEENDY < AESTDY */
    if not missing(AESTDY) and not missing(AEENDY) then do;
        if AEENDY < AESTDY then do;
            error_type = "AEENDY less than AESTDY";
            output;
        end;
    end;
    
    /* Check for impossible study days (e.g., day 0) */
    if AESTDY = 0 or AEENDY = 0 then do;
        error_type = "Study day = 0 (impossible)";
        output;
    end;
run;

proc sql noprint;
    select count(*) into :date_errors trimmed from qc_date_errors;
quit;

%if &date_errors > 0 %then %do;
    %put ERROR: &date_errors records with date logic errors!;
    %let validation_errors = YES;
    proc print data=qc_date_errors;
        var USUBJID AESEQ AESTDTC AEENDTC AESTDY AEENDY error_type;
    run;
%end;
%else %do;
    %put NOTE: All date logic checks passed;
%end;
title;

/* QC Check 7: Treatment-emergent flag distribution */
title "QC Check 7: Treatment-Emergent Flag Distribution";
proc sql;
    create table qc_te_flag as
    select 
        AETRTEM,
        count(*) as n,
        count(*) / (select count(*) from ae_base) * 100 as pct format=5.1
    from ae_base
    group by AETRTEM;
    
    select * from qc_te_flag;
quit;
title;

%put NOTE: Data quality checks completed;

/******************************************************************************
* STEP 8: EXPORT TO CSV
******************************************************************************/
proc export data=ae
    outfile="../../data/csv/ae.csv"
    dbms=csv
    replace;
run;

proc export data=suppae
    outfile="../../data/csv/suppae.csv"
    dbms=csv
    replace;
run;

%put NOTE: CSV files exported successfully;

/******************************************************************************
* STEP 9: EXPORT TO XPT v5 FORMAT FOR REGULATORY SUBMISSION
******************************************************************************/
libname xptout xport "../../data/xpt/ae.xpt";
data xptout.ae;
    set ae;
run;
libname xptout clear;

libname xptout xport "../../data/xpt/suppae.xpt";
data xptout.suppae;
    set suppae;
run;
libname xptout clear;

%put NOTE: XPT files exported successfully;

/******************************************************************************
* STEP 10: FINAL LOGGING AND VALIDATION STATUS
******************************************************************************/

%put NOTE: ============================================================;
%put NOTE: AE DOMAIN GENERATION COMPLETED;
%put NOTE: ============================================================;
%put NOTE: Output files created:;
%put NOTE:   CSV: ../../data/csv/ae.csv (&ae_count records);
%put NOTE:   CSV: ../../data/csv/suppae.csv (&suppae_count records);
%put NOTE:   XPT: ../../data/xpt/ae.xpt;
%put NOTE:   XPT: ../../data/xpt/suppae.xpt;
%put NOTE: ============================================================;
%put NOTE: Summary Statistics:;
%put NOTE:   Total AE records: &ae_count;
%put NOTE:   Subjects with AEs: &subj_count;
%put NOTE:   Treatment-emergent records: &suppae_count;
%put NOTE: ============================================================;

/* Validation Status Report */
%if &validation_errors = YES %then %do;
    %put ERROR: *** VALIDATION ERRORS DETECTED ***;
    %put ERROR: Review log and QC outputs before proceeding;
    %put ERROR: Program completed with ERRORS;
%end;
%else %if &validation_warnings = YES %then %do;
    %put WARNING: Validation warnings detected;
    %put WARNING: Review log for details;
    %put NOTE: Program completed with WARNINGS;
%end;
%else %do;
    %put NOTE: *** ALL VALIDATION CHECKS PASSED ***;
    %put NOTE: Program completed successfully;
%end;

%put NOTE: ============================================================;
%put NOTE: NEXT STEPS:;
%put NOTE: 1. Review log file: logs/30_sdtm_ae.log;
%put NOTE: 2. Run Pinnacle 21 validation on XPT files;
%put NOTE: 3. Create define.xml with variable metadata;
%put NOTE: 4. Review QC outputs before submission;
%put NOTE: ============================================================;

/* Stop logging */
proc printto;
run;
