/****************************************************************************
MACRO: derive_crs_grade
PURPOSE: Derive Cytokine Release Syndrome (CRS) grade per ASTCT 2019

CRS GRADING (Lee et al. 2019):
Grade 1: Fever ≥38°C only
Grade 2: Fever + hypotension (not requiring vasopressors) OR low-flow O2
Grade 3: Fever + vasopressors OR high-flow O2/ventilator
Grade 4: Life-threatening (multiple vasopressors + ventilator)

INPUTS:
- AE domain: CRS adverse event records (AETERM = "CYTOKINE RELEASE SYNDROME")
- VS domain: Temperature measurements (VSTESTCD = "TEMP")
- CM domain: Vasopressor/oxygen support (CMCAT = "VASOPRESSOR", "OXYGEN THERAPY")

OUTPUT:
- Dataset with CRS_GRADE_DERIVED, CRS_ONSET, CRS_DURATION
- Concordance check: CRS_GRADE_DERIVED vs CRS_GRADE_REPORTED (from AETOXGR)
*****************************************************************************/

%macro derive_crs_grade(
    ae_ds=,
    vs_ds=,
    cm_ds=,
    outds=,
    usubjid=USUBJID
);

/* STEP 1: Identify CRS events from AE domain */
data work._crs_events;
    set &ae_ds;
    where upcase(AETERM) in ('CYTOKINE RELEASE SYNDROME', 'CRS');
    CRS_ONSET = input(AESTDTC, yymmdd10.);
    CRS_END = input(AEENDTC, yymmdd10.);
    CRS_GRADE_REPORTED = input(AETOXGR, best.);
    format CRS_ONSET CRS_END yymmdd10.;
    keep &usubjid CRS_ONSET CRS_END CRS_GRADE_REPORTED AESEQ;
run;

/* STEP 2: Get fever measurements from VS domain */
proc sql;
    create table work._fever_data as
    select 
        &usubjid,
        input(VSDTC, yymmdd10.) as FEVER_DTC format=yymmdd10.,
        input(VSSTRESC, best.) as TEMP_VALUE,
        case when input(VSSTRESC, best.) >= 38 then 1 else 0 end as FEVER_FLAG
    from &vs_ds
    where upcase(VSTESTCD) = 'TEMP';
quit;

/* STEP 3: Categorize supportive care from CM domain */
data work._supportive_care;
    set &cm_ds;
    where upcase(CMCAT) in ('VASOPRESSOR', 'OXYGEN THERAPY', 'VENTILATOR SUPPORT');
    
    SUPPORT_START = input(CMSTDTC, yymmdd10.);
    format SUPPORT_START yymmdd10.;
    
    /* Categorize support level per ASTCT criteria */
    length SUPPORT_TYPE $20;
    if upcase(CMTRT) in ('NOREPINEPHRINE', 'DOPAMINE', 'EPINEPHRINE', 'VASOPRESSIN') then 
        SUPPORT_TYPE = 'VASOPRESSOR';
    else if index(upcase(CMTRT), 'NASAL CANNULA') > 0 or index(upcase(CMTRT), 'LOW FLOW') > 0 then
        SUPPORT_TYPE = 'LOW_O2';
    else if index(upcase(CMTRT), 'HIGH FLOW') > 0 or index(upcase(CMTRT), 'NON-INVASIVE') > 0 then
        SUPPORT_TYPE = 'HIGH_O2';
    else if index(upcase(CMTRT), 'INTUBAT') > 0 or index(upcase(CMTRT), 'VENTILATOR') > 0 then
        SUPPORT_TYPE = 'VENTILATOR';
    else if index(upcase(CMTRT), 'OXYGEN') > 0 then
        SUPPORT_TYPE = 'LOW_O2';  /* Default for unspecified oxygen */
    
    keep &usubjid SUPPORT_START SUPPORT_TYPE CMTRT;
run;

