/******************************************************************************
* Program: 70_adam_adrs_imwg.sas
* Purpose: IMWG 7-tier hematologic response for AL amyloidosis
* Author:  Christian Baghai
* Date:    2025-12-28
* Version: 1.0 - NEXICART-2 implementation
* 
* Input:   adam/data/adlb.csv, sdtm/data/csv/lb.csv, sdtm/data/csv/dm.csv
* Output:  adam/data/adrs.csv, adam/data/xpt/adrs.xpt
* 
* Priority: CRITICAL - Primary efficacy endpoint analysis
* 
* Response Hierarchy (IMWG 2012 Consensus Criteria):
*   1. sCR (stringent CR): Negative IF + Normal FLC ratio (0.26-1.65) + BM <5%
*   2. CR (complete): Negative IF + dFLC <40 mg/L
*   3. VGPR (very good PR): dFLC <40 mg/L OR ≥90% reduction from baseline
*   4. PR (partial): ≥50% reduction AND absolute decrease ≥50 mg/L
*   5. MR (minimal): 25-49% reduction (NOT included in ORR)
*   6. SD (stable): Neither response nor progression
*   7. PD (progressive): ≥25% increase from NADIR + absolute increase ≥50 mg/L
* 
* Reference: Palladini G, et al. Blood. 2012;119(23):5397-5404.
*            Kumar S, et al. J Clin Oncol. 2012;30(9):989-995.
******************************************************************************/

%let STUDYID = NEXICART2-AL-AMYLOIDOSIS;

libname sdtm "../../sdtm/data/csv";
libname adam "../../adam/data";

/* ========================================
   STEP 1: Import Required Datasets
   ======================================== */

title "NEXICART-2 ADRS: Import Source Datasets";

/* Import ADLB with dFLC values and nadir */
proc import datafile="../../adam/data/adlb.csv"
    out=adlb dbms=csv replace;
    guessingrows=max;
run;

/* Import SDTM LB for immunofixation results */
data lb_raw;
    set sdtm.lb;
    keep USUBJID LBDTC LBDY LBTESTCD LBSTRESC VISIT VISITNUM;
run;

/* Import DM for study information */
data dm;
    set sdtm.dm;
    keep USUBJID STUDYID RFSTDTC ARM ACTARM;
run;

/* ========================================
   STEP 2: Extract Component Variables
   ======================================== */

title "NEXICART-2 ADRS: Extract Response Components";

/* Component 1: dFLC with baseline, change, and nadir */
proc sql;
    create table dflc_data as
    select USUBJID, ADY, AVISIT, AVISITN,
           AVAL as DFLC_VALUE label="dFLC Value (mg/L)",
           BASE as DFLC_BASELINE label="Baseline dFLC (mg/L)",
           NADIR as DFLC_NADIR label="Nadir dFLC (mg/L)",
           CHG as ABS_CHANGE_BL label="Absolute Change from Baseline",
           PCHG as PCT_CHANGE_BL label="Percent Change from Baseline (%)",
           CHGNADIR as ABS_CHANGE_NADIR label="Absolute Change from Nadir",
           PCHGNADIR as PCT_CHANGE_NADIR label="Percent Change from Nadir (%)",
           NADIRF
    from adlb
    where PARAMCD = 'DFLC' and ANL01FL = 'Y'
    order by USUBJID, ADY;
quit;

/* Component 2: FLC ratio for sCR determination */
proc sql;
    create table flc_ratio_data as
    select USUBJID, ADY,
           AVAL as FLC_RATIO label="Kappa/Lambda FLC Ratio",
           case when AVAL >= 0.26 and AVAL <= 1.65 then 'Y'
                else 'N' end as FLC_RATIO_NORMAL label="FLC Ratio Normal Flag"
    from adlb
    where PARAMCD = 'FLCRATIO' and ANL01FL = 'Y'
    order by USUBJID, ADY;
quit;

/* Component 3: Immunofixation (must be NEGATIVE for CR/sCR) */
proc sql;
    create table immunofix_data as
    select USUBJID, LBDY as ADY,
           max(case when LBTESTCD='SIF' and upcase(LBSTRESC)='NEGATIVE' then 1 else 0 end) as SIF_NEG,
           max(case when LBTESTCD='UIF' and upcase(LBSTRESC)='NEGATIVE' then 1 else 0 end) as UIF_NEG
    from lb_raw
    where LBTESTCD in ('SIF','UIF')
    group by USUBJID, LBDY;
    
    /* Both serum AND urine IF must be negative for CR criteria */
    create table if_negative as
    select *,
           case when SIF_NEG=1 and UIF_NEG=1 then 'Y' 
                else 'N' end as IF_NEGATIVE label="Immunofixation Negative (Serum+Urine)"
    from immunofix_data;
