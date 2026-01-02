/******************************************************************************
* Program: 54a_sdtm_rs_recist.sas
* Purpose: Generate SDTM RS (Disease Response) domain - SOLID TUMORS ONLY
* Author:  Christian Baghai
* Date:    2026-01-02 (Updated from 2025-12-24)
* Input:   TU, TR domains (from SDTM)
* Output:  outputs/sdtm/rs_recist.xpt, supprs_recist.xpt
* 
* Indication: SOLID TUMORS with measurable lesions
* Criteria:   RECIST 1.1 (2009) with 2025 evidence-based enhancements
* Updates:    - Enaworu 25mm nadir rule for PD determination
*             - Automated measurement reliability QC flags
*             - iRECIST confirmation logic (optional for immunotherapy)
* 
* NOT APPLICABLE TO: Multiple Myeloma, AL Amyloidosis, Lymphoma
* 
* Evidence Base:
*   - Eisenhauer EA, et al. Eur J Cancer 2009 - RECIST 1.1 Guidelines
*   - Enaworu O, et al. Cureus 2025 - 25mm nadir rule simplification
*   - Seymour L, et al. Lancet Oncol 2017 - iRECIST for immunotherapy
******************************************************************************/

%let STUDYID = RECIST-DEMO-001;
%let DOMAIN = RS;
%let IMMUNOTHERAPY = N;  /* Set to Y for immunotherapy trials requiring iRECIST */

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
    rename SLD=BASELINE_SLD ASSESSMENT_DATE=BASELINE_DATE;
    keep USUBJID SLD ASSESSMENT_DATE;
run;

/* Step 3: Calculate nadir SLD (minimum post-baseline) */
data nadir_calculation;
    merge target_sld(in=a)
          baseline_sld(in=b);
    by USUBJID;
    
    retain NADIR_SLD NADIR_VISITNUM;
    
    if first.USUBJID then do;
        NADIR_SLD = SLD;
        NADIR_VISITNUM = VISITNUM;
    end;
    else if SLD < NADIR_SLD then do;
        NADIR_SLD = SLD;
        NADIR_VISITNUM = VISITNUM;
    end;
run;

/* Step 4: Apply RECIST 1.1 with Enaworu 25mm nadir simplification */
data target_response;
    set nadir_calculation;
    
    length TARGET_RESPONSE $8;
    
    /* Complete Response: All target lesions disappeared (SLD = 0) */
    if SLD = 0 then TARGET_RESPONSE = "CR";
    
    /* Partial Response: ≥30% decrease from baseline */
    else if not missing(BASELINE_SLD) and BASELINE_SLD > 0 then do;
        if (SLD / BASELINE_SLD) <= 0.70 then TARGET_RESPONSE = "PR";
        
        /* UPDATED 2026-01-02: Enaworu 25mm nadir rule per Apr 2025 research */
        else if not missing(NADIR_SLD) and NADIR_SLD > 0 then do;
            
            /* If nadir <25mm: 5mm absolute increase required for PD */
            if NADIR_SLD < 25 then do;
                if (SLD - NADIR_SLD) >= 5 then TARGET_RESPONSE = "PD";
                else TARGET_RESPONSE = "SD";
            end;
            
            /* If nadir ≥25mm: standard 20% + 5mm criteria */
            else do;
                if (SLD / NADIR_SLD) >= 1.20 and (SLD - NADIR_SLD) >= 5 then 
                    TARGET_RESPONSE = "PD";
                else TARGET_RESPONSE = "SD";
            end;
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

/* Step 8: Apply iRECIST confirmation logic for immunotherapy trials */
%macro apply_irecist();
    
    %if %upcase(&IMMUNOTHERAPY) = Y %then %do;
        
        %put NOTE: Applying iRECIST confirmation logic for immunotherapy trial;
        
        data overall_response_irecist;
            set overall_response;
            by USUBJID VISITNUM;
            
            retain IUPD_DATE IUPD_SLD IUPD_VISITNUM;
            length IRECIST_STATUS $12;
            
            /* Step 1: Flag initial Unconfirmed Progressive Disease (iUPD) */
            if OVERALL_RESPONSE = 'PD' and first.USUBJID then do;
                IRECIST_STATUS = 'iUPD';
                IUPD_DATE = ASSESSMENT_DATE;
                IUPD_SLD = SLD;
                IUPD_VISITNUM = VISITNUM;
                OVERALL_RESPONSE = 'iUPD';  /* Override RECIST 1.1 PD */
            end;
            
            /* Step 2: Confirm iCPD at next assessment (4-8 weeks later) */
            else if not missing(IUPD_DATE) then do;
                
                DAYS_FROM_IUPD = intck('day', input(IUPD_DATE, yymmdd10.), 
                                               input(ASSESSMENT_DATE, yymmdd10.));
                
                /* Confirmation window: 4-8 weeks per iRECIST guidelines */
                if 28 <= DAYS_FROM_IUPD <= 56 then do;
                    
                    /* Confirmed CPD: Further increase of ≥5mm from iUPD nadir */
                    if (SLD - IUPD_SLD) >= 5 then do;
                        IRECIST_STATUS = 'iCPD';
                        OVERALL_RESPONSE = 'PD';  /* Confirmed progression */
                    end;
                    
                    /* CR/PR/SD per baseline: pseudoprogression confirmed */
                    else if OVERALL_RESPONSE in ('CR', 'PR', 'SD') then do;
                        IRECIST_STATUS = 'iPR_POST';
                        /* Keep derived CR/PR/SD status */
                    end;
                    
                    /* Reset iUPD if not confirmed */
                    else do;
                        IRECIST_STATUS = 'iSD';
                        call missing(IUPD_DATE, IUPD_SLD);
                    end;
                end;
            end;
        run;
        
        data overall_response;
            set overall_response_irecist;
        run;
        
    %end;
    
