/******************************************************************************
* Program: 30_sdtm_ae.sas (CAR-T ENHANCED VERSION 3.0)
* Purpose: Generate FDA-compliant SDTM AE domain with CAR-T enhancements
* Author:  Christian Baghai
* Date:    2025-12-29
* Modified: Added CAR-T specific categorization, expanded SUPPAE, validation
* Input:   data/raw/adverse_events_cart_raw.csv
* Output:  data/csv/ae.csv, data/csv/suppae.csv
*          data/xpt/ae.xpt, data/xpt/suppae.xpt
* 
* Priority: HIGHEST - Required for CAR-T BLA safety reporting
* Standards: SDTM IG v3.3, FDA Technical Conformance Guide v5.0
*            ASTCT 2019 Consensus CRS/ICANS Grading
* Features: - MedDRA v27.1 coding
*           - CAR-T specific AECAT/AESCAT categorization
*           - ASTCT grading for CRS/ICANS in SUPPAE
*           - Infection pathogen tracking
*           - Prolonged cytopenia flagging
*           - Cardiovascular event detection
*           - carHLH identification
*           - CAR-T specific validation checks
******************************************************************************/

%let STUDYID = CAR-T-DEMO-001;
%let DOMAIN = AE;

/* Initialize validation flag macro variables */
%global validation_errors validation_warnings;
%let validation_errors = NO;
%let validation_warnings = NO;

/* Set library references */
libname raw "../../data/raw";
libname sdtm "../../data/csv";

/* Start logging */
proc printto log="../../logs/30_sdtm_ae_cart.log" new;
run;

%put NOTE: ============================================================;
%put NOTE: Starting CAR-T Enhanced AE domain generation;
%put NOTE: Study: &STUDYID;
%put NOTE: Timestamp: %sysfunc(datetime(), datetime20.);
%put NOTE: ============================================================;

/******************************************************************************
* STEP 1: READ RAW ADVERSE EVENTS DATA (CAR-T Enhanced)
******************************************************************************/
proc import datafile="../../data/raw/adverse_events_cart_raw.csv"
    out=raw_ae
    dbms=csv
    replace;
    guessingrows=max;
run;

