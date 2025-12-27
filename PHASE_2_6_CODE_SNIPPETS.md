# NEXICART-2 Phases 2-6: Implementation Code Snippets

## Quick Reference Guide

This document provides ready-to-use SAS code snippets for implementing Phases 2-6 of the NEXICART-2 updates.

---

## Phase 2: Laboratory Domain Enhancement

### File: `sdtm/programs/sas/42_sdtm_lb.sas`

### Location 1: After LBNRIND derivation (~line 95)

**Purpose**: Reassign LBCAT for AL amyloidosis-specific biomarkers

```sas
/*=========================================================================
* AL AMYLOIDOSIS-SPECIFIC BIOMARKER CATEGORIES
*========================================================================*/

/* Reassign LBCAT for AL amyloidosis biomarkers */
if LBTESTCD in ('KAPPA', 'LAMBDA', 'FLCRATIO') then 
    LBCAT = 'SERUM FREE LIGHT CHAINS';
else if LBTESTCD in ('NTPROBNP', 'TROP', 'TROPHS', 'TROPNI') then 
    LBCAT = 'CARDIAC BIOMARKERS';
else if LBTESTCD in ('PROT24H', 'UPROT', 'EGFR', 'CREAT') then 
    LBCAT = 'RENAL FUNCTION';
else if LBTESTCD in ('CARTPK', 'CARTCMAX', 'CARTTMAX', 'CARTAUC') then 
    LBCAT = 'CAR-T PHARMACOKINETICS';
else if LBTESTCD in ('IL6', 'IL10', 'IFNG', 'TNF') then 
    LBCAT = 'CYTOKINE PANEL';
else if LBTESTCD in ('SIF', 'UIF') then 
    LBCAT = 'IMMUNOFIXATION';
else if LBTESTCD in ('CD19POS') then 
    LBCAT = 'B-CELL RECOVERY';
```

---

### Location 2: After main LB dataset creation (~line 105)

**Purpose**: Calculate derived dFLC (PRIMARY EFFICACY ENDPOINT)

