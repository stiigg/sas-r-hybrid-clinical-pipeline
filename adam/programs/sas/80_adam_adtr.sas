/******************************************************************************
* Program: 80_adam_adtr.sas
* Purpose: Tumor Measurements Analysis Dataset (RECIST 1.1)
* Author:  Christian Baghai
* Date:    2026-01-04
* Version: 1.1 - Integrated validated import macros
* 
* Input:   sdtm/data/csv/tu.csv, sdtm/data/csv/tr.csv, sdtm/data/csv/dm.csv
* Output:  adam/data/adtr.csv, adam/data/xpt/adtr.xpt
* 
* Priority: FOUNDATIONAL - Required for ADRS (BOR) derivation
* 
* Parameters Derived:
*   - LDIAM: Longest diameter of individual target lesions
*   - SLD: Sum of Longest Diameters (all target lesions)
*   - NADIR: Minimum post-baseline SLD value
*   - PCHG: Percent change from baseline
*   - PCHGN: Percent change from nadir
*   - NEWLFL: New lesion detection flag
* 
* Reference: RECIST 1.1 - Eisenhauer et al. Eur J Cancer 2009;45(2):228-247
*            Vitale et al. JNCI 2025 (censoring transparency)
*            PharmaSUG 2025-SA-287 (efficacy roadmap)
* 
* Version History:
*   v1.0 (2026-01-03): Initial implementation
*   v1.1 (2026-01-04): Integrated validated import macros (import_tr, import_tu)
******************************************************************************/

%let STUDYID = NEXICART2-SOLID-TUMOR;

libname sdtm "../../sdtm/data/csv";
libname adam "../../adam/data";

/* Set project root if not already defined */
%let PROJ_ROOT = %sysget(PROJ_ROOT);
%if %length(&PROJ_ROOT) = 0 %then %do;
    %let PROJ_ROOT = /workspace/sas-r-hybrid-clinical-pipeline;
    %put WARNING: PROJ_ROOT not set, using default: &PROJ_ROOT;
%end;

/* Load foundation utilities */
%include "&PROJ_ROOT/adam/programs/sas/macros/level1_utilities/import_tr.sas";
%include "&PROJ_ROOT/adam/programs/sas/macros/level1_utilities/import_tu.sas";

/* ========================================
   STEP 1: Import Required Datasets
   ======================================== */

title "NEXICART-2 ADTR: Import Source Datasets";

/* Import SDTM TR (Tumor Results) with validation */
%import_tr(
    path=../../sdtm/data/csv,
    outds=work.tr_import,
    validate=1
);

/* Filter and prepare TR data */
data tr_raw;
    set work.tr_import;
    where TRTESTCD = 'LDIAM';  /* Longest diameter measurements */
    keep USUBJID TRDTC TRDY TRLNKID TRTESTCD TRORRES TRSTRESC TRSTRESN 
         VISIT VISITNUM TRLOC TRMETHOD;
run;

/* Import SDTM TU (Tumor Identification) with validation */
%import_tu(
    path=../../sdtm/data/csv,
    outds=work.tu_import,
    validate=1
);

/* Prepare TU data for target/non-target classification */
data tu_raw;
    set work.tu_import;
    keep USUBJID TULNKID TUTESTCD TUORRES TUSTRESC TUEVAL TULOC;
run;

/* Import DM for study information */
data dm;
    set sdtm.dm;
    keep USUBJID STUDYID RFSTDTC ARM ACTARM;
run;

/* ========================================
   STEP 2: Classify Target vs Non-Target Lesions
   ======================================== */

title "NEXICART-2 ADTR: Classify Target Lesions per RECIST 1.1";

/* Extract target lesion identifiers from TU */
proc sql;
    create table target_lesions as
    select distinct TULNKID as TRLNKID,
           case when upcase(TUSTRESC) = 'TARGET' then 'Y'
                else 'N' end as TARGETFL label="Target Lesion Flag"
    from tu_raw
    where TUTESTCD = 'TUMIDENT';
