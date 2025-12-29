/******************************************************************************
* Program: 60_sdtm_relrec.sas
* Purpose: Generate comprehensive SDTM RELREC domain for all relationships
* Author:  Christian Baghai
* Date:    2025-12-29
* Input:   Multiple SDTM domains (AE, CE, CM)
* Output:  data/csv/relrec.csv, data/xpt/relrec.xpt
* 
* Priority: HIGH - Required for traceability per FDA guidance
* Standards: SDTM IG v3.3
* Reference: RELREC describes relationships between records across domains
******************************************************************************/

%let STUDYID = CAR-T-DEMO-001;

libname sdtm "../../data/csv";

proc printto log="../../logs/60_sdtm_relrec.log" new;
run;

%put NOTE: ============================================================;
%put NOTE: Starting RELREC domain generation;
%put NOTE: ============================================================;

/******************************************************************************
* SECTION 1: CE to AE Relationships (CRS/ICANS symptoms to parent toxicity)
******************************************************************************/
%put NOTE: Creating CE-to-AE relationships;

data relrec_ce_ae;
    set sdtm.ce;
    where not missing(PARENT_AESEQ);
    
    length STUDYID $20 RDOMAIN $2 USUBJID $40;
    length IDVAR $8 IDVARVAL $200 RELTYPE $8 RELID $200;
    
    STUDYID = "&STUDYID";
    RDOMAIN = "CE";
    IDVAR = "CESEQ";
    IDVARVAL = strip(put(CESEQ, best.));
    RELTYPE = "COMPOF";  /* CE symptom is a component of the AE */
    RELID = "AE.AESEQ=" || strip(put(PARENT_AESEQ, best.));
    
    keep STUDYID RDOMAIN USUBJID IDVAR IDVARVAL RELTYPE RELID;
run;

/******************************************************************************
* SECTION 2: AE to CM Relationships (Treatments given FOR adverse events)
* Critical for CRS→Tocilizumab, Infection→Antibiotics linkage
******************************************************************************/
%put NOTE: Creating AE-to-CM relationships;

/* Identify CM records that treat specific AEs */
proc sql;
    create table ae_cm_links as
    select 
        ae.USUBJID,
        ae.AESEQ,
        cm.CMSEQ,
        ae.AESCAT,
        cm.CMTRT
    from sdtm.ae as ae
    inner join sdtm.cm as cm
        on ae.USUBJID = cm.USUBJID
        and cm.CMSTDTC >= ae.AESTDTC  /* CM started during or after AE */
        and (
            /* Tocilizumab for CRS */
            (ae.AESCAT = 'CRS' and (
                upcase(cm.CMTRT) like '%TOCILIZUMAB%' or
                upcase(cm.CMDECOD) like '%TOCILIZUMAB%'
            )) or
            
            /* Dexamethasone for CRS or ICANS */
            (ae.AESCAT in ('CRS', 'ICANS') and (
                upcase(cm.CMTRT) like '%DEXAMETHASONE%' or
                upcase(cm.CMTRT) like '%METHYLPREDNISOLONE%'
            )) or
            
            /* Antibiotics for infections */
            (ae.AECAT = 'INFECTION' and (
                upcase(cm.CMTRT) like '%ANTIBIOTIC%' or
                upcase(cm.CMTRT) like '%MEROPENEM%' or
                upcase(cm.CMTRT) like '%VANCOMYCIN%' or
                upcase(cm.CMTRT) like '%CEFTRIAXONE%' or
                upcase(cm.CMTRT) like '%PIPERACILLIN%'
            )) or
            
            /* Anti-seizure meds for ICANS with seizures */
            (ae.AESCAT = 'ICANS' and (
                upcase(cm.CMTRT) like '%LEVETIRACETAM%' or
                upcase(cm.CMTRT) like '%PHENYTOIN%' or
                upcase(cm.CMTRT) like '%LORAZEPAM%' or
                upcase(cm.CMTRT) like '%KEPPRA%'
            )) or
            
            /* G-CSF for cytopenias */
            (ae.AECAT = 'HEMATOLOGIC' and (
                upcase(cm.CMTRT) like '%FILGRASTIM%' or
                upcase(cm.CMTRT) like '%PEGFILGRASTIM%' or
                upcase(cm.CMTRT) like '%NEUPOGEN%' or
                upcase(cm.CMTRT) like '%NEULASTA%'
            ))
        );
quit;