```sas
/*=========================================================================
* DERIVED dFLC CALCULATION - PRIMARY EFFICACY ENDPOINT
*========================================================================*/

/* Get light chain type from DM or MH domain */
proc sql;
    create table light_chain_type as
    select distinct 
        a.USUBJID,
        case 
            when upcase(a.LIGHT_CHAIN_TYPE) = 'LAMBDA' then 'LAMBDA'
            when upcase(a.LIGHT_CHAIN_TYPE) = 'KAPPA' then 'KAPPA'
            else ''
        end as LC_TYPE
    from sdtm.dm a
    /* Or sdtm.mh if light chain type stored in medical history */
    where not missing(a.LIGHT_CHAIN_TYPE);
quit;

/* Calculate dFLC (involved FLC - uninvolved FLC) */
proc sql;
    create table dflc_calc as
    select 
        a.USUBJID,
        a.LBDTC,
        a.VISIT,
        a.VISITNUM,
        c.LC_TYPE,
        max(case when a.LBTESTCD='KAPPA' then a.LBSTRESN else . end) as KAPPA_VALUE,
        max(case when a.LBTESTCD='LAMBDA' then a.LBSTRESN else . end) as LAMBDA_VALUE,
        /* Calculate dFLC based on light chain type */
        case 
            when c.LC_TYPE = 'LAMBDA' then 
                calculated LAMBDA_VALUE - calculated KAPPA_VALUE
            when c.LC_TYPE = 'KAPPA' then 
                calculated KAPPA_VALUE - calculated LAMBDA_VALUE
            else .
        end as DFLC_VALUE
    from lb a
    left join light_chain_type c on a.USUBJID = c.USUBJID
    where a.LBTESTCD in ('KAPPA', 'LAMBDA')
      and a.LBCAT = 'SERUM FREE LIGHT CHAINS'
    group by a.USUBJID, a.LBDTC, a.VISIT, a.VISITNUM, c.LC_TYPE
    having not missing(calculated DFLC_VALUE);
quit;

/* Create dFLC records in SDTM LB format */
data lb_dflc;
    set dflc_calc;
    
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "LB";
    
    /* Test identification */
    length LBTESTCD $8 LBTEST $40;
    LBTESTCD = "DFLC";
    LBTEST = "DIFFERENCE IN FREE LIGHT CHAINS";
    
    /* Category */
    length LBCAT $40;
    LBCAT = "SERUM FREE LIGHT CHAINS";
    
    /* Results */
    length LBSTRESC $200 LBSTRESU $8;
    LBSTRESN = DFLC_VALUE;
    LBSTRESC = strip(put(DFLC_VALUE, best.));
    LBSTRESU = "mg/dL";
    
    /* Original results (same as standardized for derived parameter) */
    length LBORRES $200 LBORRESU $8;
    LBORRES = LBSTRESC;
    LBORRESU = LBSTRESU;
    
    /* Reference range for Complete Response: dFLC <4 mg/dL */
    LBSTNRHI = 4.0;
    LBSTNRLO = .;  /* No lower limit */
    
    /* Normal range indicator */
    length LBNRIND $8;
    if not missing(LBSTRESN) then do;
        if LBSTRESN <= 4 then LBNRIND = "NORMAL"; /* CR threshold */
        else LBNRIND = "HIGH";
    end;
    
    /* Timing and visit (from parent calculation) */
    length LBDTC $20 VISIT $40;
    /* LBDTC, VISIT, VISITNUM already in dataset from parent */
    
    /* Specimen type */
    length LBSPEC $40;
    LBSPEC = "SERUM";
    
    /* Method - derived calculation */
    length LBMETHOD $200;
    LBMETHOD = "DERIVED FROM KAPPA AND LAMBDA FLC BASED ON LIGHT CHAIN TYPE";
    
    keep STUDYID DOMAIN USUBJID LBTESTCD LBTEST LBCAT
         LBORRES LBORRESU LBSTRESC LBSTRESN LBSTRESU
         LBSTNRLO LBSTNRHI LBNRIND LBSPEC LBMETHOD
         LBDTC VISIT VISITNUM;
run;

/* Append dFLC to main LB dataset */
proc append base=lb data=lb_dflc force;
run;

%put NOTE: dFLC derived calculation completed and appended to LB;

/* Re-assign sequence numbers after append */
data lb;
    set lb;
    by USUBJID;
    
    retain LBSEQ_NEW;
    if first.USUBJID then LBSEQ_NEW = 0;
    LBSEQ_NEW + 1;
    LBSEQ = LBSEQ_NEW;
    
    drop LBSEQ_NEW;
run;
```

---

### Location 3: After existing QC checks (~line 95-99)

**Purpose**: Enhanced QC for AL amyloidosis biomarkers