%put NOTE: CAR-T enhanced raw AE data imported successfully;

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
* STEP 3: TRANSFORM RAW DATA TO SDTM AE WITH CAR-T CATEGORIZATION
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
    * GROUPING QUALIFIERS - CAR-T SPECIFIC CATEGORIZATION
    *========================================================================*/
    length AECAT $200;   /* Category for Adverse Event */
    length AESCAT $200;  /* Subcategory for Adverse Event */
    
    /*-------------------------------------------------------------------------
    * CAR-T TOXICITY DETECTION AND CATEGORIZATION (FDA COMPLIANT)
    *------------------------------------------------------------------------*/
    
    %put NOTE: Applying CAR-T specific categorization logic;
    
    /* Initialize CAR-T category flags */
    length IS_CART_TOX $1 CART_TOX_TYPE $40;
    IS_CART_TOX = 'N';
    CART_TOX_TYPE = '';
    
    /* 1. CRS DETECTION */
    if upcase(strip(CRS_FLAG)) = 'Y' or
       index(upcase(AEDECOD), 'CYTOKINE RELEASE') > 0 or
       index(upcase(AETERM), 'CRS') > 0 then do;
        
        AECAT = 'CAR-T TOXICITY';
        AESCAT = 'CRS';
        IS_CART_TOX = 'Y';
        CART_TOX_TYPE = 'CRS';
        
        /* CRITICAL: Fever required for CRS per ASTCT */
        if missing(CRS_FEVER_PRESENT) or upcase(CRS_FEVER_PRESENT) ne 'Y' then do;
            put "ERROR: CRS requires fever per ASTCT 2019" USUBJID= AESEQ=;
            call symputx('validation_errors', 'YES');
        end;
        
        /* Validate ASTCT grade */
        if missing(ASTCT_CRS_GRADE) then do;
            put "ERROR: Missing ASTCT_CRS_GRADE for CRS" USUBJID= AESEQ=;
            call symputx('validation_errors', 'YES');
        end;
    end;
    
    /* 2. ICANS DETECTION */
    else if upcase(strip(ICANS_FLAG)) = 'Y' or
       index(upcase(AEDECOD), 'ICANS') > 0 or
       index(upcase(AEDECOD), 'IMMUNE EFFECTOR CELL') > 0 or
       index(upcase(AEDECOD), 'ENCEPHALOPATHY') > 0 then do;
        
        AECAT = 'CAR-T TOXICITY';
        AESCAT = 'ICANS';
        IS_CART_TOX = 'Y';
        CART_TOX_TYPE = 'ICANS';
        
        /* CRITICAL: ICE Score required */
        if missing(ICE_SCORE) then do;
            put "ERROR: Missing ICE_SCORE for ICANS" USUBJID= AESEQ=;
            call symputx('validation_errors', 'YES');
        end;
    end;
    
    /* 3. INFECTION CATEGORIZATION */
    else if upcase(strip(INFECTION_FLAG)) = 'Y' or
       index(upcase(AEBODSYS), 'INFECTIONS AND INFESTATIONS') > 0 then do;
        
        AECAT = 'INFECTION';
        CART_TOX_TYPE = 'INFECTION';
        
        /* Subcategorize by timing */
        if not missing(INFECTION_ONSET_DAY_POST_INFUSION) then do;
            if INFECTION_ONSET_DAY_POST_INFUSION <= 7 then
                AESCAT = 'EARLY INFECTION (0-7 DAYS)';
            else if INFECTION_ONSET_DAY_POST_INFUSION <= 30 then
                AESCAT = 'INTERMEDIATE INFECTION (8-30 DAYS)';
            else if INFECTION_ONSET_DAY_POST_INFUSION <= 90 then
                AESCAT = 'LATE INFECTION (31-90 DAYS)';
            else
                AESCAT = 'VERY LATE INFECTION (>90 DAYS)';
        end;
    end;
    
    /* 4. CYTOPENIA CATEGORIZATION */
    else if upcase(strip(CYTOPENIA_FLAG)) = 'Y' or
       index(upcase(AEDECOD), 'NEUTROPENIA') > 0 or
       index(upcase(AEDECOD), 'THROMBOCYTOPENIA') > 0 or
       index(upcase(AEDECOD), 'ANEMIA') > 0 then do;
        
        AECAT = 'HEMATOLOGIC';
        CART_TOX_TYPE = 'CYTOPENIA';
        
        /* Duration-based subcategorization */
        if not missing(CYTOPENIA_DURATION_DAYS) then do;
            if CYTOPENIA_DURATION_DAYS <= 30 then
                AESCAT = 'ACUTE CYTOPENIA (≤30 DAYS)';
            else if CYTOPENIA_DURATION_DAYS <= 90 then
                AESCAT = 'PROLONGED CYTOPENIA (31-90 DAYS)';
            else
                AESCAT = 'CHRONIC CYTOPENIA (>90 DAYS)';
        end;
    end;
    
    /* 5. CARDIOVASCULAR EVENTS */
    else if upcase(strip(CV_EVENT_FLAG)) = 'Y' or
       index(upcase(AEBODSYS), 'CARDIAC DISORDERS') > 0 then do;
        
        AECAT = 'CARDIOVASCULAR';
        CART_TOX_TYPE = 'CARDIAC';
        
        if not missing(CV_EVENT_TYPE) then
            AESCAT = upcase(strip(CV_EVENT_TYPE));
        else
            AESCAT = 'CARDIAC EVENT';
    end;
    
    /* 6. carHLH DETECTION */
    else if upcase(strip(CARHLH_FLAG)) = 'Y' or
       index(upcase(AEDECOD), 'HEMOPHAGOCYTIC') > 0 then do;
        
        AECAT = 'CAR-T TOXICITY';
        AESCAT = 'carHLH';
        IS_CART_TOX = 'Y';
        CART_TOX_TYPE = 'carHLH';
        
        /* carHLH is ALWAYS serious */
        AESER = 'Y';
        if AESEV ne 'SEVERE' then AESEV = 'SEVERE';
    end;
    
    /* 7. HYPOGAMMAGLOBULINEMIA */
    else if upcase(strip(HYPOGAMMA_FLAG)) = 'Y' or
       index(upcase(AEDECOD), 'HYPOGAMMAGLOBULINEMIA') > 0 then do;
        
        AECAT = 'IMMUNE DEFICIENCY';
        AESCAT = 'HYPOGAMMAGLOBULINEMIA';
        CART_TOX_TYPE = 'IMMUNE_DEFICIENCY';
    end;
    
    /* Preserve manual categorization if no CAR-T category detected */
    if CART_TOX_TYPE = '' then do;
        if not missing(AE_CATEGORY) then AECAT = upcase(strip(AE_CATEGORY));
        if not missing(AE_SUBCATEGORY) then AESCAT = upcase(strip(AE_SUBCATEGORY));
    end;
    
    /*=========================================================================
    * RESULT QUALIFIERS - Location, Severity, Seriousness
    *========================================================================*/
    length AELOC $200;
    if not missing(AE_LOCATION) then AELOC = upcase(strip(AE_LOCATION));
    
    /* Severity */
    length AESEV $8;
    AESEV = upcase(strip(SEVERITY));
    
    /* Serious Event Flag */
    length AESER $1;
    if upcase(strip(SERIOUS_FLAG)) in ('Y' 'YES' '1') then AESER = 'Y';
    else if upcase(strip(SERIOUS_FLAG)) in ('N' 'NO' '0') then AESER = 'N';
    
    /*=========================================================================
    * EIGHT SERIOUSNESS CRITERIA
    *========================================================================*/
    length AESDTH AESLIFE AESHOSP AESDISAB AESCONG AESMIE AESOD $1;
    
    if upcase(strip(SAE_DEATH)) = 'Y' then AESDTH = 'Y';
    else AESDTH = '';
    
    if upcase(strip(SAE_LIFE_THREAT)) = 'Y' then AESLIFE = 'Y';
    else AESLIFE = '';
    
    if upcase(strip(SAE_HOSPITALIZATION)) = 'Y' then AESHOSP = 'Y';
    else AESHOSP = '';
    
    if upcase(strip(SAE_DISABILITY)) = 'Y' then AESDISAB = 'Y';
    else AESDISAB = '';
    
    if upcase(strip(SAE_CONGENITAL)) = 'Y' then AESCONG = 'Y';
    else AESCONG = '';
    
    if upcase(strip(SAE_MEDICALLY_IMP)) = 'Y' then AESMIE = 'Y';
    else AESMIE = '';
    
    if upcase(strip(SAE_OVERDOSE)) = 'Y' then AESOD = 'Y';
    else AESOD = '';
    
    /*=========================================================================
    * RESULT QUALIFIERS - Causality, Action, Outcome
    *========================================================================*/
    length AEREL $100;
    AEREL = upcase(strip(RELATIONSHIP));
    
    length AEACN $100;
    AEACN = upcase(strip(ACTION_TAKEN));
    
    length AEOUT $100;
    AEOUT = upcase(strip(OUTCOME));
    
    /*=========================================================================
    * TIMING VARIABLES
    *========================================================================*/
    length AESTDTC $20 AEENDTC $20;
    
    if not missing(AE_START_DATE) then
        AESTDTC = put(AE_START_DATE, yymmdd10.);
    
    if not missing(AE_END_DATE) then
        AEENDTC = put(AE_END_DATE, yymmdd10.);
    
    /* Duration */
    if not missing(AE_END_DATE) and not missing(AE_START_DATE) then
        AEDUR = AE_END_DATE - AE_START_DATE + 1;
    
    /* Study Day Calculation */
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
    
    /*=========================================================================
    * TREATMENT EMERGENT FLAG
    *========================================================================*/
    length AETRTEM $1;
    if not missing(AE_START_DATE) and not missing(RFSTDT) then do;
        if AE_START_DATE >= RFSTDT then AETRTEM = 'Y';
        else AETRTEM = '';
    end;
    
    drop RFSTDT;