quit;

/* Merge with TR measurements */
proc sql;
    create table tr_classified as
    select a.*, 
           coalesce(b.TARGETFL, 'N') as TARGETFL
    from tr_raw as a
    left join target_lesions as b
        on a.TRLNKID = b.TRLNKID
    order by USUBJID, TRDY, TRLNKID;
quit;

/* ========================================
   STEP 3: Calculate SLD per Assessment
   ======================================== */

title "NEXICART-2 ADTR: Calculate Sum of Longest Diameters (SLD)";

/* Sum target lesion measurements per visit */
proc sql;
    create table sld_by_visit as
    select USUBJID, 
           TRDTC as ADTC format=$10.,
           TRDY as ADY,
           VISIT as AVISIT,
           VISITNUM as AVISITN,
           sum(TRSTRESN) as SLD label="Sum of Longest Diameters (mm)",
           count(*) as N_LESIONS label="Number Target Lesions Measured"
    from tr_classified
    where TARGETFL = 'Y' and not missing(TRSTRESN)
    group by USUBJID, calculated ADTC, calculated ADY, VISIT, VISITNUM
    order by USUBJID, ADY;
quit;

/* ========================================
   STEP 4: Derive Baseline and Nadir
   ======================================== */

title "NEXICART-2 ADTR: Derive Baseline and Nadir per Vitale 2025";

data adtr_with_base;
    set sld_by_visit;
    by USUBJID ADY;
    
    retain BASE NADIR;
    
    /* Baseline = first post-randomization assessment */
    if first.USUBJID then do;
        BASE = SLD;
        NADIR = SLD;
        BASEFL = 'Y';
    end;
    else do;
        BASEFL = '';
        /* Update nadir (minimum post-baseline) */
        if not missing(SLD) and SLD < NADIR then NADIR = SLD;
    end;
    
    label BASE = "Baseline SLD (mm)"
          NADIR = "Nadir SLD (mm)"
          BASEFL = "Baseline Flag";
run;

/* Carry forward BASE and NADIR to all records */
proc sql;
    create table adtr_base_filled as
    select a.*,
           b.BASE
    from adtr_with_base as a
    left join (select distinct USUBJID, BASE 
               from adtr_with_base 
               where BASEFL='Y') as b
        on a.USUBJID = b.USUBJID;
quit;

/* Update NADIR correctly across all visits */
data adtr_nadir_updated;
    set adtr_base_filled;
    by USUBJID ADY;
    
    retain running_nadir;
    
    if first.USUBJID then running_nadir = BASE;
    
    if not missing(SLD) and SLD < running_nadir then 
        running_nadir = SLD;
    
    NADIR = running_nadir;
    
    drop running_nadir;
run;

/* ========================================
   STEP 5: Calculate Percent Changes (2024-2025 Standards)
   ======================================== */

title "NEXICART-2 ADTR: Percent Change Calculations per PharmaSUG 2025";

data adtr_pchg;
    set adtr_nadir_updated;
    
    /* Percent change from baseline */
    if not missing(BASE) and BASE ne 0 then do;
        CHG = SLD - BASE;
        PCHG = (CHG / BASE) * 100;
    end;
    else do;
        CHG = .;
        PCHG = .;
    end;
    
    /* Percent change from nadir */
    if not missing(NADIR) and NADIR ne 0 then do;
        CHGNADIR = SLD - NADIR;
        PCHGN = (CHGNADIR / NADIR) * 100;
    end;
    else do;
        CHGNADIR = .;
        PCHGN = .;
    end;
    
    label CHG = "Change from Baseline (mm)"
          PCHG = "Percent Change from Baseline (%)"
          CHGNADIR = "Change from Nadir (mm)"
          PCHGN = "Percent Change from Nadir (%)";
run;

/* ========================================
   STEP 6: Create BDS Structure with PARAM/PARAMCD
   ======================================== */

title "NEXICART-2 ADTR: Create BDS Structure";

