/******************************************************************************
* Program: 54b_sdtm_rs_myeloma.sas
* Purpose: Generate SDTM RS (Disease Response) - MULTIPLE MYELOMA
* Author:  Christian Baghai
* Date:    2026-01-02
* Input:   LB (laboratory), MB (bone marrow), TR (extramedullary disease)
* Output:  outputs/sdtm/rs_myeloma.xpt, supprs_myeloma.xpt
* 
* Indication: Multiple Myeloma (RRMM)
* Criteria:   IMWG Uniform Response Criteria (2025 Update)
* Updates:    - Removed sCR and MR per Sept 2025 IMWG revision
*             - Mass spectrometry MRD at 10^-5 and 10^-6 sensitivity
*             - Day 28 post-CAR-T primary response assessment
* 
* Response Categories: CR, VGPR, PR, SD, PD (sCR/MR removed)
* 
* Evidence Base:
*   - IMWG Annual Summit 2025 - Simplified response criteria
*   - Kubicki T, et al. Blood Neoplasia 2025 - MS-MRD validation
*   - ASH 2025 abstracts - 10^-6 sensitivity threshold
*   - Kumar S, et al. Lancet Oncol 2016 - IMWG Uniform Response
******************************************************************************/

%let STUDYID = MYELOMA-NXC201-001;
%let DOMAIN = RS;

libname sdtm "../../data/csv";

/* Step 1: Extract M-protein measurements from LB domain */
proc sql;
    create table mprotein_data as
    select 
        USUBJID,
        VISIT,
        VISITNUM,
        LBDTC as ASSESSMENT_DATE,
        LBTESTCD,
        LBTEST,
        LBSTRESN as PROTEIN_VALUE,
        LBSTRESU as PROTEIN_UNIT,
        case 
            when LBTESTCD = 'MSMRD' then 1      /* Prioritize MS-MRD */
            when LBTESTCD = 'MSPROTSP' then 2   /* SPEP second */
            when LBTESTCD = 'SERLC' then 3      /* FLC third */
            else 99
        end as METHOD_PRIORITY
    from sdtm.lb
    where LBTESTCD in ('MSPROTSP', 'MUPROTUR', 'SERLC', 'MSMRD', 'KAPPA', 'LAMBDA')
      and not missing(LBSTRESN)
    order by USUBJID, VISITNUM, METHOD_PRIORITY;
quit;

/* Step 2: Get immunofixation results */
proc sql;
    create table immunofixation as
    select 
        USUBJID,
        VISITNUM,
        LBDTC as ASSESSMENT_DATE,
        case 
            when upcase(LBSTRESC) = 'NEGATIVE' then 1
            when upcase(LBSTRESC) = 'POSITIVE' then 0
            else .
        end as IMMFIX_NEGATIVE
    from sdtm.lb
    where LBTESTCD = 'IMMFIX'
      and not missing(LBSTRESC);
quit;

/* Step 3: Calculate baseline M-protein */
data baseline_mprotein;
    set mprotein_data;
    by USUBJID LBTESTCD;
    if first.LBTESTCD and VISITNUM = 1;
    rename PROTEIN_VALUE=BASELINE_VALUE;
    keep USUBJID LBTESTCD PROTEIN_VALUE;
run;

/* Step 4: Calculate nadir (minimum post-baseline) M-protein */
data nadir_calculation;
    merge mprotein_data(in=a)
          baseline_mprotein(in=b);
    by USUBJID LBTESTCD;
    
    retain NADIR_VALUE NADIR_VISITNUM;
    
    if first.LBTESTCD then do;
        NADIR_VALUE = PROTEIN_VALUE;
        NADIR_VISITNUM = VISITNUM;
    end;
    else if PROTEIN_VALUE < NADIR_VALUE then do;
        NADIR_VALUE = PROTEIN_VALUE;
        NADIR_VISITNUM = VISITNUM;
    end;
run;