/* STEP 4: Derive CRS grade algorithmically */
proc sql;
    create table &outds as
    select 
        a.*,
        max(b.FEVER_FLAG) as MAX_FEVER,
        max(case when c.SUPPORT_TYPE = 'VASOPRESSOR' then 1 else 0 end) as VASOPRESSOR_FLAG,
        max(case when c.SUPPORT_TYPE = 'LOW_O2' then 1 else 0 end) as LOW_O2_FLAG,
        max(case when c.SUPPORT_TYPE = 'HIGH_O2' then 1 else 0 end) as HIGH_O2_FLAG,
        max(case when c.SUPPORT_TYPE = 'VENTILATOR' then 1 else 0 end) as VENTILATOR_FLAG,
        count(distinct case when c.SUPPORT_TYPE = 'VASOPRESSOR' then c.CMTRT end) as N_VASOPRESSORS
    from work._crs_events a
    left join work._fever_data b
        on a.&usubjid = b.&usubjid and 
           b.FEVER_DTC between a.CRS_ONSET and coalesce(a.CRS_END, b.FEVER_DTC)
    left join work._supportive_care c
        on a.&usubjid = c.&usubjid and
           c.SUPPORT_START between a.CRS_ONSET and coalesce(a.CRS_END, c.SUPPORT_START)
    group by a.&usubjid, a.CRS_ONSET, a.CRS_END, a.CRS_GRADE_REPORTED, a.AESEQ;
quit;

data &outds;
    set &outds;
    length CRS_GRADE_DERIVED $10 CRS_LOGIC $200;
    
    /* Grade 4: Ventilator + multiple vasopressors */
    if VENTILATOR_FLAG = 1 and N_VASOPRESSORS >= 2 then do;
        CRS_GRADE_DERIVED = '4';
        CRS_LOGIC = 'Grade 4: Ventilator + multiple vasopressors (life-threatening)';
    end;
    
    /* Grade 3: Vasopressor(s) OR high-flow O2 */
    else if VASOPRESSOR_FLAG = 1 or HIGH_O2_FLAG = 1 or VENTILATOR_FLAG = 1 then do;
        CRS_GRADE_DERIVED = '3';
        CRS_LOGIC = cats('Grade 3: ', 
                         ifc(VASOPRESSOR_FLAG=1, 'Vasopressor(s)', ''),
                         ifc(HIGH_O2_FLAG=1, ' High-flow O2', ''),
                         ifc(VENTILATOR_FLAG=1, ' Ventilator', ''));
    end;
    
    /* Grade 2: Low-flow oxygen */
    else if MAX_FEVER = 1 and LOW_O2_FLAG = 1 then do;
        CRS_GRADE_DERIVED = '2';
        CRS_LOGIC = 'Grade 2: Fever + low-flow oxygen';
    end;
    
    /* Grade 1: Fever only */
    else if MAX_FEVER = 1 then do;
        CRS_GRADE_DERIVED = '1';
        CRS_LOGIC = 'Grade 1: Fever ≥38°C without organ dysfunction';
    end;
    
    /* No CRS */
    else do;
        CRS_GRADE_DERIVED = '0';
        CRS_LOGIC = 'No CRS criteria met';
    end;
    
    /* Concordance check */
    CRS_GRADE_CONCORDANCE = (input(CRS_GRADE_DERIVED, best.) = CRS_GRADE_REPORTED);
    
    /* Duration calculation */
    if not missing(CRS_END) then do;
        CRS_DURATION_DAYS = CRS_END - CRS_ONSET + 1;
    end;
    
    label 
        CRS_GRADE_DERIVED = 'Algorithmically Derived CRS Grade (ASTCT 2019)'
        CRS_GRADE_REPORTED = 'Investigator-Reported CRS Grade'
        CRS_GRADE_CONCORDANCE = 'Grade Concordance (1=Match, 0=Discrepancy)'
        CRS_LOGIC = 'CRS Grading Logic'
        CRS_DURATION_DAYS = 'CRS Duration (Days)'
        N_VASOPRESSORS = 'Number of Vasopressors Used';
run;

/* Report concordance */
proc freq data=&outds;
    tables CRS_GRADE_DERIVED * CRS_GRADE_REPORTED / missing nocol nopercent;
    title "CRS Grade Concordance: Derived vs Reported";
run;
title;

/* Clean up */
proc datasets library=work nolist;
    delete _crs_events _fever_data _supportive_care;
quit;

%mend derive_crs_grade;
