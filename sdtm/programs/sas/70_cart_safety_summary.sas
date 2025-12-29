/******************************************************************************
* Program: 70_cart_safety_summary.sas
* Purpose: Generate comprehensive CAR-T safety summary tables for BLA
* Author:  Christian Baghai
* Date:    2025-12-29
* Input:   All SDTM domains (AE, SUPPAE, CE, RELREC, DM)
* Output:  output/cart_safety_summary.rtf
* 
* Priority: HIGHEST - Required for ISS (Integrated Summary of Safety)
* Standards: ASTCT 2019 consensus, FDA BLA safety reporting guidelines
******************************************************************************/

%let STUDYID = CAR-T-DEMO-001;

libname sdtm "../../data/csv";

ods rtf file="../../output/cart_safety_summary.rtf" style=journal;

title1 "CAR-T Safety Summary Tables";
title2 "Study: &STUDYID";
title3 "Generated: %sysfunc(date(), worddate.)";

/******************************************************************************
* TABLE 1: Overall CAR-T Toxicity Incidence
******************************************************************************/
title4 "Table 1: Incidence of CAR-T Specific Toxicities";

proc sql;
    create table tbl1_cart_tox as
    select 
        AESCAT as Toxicity_Type,
        count(distinct USUBJID) as N_Patients,
        calculated N_Patients / (select count(distinct USUBJID) from sdtm.dm where ACTARM like '%CAR%T%') * 100 
            as Pct_Patients format=5.1,
        count(*) as Total_Events,
        sum(case when AESER='Y' then 1 else 0 end) as Serious_Events,
        sum(case when AESEV='SEVERE' then 1 else 0 end) as Grade_3_4_Events,
        sum(case when AEOUT='FATAL' then 1 else 0 end) as Fatal_Events
    from sdtm.ae
    where AECAT = 'CAR-T TOXICITY'
    group by AESCAT
    order by N_Patients desc;
quit;

proc print data=tbl1_cart_tox noobs label;
    var Toxicity_Type N_Patients Pct_Patients Total_Events 
        Serious_Events Grade_3_4_Events Fatal_Events;
    label Toxicity_Type = "CAR-T Toxicity Type"
          N_Patients = "N Patients"
          Pct_Patients = "% Patients"
          Total_Events = "Total Events"
          Serious_Events = "Serious Events"
          Grade_3_4_Events = "Grade ≥3"
          Fatal_Events = "Fatal";
run;

/******************************************************************************
* TABLE 2: CRS Grading Distribution per ASTCT Consensus
******************************************************************************/
title4 "Table 2: CRS ASTCT Grade Distribution";

proc sql;
    create table tbl2_crs_grade as
    select 
        s.QVAL as CRS_Grade,
        count(distinct s.USUBJID) as N_Patients,
        calculated N_Patients / (select count(distinct USUBJID) from sdtm.ae where AESCAT='CRS') * 100 
            as Pct_Of_CRS format=5.1,
        round(mean(ae.AESTDY), 0.1) as Mean_Onset_Day format=5.1,
        round(mean(ae.AEDUR), 0.1) as Mean_Duration_Days format=5.1,
        sum(case when toci.QVAL='Y' then 1 else 0 end) as N_Toci_Treated,
        sum(case when ster.QVAL='Y' then 1 else 0 end) as N_Steroid_Treated
    from sdtm.suppae as s
    inner join sdtm.ae as ae
        on s.USUBJID = ae.USUBJID
        and s.IDVARVAL = put(ae.AESEQ, best.)
    left join (select * from sdtm.suppae where QNAM='CRSTOCI') as toci
        on s.USUBJID = toci.USUBJID
        and s.IDVARVAL = toci.IDVARVAL
    left join (select * from sdtm.suppae where QNAM='CRSSTER') as ster
        on s.USUBJID = ster.USUBJID
        and s.IDVARVAL = ster.IDVARVAL
    where s.QNAM = 'CRSASTCT'
    group by s.QVAL
    order by input(s.QVAL, best.);
quit;

