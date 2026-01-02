/******************************************************************************
* Program: 54c_sdtm_rs_amyloidosis.sas
* Purpose: Generate SDTM RS (Disease Response) - AL AMYLOIDOSIS
* Author:  Christian Baghai
* Date:    2026-01-02
* Input:   LB domain (dFLC, NT-proBNP, proteinuria, eGFR, immunofixation)
* Output:  outputs/sdtm/rs_amyloidosis.xpt, supprs_amyloidosis.xpt
* 
* Indication: AL (Light Chain) Amyloidosis
* Criteria:   Palladini 2012 Consensus Criteria (used in NCT06097832)
* Endpoints:  Multi-domain composite (hematologic + cardiac + renal)
* 
* FDA-Qualified Biomarkers:
*   - NT-proBNP cardiac response (>30% AND >300 ng/L decrease)
*   - Hematologic response (dFLC ≥50% reduction or normal FLC ratio)
* 
* Evidence Base:
*   - Palladini G, et al. Leukemia 2012 - Consensus response criteria
*   - Merlini G, et al. Leukemia 2016 - FDA-qualified NT-proBNP biomarker
*   - FDA Guidance Dec 2016 - AL amyloidosis drug development endpoints
******************************************************************************/

%let STUDYID = AMYLOID-NXC201-001;
%let DOMAIN = RS;

libname sdtm "../../data/csv";

/* Step 1: Calculate dFLC (difference between involved and uninvolved FLC) */
proc sql;
    create table flc_data as
    select 
        USUBJID,
        VISIT,
        VISITNUM,
        LBDTC as ASSESSMENT_DATE,
        max(case when LBTESTCD='KAPPA' then LBSTRESN else . end) as KAPPA_FLC,
        max(case when LBTESTCD='LAMBDA' then LBSTRESN else . end) as LAMBDA_FLC,
        max(case when LBTESTCD='FLCRATIO' then LBSTRESN else . end) as FLC_RATIO
    from sdtm.lb
    where LBTESTCD in ('KAPPA', 'LAMBDA', 'FLCRATIO')
      and not missing(LBSTRESN)
    group by USUBJID, VISIT, VISITNUM, LBDTC;
quit;

/* Calculate dFLC (involved - uninvolved) based on which chain is elevated */
data flc_with_dflc;
    set flc_data;
    
    /* Determine involved chain based on FLC ratio */
    if FLC_RATIO > 1.65 then do;  /* Kappa involved */
        INVOLVED_FLC = KAPPA_FLC;
        UNINVOLVED_FLC = LAMBDA_FLC;
        INVOLVED_CHAIN = 'KAPPA';
    end;
    else if FLC_RATIO < 0.26 then do;  /* Lambda involved */
        INVOLVED_FLC = LAMBDA_FLC;
        UNINVOLVED_FLC = KAPPA_FLC;
        INVOLVED_CHAIN = 'LAMBDA';
    end;
    
    /* dFLC = involved - uninvolved */
    if not missing(INVOLVED_FLC) and not missing(UNINVOLVED_FLC) then
        dFLC = abs(INVOLVED_FLC - UNINVOLVED_FLC);
run;

/* Step 2: Determine baseline dFLC and FLC ratio */
data baseline_flc;
    set flc_with_dflc;
    by USUBJID;
    if first.USUBJID and VISITNUM = 1;
    rename dFLC=BASELINE_dFLC FLC_RATIO=BASELINE_FLC_RATIO;
    keep USUBJID dFLC FLC_RATIO;
run;

/* Step 3: Get immunofixation status */
proc sql;
    create table immunofixation as
    select 
        USUBJID,
        VISITNUM,
        case 
            when upcase(LBSTRESC) = 'NEGATIVE' then 1
            else 0
        end as IMMFIX_NEGATIVE
    from sdtm.lb
    where LBTESTCD = 'IMMFIX';
quit;

/* Step 4: Derive hematologic response per Palladini 2012 */
data hematologic_response;
    merge flc_with_dflc(in=a)
          baseline_flc(in=b)
          immunofixation(in=c);
    by USUBJID VISITNUM;
    
    length HEMAT_RESPONSE $30;
    
    /* Complete Response: Normal FLC ratio (0.26-1.65) AND negative IF */
    if 0.26 <= FLC_RATIO <= 1.65 and IMMFIX_NEGATIVE = 1 then
        HEMAT_RESPONSE = "HEMAT_CR";
    
    /* Partial Response: ≥50% dFLC reduction from baseline */
    else if not missing(BASELINE_dFLC) and BASELINE_dFLC > 0 then do;
        dFLC_PCT_CHANGE = (dFLC - BASELINE_dFLC) / BASELINE_dFLC * 100;
        
        if dFLC_PCT_CHANGE <= -50 then
            HEMAT_RESPONSE = "HEMAT_PR";
        else
            HEMAT_RESPONSE = "NO_HEMAT_RESPONSE";
    end;
    else HEMAT_RESPONSE = "NOT_EVALUABLE";