/* Step 5: Apply 2025 IMWG response criteria (sCR and MR removed) */
data imwg_response;
    set nadir_calculation;
    
    length PROTEIN_RESPONSE $8;
    
    /* Note: sCR removed per IMWG Sept 2025 update - now mapped to CR */
    
    if not missing(BASELINE_VALUE) and BASELINE_VALUE > 0 then do;
        
        /* Very Good Partial Response: ≥90% reduction */
        if (PROTEIN_VALUE / BASELINE_VALUE) <= 0.10 then 
            PROTEIN_RESPONSE = "VGPR";
        
        /* Partial Response: ≥50% reduction */
        else if (PROTEIN_VALUE / BASELINE_VALUE) <= 0.50 then 
            PROTEIN_RESPONSE = "PR";
        
        /* Progressive Disease: ≥25% increase from nadir AND ≥0.5 g/dL absolute */
        else if not missing(NADIR_VALUE) and NADIR_VALUE > 0 then do;
            if (PROTEIN_VALUE / NADIR_VALUE) >= 1.25 and 
               (PROTEIN_VALUE - NADIR_VALUE) >= 0.5 then 
                PROTEIN_RESPONSE = "PD";
            else PROTEIN_RESPONSE = "SD";
        end;
        else PROTEIN_RESPONSE = "SD";
    end;
    else PROTEIN_RESPONSE = "NE";
run;

/* Step 6: Integrate immunofixation for Complete Response */
data protein_with_immfix;
    merge imwg_response(in=a)
          immunofixation(in=b);
    by USUBJID VISITNUM;
    
    /* CR requires negative immunofixation */
    if PROTEIN_RESPONSE in ('VGPR', 'PR') and IMMFIX_NEGATIVE = 1 then
        PROTEIN_RESPONSE = "CR";
run;

/* Step 7: Get bone marrow plasma cell percentage */
proc sql;
    create table bone_marrow as
    select 
        USUBJID,
        VISITNUM,
        MBDTC as ASSESSMENT_DATE,
        MBSTRESN as PLASMA_CELL_PCT
    from sdtm.mb
    where MBTESTCD = 'PLASMAPCT'
      and not missing(MBSTRESN);
quit;

/* Step 8: Confirm CR with bone marrow criteria (<5% plasma cells) */
data response_with_bm;
    merge protein_with_immfix(in=a)
          bone_marrow(in=b);
    by USUBJID VISITNUM;
    
    /* Downgrade CR to VGPR if bone marrow not <5% */
    if PROTEIN_RESPONSE = 'CR' and not missing(PLASMA_CELL_PCT) then do;
        if PLASMA_CELL_PCT >= 5 then
            PROTEIN_RESPONSE = 'VGPR';
    end;
run;

/* Step 9: Get MRD status (2025 IMWG emphasis on mass spectrometry) */
proc sql;
    create table mrd_status as
    select 
        USUBJID,
        VISITNUM,
        LBSTRESN as MRD_LEVEL,
        case 
            when LBSTRESN < 0.000001 then 'MRD_NEG_10E6'  /* Ultra-sensitive MS */
            when LBSTRESN < 0.00001 then 'MRD_NEG_10E5'   /* Standard MS threshold */
            else 'MRD_POS'
        end as MRD_STATUS,
        LBTESTCD as MRD_METHOD  /* MRDFLOW, MRDNGS, or MSMRD */
    from sdtm.lb
    where LBTESTCD in ('MRDFLOW', 'MRDNGS', 'MSMRD')
      and not missing(LBSTRESN);
quit;

/* Step 10: Check for extramedullary disease (EMD) progression */
proc sql;
    create table emd_assessment as
    select 
        a.USUBJID,
        a.VISITNUM,
        count(*) as N_EMD_LESIONS,
        sum(a.TRSTRESN) as TOTAL_EMD_SIZE
    from sdtm.tr a
    inner join sdtm.tu b on 
        a.USUBJID = b.USUBJID and
        a.TRLINKID = b.TULINKID
    where b.TUSTRESC = 'EXTRAMEDULLARY'
      and a.TRTESTCD = 'LDIAM'
      and not missing(a.TRSTRESN)
    group by a.USUBJID, a.VISITNUM;
quit;

/* Step 11: Get CAR-T infusion date for Day 28 assessment flagging */
proc sql;
    create table cart_infusion as
    select 
        USUBJID,
        EXSTDTC as CART_INFUSION_DATE
    from sdtm.ex
    where (upcase(EXTRT) contains 'CAR-T' or EXTRT = 'NXC-201')
      and not missing(EXSTDTC);
quit;