proc print data=tbl2_crs_grade noobs label;
    var CRS_Grade N_Patients Pct_Of_CRS Mean_Onset_Day Mean_Duration_Days 
        N_Toci_Treated N_Steroid_Treated;
    label CRS_Grade = "ASTCT Grade"
          N_Patients = "N Patients"
          Pct_Of_CRS = "% of CRS"
          Mean_Onset_Day = "Mean Onset (Days Post-Infusion)"
          Mean_Duration_Days = "Mean Duration (Days)"
          N_Toci_Treated = "Tocilizumab Given"
          N_Steroid_Treated = "Steroids Given";
run;

/******************************************************************************
* TABLE 3: ICANS Grading Distribution with ICE Scores
******************************************************************************/
title4 "Table 3: ICANS ASTCT Grade Distribution with ICE Scores";

proc sql;
    create table tbl3_icans_grade as
    select 
        grade.QVAL as ICANS_Grade,
        count(distinct grade.USUBJID) as N_Patients,
        calculated N_Patients / (select count(distinct USUBJID) from sdtm.ae where AESCAT='ICANS') * 100 
            as Pct_Of_ICANS format=5.1,
        round(mean(input(ice.QVAL, best.)), 0.1) as Mean_ICE_Score format=5.1,
        round(std(input(ice.QVAL, best.)), 0.1) as SD_ICE_Score format=5.1,
        min(input(ice.QVAL, best.)) as Min_ICE,
        max(input(ice.QVAL, best.)) as Max_ICE,
        sum(case when seiz.QVAL='Y' then 1 else 0 end) as N_With_Seizures
    from (select * from sdtm.suppae where QNAM='ICANSAST') as grade
    left join (select * from sdtm.suppae where QNAM='ICESCORE') as ice
        on grade.USUBJID = ice.USUBJID
        and grade.IDVARVAL = ice.IDVARVAL
    left join (select * from sdtm.suppae where QNAM='ICANSSEIZ') as seiz
        on grade.USUBJID = seiz.USUBJID
        and grade.IDVARVAL = seiz.IDVARVAL
    group by grade.QVAL
    order by input(grade.QVAL, best.);
quit;

proc print data=tbl3_icans_grade noobs label;
    var ICANS_Grade N_Patients Pct_Of_ICANS Mean_ICE_Score SD_ICE_Score
        Min_ICE Max_ICE N_With_Seizures;
    label ICANS_Grade = "ASTCT Grade"
          N_Patients = "N Patients"
          Pct_Of_ICANS = "% of ICANS"
          Mean_ICE_Score = "Mean ICE Score"
          SD_ICE_Score = "SD ICE Score"
          Min_ICE = "Min ICE"
          Max_ICE = "Max ICE"
          N_With_Seizures = "Seizures";
run;

/******************************************************************************
* TABLE 4: Infection Summary by Timing and Pathogen
******************************************************************************/
title4 "Table 4: Infection Characteristics";

proc sql;
    create table tbl4_infections as
    select 
        AESCAT as Timing_Category,
        count(distinct USUBJID) as N_Patients,
        count(*) as Total_Infections,
        sum(case when AESER='Y' then 1 else 0 end) as Serious_Infections,
        sum(case when AEOUT='FATAL' then 1 else 0 end) as Fatal_Infections,
        sum(case when path.QVAL is not null and path.QVAL ne '' then 1 else 0 end) as N_With_Pathogen,
        calculated N_With_Pathogen / calculated Total_Infections * 100 as Pct_Pathogen_ID format=5.1
    from sdtm.ae as ae
    left join (select * from sdtm.suppae where QNAM='PATHOGEN') as path
        on ae.USUBJID = path.USUBJID
        and put(ae.AESEQ, best.) = path.IDVARVAL
    where ae.AECAT = 'INFECTION'
    group by ae.AESCAT
    order by N_Patients desc;
quit;

proc print data=tbl4_infections noobs label;
    var Timing_Category N_Patients Total_Infections Serious_Infections 
        Fatal_Infections N_With_Pathogen Pct_Pathogen_ID;
    label Timing_Category = "Infection Timing"
          N_Patients = "N Patients"
          Total_Infections = "Total Infections"
          Serious_Infections = "Serious"
          Fatal_Infections = "Fatal"
          N_With_Pathogen = "Pathogen Identified"
          Pct_Pathogen_ID = "% ID Rate";