run;

%put NOTE: AE transformation with CAR-T categorization completed;

/******************************************************************************
* STEP 4: CREATE FINAL AE DOMAIN
******************************************************************************/
data ae;
    set ae_base;
    
    keep 
        STUDYID DOMAIN USUBJID AESEQ
        AETERM
        AEDECOD AEPTCD AEBODSYS AESOC AEHLT AEHLGT AELLT
        AECAT AESCAT
        AELOC
        AESEV AESER
        AESDTH AESLIFE AESHOSP AESDISAB AESCONG AESMIE AESOD
        AEACN AEREL AEOUT
        AESTDTC AEENDTC AEDUR AESTDY AEENDY;
run;

proc sql noprint;
    select count(*) into :ae_count trimmed from ae;
    select count(distinct USUBJID) into :subj_count trimmed from ae;
quit;

%put NOTE: AE domain created with &ae_count records for &subj_count subjects;

/******************************************************************************
* STEP 5: CREATE COMPREHENSIVE SUPPAE DOMAIN (CAR-T Enhanced)
******************************************************************************/

%put NOTE: Generating comprehensive SUPPAE domain for CAR-T submission;

/* Treatment-Emergent Flag */
data suppae_trtem;
    set ae_base;
    where not missing(AETRTEM);
    
    length STUDYID $20 RDOMAIN $2 USUBJID $40;
    length IDVAR $8 IDVARVAL $200;
    length QNAM $8 QLABEL $40 QVAL $200 QORIG $8 QEVAL $40;
    
    STUDYID = "&STUDYID";
    RDOMAIN = "AE";
    IDVAR = "AESEQ";
    IDVARVAL = strip(put(AESEQ, best.));
    QNAM = "AETRTEM";
    QLABEL = "Treatment Emergent Flag";
    QVAL = AETRTEM;
    QORIG = "DERIVED";
    QEVAL = "";
    
    keep STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG QEVAL;
