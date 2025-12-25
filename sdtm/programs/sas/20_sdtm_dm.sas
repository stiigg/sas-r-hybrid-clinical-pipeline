/******************************************************************************
 * Program: 20_sdtm_dm.sas
 * Purpose: Create SDTM DM domain from raw data using metadata-driven approach
 * Version: 2.0 (Production-grade with transformation engine)
 * 
 * Inputs:  - RAW.SUBJECTS_CLEAN
 *          - sdtm/specs/sdtm_dm_spec_v2.csv
 *
 * Outputs: - SDTM.DM
 *          - WORK.DM_QC_REPORT (quality control metrics)
 *
 * Notes:   Implements transformation types based on industry best practices:
 *          - DIRECT_MAP: Simple 1:1 mapping
 *          - CONSTANT: Hard-coded values
 *          - CONCAT: Concatenation of multiple fields
 *          - DATE_CONSTRUCT: Build dates from components
 *          - DATE_CONVERT: Convert date formats to ISO 8601
 *          - RECODE: Value standardization/mapping
 *          - CONDITIONAL: If-then logic
 *          - MULTI_CHECKBOX: Handle multiple checkbox selections
 *
 * References:
 *          - Eli Lilly metadata-driven approach (95-97% automation)
 *          - CDISC SDTM IG v3.4
 *          - AbbVie AI/ML transformation pipeline
 *          - Roche {sdtm.oak} package patterns
 ******************************************************************************/

%include "sas/include/check_manifest.sas";
%include "sas/include/logcheck.sas";
%include "sas/include/check_syscc.sas";
%include "00_setup.sas";

%logmsg(START: SDTM DM v2.0 - Metadata-Driven Production Engine);

/******************************************************************************
 * STEP 1: Import SDTM DM Specification
 ******************************************************************************/
proc import datafile="%spec_file(sdtm_dm_spec_v2.csv)"
    out=work.sdtm_dm_spec
    dbms=csv
    replace;
    guessingrows=max;
run;
%check_syscc(step=SDTM DM - spec import);

/* Validate spec structure */
proc sql;
    select count(*) into :spec_count trimmed
    from work.sdtm_dm_spec;
    
    %if &spec_count = 0 %then %do;
        %put ERROR: Specification file is empty;
        %abort cancel;
    %end;
quit;

%logmsg(INFO: Loaded &spec_count mapping specifications);

/******************************************************************************
 * STEP 2: Initialize Output Dataset with Required Variables
 ******************************************************************************/
data sdtm.dm;
    set raw.subjects_clean;
    
    /* Initialize all SDTM variables as missing */
    length 
        STUDYID    $20
        DOMAIN     $2
        USUBJID    $40
        SUBJID     $10
        SITEID     $10
        INVID      $20
        INVNAM     $200
        BRTHDTC    $10
        AGE        8
        AGEU       $6
        SEX        $1
        RACE       $100
        ETHNIC     $50
        ARMCD      $20
        ARM        $200
        ACTARMCD   $20
        ACTARM     $200
        COUNTRY    $3
        DMDTC      $19
        DMDY       8
        RFICDTC    $19
        RFSTDTC    $19
        RFENDTC    $19
        RFXSTDTC   $19
        RFXENDTC   $19
        RFPENDTC   $19
        DTHDTC     $19
        DTHFL      $1
    ;
    
    /* Set defaults */
    call missing(of _all_);
    
    /* Keep only raw data for transformations */
run;
%check_syscc(step=SDTM DM - initialize dataset);

/******************************************************************************
 * STEP 3: Apply Transformations Based on Specification
 ******************************************************************************/