/* Step 12: Derive overall IMWG response */
data overall_imwg_response;
    merge response_with_bm(in=a)
          mrd_status(in=m)
          emd_assessment(in=e)
          cart_infusion(in=c);
    by USUBJID VISITNUM;
    
    length OVERALL_RESPONSE $8;
    
    /* New/progressive EMD overrides lab response */
    if N_EMD_LESIONS > 0 and VISITNUM > 1 then
        OVERALL_RESPONSE = "PD";
    else
        OVERALL_RESPONSE = PROTEIN_RESPONSE;
    
    /* Calculate days from CAR-T infusion */
    if not missing(CART_INFUSION_DATE) and not missing(ASSESSMENT_DATE) then do;
        DAYS_FROM_CART = intck('day', input(CART_INFUSION_DATE, yymmdd10.), 
                                        input(ASSESSMENT_DATE, yymmdd10.));
        
        /* Flag Day 28 primary response assessment (Day 21-35 window) */
        if 21 <= DAYS_FROM_CART <= 35 then
            PRIMARY_RESPONSE_FLAG = 'Y';
        else
            PRIMARY_RESPONSE_FLAG = 'N';
    end;
run;

/* Step 13: Derive sustained MRD negativity (≥12 months) */
proc sql;
    create table sustained_mrd as
    select 
        a.USUBJID,
        a.VISITNUM,
        a.ASSESSMENT_DATE,
        a.MRD_STATUS,
        b.ASSESSMENT_DATE as PRIOR_MRD_DATE,
        intck('month', input(b.ASSESSMENT_DATE, yymmdd10.),
                       input(a.ASSESSMENT_DATE, yymmdd10.)) as MONTHS_APART
    from mrd_status a
    left join mrd_status b on 
        a.USUBJID = b.USUBJID and
        b.VISITNUM < a.VISITNUM and
        b.MRD_STATUS in ('MRD_NEG_10E5', 'MRD_NEG_10E6')
    where a.MRD_STATUS in ('MRD_NEG_10E5', 'MRD_NEG_10E6')
    having calculated MONTHS_APART >= 12
    order by a.USUBJID, a.VISITNUM;
quit;

data sustained_mrd_flag;
    set sustained_mrd;
    by USUBJID;
    
    length SUSTAINED_MRD $20;
    if MRD_STATUS = 'MRD_NEG_10E6' then
        SUSTAINED_MRD = 'SUSTAINED_MRD_10E6';
    else
        SUSTAINED_MRD = 'SUSTAINED_MRD_10E5';
    
    keep USUBJID VISITNUM SUSTAINED_MRD MONTHS_APART;
run;

/* Step 14: Merge sustained MRD into overall response */
data overall_with_sustained_mrd;
    merge overall_imwg_response(in=a)
          sustained_mrd_flag(in=s);
    by USUBJID VISITNUM;
    if a;
run;

/* Step 15: Create final RS domain with IMWG structure */
data rs_myeloma;
    set overall_with_sustained_mrd;
    
    length STUDYID $20 DOMAIN $2;
    STUDYID = "&STUDYID";
    DOMAIN = "&DOMAIN";
    RSSEQ = _N_;
    
    /* Test code for overall response */
    length RSTESTCD $8 RSTEST $40;
    RSTESTCD = "IMWGRESP";
    RSTEST = "IMWG Overall Response";
    
    /* Category - 2025 IMWG criteria */
    length RSCAT $100;
    RSCAT = "IMWG UNIFORM RESPONSE CRITERIA 2025";
    
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
    
    /* Visit info */
    length VISIT $40;
    VISIT = VISIT;
    VISITNUM = VISITNUM;
    
    /* Epoch - based on CAR-T timing */
    length EPOCH $40;
    if missing(DAYS_FROM_CART) then EPOCH = "SCREENING";
    else if DAYS_FROM_CART < 0 then EPOCH = "LYMPHODEPLETION";
    else if 0 <= DAYS_FROM_CART <= 28 then EPOCH = "CAR-T_EXPANSION";
    else EPOCH = "FOLLOW-UP";
    
    keep STUDYID DOMAIN USUBJID RSSEQ RSTESTCD RSTEST RSCAT
         RSORRES RSSTRESC RSEVAL RSDTC VISIT VISITNUM EPOCH;
run;