run;

/* Step 5: Get NT-proBNP values (FDA-qualified cardiac biomarker) */
proc sql;
    create table ntprobnp_data as
    select 
        USUBJID,
        VISIT,
        VISITNUM,
        LBDTC as ASSESSMENT_DATE,
        LBSTRESN as NTPROBNP,
        LBSTRESU as NTPROBNP_UNIT
    from sdtm.lb
    where LBTESTCD = 'NTPROBNP'
      and not missing(LBSTRESN);
quit;

/* Standardize NT-proBNP to ng/L per FDA guidance */
data ntprobnp_standardized;
    set ntprobnp_data;
    
    if upcase(NTPROBNP_UNIT) = 'PMOL/L' then do;
        NTPROBNP = NTPROBNP / 0.1181;  /* Convert to ng/L */
        NTPROBNP_UNIT = 'ng/L';
    end;
    else if upcase(NTPROBNP_UNIT) in ('PG/ML', 'NG/L') then do;
        NTPROBNP = NTPROBNP;  /* Already in ng/L */
        NTPROBNP_UNIT = 'ng/L';
    end;
run;

/* Step 6: Determine baseline NT-proBNP */
data baseline_ntprobnp;
    set ntprobnp_standardized;
    by USUBJID;
    if first.USUBJID and VISITNUM = 1;
    rename NTPROBNP=BASELINE_NTPROBNP;
    keep USUBJID NTPROBNP;
run;

/* Step 7: Derive cardiac response per FDA-qualified criteria */
data cardiac_response;
    merge ntprobnp_standardized(in=a)
          baseline_ntprobnp(in=b);
    by USUBJID;
    
    length CARDIAC_RESPONSE $30 CARDIAC_EVALUABLE $1;
    
    /* FDA evaluability criterion: baseline NT-proBNP ≥650 ng/L */
    if BASELINE_NTPROBNP < 650 then do;
        CARDIAC_RESPONSE = "NOT_EVALUABLE";
        CARDIAC_EVALUABLE = 'N';
        CARDIAC_REASON = 'Baseline NT-proBNP <650 ng/L';
    end;
    else do;
        CARDIAC_EVALUABLE = 'Y';
        
        /* Calculate changes */
        PCT_CHANGE = (NTPROBNP - BASELINE_NTPROBNP) / BASELINE_NTPROBNP * 100;
        ABS_CHANGE = NTPROBNP - BASELINE_NTPROBNP;
        
        /* FDA-qualified response: BOTH >30% decrease AND >300 ng/L decrease */
        if PCT_CHANGE <= -30 and ABS_CHANGE <= -300 then
            CARDIAC_RESPONSE = "CARDIAC_RESPONSE";
        else
            CARDIAC_RESPONSE = "NO_CARDIAC_RESPONSE";
    end;
run;

/* Step 8: Get proteinuria and eGFR for renal response */
proc sql;
    create table renal_data as
    select 
        USUBJID,
        VISIT,
        VISITNUM,
        LBDTC as ASSESSMENT_DATE,
        max(case when LBTESTCD='UPROT24' then LBSTRESN else . end) as PROTEINURIA_24H,
        max(case when LBTESTCD='EGFR' then LBSTRESN else . end) as EGFR
    from sdtm.lb
    where LBTESTCD in ('UPROT24', 'EGFR')
      and not missing(LBSTRESN)
    group by USUBJID, VISIT, VISITNUM, LBDTC;
quit;

/* Step 9: Determine baseline renal parameters */
data baseline_renal;
    set renal_data;
    by USUBJID;
    if first.USUBJID and VISITNUM = 1;
    rename PROTEINURIA_24H=BASELINE_PROTEINURIA EGFR=BASELINE_EGFR;
    keep USUBJID PROTEINURIA_24H EGFR;
run;

/* Step 10: Derive renal response per Palladini criteria */
data renal_response;
    merge renal_data(in=a)
          baseline_renal(in=b);
    by USUBJID;
    
    length RENAL_RESPONSE $30 RENAL_EVALUABLE $1;
    
    /* Evaluability: baseline proteinuria ≥0.5 g/24h per FDA guidance */
    if BASELINE_PROTEINURIA < 0.5 then do;
        RENAL_RESPONSE = "NOT_EVALUABLE";
        RENAL_EVALUABLE = 'N';
        RENAL_REASON = 'Baseline proteinuria <0.5 g/24h';
    end;
    else do;
        RENAL_EVALUABLE = 'Y';
        
        /* Calculate changes */
        PROTEINURIA_PCT_CHG = (PROTEINURIA_24H - BASELINE_PROTEINURIA) / 
                               BASELINE_PROTEINURIA * 100;
        EGFR_PCT_CHG = (EGFR - BASELINE_EGFR) / BASELINE_EGFR * 100;
        
        /* ≥30% proteinuria decrease WITHOUT ≥25% eGFR worsening */
        if PROTEINURIA_PCT_CHG <= -30 and EGFR_PCT_CHG > -25 then
            RENAL_RESPONSE = "RENAL_RESPONSE";
        else
            RENAL_RESPONSE = "NO_RENAL_RESPONSE";
    end;