run;

/* CRS-Specific SUPPAE */
data suppae_crs;
    set ae_base;
    where AESCAT = 'CRS';
    
    length STUDYID $20 RDOMAIN $2 USUBJID $40;
    length IDVAR $8 IDVARVAL $200;
    length QNAM $8 QLABEL $40 QVAL $200 QORIG $8 QEVAL $40;
    
    STUDYID = "&STUDYID";
    RDOMAIN = "AE";
    IDVAR = "AESEQ";
    IDVARVAL = strip(put(AESEQ, best.));
    
    /* ASTCT Grade */
    if not missing(ASTCT_CRS_GRADE) then do;
        QNAM = "CRSASTCT";
        QLABEL = "CRS ASTCT Consensus Grade";
        QVAL = strip(ASTCT_CRS_GRADE);
        QORIG = "ASSIGNED";
        QEVAL = "INVESTIGATOR";
        output;
    end;
    
    /* Fever */
    if not missing(CRS_FEVER_PRESENT) then do;
        QNAM = "CRSFEVER";
        QLABEL = "Fever Present";
        QVAL = upcase(strip(CRS_FEVER_PRESENT));
        QORIG = "REPORTED";
        QEVAL = "";
        output;
    end;
    
    /* Peak Temperature */
    if not missing(CRS_PEAK_TEMP_C) then do;
        QNAM = "CRSMAXTP";
        QLABEL = "Maximum Temperature (C)";
        QVAL = strip(put(CRS_PEAK_TEMP_C, 5.1));
        QORIG = "REPORTED";
        QEVAL = "";
        output;
    end;
    
    /* Tocilizumab */
    if not missing(TOCILIZUMAB_GIVEN) then do;
        QNAM = "CRSTOCI";
        QLABEL = "Tocilizumab Administered";
        QVAL = upcase(strip(TOCILIZUMAB_GIVEN));
        QORIG = "REPORTED";
        QEVAL = "";
        output;
    end;
    
    /* Steroids */
    if not missing(STEROIDS_GIVEN_FOR_CRS) then do;
        QNAM = "CRSSTER";
        QLABEL = "Steroids Administered";
        QVAL = upcase(strip(STEROIDS_GIVEN_FOR_CRS));
        QORIG = "REPORTED";
        QEVAL = "";
        output;
    end;
    
    keep STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG QEVAL;
run;