quit;

/* ========================================
   STEP 3: Merge All Components
   ======================================== */

title "NEXICART-2 ADRS: Merge Response Components";

proc sql;
    create table response_components as
    select a.*,
           b.FLC_RATIO,
           b.FLC_RATIO_NORMAL,
           coalesce(c.IF_NEGATIVE, 'N') as IF_NEGATIVE
    from dflc_data as a
    left join flc_ratio_data as b
        on a.USUBJID = b.USUBJID and a.ADY = b.ADY
    left join if_negative as c
        on a.USUBJID = c.USUBJID and a.ADY = c.ADY
    order by USUBJID, ADY;
quit;

/* ========================================
   STEP 4: APPLY IMWG 7-TIER RESPONSE HIERARCHY
   Critical: Must apply in strict order per IMWG consensus
   ======================================== */

title "NEXICART-2 ADRS: CRITICAL - Apply IMWG Response Hierarchy";
title2 "Reference: Palladini et al. Blood 2012";

data adrs_response;
    merge response_components
          dm;
    by USUBJID;
    
    length PARAM $200 PARAMCD $8;
    PARAM = 'IMWG Hematologic Response';
    PARAMCD = 'IMWGRESP';
    
    length AVALC $10 AVAL 8;
    
    /* Calculate percent reduction from baseline (positive = improvement) */
    if not missing(PCT_CHANGE_BL) then 
        PCT_REDUCTION_BL = -PCT_CHANGE_BL;
    else PCT_REDUCTION_BL = .;
    
    /* ===== PRIORITY 1: PROGRESSIVE DISEASE (CHECK FIRST) ===== */
    /* PD: ≥25% increase from NADIR + absolute increase ≥50 mg/L */
    /* NOTE: PD uses NADIR, not baseline */
    
    if not missing(PCT_CHANGE_NADIR) and not missing(ABS_CHANGE_NADIR) then do;
        if PCT_CHANGE_NADIR >= 25 and ABS_CHANGE_NADIR >= 50 then do;
            AVALC = 'PD';
            AVAL = 1;
            goto response_assigned;
        end;
    end;
    
    /* ===== PRIORITY 2: STRINGENT COMPLETE RESPONSE ===== */
    /* sCR: Negative IF + Normal FLC ratio (0.26-1.65) */
    /* Note: BM plasma cell <5% criterion omitted if not collected */
    
    if IF_NEGATIVE = 'Y' and FLC_RATIO_NORMAL = 'Y' then do;
        AVALC = 'sCR';
        AVAL = 7;
        goto response_assigned;
    end;
    
    /* ===== PRIORITY 3: COMPLETE RESPONSE ===== */
    /* CR: Negative IF + dFLC <40 mg/L */
    
    if IF_NEGATIVE = 'Y' and not missing(DFLC_VALUE) and DFLC_VALUE < 40 then do;
        AVALC = 'CR';
        AVAL = 6;
        goto response_assigned;
    end;
    
    /* ===== PRIORITY 4: VERY GOOD PARTIAL RESPONSE ===== */
    /* VGPR: dFLC <40 mg/L OR ≥90% reduction from baseline */
    
    if not missing(DFLC_VALUE) then do;
        if DFLC_VALUE < 40 or 
           (not missing(PCT_REDUCTION_BL) and PCT_REDUCTION_BL >= 90) then do;
            AVALC = 'VGPR';
            AVAL = 5;
            goto response_assigned;
        end;
    end;
    
    /* ===== PRIORITY 5: PARTIAL RESPONSE ===== */
    /* PR: ≥50% reduction AND absolute decrease ≥50 mg/L */
    
    if not missing(PCT_REDUCTION_BL) and not missing(ABS_CHANGE_BL) then do;
        if PCT_REDUCTION_BL >= 50 and ABS_CHANGE_BL <= -50 then do;
            AVALC = 'PR';
            AVAL = 4;
            goto response_assigned;
        end;
    end;
    
    /* ===== PRIORITY 6: MINIMAL RESPONSE (NOT IN ORR) ===== */
    /* MR: 25-49% reduction */
    
    if not missing(PCT_REDUCTION_BL) then do;
        if PCT_REDUCTION_BL >= 25 and PCT_REDUCTION_BL < 50 then do;
            AVALC = 'MR';
            AVAL = 3;
            goto response_assigned;
        end;
    end;
    
    /* ===== PRIORITY 7: STABLE DISEASE (DEFAULT) ===== */
    /* SD: Neither response nor progression criteria met */
    
    AVALC = 'SD';
    AVAL = 2;
    
    response_assigned:
    
    /* Analysis value as numeric */
    AVALU = '';
    
    /* Keep analysis variables */
    AVISIT = AVISIT;
    AVISITN = AVISITN;
    
    label AVALC = "IMWG Response Category"
          AVAL = "IMWG Response (Numeric Rank: 1=PD, 7=sCR)"
          PCT_REDUCTION_BL = "Percent Reduction from Baseline (%)";