```sas
/*=========================================================================
* ENHANCED QC FOR AL AMYLOIDOSIS BIOMARKERS
*========================================================================*/

title "LB Domain - Enhanced QC for AL Amyloidosis Biomarkers";

/* QC Check: Biomarker category distribution */
proc freq data=lb;
    tables LBCAT / nocol nopercent;
    title2 "Distribution of Laboratory Categories";
run;

proc freq data=lb;
    tables LBCAT*LBNRIND / nocol nopercent;
    title2 "Normal Range by Category";
run;

/* QC Check: AL Biomarker Completeness */
title2 "AL Amyloidosis Biomarker Completeness";
proc sql;
    create table qc_al_biomarkers as
    select 
        LBCAT,
        LBTESTCD,
        count(distinct USUBJID) as N_SUBJECTS,
        count(*) as N_MEASUREMENTS,
        sum(case when missing(LBSTRESN) then 1 else 0 end) as N_MISSING,
        calculated N_MISSING / calculated N_MEASUREMENTS * 100 
            as PCT_MISSING format=5.1
    from lb
    where LBCAT in ('SERUM FREE LIGHT CHAINS', 'CARDIAC BIOMARKERS',
                    'RENAL FUNCTION', 'CAR-T PHARMACOKINETICS',
                    'CYTOKINE PANEL', 'IMMUNOFIXATION', 'B-CELL RECOVERY')
    group by LBCAT, LBTESTCD
    order by LBCAT, LBTESTCD;
    
    select * from qc_al_biomarkers;
quit;

/* QC Check: dFLC Calculation Validation - Manual Review Sample */
title2 "dFLC Calculation Validation (First 10 Subjects)";
proc sql outobs=10;
    select 
        a.USUBJID,
        a.LBDTC,
        b.LC_TYPE as LIGHT_CHAIN_TYPE,
        max(case when a.LBTESTCD='KAPPA' then a.LBSTRESN else . end) 
            as KAPPA format=8.2,
        max(case when a.LBTESTCD='LAMBDA' then a.LBSTRESN else . end) 
            as LAMBDA format=8.2,
        max(case when a.LBTESTCD='DFLC' then a.LBSTRESN else . end) 
            as DFLC_DERIVED format=8.2,
        /* Verify calculation */
        case 
            when b.LC_TYPE='LAMBDA' then calculated LAMBDA - calculated KAPPA
            when b.LC_TYPE='KAPPA' then calculated KAPPA - calculated LAMBDA
        end as DFLC_EXPECTED format=8.2
    from lb a
    left join (select distinct USUBJID, LC_TYPE from dflc_calc) b
        on a.USUBJID = b.USUBJID
    where a.LBTESTCD in ('KAPPA', 'LAMBDA', 'DFLC')
      and a.LBCAT = 'SERUM FREE LIGHT CHAINS'
    group by a.USUBJID, a.LBDTC, b.LC_TYPE
    having not missing(calculated DFLC_DERIVED)
    order by a.USUBJID, a.LBDTC;
quit;

/* QC Check: Baseline dFLC Distribution */
title2 "Baseline dFLC Distribution";
proc means data=lb n mean median min max;
    where LBTESTCD = 'DFLC' and LBBLFL = 'Y';
    var LBSTRESN;
run;

/* QC Check: NT-proBNP Baseline and Follow-up */
title2 "NT-proBNP Cardiac Biomarker Distribution";
proc means data=lb n mean median min max;
    where LBTESTCD = 'NTPROBNP';
    var LBSTRESN;
    class LBBLFL;
run;

title;
```

---

## Phase 3: Demographics Enhancement

### File: `sdtm/programs/sas/20_sdtm_dm.sas`

### Location: After existing demographic variables (~line 50)