/* ICANS-Specific SUPPAE */
data suppae_icans;
    set ae_base;
    where AESCAT = 'ICANS';
    
    length STUDYID $20 RDOMAIN $2 USUBJID $40;
    length IDVAR $8 IDVARVAL $200;
    length QNAM $8 QLABEL $40 QVAL $200 QORIG $8 QEVAL $40;
    
    STUDYID = "&STUDYID";
    RDOMAIN = "AE";
    IDVAR = "AESEQ";
    IDVARVAL = strip(put(AESEQ, best.));
    
    /* ASTCT ICANS Grade */
    if not missing(ASTCT_ICANS_GRADE) then do;
        QNAM = "ICANSAST";
        QLABEL = "ICANS ASTCT Consensus Grade";
        QVAL = strip(ASTCT_ICANS_GRADE);
        QORIG = "ASSIGNED";
        QEVAL = "INVESTIGATOR";
        output;
    end;
    
    /* ICE Score (REQUIRED) */
    if not missing(ICE_SCORE) then do;
        QNAM = "ICESCORE";
        QLABEL = "ICE Score at Peak ICANS";
        QVAL = strip(put(ICE_SCORE, 3.));
        QORIG = "ASSIGNED";
        QEVAL = "INVESTIGATOR";
        output;
    end;
    
    /* Level of Consciousness */
    if not missing(ICANS_CONSCIOUSNESS_LEVEL) then do;
        QNAM = "ICANSLOC";
        QLABEL = "Level of Consciousness";
        QVAL = upcase(strip(ICANS_CONSCIOUSNESS_LEVEL));
        QORIG = "ASSIGNED";
        QEVAL = "INVESTIGATOR";
        output;
    end;
    
    /* Seizures */
    if not missing(ICANS_SEIZURE_PRESENT) then do;
        QNAM = "ICANSSEIZ";
        QLABEL = "Seizures Present";
        QVAL = upcase(strip(ICANS_SEIZURE_PRESENT));
        QORIG = "REPORTED";
        QEVAL = "";
        output;
    end;
    
    /* Dexamethasone */
    if not missing(DEXAMETHASONE_FOR_ICANS) then do;
        QNAM = "ICANSDEX";
        QLABEL = "Dexamethasone Given";
        QVAL = upcase(strip(DEXAMETHASONE_FOR_ICANS));
        QORIG = "REPORTED";
        QEVAL = "";
        output;
    end;
    
    keep STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG QEVAL;
run;

/* Infection-Specific SUPPAE */
data suppae_infections;
    set ae_base;
    where AECAT = 'INFECTION';
    
    length STUDYID $20 RDOMAIN $2 USUBJID $40;
    length IDVAR $8 IDVARVAL $200;
    length QNAM $8 QLABEL $40 QVAL $200 QORIG $8 QEVAL $40;
    
    STUDYID = "&STUDYID";
    RDOMAIN = "AE";
    IDVAR = "AESEQ";
    IDVARVAL = strip(put(AESEQ, best.));
    
    /* Infection Type */
    if not missing(INFECTION_TYPE) then do;
        QNAM = "INFTYPE";
        QLABEL = "Infection Type";
        QVAL = upcase(strip(INFECTION_TYPE));
        QORIG = "ASSIGNED";
        QEVAL = "INVESTIGATOR";
        output;
    end;
    
    /* Pathogen */
    if not missing(PATHOGEN_NAME) then do;
        QNAM = "PATHOGEN";
        QLABEL = "Pathogen Identified";
        QVAL = upcase(strip(PATHOGEN_NAME));
        QORIG = "REPORTED";
        QEVAL = "";
        output;
    end;
    
    /* Site */
    if not missing(INFECTION_SITE) then do;
        QNAM = "INFSITE";
        QLABEL = "Site of Infection";
        QVAL = upcase(strip(INFECTION_SITE));
        QORIG = "ASSIGNED";
        QEVAL = "INVESTIGATOR";
        output;
    end;
    
    keep STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG QEVAL;
run;

/* Cytopenia-Specific SUPPAE */
data suppae_cytopenias;
    set ae_base;
    where AECAT = 'HEMATOLOGIC';
    
    length STUDYID $20 RDOMAIN $2 USUBJID $40;
    length IDVAR $8 IDVARVAL $200;
    length QNAM $8 QLABEL $40 QVAL $200 QORIG $8 QEVAL $40;
    
    STUDYID = "&STUDYID";
    RDOMAIN = "AE";
    IDVAR = "AESEQ";
    IDVARVAL = strip(put(AESEQ, best.));
    
    /* Duration Category */
    if not missing(CYTOPENIA_DURATION_DAYS) then do;
        QNAM = "CYTOPDUR";
        QLABEL = "Cytopenia Duration Category";
        if CYTOPENIA_DURATION_DAYS <= 30 then QVAL = "ACUTE (<=30 DAYS)";
        else if CYTOPENIA_DURATION_DAYS <= 90 then QVAL = "PROLONGED (31-90 DAYS)";
        else QVAL = "CHRONIC (>90 DAYS)";
        QORIG = "DERIVED";
        QEVAL = "";
        output;
    end;
    
    /* Nadir Values */
    if not missing(NADIR_ANC_VALUE) then do;
        QNAM = "CYTOPNAD";
        QLABEL = "Nadir ANC Value";
        QVAL = strip(put(NADIR_ANC_VALUE, best.));
        QORIG = "REPORTED";
        QEVAL = "";
        output;
    end;
    
    /* G-CSF */
    if not missing(GCSF_ADMINISTERED) then do;
        QNAM = "CYTOPGF";
        QLABEL = "Growth Factor Given";
        QVAL = upcase(strip(GCSF_ADMINISTERED));
        QORIG = "DERIVED";
        QEVAL = "";
        output;
    end;
    
    keep STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG QEVAL;
