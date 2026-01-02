/******************************************************************************
* Program: 82_adam_adintev.sas
* Purpose: Intermediate Event Dataset for Time-to-Event Analysis
* Author:  Christian Baghai
* Date:    2026-01-03
* Version: 1.0 - NEXICART-2 with 2025 censoring transparency
* 
* Input:   adam/data/adrs_recist.csv (PD dates)
*          sdtm/data/csv/dm.csv (death dates)
*          sdtm/data/csv/ds.csv (discontinuation)
*          sdtm/data/csv/cm.csv (subsequent therapy)
* Output:  adam/data/adintev.csv, adam/data/xpt/adintev.xpt
* 
* Priority: CRITICAL - Defines PFS events and censoring rules
* 
* NEW 2024-2025 Enhancements per Vitale JNCI 2025:
*   - CNSR_TIME_CAT: Categorize censoring timing (early/mid/late)
*   - CNSDTDSC: Detailed censoring description
*   - CNSRREASN: Specific censoring reason code
*   - Document censoring patterns for transparency
* 
* Censoring Rules (per protocol and Lesan 2024):
*   1. Last adequate tumor assessment without PD
*   2. Last assessment before subsequent anti-cancer therapy
*   3. Last assessment before study discontinuation (non-PD reasons)
*   4. No baseline assessment
*   5. No post-baseline assessment
* 
* Reference: Vitale et al. JNCI 2025 (censoring transparency)
*            Lesan et al. Eur J Cancer 2024 (censoring impact on PFS)
******************************************************************************/

%let STUDYID = NEXICART2-SOLID-TUMOR;

libname sdtm "../../sdtm/data/csv";
libname adam "../../adam/data";

/* ========================================
   STEP 1: Import Required Datasets
   ======================================== */

title "NEXICART-2 ADINTEV: Import Source Datasets";

/* Import ADRS for PD dates */
proc import datafile="../../adam/data/adrs_recist.csv"
    out=adrs dbms=csv replace;
    guessingrows=max;
run;

/* Import DM for death dates and randomization */
data dm;
    set sdtm.dm;
    
    /* Death date */
    if not missing(DTHDTC) then
        DTHDT = input(DTHDTC, yymmdd10.);
    else DTHDT = .;
    format DTHDT date9.;
    
    /* Randomization/first dose date */
    if not missing(RFSTDTC) then
        TRTSDT = input(RFSTDTC, yymmdd10.);
    else TRTSDT = .;
    format TRTSDT date9.;
    
    keep USUBJID STUDYID ARM ACTARM DTHFL DTHDT TRTSDT;
run;

/* Import DS for discontinuation dates */
data ds;
    set sdtm.ds;
    where DSDECOD ne 'COMPLETED' and DSDECOD ne '';
    
    if not missing(DSSTDTC) then
        DSSTDT = input(DSSTDTC, yymmdd10.);
    else DSSTDT = .;
    format DSSTDT date9.;
    
    keep USUBJID DSDECOD DSSTDT;
run;

/* Import CM for subsequent therapy */
data cm_subsequent;
    set sdtm.cm;
    where upcase(CMCAT) = 'ANTICANCER THERAPY';
    
    if not missing(CMSTDTC) then
        CMSTDT = input(CMSTDTC, yymmdd10.);
    else CMSTDT = .;
    format CMSTDT date9.;
    
    keep USUBJID CMTRT CMSTDT;
run;

/* Get earliest subsequent therapy date per patient */
proc sql;
    create table subsequent_therapy as
    select USUBJID,
           min(CMSTDT) as SUBSEQ_DT format=date9. label="Earliest Subsequent Therapy Date"
    from cm_subsequent
    where not missing(CMSTDT)
    group by USUBJID;
quit;

/* ========================================
   STEP 2: Identify Progressive Disease Events
   ======================================== */

title "NEXICART-2 ADINTEV: Identify PD Events from ADRS";

proc sql;
    create table pd_events as
    select USUBJID,
           min(ADT) as PD_DT format=date9. label="Progressive Disease Date",
           min(ADY) as PD_DY label="Progressive Disease Study Day"
    from adrs
    where PARAMCD = 'OVRLRESP' and AVALC = 'PD' and not missing(ADT)
    group by USUBJID;
quit;

/* ========================================
   STEP 3: Identify Last Adequate Tumor Assessment (Censoring)
   Per Vitale 2025 - Most Common Censoring Reason
   ======================================== */

title "NEXICART-2 ADINTEV: Last Adequate Assessment (Censoring per Vitale 2025)";