/* Create RELREC records from AE perspective */
data relrec_ae_cm;
    set ae_cm_links;
    
    length STUDYID $20 RDOMAIN $2 USUBJID $40;
    length IDVAR $8 IDVARVAL $200 RELTYPE $8 RELID $200;
    
    STUDYID = "&STUDYID";
    RDOMAIN = "AE";
    IDVAR = "AESEQ";
    IDVARVAL = strip(put(AESEQ, best.));
    RELTYPE = "TREATFOR";  /* CM was treatment given FOR this AE */
    RELID = "CM.CMSEQ=" || strip(put(CMSEQ, best.));
    
    keep STUDYID RDOMAIN USUBJID IDVAR IDVARVAL RELTYPE RELID;
run;

/* Also create reciprocal RELREC from CM perspective */
data relrec_cm_ae;
    set ae_cm_links;
    
    length STUDYID $20 RDOMAIN $2 USUBJID $40;
    length IDVAR $8 IDVARVAL $200 RELTYPE $8 RELID $200;
    
    STUDYID = "&STUDYID";
    RDOMAIN = "CM";
    IDVAR = "CMSEQ";
    IDVARVAL = strip(put(CMSEQ, best.));
    RELTYPE = "TREATFOR";  /* This CM treats the linked AE */
    RELID = "AE.AESEQ=" || strip(put(AESEQ, best.));
    
    keep STUDYID RDOMAIN USUBJID IDVAR IDVARVAL RELTYPE RELID;
run;

/******************************************************************************
* SECTION 3: Combine All RELREC Records
******************************************************************************/
data relrec;
    set relrec_ce_ae
        relrec_ae_cm
        relrec_cm_ae;
run;

proc sort data=relrec nodupkey;
    by STUDYID RDOMAIN USUBJID IDVAR IDVARVAL RELTYPE RELID;
run;

proc sql noprint;
    select count(*) into :relrec_count trimmed from relrec;
quit;

%put NOTE: RELREC domain created with &relrec_count relationship records;

/******************************************************************************
* SECTION 4: VALIDATION AND SUMMARY REPORTS
******************************************************************************/

title "RELREC Summary by Relationship Type";
proc freq data=relrec;
    tables RDOMAIN*RELTYPE / missing nocol norow nopercent;
run;
title;

title "CRS Treatment Linkages (AE→CM)";
proc sql;
    select 
        rel.USUBJID,
        ae.AETERM,
        ae.AESCAT,
        cm.CMTRT as Treatment,
        cm.CMSTDTC as Treatment_Start
    from relrec as rel
    inner join sdtm.ae as ae
        on rel.USUBJID = ae.USUBJID
        and rel.RDOMAIN = 'AE'
        and input(rel.IDVARVAL, best.) = ae.AESEQ
    inner join sdtm.cm as cm
        on rel.USUBJID = cm.USUBJID
        and input(scan(rel.RELID, 2, '='), best.) = cm.CMSEQ
    where ae.AESCAT = 'CRS'
      and rel.RELTYPE = 'TREATFOR'
    order by rel.USUBJID, ae.AESEQ;
quit;
title;

title "Infection Treatment Linkages";
proc sql;
    select 
        rel.USUBJID,
        ae.AETERM,
        cm.CMTRT as Antibiotic,
        cm.CMSTDTC as Start_Date
    from relrec as rel
    inner join sdtm.ae as ae
        on rel.USUBJID = ae.USUBJID
        and rel.RDOMAIN = 'AE'
        and input(rel.IDVARVAL, best.) = ae.AESEQ
    inner join sdtm.cm as cm
        on rel.USUBJID = cm.USUBJID
        and input(scan(rel.RELID, 2, '='), best.) = cm.CMSEQ
    where ae.AECAT = 'INFECTION'
      and rel.RELTYPE = 'TREATFOR'
    order by rel.USUBJID, ae.AESEQ;
quit;
title;

/******************************************************************************
* SECTION 5: EXPORT TO CSV AND XPT
******************************************************************************/
proc export data=relrec
    outfile="../../data/csv/relrec.csv"
    dbms=csv
    replace;
run;

libname xptout xport "../../data/xpt/relrec.xpt";
data xptout.relrec;
    set relrec;
run;
libname xptout clear;

%put NOTE: ============================================================;
%put NOTE: RELREC DOMAIN GENERATION COMPLETED;
%put NOTE: Total relationship records: &relrec_count;
%put NOTE: Files created:
%put NOTE:   - ../../data/csv/relrec.csv;
%put NOTE:   - ../../data/xpt/relrec.xpt;
%put NOTE: ============================================================;

proc printto;
run;