run;

/* Combine all SUPPAE records */
data suppae;
    set suppae_trtem
        suppae_crs
        suppae_icans
        suppae_infections
        suppae_cytopenias;
run;

proc sql noprint;
    select count(*) into :suppae_count trimmed from suppae;
quit;

%put NOTE: SUPPAE domain created with &suppae_count records;

/******************************************************************************
* STEP 6: CAR-T SPECIFIC QC CHECKS
******************************************************************************/

%put NOTE: Running CAR-T specific quality checks;

/* QC Check: CRS without fever */
title "CAR-T QC Check: CRS Events Without Fever";
proc sql;
    create table qc_crs_no_fever as
    select ae.USUBJID, ae.AESEQ, ae.AETERM
    from ae
    where AESCAT = 'CRS'
      and not exists (
          select 1 from suppae s
          where s.USUBJID = ae.USUBJID
            and s.IDVARVAL = put(ae.AESEQ, best.)
            and s.QNAM = 'CRSFEVER'
            and s.QVAL = 'Y'
      );
    
    select count(*) into :crs_no_fever trimmed from qc_crs_no_fever;
quit;

%if &crs_no_fever > 0 %then %do;
    %put ERROR: &crs_no_fever CRS events missing fever documentation!;
    %let validation_errors = YES;
%end;
title;

/* QC Check: ICANS without ICE Score */
title "CAR-T QC Check: ICANS Events Without ICE Score";
proc sql;
    create table qc_icans_no_ice as
    select ae.USUBJID, ae.AESEQ, ae.AETERM
    from ae
    where AESCAT = 'ICANS'
      and not exists (
          select 1 from suppae s
          where s.USUBJID = ae.USUBJID
            and s.IDVARVAL = put(ae.AESEQ, best.)
            and s.QNAM = 'ICESCORE'
      );
    
    select count(*) into :icans_no_ice trimmed from qc_icans_no_ice;
quit;

%if &icans_no_ice > 0 %then %do;
    %put ERROR: &icans_no_ice ICANS events missing ICE score!;
    %let validation_errors = YES;
%end;
title;

/* QC Check: CAR-T Toxicity Distribution */
title "CAR-T QC Check: Toxicity Distribution";
proc sql;
    create table qc_cart_dist as
    select AECAT, AESCAT, count(*) as n
    from ae
    where AECAT in ('CAR-T TOXICITY', 'INFECTION', 'HEMATOLOGIC', 'CARDIOVASCULAR')
    group by AECAT, AESCAT
    order by AECAT, n desc;
    
    select * from qc_cart_dist;
quit;
title;

/******************************************************************************
* STEP 7: EXPORT FILES
******************************************************************************/

proc sort data=ae;
    by USUBJID AESEQ;
run;

proc sort data=suppae;
    by USUBJID IDVARVAL;
run;

/* Export to CSV */
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

/* Export to XPT */
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

%put NOTE: ============================================================;
%put NOTE: CAR-T ENHANCED AE DOMAIN GENERATION COMPLETED;
%put NOTE: Total AE records: &ae_count;
%put NOTE: Subjects with AEs: &subj_count;
%put NOTE: SUPPAE records: &suppae_count;

%if &validation_errors = YES %then %do;
    %put ERROR: *** VALIDATION ERRORS DETECTED ***;
    %put ERROR: Review log before proceeding;
%end;
%else %do;
    %put NOTE: *** ALL VALIDATION CHECKS PASSED ***;
%end;

%put NOTE: ============================================================;

proc printto;
run;