proc sql;
    create table last_assessment as
    select USUBJID,
           max(ADT) as LAST_ASSESS_DT format=date9.,
           max(ADY) as LAST_ASSESS_DY
    from adrs
    where PARAMCD = 'OVRLRESP' and AVALC ne 'NE' and not missing(ADT)  /* Evaluable assessments only */
    group by USUBJID;
quit;

/* ========================================
   STEP 4: Merge All Event Sources
   ======================================== */

title "NEXICART-2 ADINTEV: Merge All PFS Event and Censoring Sources";

proc sql;
    create table events_merged as
    select a.USUBJID, a.TRTSDT, a.DTHFL, a.DTHDT, a.ARM,
           b.PD_DT, b.PD_DY,
           c.LAST_ASSESS_DT, c.LAST_ASSESS_DY,
           d.SUBSEQ_DT,
           e.DSSTDT, e.DSDECOD
    from dm as a
    left join pd_events as b on a.USUBJID = b.USUBJID
    left join last_assessment as c on a.USUBJID = c.USUBJID
    left join subsequent_therapy as d on a.USUBJID = d.USUBJID
    left join ds as e on a.USUBJID = e.USUBJID;
quit;

/* ========================================
   STEP 5: Apply Censoring Hierarchy (Per Protocol)
   NEW 2024-2025: Enhanced Transparency per Vitale JNCI 2025
   ======================================== */

title "NEXICART-2 ADINTEV: CRITICAL - Apply PFS Censoring Rules";
title2 "Enhanced per Vitale 2025 and Lesan 2024";

data adintev_pfs;
    set events_merged;
    
    length PARAMCD $8 PARAM $200;
    PARAMCD = 'PFS';
    PARAM = 'Progression-Free Survival Event';
    
    /* Initialize censoring variables */
    length CNSR 8 CNSRDESC $200 CNSDTDSC $200 CNSRREASN $50 EVNTDESC $200 SRCDOM $8;
    CNSR = .;
    ADT = .;
    ADY = .;
    format ADT date9.;
    
    /* ===== EVENT HIERARCHY (CHECK IN ORDER) ===== */
    
    /* Event 1: Progressive Disease */
    if not missing(PD_DT) and (missing(DTHDT) or PD_DT <= DTHDT) then do;
        CNSR = 0;  /* Event occurred */
        ADT = PD_DT;
        ADY = PD_DY;
        CNSRDESC = "Progressive Disease";
        EVNTDESC = "Progressive Disease per RECIST 1.1";
        SRCDOM = "ADRS";
        goto event_assigned;
    end;
    
    /* Event 2: Death (without prior PD) */
    if DTHFL = 'Y' and not missing(DTHDT) then do;
        CNSR = 0;
        ADT = DTHDT;
        if not missing(TRTSDT) then ADY = DTHDT - TRTSDT + 1;
        CNSRDESC = "Death";
        EVNTDESC = "Death without prior PD";
        SRCDOM = "DM";
        goto event_assigned;
    end;
    
    /* ===== CENSORING RULES (If no event) ===== */
    
    /* Censoring Rule 1: Subsequent therapy started before PD */
    if not missing(SUBSEQ_DT) and not missing(LAST_ASSESS_DT) and 
       SUBSEQ_DT > LAST_ASSESS_DT then do;
        CNSR = 1;
        ADT = LAST_ASSESS_DT;
        ADY = LAST_ASSESS_DY;
        CNSRDESC = "Last assessment before subsequent anti-cancer therapy";
        CNSDTDSC = "Censored at last adequate assessment before subsequent therapy per Lesan 2024";
        CNSRREASN = "SUBSEQUENT_TX";
        SRCDOM = "ADRS";
        goto event_assigned;
    end;
    
    /* Censoring Rule 2: Study discontinuation for non-PD reasons */
    if not missing(DSSTDT) and not missing(LAST_ASSESS_DT) and 
       DSSTDT > LAST_ASSESS_DT and 
       upcase(DSDECOD) not in ('PROGRESSIVE DISEASE','DEATH') then do;
        CNSR = 1;
        ADT = LAST_ASSESS_DT;
        ADY = LAST_ASSESS_DY;
        CNSRDESC = "Last assessment before study discontinuation";
        CNSDTDSC = catx(": ", "Discontinued for", DSDECOD);
        CNSRREASN = "DISCONTINUATION";
        SRCDOM = "ADRS";
        goto event_assigned;
    end;
    
    /* Censoring Rule 3: Last adequate assessment (default) */
    if not missing(LAST_ASSESS_DT) then do;
        CNSR = 1;
        ADT = LAST_ASSESS_DT;
        ADY = LAST_ASSESS_DY;
        CNSRDESC = "Last adequate tumor assessment without PD";
        CNSDTDSC = "Censored at last evaluable assessment per Vitale 2025 - most common censoring reason";
        CNSRREASN = "LAST_ASSESS";
        SRCDOM = "ADRS";
        goto event_assigned;
    end;
    
    /* Censoring Rule 4: No post-baseline assessment */
    if missing(LAST_ASSESS_DT) and not missing(TRTSDT) then do;
        CNSR = 1;
        ADT = TRTSDT;
        ADY = 1;
        CNSRDESC = "No post-baseline tumor assessment";
        CNSDTDSC = "Censored at first dose date - no evaluable post-baseline assessment";
        CNSRREASN = "NO_POST_BASE";
        SRCDOM = "DM";
        goto event_assigned;
    end;
    
    event_assigned:
    
    /* NEW 2024-2025: Censoring Time Category per Vitale 2025 */
    length CNSR_TIME_CAT $20;
    if CNSR = 1 and not missing(ADY) then do;
        if ADY <= 90 then CNSR_TIME_CAT = "Early (<3 months)";
        else if ADY <= 180 then CNSR_TIME_CAT = "Mid (3-6 months)";
        else CNSR_TIME_CAT = "Late (>6 months)";
    end;
    else CNSR_TIME_CAT = "";
    
    label PARAMCD = "Parameter Code"
          PARAM = "Parameter"
          CNSR = "Censoring Indicator (0=Event, 1=Censored)"
          ADT = "Analysis Date (Event or Censoring)"
          ADY = "Analysis Relative Day"
          CNSRDESC = "Censoring Description"
          CNSDTDSC = "Detailed Censoring Description (per Vitale 2025)"
          CNSRREASN = "Censoring Reason Code"
          CNSR_TIME_CAT = "Censoring Timing Category (per Vitale 2025)"
          EVNTDESC = "Event Description"
          SRCDOM = "Source Domain";