run;

proc sort data=adrs_response; by USUBJID ADY; run;

/* ========================================
   STEP 5: DERIVE CONFIRMED RESPONSE
   Criteria: Same response ≥28 days apart
   ======================================== */

title "NEXICART-2 ADRS: Derive Confirmed Response (≥28 days)";

data adrs_confirmed;
    set adrs_response;
    by USUBJID ADY;
    
    retain prev_response prev_ady;
    
    length CONFIRMEDFL $1;
    
    if first.USUBJID then do;
        prev_response = '';
        prev_ady = .;
        CONFIRMEDFL = '';
    end;
    else do;
        /* Check if same response maintained ≥28 days apart */
        if AVALC in ('sCR','CR','VGPR','PR') and 
           AVALC = prev_response and 
           ADY - prev_ady >= 28 then do;
            CONFIRMEDFL = 'Y';
        end;
        else CONFIRMEDFL = '';
    end;
    
    prev_response = AVALC;
    prev_ady = ADY;
    
    label CONFIRMEDFL = "Confirmed Response Flag (≥28 days apart)";
run;

/* ========================================
   STEP 6: DERIVE BEST OVERALL RESPONSE (BOR)
   ======================================== */

title "NEXICART-2 ADRS: Derive Best Overall Response (BOR)";

/* BOR = Highest confirmed response during study */
proc sql;
    create table bor_analysis as
    select USUBJID,
           max(AVAL) as BOR_NUM label="Best Overall Response (Numeric)",
           case(calculated BOR_NUM)
               when 7 then 'sCR'
               when 6 then 'CR'
               when 5 then 'VGPR'
               when 4 then 'PR'
               when 3 then 'MR'
               when 2 then 'SD'
               when 1 then 'PD'
               else 'NE'
           end as BOR label="Best Overall Response",
           min(case when CONFIRMEDFL='Y' then ADY else . end) as BOR_DAY label="Study Day of BOR"
    from adrs_confirmed
    where CONFIRMEDFL = 'Y'
    group by USUBJID;
quit;

/* ========================================
   STEP 7: DERIVE EFFICACY ENDPOINT FLAGS
   ======================================== */

title "NEXICART-2 ADRS: Derive Efficacy Endpoint Flags";

data bor_with_flags;
    set bor_analysis;
    
    /* Complete Response Flag (sCR or CR) */
    length CRFL $1;
    if BOR in ('sCR','CR') then CRFL = 'Y';
    else CRFL = 'N';
    
    /* Overall Response Rate Flag (sCR + CR + VGPR + PR, EXCLUDES MR) */
    length ORRFL $1;
    if BOR in ('sCR','CR','VGPR','PR') then ORRFL = 'Y';
    else ORRFL = 'N';
    
    /* Deep Response Flag (sCR + CR) - Same as CRFL */
    length DEEPFL $1;
    if BOR in ('sCR','CR') then DEEPFL = 'Y';
    else DEEPFL = 'N';
    
    /* Very Good Response or Better (sCR + CR + VGPR) */
    length VGPRFL $1;
    if BOR in ('sCR','CR','VGPR') then VGPRFL = 'Y';
    else VGPRFL = 'N';
    
    label CRFL = "Complete Response Flag (sCR or CR)"
          ORRFL = "Overall Response Rate Flag (sCR/CR/VGPR/PR)"
          DEEPFL = "Deep Response Flag (sCR or CR)"
          VGPRFL = "VGPR or Better Flag (sCR/CR/VGPR)";