/* Create macro variables from spec for each transformation type */
proc sql noprint;
    /* CONSTANT transformations */
    select seq, target_var, transformation_logic
    into :const_seq1-:const_seq999,
         :const_tgt1-:const_tgt999,
         :const_logic1-:const_logic999
    from work.sdtm_dm_spec
    where upcase(transformation_type) = 'CONSTANT';
    %let n_const = &sqlobs;
    
    /* DIRECT_MAP transformations */
    select seq, source_var, target_var
    into :dm_seq1-:dm_seq999,
         :dm_src1-:dm_src999,
         :dm_tgt1-:dm_tgt999
    from work.sdtm_dm_spec
    where upcase(transformation_type) = 'DIRECT_MAP';
    %let n_dm = &sqlobs;
    
    /* RECODE transformations */
    select seq, source_var, target_var, transformation_logic
    into :rc_seq1-:rc_seq999,
         :rc_src1-:rc_src999,
         :rc_tgt1-:rc_tgt999,
         :rc_logic1-:rc_logic999
    from work.sdtm_dm_spec
    where upcase(transformation_type) = 'RECODE';
    %let n_rc = &sqlobs;
    
    /* DATE_CONSTRUCT transformations */
    select seq, source_var, target_var, transformation_logic
    into :dc_seq1-:dc_seq999,
         :dc_src1-:dc_src999,
         :dc_tgt1-:dc_tgt999,
         :dc_logic1-:dc_logic999
    from work.sdtm_dm_spec
    where upcase(transformation_type) = 'DATE_CONSTRUCT';
    %let n_dc = &sqlobs;
    
    /* DATE_CONVERT transformations */
    select seq, source_var, target_var, transformation_logic
    into :dv_seq1-:dv_seq999,
         :dv_src1-:dv_src999,
         :dv_tgt1-:dv_tgt999,
         :dv_logic1-:dv_logic999
    from work.sdtm_dm_spec
    where upcase(transformation_type) = 'DATE_CONVERT';
    %let n_dv = &sqlobs;
    
    /* CONDITIONAL transformations */
    select seq, source_var, target_var, transformation_logic
    into :cd_seq1-:cd_seq999,
         :cd_src1-:cd_src999,
         :cd_tgt1-:cd_tgt999,
         :cd_logic1-:cd_logic999
    from work.sdtm_dm_spec
    where upcase(transformation_type) = 'CONDITIONAL';
    %let n_cd = &sqlobs;
    
    /* CONCAT transformations */
    select seq, source_var, target_var, transformation_logic
    into :cc_seq1-:cc_seq999,
         :cc_src1-:cc_src999,
         :cc_tgt1-:cc_tgt999,
         :cc_logic1-:cc_logic999
    from work.sdtm_dm_spec
    where upcase(transformation_type) = 'CONCAT';
    %let n_cc = &sqlobs;
quit;

%logmsg(INFO: Transformation counts - CONSTANT:&n_const DIRECT:&n_dm RECODE:&n_rc DATE_CONSTRUCT:&n_dc DATE_CONVERT:&n_dv CONDITIONAL:&n_cd CONCAT:&n_cc);

/******************************************************************************
 * STEP 4: Execute Transformations
 ******************************************************************************/
data sdtm.dm;
    set sdtm.dm;
    
    /*--- CONSTANT transformations ---*/
    %do i = 1 %to &n_const;
        &&const_logic&i;
    %end;
    
    /*--- DIRECT_MAP transformations ---*/
    %do i = 1 %to &n_dm;
        &&dm_tgt&i = &&dm_src&i;
    %end;
    
    /*--- CONCAT transformations ---*/
    %do i = 1 %to &n_cc;
        &&cc_tgt&i = &&cc_logic&i;
    %end;
    
    /*--- DATE_CONSTRUCT transformations ---*/
    %do i = 1 %to &n_dc;
        &&dc_tgt&i = &&dc_logic&i;
    %end;
    
    /*--- DATE_CONVERT transformations ---*/
    %do i = 1 %to &n_dv;
        &&dv_tgt&i = &&dv_logic&i;
    %end;
    
    /*--- RECODE transformations ---*/
    %do i = 1 %to &n_rc;
        &&rc_tgt&i = &&rc_logic&i;
    %end;
    
    /*--- CONDITIONAL transformations ---*/
    %do i = 1 %to &n_cd;
        &&cd_logic&i;
    %end;
    
    /*--- Complex derivation: RACE from multiple checkboxes ---*/
    /* This requires custom logic not easily spec-driven */
    /* Example: If your raw data has race_white, race_black, race_asian as 0/1 */
    length _race_count 8;
    _race_count = sum(race_white, race_black, race_asian, 
                      race_native_american, race_pacific_islander);
    
    if _race_count = 0 then RACE = 'NOT REPORTED';
    else if _race_count = 1 then do;
        if race_white = 1 then RACE = 'WHITE';
        else if race_black = 1 then RACE = 'BLACK OR AFRICAN AMERICAN';
        else if race_asian = 1 then RACE = 'ASIAN';
        else if race_native_american = 1 then RACE = 'AMERICAN INDIAN OR ALASKA NATIVE';
        else if race_pacific_islander = 1 then RACE = 'NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER';
    end;
    else if _race_count > 1 then RACE = 'MULTIPLE';
    
    drop _race_count;
    
    /* Keep only SDTM variables */
    keep STUDYID DOMAIN USUBJID SUBJID SITEID INVID INVNAM
         BRTHDTC AGE AGEU SEX RACE ETHNIC 
         ARMCD ARM ACTARMCD ACTARM COUNTRY
         DMDTC DMDY RFICDTC RFSTDTC RFENDTC RFXSTDTC RFXENDTC RFPENDTC
         DTHDTC DTHFL;