%mend apply_irecist;

%apply_irecist();

/* Step 9: Quality control flags for potential measurement errors */
data overall_response_with_qc;
    set overall_response;
    by USUBJID VISITNUM;
    
    length QCFLAG $500;
    
    retain LAG_SLD LAG_VISITNUM;
    
    /* Flag implausible SLD increase (>50% in single visit) */
    if not first.USUBJID then do;
        if not missing(LAG_SLD) and not missing(SLD) and LAG_SLD > 0 then do;
            if SLD / LAG_SLD > 1.50 and VISITNUM = LAG_VISITNUM + 1 then
                QCFLAG = "IMPLAUSIBLE_INCREASE: >50% SLD change - verify measurements";
        end;
    end;
    
    /* Flag prolonged SD (≥6 months) - consider volumetric assessment */
    if not missing(BASELINE_DATE) and not missing(ASSESSMENT_DATE) then do;
        MONTHS_FROM_BASELINE = intck('month', input(BASELINE_DATE, yymmdd10.), 
                                              input(ASSESSMENT_DATE, yymmdd10.));
        if OVERALL_RESPONSE = 'SD' and MONTHS_FROM_BASELINE >= 6 then
            QCFLAG = catx('; ', QCFLAG, "PROLONGED_SD: Consider volumetric RECIST");
    end;
    
    LAG_SLD = SLD;
    LAG_VISITNUM = VISITNUM;
run;

/* Output QC flags to separate dataset for review */
data qc_flags;
    set overall_response_with_qc;
    where not missing(QCFLAG);
    keep USUBJID VISIT OVERALL_RESPONSE SLD LAG_SLD QCFLAG;
run;

proc print data=qc_flags noobs;
    title "RECIST Measurement Quality Control Flags";
    var USUBJID VISIT OVERALL_RESPONSE SLD LAG_SLD QCFLAG;
run;

/* Step 10: Create final RS domain in SDTM structure */
data rs;
    set overall_response_with_qc;
    
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    RSSEQ = _N_;
    
    /* Test code for overall response */
    length RSTESTCD $8 RSTEST $40;
    RSTESTCD = "OVRLRESP";
    RSTEST = "Overall Response";
    
    /* Category - RECIST version */
    length RSCAT $100;
    %if %upcase(&IMMUNOTHERAPY) = Y %then %do;
        RSCAT = "RECIST 1.1 + iRECIST (IMMUNOTHERAPY)";
    %end;
    %else %do;
        RSCAT = "RECIST 1.1 + ENAWORU 25MM RULE";
    %end;
    
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

/* Step 11: Create SUPPRS for iRECIST metadata and QC flags */
data supprs;
    set overall_response_with_qc;
    where not missing(IRECIST_STATUS) or not missing(QCFLAG);
    
    STUDYID = "&STUDYID";
    RDOMAIN = "RS";
    IDVAR = "RSSEQ";
    IDVARVAL = put(RSSEQ, best.);
    
    /* iRECIST status */
    %if %upcase(&IMMUNOTHERAPY) = Y %then %do;
        if not missing(IRECIST_STATUS) then do;
            QNAM = "IRECIST";
            QLABEL = "iRECIST Immune Confirmation Status";
            QVAL = IRECIST_STATUS;
            QORIG = "DERIVED";
            output;
            
            if not missing(DAYS_FROM_IUPD) then do;
                QNAM = "IUPDDAYS";
                QLABEL = "Days From Initial iUPD to Confirmation";
                QVAL = put(DAYS_FROM_IUPD, best.);
                QORIG = "DERIVED";
                output;
            end;
        end;
    %end;
    
    /* QC flags */
    if not missing(QCFLAG) then do;
        QNAM = "QCFLAG";
        QLABEL = "Quality Control Flag";
        QVAL = QCFLAG;
        QORIG = "DERIVED";
        output;
    end;
    
    keep STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG;
run;

proc sort data=rs; by USUBJID RSSEQ; run;
proc sort data=supprs; by USUBJID IDVARVAL; run;

/* Response distribution by visit */
proc freq data=rs;
    tables RSSTRESC*VISIT / nocol nopercent;
    title "RS Domain - Response Distribution by Visit (RECIST 1.1 + Enaworu 25mm)";
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

proc export data=rs outfile="../../data/csv/rs_recist.csv" dbms=csv replace; run;
proc export data=supprs outfile="../../data/csv/supprs_recist.csv" dbms=csv replace; run;

libname xptout xport "../../data/xpt/rs_recist.xpt";
data xptout.rs; set rs; run;
libname xptout clear;

libname xptout xport "../../data/xpt/supprs_recist.xpt";
data xptout.supprs; set supprs; run;
libname xptout clear;

%put NOTE: ========================================;
%put NOTE: RS RECIST domain generation completed;
%put NOTE: ========================================;
%put NOTE: Indication: SOLID TUMORS;
%put NOTE: Criteria: RECIST 1.1 + Enaworu 25mm nadir rule;
%put NOTE: Immunotherapy mode: &IMMUNOTHERAPY;
%put NOTE: Output files created:;
%put NOTE:   - ../../data/csv/rs_recist.csv;
%put NOTE:   - ../../data/csv/supprs_recist.csv;
%put NOTE:   - ../../data/xpt/rs_recist.xpt;
%put NOTE:   - ../../data/xpt/supprs_recist.xpt;
%put NOTE: ========================================;
