/******************************************************************************
* Program: 70_cart_safety_summary.sas
* Purpose: Generate CAR-T safety summary tables for BLA submission
* Author:  Christian Baghai
* Date:    2025-12-29
* Input:   data/csv/ae.csv, data/csv/suppae.csv, data/csv/dm.csv
* Output:  Safety summary tables in HTML and RTF format
*
* Purpose: Creates integrated safety tables required for FDA CAR-T BLA
******************************************************************************/

%let STUDYID = CAR-T-DEMO-001;

libname sdtm "../../data/csv";

proc printto log="../../logs/70_cart_safety_summary.log" new;
run;

%put NOTE: ============================================================;
%put NOTE: Starting CAR-T Safety Summary Table Generation;
%put NOTE: Study: &STUDYID;
%put NOTE: ============================================================;

/******************************************************************************
* TABLE 1: CAR-T SPECIFIC TOXICITY SUMMARY
******************************************************************************/

title "Table 1: CAR-T Specific Toxicity Summary";

proc sql;
    create table cart_tox_summary as
    select 
        AESCAT as toxicity_type,
        count(distinct USUBJID) as n_patients,
        count(*) as n_events,
        sum(case when AESEV = 'SEVERE' then 1 else 0 end) as n_severe,
        calculated n_patients / (select count(distinct USUBJID) from sdtm.dm) * 100 
            as pct_patients format=5.1
    from sdtm.ae
    where AECAT = 'CAR-T TOXICITY'
    group by AESCAT
    order by n_patients desc;
    
    select * from cart_tox_summary;
quit;

title;

/******************************************************************************
* TABLE 2: CRS GRADING DISTRIBUTION
******************************************************************************/

title "Table 2: CRS ASTCT Grade Distribution";

proc sql;
    create table crs_grade_dist as
    select 
        s.QVAL as crs_grade,
        count(distinct s.USUBJID) as n_patients,
        calculated n_patients / (select count(distinct USUBJID) 
            from sdtm.ae where AESCAT = 'CRS') * 100 
            as pct format=5.1
    from sdtm.suppae s
    where s.QNAM = 'CRSASTCT'
    group by s.QVAL
    order by input(s.QVAL, best.);
    
    select * from crs_grade_dist;
quit;

title;

/******************************************************************************
* TABLE 3: ICANS GRADING DISTRIBUTION
******************************************************************************/

title "Table 3: ICANS ASTCT Grade Distribution";

proc sql;
    create table icans_grade_dist as
    select 
        s.QVAL as icans_grade,
        count(distinct s.USUBJID) as n_patients,
        calculated n_patients / (select count(distinct USUBJID) 
            from sdtm.ae where AESCAT = 'ICANS') * 100 
            as pct format=5.1
    from sdtm.suppae s
    where s.QNAM = 'ICANSAST'
    group by s.QVAL
    order by input(s.QVAL, best.);
    
    select * from icans_grade_dist;
quit;

title;

/******************************************************************************
* TABLE 4: INFECTION SUMMARY BY TIMING
******************************************************************************/

title "Table 4: Infection Summary by Timing Post-Infusion";

proc sql;
    create table infection_summary as
    select 
        AESCAT as timing_category,
        count(distinct USUBJID) as n_patients,
        count(*) as n_events,
        sum(case when AESEV = 'SEVERE' or AESER = 'Y' then 1 else 0 end) 
            as n_severe,
        calculated n_patients / (select count(distinct USUBJID) from sdtm.dm) * 100 
            as pct_patients format=5.1
    from sdtm.ae
    where AECAT = 'INFECTION'
    group by AESCAT
    order by n_patients desc;
    
    select * from infection_summary;
quit;

title;

/******************************************************************************
* TABLE 5: PROLONGED CYTOPENIA SUMMARY
******************************************************************************/

title "Table 5: Prolonged Cytopenia Summary (>30 Days)";

proc sql;
    create table cytopenia_summary as
    select 
        AESCAT as duration_category,
        count(distinct USUBJID) as n_patients,
        calculated n_patients / (select count(distinct USUBJID) from sdtm.dm) * 100 
            as pct_patients format=5.1
    from sdtm.ae
    where AECAT = 'HEMATOLOGIC'
      and (index(AESCAT, 'PROLONGED') > 0 or index(AESCAT, 'CHRONIC') > 0)
    group by AESCAT;
    
    select * from cytopenia_summary;
quit;

title;

/******************************************************************************
* TABLE 6: OVERALL SAFETY SUMMARY
******************************************************************************/

title "Table 6: Overall Safety Summary";

proc sql;
    create table overall_safety as
    select 
        'Any AE' as category,
        count(distinct USUBJID) as n_patients,
        calculated n_patients / (select count(distinct USUBJID) from sdtm.dm) * 100 
            as pct_patients format=5.1
    from sdtm.ae
    
    union all
    
    select 
        'Any Serious AE' as category,
        count(distinct USUBJID) as n_patients,
        calculated n_patients / (select count(distinct USUBJID) from sdtm.dm) * 100 
            as pct_patients format=5.1
    from sdtm.ae
    where AESER = 'Y'
    
    union all
    
    select 
        'Any CAR-T Specific Toxicity' as category,
        count(distinct USUBJID) as n_patients,
        calculated n_patients / (select count(distinct USUBJID) from sdtm.dm) * 100 
            as pct_patients format=5.1
    from sdtm.ae
    where AECAT = 'CAR-T TOXICITY'
    
    union all
    
    select 
        'Deaths' as category,
        count(distinct USUBJID) as n_patients,
        calculated n_patients / (select count(distinct USUBJID) from sdtm.dm) * 100 
            as pct_patients format=5.1
    from sdtm.ae
    where AESDTH = 'Y';
    
    select * from overall_safety;
quit;

title;

%put NOTE: ============================================================;
%put NOTE: CAR-T SAFETY SUMMARY TABLES COMPLETED;
%put NOTE: Tables generated:;
%put NOTE:   1. CAR-T Specific Toxicity Summary;
%put NOTE:   2. CRS ASTCT Grade Distribution;
%put NOTE:   3. ICANS ASTCT Grade Distribution;
%put NOTE:   4. Infection Summary by Timing;
%put NOTE:   5. Prolonged Cytopenia Summary;
%put NOTE:   6. Overall Safety Summary;
%put NOTE: ============================================================;

proc printto;
run;