run;
%check_syscc(step=SDTM DM - transformations);

/******************************************************************************
 * STEP 5: Quality Control Checks
 ******************************************************************************/

/* QC Report: Check required variables */
proc sql;
    create table work.dm_qc_report as
    select 
        'USUBJID' as variable,
        count(*) as total_records,
        nmiss(USUBJID) as missing_count,
        count(distinct USUBJID) as unique_count,
        calculated missing_count / calculated total_records * 100 as pct_missing format=5.2
    from sdtm.dm
    
    union all
    
    select 
        'SEX' as variable,
        count(*) as total_records,
        nmiss(SEX) as missing_count,
        count(distinct SEX) as unique_count,
        calculated missing_count / calculated total_records * 100 as pct_missing format=5.2
    from sdtm.dm
    
    union all
    
    select 
        'AGE' as variable,
        count(*) as total_records,
        nmiss(AGE) as missing_count,
        count(distinct AGE) as unique_count,
        calculated missing_count / calculated total_records * 100 as pct_missing format=5.2
    from sdtm.dm
    
    union all
    
    select 
        'RACE' as variable,
        count(*) as total_records,
        nmiss(RACE) as missing_count,
        count(distinct RACE) as unique_count,
        calculated missing_count / calculated total_records * 100 as pct_missing format=5.2
    from sdtm.dm;
quit;

/* Print QC report to log */
proc print data=work.dm_qc_report;
    title "SDTM DM Quality Control Report";
run;

/* Check for critical issues */
data _null_;
    set work.dm_qc_report;
    
    /* USUBJID must be 100% populated and unique */
    if variable = 'USUBJID' then do;
        if missing_count > 0 then do;
            put "ERROR: USUBJID has " missing_count "missing values";
            call symputx('qc_error', '1');
        end;
        if unique_count ne total_records then do;
            put "ERROR: USUBJID is not unique (" unique_count "unique vs " total_records "total)";
            call symputx('qc_error', '1');
        end;
    end;
    
    /* SEX should be populated */
    if variable = 'SEX' and pct_missing > 5 then do;
        put "WARNING: SEX has " pct_missing "% missing values";
    end;
run;

%if %symexist(qc_error) %then %do;
    %put ERROR: Quality control checks failed;
    %abort cancel;
%end;

/******************************************************************************
 * STEP 6: Generate Summary Statistics
 ******************************************************************************/
proc freq data=sdtm.dm;
    tables SEX RACE ETHNIC ARMCD / missing;
    title "SDTM DM Frequency Distributions";
run;

proc means data=sdtm.dm n nmiss mean std min max;
    var AGE DMDY;
    title "SDTM DM Numeric Variable Summary";
run;

%logmsg(END: SDTM DM - Successfully created);

/******************************************************************************
 * STEP 7: Final Log Check
 ******************************************************************************/
%if %sysfunc(fileexist(%superq(ETL_LOG_PATH))) %then %do;
  %logcheck(%superq(ETL_LOG_PATH));
%end;
%else %do;
  %put [ERROR] Expected log file %superq(ETL_LOG_PATH) not found.;
  %abort cancel;
%end;
