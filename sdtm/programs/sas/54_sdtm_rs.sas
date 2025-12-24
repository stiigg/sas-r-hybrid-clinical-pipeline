/******************************************************************************
* Program: 54_sdtm_rs.sas
* Purpose: Generate SDTM RS (Disease Response) domain
* Author:  Christian Baghai
* Date:    2025-12-24
* Input:   TU, TR domains (from SDTM)
* Output:  outputs/sdtm/rs.xpt
* 
* Priority: CRITICAL - Overall response assessment using RECIST 1.1
* Notes:   MOST COMPLEX domain - integrates tumor measurements into response
*          Leverages RECIST logic from ADaM library
******************************************************************************/

%let STUDYID = RECIST-DEMO-001;
%let DOMAIN = RS;

libname sdtm "../../data/csv";

/* Step 1: Calculate target lesion SLD from TR domain */
proc sql;
    create table target_sld as
    select 
        a.USUBJID,
        a.VISIT,
        a.VISITNUM,
        a.TRDTC as ASSESSMENT_DATE,
        sum(a.TRSTRESN) as SLD,  /* Sum of longest diameters */
        count(*) as N_LESIONS
    from sdtm.tr a
    inner join sdtm.tu b on 
        a.USUBJID = b.USUBJID and
        a.TRLINKID = b.TULINKID
    where b.TUSTRESC = 'TARGET'
      and a.TRTESTCD = 'LDIAM'
      and not missing(a.TRSTRESN)
    group by a.USUBJID, a.VISIT, a.VISITNUM, a.TRDTC
    order by a.USUBJID, a.VISITNUM;
quit;

/* Step 2: Determine baseline SLD */
data baseline_sld;
    set target_sld;
    by USUBJID;
    if first.USUBJID;
    rename SLD=BASELINE_SLD;
    keep USUBJID SLD;
run;

/* Step 3: Calculate nadir SLD (minimum post-baseline) */
data nadir_calculation;
    merge target_sld(in=a)
          baseline_sld(in=b);
    by USUBJID;
    
    retain NADIR_SLD;
    
    if first.USUBJID then NADIR_SLD = SLD;
    else if SLD < NADIR_SLD then NADIR_SLD = SLD;
run;

/* Step 4: Apply RECIST 1.1 logic for target lesion response */
data target_response;
    set nadir_calculation;
    
    length TARGET_RESPONSE $8;
    
    /* Complete Response: All target lesions disappeared (SLD = 0) */
    if SLD = 0 then TARGET_RESPONSE = "CR";
    
    /* Partial Response: ≥30% decrease from baseline */
    else if not missing(BASELINE_SLD) and BASELINE_SLD > 0 then do;
        if (SLD / BASELINE_SLD) <= 0.70 then TARGET_RESPONSE = "PR";
        
        /* Progressive Disease: ≥20% increase from nadir AND ≥5mm absolute */
        else if not missing(NADIR_SLD) and NADIR_SLD > 0 then do;
            if (SLD / NADIR_SLD) >= 1.20 and (SLD - NADIR_SLD) >= 5 then 
                TARGET_RESPONSE = "PD";
            /* Stable Disease: Neither PR nor PD criteria met */
            else TARGET_RESPONSE = "SD";
        end;
        else TARGET_RESPONSE = "SD";
    end;
    
    /* Not evaluable if baseline missing */
    else TARGET_RESPONSE = "NE";
run;

/* Step 5: Get non-target lesion response from TR */
proc sql;
    create table nontarget_response as
    select distinct
        a.USUBJID,
        a.VISIT,
        a.VISITNUM,
        a.TRDTC as ASSESSMENT_DATE,
        case 
            /* All non-target disappeared = CR */
            when max(case when upcase(a.TRSTRESC) = 'ABSENT' then 1 else 0 end) = 1 
                 and min(case when upcase(a.TRSTRESC) = 'ABSENT' then 1 else 0 end) = 1
                then 'CR'
            /* Any progression = PD */
            when max(case when upcase(a.TRSTRESC) contains 'PROGRESSION' then 1 else 0 end) = 1 
                 or max(case when upcase(a.TRSTRESC) = 'UNEQUIVOCAL PROGRESSION' then 1 else 0 end) = 1
                then 'PD'
            /* Otherwise non-CR/non-PD */
            else 'NON-CR-NON-PD'
        end as NONTARGET_RESPONSE
    from sdtm.tr a
    inner join sdtm.tu b on 
        a.USUBJID = b.USUBJID and
        a.TRLINKID = b.TULINKID
    where b.TUSTRESC = 'NON-TARGET'
    group by a.USUBJID, a.VISIT, a.VISITNUM, a.TRDTC;
quit;

/* Step 6: Check for new lesions */
proc sql;
    create table new_lesions as
    select distinct
        USUBJID,
        VISIT,
        VISITNUM,
        TUDTC as ASSESSMENT_DATE,
        'YES' as NEW_LESION
    from sdtm.tu
    where TUSTRESC = 'NEW'
      and VISITNUM > 1;  /* New lesions after baseline */