run;

/* ========================================
   STEP 8: CREATE FINAL ADRS WITH BOR
   ======================================== */

data adrs_with_bor;
    merge adrs_confirmed(in=a)
          bor_with_flags(in=b);
    by USUBJID;
    if a;
    
    /* Add analysis flags */
    length ANL01FL $1;
    if not missing(AVALC) then ANL01FL = 'Y';
    else ANL01FL = '';
    
    /* Sequence number */
    ASEQ = _N_;
    
    label ANL01FL = "Analysis Flag 01"
          ASEQ = "Analysis Sequence Number";
run;

proc sort data=adrs_with_bor; by USUBJID ADY; run;

/* Final ADRS dataset */
data adrs;
    set adrs_with_bor;
run;

/* ========================================
   STEP 9: QC VALIDATION & SUMMARY REPORTS
   ======================================== */

title "NEXICART-2 ADRS QC: Patient-Level Response Progression";
title2 "Verify Response Hierarchy: PD -> SD -> MR -> PR -> VGPR -> CR -> sCR";

proc print data=adrs(where=(USUBJID in ('NEXICART2-001','NEXICART2-002')));
    by USUBJID;
    id USUBJID;
    var AVISIT ADY DFLC_VALUE PCT_REDUCTION_BL IF_NEGATIVE FLC_RATIO_NORMAL AVALC AVAL CONFIRMEDFL;
    format DFLC_VALUE PCT_REDUCTION_BL 8.1;
run;

title "NEXICART-2 ADRS Summary: Best Overall Response Distribution";
title2 "Primary Efficacy Endpoint: ORR = sCR + CR + VGPR + PR (excludes MR)";

proc freq data=bor_with_flags;
    tables BOR*ORRFL / nocol nopercent;
    tables CRFL DEEPFL VGPRFL ORRFL / nocum;
run;

title "NEXICART-2 ADRS Summary: Response Rates";

proc sql;
    select count(distinct USUBJID) as N_PATIENTS label="Total Patients",
           sum(ORRFL='Y') as ORR_N label="ORR (n)",
           calculated ORR_N / calculated N_PATIENTS * 100 as ORR_PCT format=5.1 label="ORR (%)",
           sum(CRFL='Y') as CR_N label="CR Rate (n)",
           calculated CR_N / calculated N_PATIENTS * 100 as CR_PCT format=5.1 label="CR Rate (%)",
           sum(DEEPFL='Y') as DEEP_N label="Deep Response (n)",
           calculated DEEP_N / calculated N_PATIENTS * 100 as DEEP_PCT format=5.1 label="Deep Response (%)"
    from bor_with_flags;
quit;

title "NEXICART-2 ADRS Summary: Response by Category";

proc freq data=bor_with_flags order=data;
    tables BOR / nocum;
run;

/* ========================================
   STEP 10: EXPORT DATASETS
   ======================================== */

title "NEXICART-2 ADRS: Export Final Dataset";

proc export data=adrs 
            outfile="../../adam/data/adrs.csv" 
            dbms=csv replace; 
run;

libname xptout xport "../../adam/data/xpt/adrs.xpt";
data xptout.adrs;
    set adrs;
run;

proc contents data=adrs varnum;
    title "NEXICART-2 ADRS: Dataset Contents";
run;

%put NOTE: ============================================;
%put NOTE: ADRS dataset created successfully;
%put NOTE: IMWG 7-tier response hierarchy applied:;
%put NOTE:   sCR (stringent CR) = Rank 7;
%put NOTE:   CR (complete) = Rank 6;
%put NOTE:   VGPR (very good PR) = Rank 5;
%put NOTE:   PR (partial) = Rank 4;
%put NOTE:   MR (minimal, NOT in ORR) = Rank 3;
%put NOTE:   SD (stable) = Rank 2;
%put NOTE:   PD (progressive) = Rank 1;
%put NOTE: Key endpoints derived:;
%put NOTE:   - Best Overall Response (BOR);
%put NOTE:   - Overall Response Rate (ORR = sCR+CR+VGPR+PR);
%put NOTE:   - Complete Response Rate (CR = sCR+CR);
%put NOTE:   - Deep Response Rate (same as CR);
%put NOTE: Output: adam/data/adrs.csv, adam/data/xpt/adrs.xpt;
%put NOTE: ============================================;