```sas
/*=========================================================================
* AL AMYLOIDOSIS BASELINE DISEASE CHARACTERISTICS
*========================================================================*/

/* Prior Treatment History */
NPRTLIN = NUMBER_PRIOR_LINES;  /* Median 4, range 1-12 */

length PRBORT PRDARATU PRASCT PRLMWCLS $1;
if upcase(strip(PRIOR_BORTEZOMIB)) = 'Y' then PRBORT = 'Y';  /* 100% in NEXICART-2 */
if upcase(strip(PRIOR_DARATUMUMAB)) = 'Y' then PRDARATU = 'Y';  /* 100% */
if upcase(strip(PRIOR_ASCT)) = 'Y' then PRASCT = 'Y';  /* 50% */
if upcase(strip(TRIPLE_CLASS_EXPOSED)) = 'Y' then PRLMWCLS = 'Y';

/* Light Chain Type and Cytogenetics */
length LCHTYPEC $6 CYTT1114 CYTG1Q CYTD17P $1;
if upcase(strip(LIGHT_CHAIN_TYPE)) = 'LAMBDA' then LCHTYPEC = 'LAMBDA';
else if upcase(strip(LIGHT_CHAIN_TYPE)) = 'KAPPA' then LCHTYPEC = 'KAPPA';

if upcase(strip(T1114_PRESENT)) = 'Y' then CYTT1114 = 'Y';
if upcase(strip(GAIN1Q_PRESENT)) = 'Y' then CYTG1Q = 'Y';
if upcase(strip(DEL17P_PRESENT)) = 'Y' then CYTD17P = 'Y';

/* Baseline Organ Involvement */
length CRDBASEF RENBASF HEPBASF NEUROBASF $1;
if upcase(strip(CARDIAC_INVOLVEMENT)) = 'Y' then CRDBASEF = 'Y';  /* 60% */
if upcase(strip(RENAL_INVOLVEMENT)) = 'Y' then RENBASF = 'Y';
if upcase(strip(HEPATIC_INVOLVEMENT)) = 'Y' then HEPBASF = 'Y';
if upcase(strip(PERIPHERAL_NEUROPATHY)) = 'Y' then NEUROBASF = 'Y';

/* Mayo Cardiac Stage */
length MAYOSTGB $4;
if not missing(MAYO_STAGE) then 
    MAYOSTGB = upcase(strip(MAYO_STAGE));  /* I, II, IIIA, IIIB */

/* NYHA Heart Failure Class */
length NYHACALB $2;
if not missing(NYHA_CLASS) then 
    NYHACALB = strip(put(NYHA_CLASS, 1.));  /* I, II, III, IV */

/* Number of Organs Involved */
NORGINV = sum((CRDBASEF='Y'), (RENBASF='Y'), 
              (HEPBASF='Y'), (NEUROBASF='Y'));

/* Baseline Disease Burden - Continuous */
DFLCLCBL = BASELINE_DFLC;      /* mg/dL */
NTPROBNPB = BASELINE_NTPROBNP;  /* ng/L */
TROPBL = BASELINE_TROPONIN;     /* ng/mL */
PROTBL = BASELINE_PROTEINURIA;  /* g/24h */
```

### Update KEEP statement:

```sas
keep 
    STUDYID DOMAIN USUBJID SUBJID
    RFSTDTC RFENDTC RFXSTDTC RFXENDTC RFICDTC RFPENDTC
    DTHDTC DTHFL
    SITEID INVID INVNAM
    BRTHDTC AGE AGEU SEX RACE ETHNIC
    ARMCD ARM ACTARMCD ACTARM
    COUNTRY DMDTC DMDY
    /* AL Amyloidosis variables */
    NPRTLIN PRBORT PRDARATU PRASCT PRLMWCLS
    LCHTYPEC CYTT1114 CYTG1Q CYTD17P
    CRDBASEF RENBASF HEPBASF NEUROBASF
    MAYOSTGB NYHACALB NORGINV
    DFLCLCBL NTPROBNPB TROPBL PROTBL;
```

---

## Phase 4: Adverse Events Enhancement

### File: `sdtm/programs/sas/30_sdtm_ae.sas`

### Add after AESEV derivation:

```sas
/*=========================================================================
* CAR-T SPECIFIC TOXICITY GRADING
*========================================================================*/

/* CRS Grading (Lee 2019 criteria) */
length CRSGRADE $8;
if index(upcase(AETERM), 'CYTOKINE RELEASE') or 
   index(upcase(AETERM), 'CRS') then do;
   
    if AESEV = 'MILD' then CRSGRADE = 'GRADE 1';
    else if AESEV = 'MODERATE' then CRSGRADE = 'GRADE 2';
    else if AESEV = 'SEVERE' then CRSGRADE = 'GRADE 3';
    else if AETOXGR in ('4', '5') then CRSGRADE = 'GRADE ' || strip(AETOXGR);
end;

/* ICANS Grading (ASTCT consensus) */
length ICANSGRAD $8;
if index(upcase(AETERM), 'NEUROTOXICITY') or
   index(upcase(AETERM), 'ICANS') or
   index(upcase(AETERM), 'IMMUNE EFFECTOR CELL') then do;
   
    ICANSGRAD = 'GRADE ' || strip(AETOXGR);
end;

/* Infection Categorization */
length INFCTCAT $40;
if index(upcase(AETERM), 'INFECTION') or
   index(upcase(AETERM), 'SEPSIS') then do;
   
    if index(upcase(AETERM), 'VIRAL') then INFCTCAT = 'VIRAL INFECTION';
    else if index(upcase(AETERM), 'BACTERIAL') then INFCTCAT = 'BACTERIAL INFECTION';
    else if index(upcase(AETERM), 'FUNGAL') then INFCTCAT = 'FUNGAL INFECTION';
    else INFCTCAT = 'INFECTION - OTHER';
end;
```