run;

/* Step 11: Merge all organ-specific responses */
data combined_responses;
    merge hematologic_response(in=h)
          cardiac_response(in=c)
          renal_response(in=r);
    by USUBJID VISITNUM;
    if h;  /* Keep all visits with hematologic assessment */
run;

/* Step 12: Create RS domain with SEPARATE RECORDS per organ system */
data rs_amyloidosis;
    set combined_responses;
    
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    
    length RSTESTCD $20 RSTEST $100 RSCAT $100;
    length RSORRES $200 RSSTRESC $30 RSEVAL $40 RSDTC $20;
    
    RSEVAL = "INVESTIGATOR";
    RSDTC = ASSESSMENT_DATE;
    
    /* Record 1: Hematologic Response */
    RSSEQ = (_N_ * 4) - 3;
    RSTESTCD = "HEMAT";
    RSTEST = "Hematologic Response";
    RSCAT = "AL AMYLOIDOSIS - PALLADINI 2012";
    RSORRES = HEMAT_RESPONSE;
    RSSTRESC = HEMAT_RESPONSE;
    output;
    
    /* Record 2: Cardiac Response */
    RSSEQ + 1;
    RSTESTCD = "CARDIAC";
    RSTEST = "Cardiac Response (NT-proBNP)";
    RSCAT = "AL AMYLOIDOSIS - FDA QUALIFIED BIOMARKER";
    RSORRES = CARDIAC_RESPONSE;
    RSSTRESC = CARDIAC_RESPONSE;
    output;
    
    /* Record 3: Renal Response */
    RSSEQ + 1;
    RSTESTCD = "RENAL";
    RSTEST = "Renal Response (Proteinuria)";
    RSCAT = "AL AMYLOIDOSIS - PALLADINI 2012";
    RSORRES = RENAL_RESPONSE;
    RSSTRESC = RENAL_RESPONSE;
    output;
    
    /* Record 4: Composite Multi-Domain Response */
    RSSEQ + 1;
    RSTESTCD = "COMPOSITE";
    RSTEST = "Composite Multi-Domain Response";
    RSCAT = "AL AMYLOIDOSIS - COMPOSITE ENDPOINT";
    
    /* Composite CR: Hematologic CR + any organ response */
    if HEMAT_RESPONSE = "HEMAT_CR" and 
       (CARDIAC_RESPONSE = "CARDIAC_RESPONSE" or RENAL_RESPONSE = "RENAL_RESPONSE") then
        RSSTRESC = "COMPOSITE_CR";
    
    /* Composite PR: Hematologic PR + any organ response */
    else if HEMAT_RESPONSE = "HEMAT_PR" and
            (CARDIAC_RESPONSE = "CARDIAC_RESPONSE" or RENAL_RESPONSE = "RENAL_RESPONSE") then
        RSSTRESC = "COMPOSITE_PR";
    
    /* Hematologic only (no organ response) */
    else if HEMAT_RESPONSE in ("HEMAT_CR", "HEMAT_PR") then
        RSSTRESC = "HEMAT_ONLY";
    
    /* No response */
    else RSSTRESC = "NO_COMPOSITE_RESPONSE";
    
    RSORRES = RSSTRESC;
    output;
    
    keep STUDYID DOMAIN USUBJID RSSEQ RSTESTCD RSTEST RSCAT
         RSORRES RSSTRESC RSEVAL RSDTC VISIT VISITNUM;
run;