quit;

/* Step 7: Derive overall response using RECIST 1.1 Table 4 */
data overall_response;
    merge target_response(in=t keep=USUBJID VISITNUM VISIT ASSESSMENT_DATE 
                                    TARGET_RESPONSE SLD BASELINE_SLD NADIR_SLD)
          nontarget_response(in=nt keep=USUBJID VISITNUM NONTARGET_RESPONSE)
          new_lesions(in=nl keep=USUBJID VISITNUM NEW_LESION);
    by USUBJID VISITNUM;
    
    length OVERALL_RESPONSE $8;
    
    /* New lesion present = PD (overrides everything) */
    if NEW_LESION = 'YES' then OVERALL_RESPONSE = "PD";
    
    /* Target=CR + Non-target=CR = CR */
    else if TARGET_RESPONSE = 'CR' and NONTARGET_RESPONSE = 'CR' then 
        OVERALL_RESPONSE = "CR";
    
    /* Target=CR + Non-target=Non-CR/Non-PD = PR */
    else if TARGET_RESPONSE = 'CR' and NONTARGET_RESPONSE = 'NON-CR-NON-PD' then 
        OVERALL_RESPONSE = "PR";
    
    /* Target=PR + Non-target ne PD = PR */
    else if TARGET_RESPONSE = 'PR' and NONTARGET_RESPONSE ne 'PD' then 
        OVERALL_RESPONSE = "PR";
    
    /* Target=SD + Non-target ne PD = SD */
    else if TARGET_RESPONSE = 'SD' and NONTARGET_RESPONSE ne 'PD' then 
        OVERALL_RESPONSE = "SD";
    
    /* Any PD = PD */
    else if TARGET_RESPONSE = 'PD' or NONTARGET_RESPONSE = 'PD' then 
        OVERALL_RESPONSE = "PD";
    
    /* Only non-target, no target */
    else if missing(TARGET_RESPONSE) and NONTARGET_RESPONSE = 'CR' then
        OVERALL_RESPONSE = "CR";
    else if missing(TARGET_RESPONSE) and NONTARGET_RESPONSE = 'NON-CR-NON-PD' then
        OVERALL_RESPONSE = "NON-CR-NON-PD";
    
    /* Default to not evaluable */
    else OVERALL_RESPONSE = "NE";
run;

/* Step 8: Create final RS domain in SDTM structure */
data rs;
    set overall_response;
    
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    RSSEQ = _N_;
    
    /* Test code for overall response */
    length RSTESTCD $8 RSTEST $40;
    RSTESTCD = "OVRLRESP";
    RSTEST = "Overall Response";
    
    /* Category - RECIST version */
    length RSCAT $40;
    RSCAT = "RECIST 1.1";
    
    /* Response result */
    length RSORRES $200 RSSTRESC $8;
    RSORRES = OVERALL_RESPONSE;
    RSSTRESC = OVERALL_RESPONSE;
    
    /* Evaluator */
    length RSEVAL $40;
    RSEVAL = "INVESTIGATOR";
    
    /* Assessment date */
    length RSDTC $20;
    RSDTC = ASSESSMENT_DATE;
    
    /* Visit */
    length VISIT $40;
    VISIT = VISIT;
    VISITNUM = VISITNUM;
    
    /* Epoch */
    length EPOCH $40;
    if VISITNUM = 1 then EPOCH = "SCREENING";
    else EPOCH = "TREATMENT";
    
    keep STUDYID DOMAIN USUBJID RSSEQ RSTESTCD RSTEST RSCAT
         RSORRES RSSTRESC RSEVAL RSDTC VISIT VISITNUM EPOCH;
run;

proc sort data=rs; by USUBJID RSSEQ; run;

/* Response distribution by visit */
proc freq data=rs;
    tables RSSTRESC*VISIT / nocol nopercent;
    title "RS Domain - Response Distribution by Visit";
run;

/* Waterfall plot data */
proc sql;
    create table response_summary as
    select 
        USUBJID,
        max(case when RSSTRESC = 'CR' then 1 else 0 end) as Ever_CR,
        max(case when RSSTRESC = 'PR' then 1 else 0 end) as Ever_PR,
        max(case when RSSTRESC in ('CR','PR') then 1 else 0 end) as Ever_Responder
    from rs
    group by USUBJID;
quit;

proc print data=response_summary noobs;
    title "Subject Response Summary";
run;

proc export data=rs outfile="../../data/csv/rs.csv" dbms=csv replace; run;

libname xptout xport "../../data/xpt/rs.xpt";
data xptout.rs; set rs; run;
libname xptout clear;

%put NOTE: RS domain generation completed successfully;
%put NOTE: Output files created:;
%put NOTE:   - ../../data/csv/rs.csv;
%put NOTE:   - ../../data/xpt/rs.xpt;
%put NOTE: RECIST 1.1 Overall Response assessment complete;