/* Step 16: Create SUPPRS for MRD, Day 28 flag, and sustained MRD */
data supprs_myeloma;
    set overall_with_sustained_mrd;
    where not missing(MRD_STATUS) or PRIMARY_RESPONSE_FLAG = 'Y' or not missing(SUSTAINED_MRD);
    
    STUDYID = "&STUDYID";
    RDOMAIN = "RS";
    IDVAR = "RSSEQ";
    IDVARVAL = put(RSSEQ, best.);
    
    /* MRD status */
    if not missing(MRD_STATUS) then do;
        QNAM = "MRD";
        QLABEL = "Minimal Residual Disease Status";
        QVAL = MRD_STATUS;
        QORIG = "DERIVED";
        output;
        
        QNAM = "MRDMETH";
        QLABEL = "MRD Assessment Method";
        QVAL = MRD_METHOD;
        QORIG = "CRF";
        output;
    end;
    
    /* Sustained MRD negativity (≥12 months) */
    if not missing(SUSTAINED_MRD) then do;
        QNAM = "SUSTMRD";
        QLABEL = "Sustained MRD Negativity Status";
        QVAL = SUSTAINED_MRD;
        QORIG = "DERIVED";
        output;
        
        QNAM = "MRDMONTH";
        QLABEL = "Months Between MRD Negative Assessments";
        QVAL = put(MONTHS_APART, best.);
        QORIG = "DERIVED";
        output;
    end;
    
    /* Day 28 primary assessment flag */
    if PRIMARY_RESPONSE_FLAG = 'Y' then do;
        QNAM = "DAY28";
        QLABEL = "Day 28 Primary Response Assessment";
        QVAL = "Y";
        QORIG = "DERIVED";
        output;
    end;
    
    /* Days from CAR-T infusion */
    if not missing(DAYS_FROM_CART) then do;
        QNAM = "CARTDAYS";
        QLABEL = "Days From CAR-T Infusion";
        QVAL = put(DAYS_FROM_CART, best.);
        QORIG = "DERIVED";
        output;
    end;
    
    keep STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG;
run;

proc sort data=rs_myeloma; by USUBJID RSSEQ; run;
proc sort data=supprs_myeloma; by USUBJID IDVARVAL; run;

/* Response distribution */
proc freq data=rs_myeloma;
    tables RSSTRESC*VISIT / nocol nopercent;
    title "IMWG Response Distribution by Visit (2025 Criteria)";
run;

/* MRD distribution */
proc freq data=supprs_myeloma;
    where QNAM = 'MRD';
    tables QVAL / nocol nopercent;
    title "MRD Status Distribution (Mass Spectrometry)";
run;

/* Overall Response Rate (ORR) = CR + VGPR + PR */
proc sql;
    create table orr_summary as
    select 
        count(distinct USUBJID) as N_PATIENTS,
        sum(case when RSSTRESC in ('CR', 'VGPR', 'PR') then 1 else 0 end) as N_RESPONDERS,
        calculated N_RESPONDERS / calculated N_PATIENTS * 100 as ORR_PCT format=5.1
    from rs_myeloma
    where VISITNUM = (select max(VISITNUM) from rs_myeloma);
quit;

proc print data=orr_summary noobs;
    title "Overall Response Rate (Latest Visit)";
run;

proc export data=rs_myeloma outfile="../../data/csv/rs_myeloma.csv" dbms=csv replace; run;
proc export data=supprs_myeloma outfile="../../data/csv/supprs_myeloma.csv" dbms=csv replace; run;

libname xptout xport "../../data/xpt/rs_myeloma.xpt";
data xptout.rs; set rs_myeloma; run;
libname xptout clear;

libname xptout xport "../../data/xpt/supprs_myeloma.xpt";
data xptout.supprs; set supprs_myeloma; run;
libname xptout clear;

%put NOTE: ========================================;
%put NOTE: RS Myeloma domain generation completed;
%put NOTE: ========================================;
%put NOTE: Indication: MULTIPLE MYELOMA (RRMM);
%put NOTE: Criteria: IMWG 2025 (sCR/MR removed);
%put NOTE: Response categories: CR, VGPR, PR, SD, PD;
%put NOTE: MRD thresholds: 10^-5 and 10^-6 sensitivity;
%put NOTE: Output files created:;
%put NOTE:   - ../../data/csv/rs_myeloma.csv;
%put NOTE:   - ../../data/csv/supprs_myeloma.csv;
%put NOTE:   - ../../data/xpt/rs_myeloma.xpt;
%put NOTE:   - ../../data/xpt/supprs_myeloma.xpt;
%put NOTE: ========================================;