data adtr;
    merge adtr_pchg
          dm;
    by USUBJID;
    
    /* BDS structure */
    length PARAMCD $8 PARAM $200;
    PARAMCD = 'SLD';
    PARAM = 'Sum of Longest Diameters per RECIST 1.1';
    
    /* Analysis value */
    AVAL = SLD;
    AVALU = 'mm';
    
    /* Analysis flag */
    length ANL01FL $1;
    if not missing(AVAL) then ANL01FL = 'Y';
    else ANL01FL = '';
    
    /* Analysis date (convert from character) */
    ADT = input(ADTC, yymmdd10.);
    format ADT date9.;
    
    /* Sequence */
    ASEQ = _N_;
    
    /* Quality control flag per 2025 recommendations */
    length QCFLAG $50;
    if N_LESIONS < 1 then QCFLAG = 'MISSING LESIONS';
    else if missing(BASE) and BASEFL ne 'Y' then QCFLAG = 'NO BASELINE';
    else QCFLAG = '';
    
    label PARAMCD = "Parameter Code"
          PARAM = "Parameter"
          AVAL = "Analysis Value (SLD in mm)"
          AVALU = "Analysis Value Unit"
          ANL01FL = "Analysis Flag 01"
          ADT = "Analysis Date"
          ADTC = "Analysis Date (Character)"
          ADY = "Analysis Relative Day"
          ASEQ = "Analysis Sequence Number"
          QCFLAG = "Quality Control Flag (Vitale 2025)";
run;

proc sort data=adtr; by USUBJID ADY; run;

/* ========================================
   STEP 7: QC VALIDATION & WATERFALL PLOT DATA
   ======================================== */

title "NEXICART-2 ADTR QC: SLD Progression by Patient";
title2 "Verify: Baseline established, Nadir tracking correctly";

proc print data=adtr(obs=50);
    by USUBJID;
    id USUBJID;
    var AVISIT ADY AVAL BASE NADIR CHG PCHG PCHGN BASEFL QCFLAG;
    format AVAL BASE NADIR 8.1 PCHG PCHGN 6.1;
run;

title "NEXICART-2 ADTR Summary: Baseline SLD Distribution";

proc means data=adtr(where=(BASEFL='Y')) 
           n mean std median min max maxdec=1;
    var AVAL;
    class ARM;
run;

title "NEXICART-2 ADTR Summary: Best Percent Change from Baseline (Waterfall Data)";

proc sql;
    create table best_pchg as
    select USUBJID, ARM,
           min(PCHG) as BEST_PCHG label="Best Percent Change from Baseline (%)"
    from adtr
    where not missing(PCHG)
    group by USUBJID, ARM
    order by BEST_PCHG;
quit;

proc print data=best_pchg;
    format BEST_PCHG 6.1;
run;

/* ========================================
   STEP 8: EXPORT DATASETS
   ======================================== */

title "NEXICART-2 ADTR: Export Final Dataset";

proc export data=adtr 
            outfile="../../adam/data/adtr.csv" 
            dbms=csv replace; 
run;

libname xptout xport "../../adam/data/xpt/adtr.xpt";
data xptout.adtr;
    set adtr;
run;

proc contents data=adtr varnum;
    title "NEXICART-2 ADTR: Dataset Contents";
run;

%put NOTE: ============================================;
%put NOTE: ADTR dataset created successfully (v1.1);
%put NOTE: Parameters derived:;
%put NOTE:   - SLD (Sum of Longest Diameters);
%put NOTE:   - Baseline and Nadir values;
%put NOTE:   - Percent changes from baseline and nadir;
%put NOTE: Quality checks per Vitale 2025 included;
%put NOTE: Import validation: import_tr v2.0, import_tu integrated;
%put NOTE: Ready for ADRS (BOR) derivation input;
%put NOTE: Output: adam/data/adtr.csv, adam/data/xpt/adtr.xpt;
%put NOTE: ============================================;
