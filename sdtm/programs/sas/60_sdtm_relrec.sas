/******************************************************************************
* Program: 60_sdtm_relrec.sas
* Purpose: Generate SDTM RELREC domain for AE-to-CM relationships
* Author:  Christian Baghai
* Date:    2025-12-29
* Input:   data/csv/ae.csv, data/csv/cm.csv
* Output:  data/csv/relrec.csv, data/xpt/relrec.xpt
*
* Purpose: Links adverse events to their treatments in CM domain
*          Required for FDA traceability of CAR-T toxicity management
******************************************************************************/

%let STUDYID = CAR-T-DEMO-001;

libname sdtm "../../data/csv";

proc printto log="../../logs/60_sdtm_relrec.log" new;
run;

%put NOTE: ============================================================;
%put NOTE: Starting RELREC domain generation;
%put NOTE: Study: &STUDYID;
%put NOTE: ============================================================;

/******************************************************************************
* STEP 1: READ AE BASE DATA WITH LINKAGE INFORMATION
******************************************************************************/

data ae_cm_links;
    set sdtm.ae_base;
    where not missing(PRIMARY_TREATMENT_FOR_AE);
    
    keep USUBJID AESEQ PRIMARY_TREATMENT_FOR_AE;
run;

%put NOTE: Read AE linkage data;

/******************************************************************************
* STEP 2: CREATE RELREC FOR AE-TO-CM RELATIONSHIPS
******************************************************************************/

data relrec;
    set ae_cm_links;
    
    length STUDYID $20 RDOMAIN $2 USUBJID $40;
    length IDVAR $8 IDVARVAL $200;
    length RELTYPE $8 RELID $200;
    
    STUDYID = "&STUDYID";
    RDOMAIN = "AE";
    USUBJID = USUBJID;
    IDVAR = "AESEQ";
    IDVARVAL = strip(put(AESEQ, best.));
    RELTYPE = "TREATFOR";  /* Treatment given FOR this AE */
    RELID = "CM.CMSEQ=" || strip(put(PRIMARY_TREATMENT_FOR_AE, best.));
    
    keep STUDYID RDOMAIN USUBJID IDVAR IDVARVAL RELTYPE RELID;
run;

proc sql noprint;
    select count(*) into :relrec_count trimmed from relrec;
quit;

%put NOTE: RELREC domain created with &relrec_count records;

/******************************************************************************
* STEP 3: SORT AND EXPORT
******************************************************************************/

proc sort data=relrec;
    by USUBJID RELID;
run;

/* Export to CSV */
proc export data=relrec
    outfile="../../data/csv/relrec.csv"
    dbms=csv
    replace;
run;

/* Export to XPT */
libname xptout xport "../../data/xpt/relrec.xpt";
data xptout.relrec;
    set relrec;
run;
libname xptout clear;

%put NOTE: ============================================================;
%put NOTE: RELREC DOMAIN GENERATION COMPLETED;
%put NOTE: Total RELREC records: &relrec_count;
%put NOTE: Files created:;
%put NOTE:   - data/csv/relrec.csv;
%put NOTE:   - data/xpt/relrec.xpt;
%put NOTE: ============================================================;

proc printto;
run;