---

## Phase 5: Exposure Enhancement

### File: `sdtm/programs/sas/38_sdtm_ex.sas`

### Add CAR-T specific variables:

```sas
/*=========================================================================
* CAR-T DOSING DETAILS
*========================================================================*/

/* For CAR-T infusion records */
if EXTRT = 'ANTI-BCMA CAR-T CELLS' or 
   index(upcase(EXTRT), 'CAR-T') then do;
   
    /* Actual dose in CAR+ T cells */
    length EXDOSE 8 EXDOSU $40;
    EXDOSE = CART_DOSE_ACTUAL;
    EXDOSU = 'CAR+ T CELLS';
    
    /* Manufacturing outcome */
    length EXMFGOUT $20;
    if upcase(MFG_OUTCOME) = 'SUCCESS' then EXMFGOUT = 'SUCCESS';
    else if upcase(MFG_OUTCOME) = 'FAILURE' then EXMFGOUT = 'FAILURE';
    
    /* Manufacturing duration (days) */
    EXMFGDUR = MFG_DURATION_DAYS;
end;
```

---

## Phase 6: Response Assessment

### File: `sdtm/programs/sas/54_sdtm_rs.sas`

### AL Amyloidosis Response Criteria:

```sas
/*=========================================================================
* AL AMYLOIDOSIS HEMATOLOGIC RESPONSE CRITERIA
*========================================================================*/

data rs_hematologic;
    merge 
        lb_dflc(where=(LBTESTCD='DFLC') keep=USUBJID VISIT LBSTRESN rename=(LBSTRESN=DFLC))
        lb_sif(where=(LBTESTCD='SIF') keep=USUBJID VISIT LBSTRESC rename=(LBSTRESC=SIF));
    by USUBJID VISIT;
    
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "RS";
    
    /* Response test */
    length RSTESTCD $8 RSTEST $200;
    RSTESTCD = "HEMRESP";
    RSTEST = "HEMATOLOGIC RESPONSE";
    
    /* Assessment category */
    length RSCAT $40;
    RSCAT = "AL AMYLOIDOSIS RESPONSE";
    
    /* Determine response */
    length RSORRES $200 RSSTRESC $20;
    
    if DFLC <= 4 and upcase(SIF) = 'NEGATIVE' then do;
        RSORRES = "COMPLETE RESPONSE (CR)";
        RSSTRESC = "CR";
    end;
    else if DFLC <= 4 then do;
        RSORRES = "VERY GOOD PARTIAL RESPONSE (VGPR)";
        RSSTRESC = "VGPR";
    end;
    else do;
        /* Calculate percent reduction from baseline */
        /* Would need baseline dFLC here */
        RSORRES = "TO BE DETERMINED";
        RSSTRESC = "TBD";
    end;
run;
```

---

## Integration Notes

1. **Test each phase independently** before moving to the next
2. **Run QC checks** after each update
3. **Backup original files** before making changes
4. **Document assumptions** about data structure
5. **Validate calculations** manually for sample subjects

---

## Questions?

Refer to `NEXICART2_IMPLEMENTATION.md` for full context and clinical rationale.

Date: December 27, 2025