run;

/******************************************************************************
* TABLE 5: Prolonged Cytopenias (>30 days)
******************************************************************************/
title4 "Table 5: Prolonged and Chronic Cytopenias";

proc sql;
    create table tbl5_cytopenias as
    select 
        case 
            when index(AEDECOD, 'NEUTROPENIA') > 0 then 'Neutropenia'
            when index(AEDECOD, 'THROMBOCYTOPENIA') > 0 then 'Thrombocytopenia'
            when index(AEDECOD, 'ANEMIA') > 0 then 'Anemia'
            when index(AEDECOD, 'PANCYTOPENIA') > 0 then 'Pancytopenia'
            else 'Other'
        end as Cytopenia_Type,
        AESCAT as Duration_Category,
        count(distinct USUBJID) as N_Patients,
        round(mean(AEDUR), 1) as Mean_Duration_Days format=6.1,
        round(median(AEDUR), 1) as Median_Duration_Days format=6.1,
        min(AEDUR) as Min_Duration,
        max(AEDUR) as Max_Duration,
        sum(case when gcsf.QVAL='Y' then 1 else 0 end) as N_GCSF_Given
    from sdtm.ae as ae
    left join (select * from sdtm.suppae where QNAM='CYTOPGF') as gcsf
        on ae.USUBJID = gcsf.USUBJID
        and put(ae.AESEQ, best.) = gcsf.IDVARVAL
    where ae.AECAT = 'HEMATOLOGIC'
      and (index(ae.AESCAT, 'PROLONGED') > 0 or index(ae.AESCAT, 'CHRONIC') > 0)
    group by Cytopenia_Type, ae.AESCAT
    order by Cytopenia_Type, N_Patients desc;
quit;

proc print data=tbl5_cytopenias noobs label;
    var Cytopenia_Type Duration_Category N_Patients Mean_Duration_Days 
        Median_Duration_Days Min_Duration Max_Duration N_GCSF_Given;
    label Cytopenia_Type = "Type"
          Duration_Category = "Duration"
          N_Patients = "N"
          Mean_Duration_Days = "Mean (Days)"
          Median_Duration_Days = "Median (Days)"
          Min_Duration = "Min"
          Max_Duration = "Max"
          N_GCSF_Given = "G-CSF";
run;

/******************************************************************************
* TABLE 6: CRS Treatment Patterns via RELREC
******************************************************************************/
title4 "Table 6: CRS Treatment Patterns (via RELREC Linkage)";

proc sql;
    create table tbl6_crs_treatment as
    select 
        cm.CMTRT as Treatment,
        count(distinct rel.USUBJID) as N_Patients_Treated,
        calculated N_Patients_Treated / (select count(distinct USUBJID) from sdtm.ae where AESCAT='CRS') * 100 
            as Pct_Of_CRS_Patients format=5.1,
        round(mean(ae.AESTDY), 0.1) as Mean_AE_Day_Treated format=5.1
    from sdtm.relrec as rel
    inner join sdtm.ae as ae
        on rel.USUBJID = ae.USUBJID
        and rel.RDOMAIN = 'AE'
        and input(rel.IDVARVAL, best.) = ae.AESEQ
    inner join sdtm.cm as cm
        on rel.USUBJID = cm.USUBJID
        and input(scan(rel.RELID, 2, '='), best.) = cm.CMSEQ
    where ae.AESCAT = 'CRS'
      and rel.RELTYPE = 'TREATFOR'
    group by cm.CMTRT
    order by N_Patients_Treated desc;
quit;

proc print data=tbl6_crs_treatment noobs label;
    var Treatment N_Patients_Treated Pct_Of_CRS_Patients Mean_AE_Day_Treated;
    label Treatment = "CRS Treatment"
          N_Patients_Treated = "N Treated"
          Pct_Of_CRS_Patients = "% of CRS Pts"
          Mean_AE_Day_Treated = "Mean Day Tx Given";
run;

ods rtf close;

%put NOTE: ============================================================;
%put NOTE: CAR-T SAFETY SUMMARY TABLES COMPLETED;
%put NOTE: Output: ../../output/cart_safety_summary.rtf;
%put NOTE: ============================================================;