run;

/* ========================================
   STEP 6: Add Analysis Flags and Sequence
   ======================================== */

data adintev;
    set adintev_pfs;
    
    length ANL01FL $1;
    if not missing(CNSR) then ANL01FL = 'Y';
    else ANL01FL = '';
    
    ASEQ = _N_;
    
    label ANL01FL = "Analysis Flag 01"
          ASEQ = "Analysis Sequence Number";
run;

/* ========================================
   STEP 7: QC VALIDATION & CENSORING SUMMARY
   NEW 2024-2025: Transparency per Vitale JNCI 2025
   ======================================== */

title "NEXICART-2 ADINTEV QC: PFS Event vs Censoring Distribution";
title2 "Per Vitale 2025: Document censoring patterns for transparency";

proc freq data=adintev;
    tables CNSR / nocum;
    tables CNSRREASN*CNSR_TIME_CAT / missing;
run;

title "NEXICART-2 ADINTEV QC: Censoring by Treatment Arm";
title2 "Per Vitale 2025: Monitor for differential censoring (concern in open-label trials)";

proc freq data=adintev;
    tables ARM*CNSR / nopercent norow;
    tables ARM*CNSRREASN / nopercent nocol;
run;

title "NEXICART-2 ADINTEV QC: Early Censoring Flag (<3 months)";
title2 "Per Vitale 2025: High censoring at T1 requires investigation";

proc freq data=adintev(where=(CNSR=1));
    tables CNSR_TIME_CAT / nocum;
run;

title "NEXICART-2 ADINTEV QC: Patient-Level Event/Censoring Detail";

proc print data=adintev(obs=20);
    var USUBJID ARM CNSR ADY CNSRDESC CNSDTDSC CNSR_TIME_CAT;
run;

/* ========================================
   STEP 8: EXPORT DATASETS
   ======================================== */

title "NEXICART-2 ADINTEV: Export Final Dataset";

proc export data=adintev 
            outfile="../../adam/data/adintev.csv" 
            dbms=csv replace; 
run;

libname xptout xport "../../adam/data/xpt/adintev.xpt";
data xptout.adintev;
    set adintev;
run;

proc contents data=adintev varnum;
    title "NEXICART-2 ADINTEV: Dataset Contents";
run;

%put NOTE: ============================================;
%put NOTE: ADINTEV dataset created successfully;
%put NOTE: NEW 2024-2025 enhancements per Vitale JNCI 2025:;
%put NOTE:   - CNSR_TIME_CAT: Censoring timing category;
%put NOTE:   - CNSDTDSC: Detailed censoring description;
%put NOTE:   - CNSRREASN: Censoring reason code;
%put NOTE: Censoring rules per Lesan 2024 and protocol;
%put NOTE: Ready for ADTTE (PFS, OS, DOR) derivation;
%put NOTE: Output: adam/data/adintev.csv;
%put NOTE: ============================================;