/* Step 13: Create SUPPRS with FDA thresholds and evaluability */
data supprs_amyloidosis;
    set combined_responses;
    
    STUDYID = "&STUDYID";
    RDOMAIN = "RS";
    IDVAR = "RSSEQ";
    
    /* Cardiac evaluability flag */
    IDVARVAL = put((_N_ * 4) - 2, best.);  /* Cardiac RSSEQ */
    
    QNAM = "CARDEVAL";
    QLABEL = "Cardiac Response Evaluability";
    QVAL = CARDIAC_EVALUABLE;
    QORIG = "DERIVED";
    output;
    
    if CARDIAC_EVALUABLE = 'N' then do;
        QNAM = "CARDREASON";
        QLABEL = "Cardiac Non-Evaluability Reason";
        QVAL = CARDIAC_REASON;
        QORIG = "DERIVED";
        output;
    end;
    
    QNAM = "CARDTHRS";
    QLABEL = "Cardiac FDA Threshold";
    QVAL = ">30% decrease AND >300 ng/L decrease in NT-proBNP";
    QORIG = "PROTOCOL";
    output;
    
    /* Cardiac response magnitude (for responders) */
    if CARDIAC_RESPONSE = 'CARDIAC_RESPONSE' then do;
        QNAM = "CARDMAG";
        QLABEL = "NT-proBNP Decrease Magnitude";
        QVAL = catx(', ', 
                    cats(round(PCT_CHANGE, 0.1), "% decrease"),
                    cats(round(abs(ABS_CHANGE), 1), " ng/L decrease"));
        QORIG = "DERIVED";
        output;
    end;
    
    /* Renal evaluability flag */
    IDVARVAL = put((_N_ * 4) - 1, best.);  /* Renal RSSEQ */
    
    QNAM = "RENALEVAL";
    QLABEL = "Renal Response Evaluability";
    QVAL = RENAL_EVALUABLE;
    QORIG = "DERIVED";
    output;
    
    if RENAL_EVALUABLE = 'N' then do;
        QNAM = "RENREASON";
        QLABEL = "Renal Non-Evaluability Reason";
        QVAL = RENAL_REASON;
        QORIG = "DERIVED";
        output;
    end;
    
    /* Renal response with eGFR safety check */
    if RENAL_RESPONSE = 'RENAL_RESPONSE' and EGFR_PCT_CHG < -15 then do;
        QNAM = "RENALQC";
        QLABEL = "Renal QC Flag";
        QVAL = catx('', "eGFR decline ", round(abs(EGFR_PCT_CHG), 0.1), 
                    "% - monitor for progression");
        QORIG = "DERIVED";
        output;
    end;
    
    keep STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG;
run;

proc sort data=rs_amyloidosis; by USUBJID RSSEQ; run;
proc sort data=supprs_amyloidosis; by USUBJID IDVARVAL; run;

/* Response distributions */
proc freq data=rs_amyloidosis;
    tables RSTESTCD*RSSTRESC / nocol nopercent;
    title "AL Amyloidosis Multi-Domain Response Distribution";
run;

/* Composite response summary */
proc freq data=rs_amyloidosis;
    where RSTESTCD = 'COMPOSITE';
    tables RSSTRESC / nocol nopercent;
    title "AL Amyloidosis Composite Endpoint Distribution";
run;

/* Organ-specific response crosstab */
proc sql;
    create table organ_response_matrix as
    select 
        USUBJID,
        VISITNUM,
        max(case when RSTESTCD='HEMAT' then RSSTRESC else '' end) as HEMATOLOGIC,
        max(case when RSTESTCD='CARDIAC' then RSSTRESC else '' end) as CARDIAC,
        max(case when RSTESTCD='RENAL' then RSSTRESC else '' end) as RENAL,
        max(case when RSTESTCD='COMPOSITE' then RSSTRESC else '' end) as COMPOSITE
    from rs_amyloidosis
    group by USUBJID, VISITNUM;
quit;

proc print data=organ_response_matrix(obs=10) noobs;
    title "AL Amyloidosis Organ-Specific Response Matrix (First 10 Records)";
run;

proc export data=rs_amyloidosis outfile="../../data/csv/rs_amyloidosis.csv" dbms=csv replace; run;
proc export data=supprs_amyloidosis outfile="../../data/csv/supprs_amyloidosis.csv" dbms=csv replace; run;

libname xptout xport "../../data/xpt/rs_amyloidosis.xpt";
data xptout.rs; set rs_amyloidosis; run;
libname xptout clear;

libname xptout xport "../../data/xpt/supprs_amyloidosis.xpt";
data xptout.supprs; set supprs_amyloidosis; run;
libname xptout clear;

%put NOTE: ========================================;
%put NOTE: RS AL Amyloidosis domain generation completed;
%put NOTE: ========================================;
%put NOTE: Indication: AL (LIGHT CHAIN) AMYLOIDOSIS;
%put NOTE: Criteria: Palladini 2012 + FDA biomarkers;
%put NOTE: FDA-qualified NT-proBNP cardiac endpoint included;
%put NOTE: Multi-domain composite response per Palladini 2012;
%put NOTE: Separate RS records: HEMAT, CARDIAC, RENAL, COMPOSITE;
%put NOTE: Output files created:;
%put NOTE:   - ../../data/csv/rs_amyloidosis.csv;
%put NOTE:   - ../../data/csv/supprs_amyloidosis.csv;
%put NOTE:   - ../../data/xpt/rs_amyloidosis.xpt;
%put NOTE:   - ../../data/xpt/supprs_amyloidosis.xpt;
%put NOTE: ========================================;
