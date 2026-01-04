%include "sas/include/check_manifest.sas";
%include "sas/include/logcheck.sas";
%include "sas/include/check_syscc.sas";

%include "00_setup.sas";

/* 30_adam_adsl.sas: create ADaM-style ADSL from multiple SDTM domains */

%logmsg(START: ADaM ADSL);

/*-------------------------------------------------------------------*/
/* STEP 1: Read ADSL specification                                  */
/*-------------------------------------------------------------------*/
proc import datafile="%spec_file(adam_adsl_spec.csv)"
    out=work.adam_adsl_spec
    dbms=csv
    replace;
    guessingrows=max;
run;
%check_syscc(step=ADSL - spec import);

proc sql noprint;
    select source_domain, source_var, target_var
    into :srcdom1-:srcdom999,
         :srcvar1-:srcvar999,
         :tgtvar1-:tgtvar999
    from work.adam_adsl_spec
    where derivation_type = 'direct';  /* Only direct mappings for now */
    %let nmap = &sqlobs;
quit;
%check_syscc(step=ADSL - mapping query);

/*-------------------------------------------------------------------*/
/* STEP 2: Prepare SDTM source domains                              */
/*-------------------------------------------------------------------*/

/* Sort DM by USUBJID */
proc sort data=sdtm.dm out=work.dm_sorted;
    by USUBJID;
run;
%check_syscc(step=ADSL - SDTM.DM sort);

/* Derive treatment start and end dates from EX domain */
proc sql;
    create table work.ex_dates as
    select 
        USUBJID,
        min(input(EXSTDTC, ?? yymmdd10.)) as TRTSDT format=date9. label="Date of First Exposure to Treatment",
        max(input(EXENDTC, ?? yymmdd10.)) as TRTEDT format=date9. label="Date of Last Exposure to Treatment"
    from sdtm.ex
    where not missing(EXSTDTC) and EXOCCUR ne 'N'  /* Only actual exposures */
    group by USUBJID;
quit;
%check_syscc(step=ADSL - EX dates derivation);

/* Get end of study information from DS domain */
proc sql;
    create table work.ds_eos as
    select 
        USUBJID,
        input(DSSTDTC, ?? yymmdd10.) as EOSDT format=date9. label="End of Study Date",
        DSDECOD as EOSSTT label="End of Study Status",
        case 
            when upcase(DSTERM) in ('COMPLETED', 'STUDY COMPLETED') then 'COMPLETED'
            when upcase(DSTERM) contains 'WITHDRAW' then 'DISCONTINUED'
            else DSTERM 
        end as DCSREAS length=$200 label="Reason for Discontinuation"
    from sdtm.ds
    where upcase(DSCAT) = 'DISPOSITION'
    order by USUBJID, input(DSSTDTC, ?? yymmdd10.);
quit;

/* Keep only last disposition record per subject */
data work.ds_eos;
    set work.ds_eos;
    by USUBJID;
    if last.USUBJID;
run;
%check_syscc(step=ADSL - DS disposition derivation);

/* Get randomization flag if available */
proc sql;
    create table work.dm_rand as
    select 
        USUBJID,
        case 
            when not missing(ARM) or not missing(ACTARM) then 'Y'
            else 'N'
        end as RANDFL length=$1 label="Randomized Flag"
    from sdtm.dm;
quit;
%check_syscc(step=ADSL - Randomization flag);

/*-------------------------------------------------------------------*/
/* STEP 3: Merge all source domains to create base ADSL             */
/*-------------------------------------------------------------------*/
data work.adsl_base;
    merge 
        work.dm_sorted (in=indm)
        work.ex_dates (in=inex)
        work.ds_eos (in=inds)
        work.dm_rand;
    by USUBJID;
    
    /* Only keep subjects from DM */
    if not indm then delete;
    
    /* Initialize all required lengths */
    length SAFFL ITTFL PPROTFL EVLFL $1
           AGEGRP $8
           TRT01P TRT01A $200
           TRT01PN TRT01AN 8;
    
    /* Map variables from DM to ADSL using specification */
    %do i = 1 %to &nmap;
        %let srcdom = &&srcdom&i;
        %let srcvar = &&srcvar&i;
        %let tgtvar = &&tgtvar&i;

        %if &srcdom = DM %then %do;
            &tgtvar = &srcvar;
        %end;
    %end;
    
    /*----------------------------------------------------------------*/
    /* STEP 4: Derive treatment variables                             */
    /*----------------------------------------------------------------*/
    
    *DERIVATION_ID=ADSL-DERV-001;
    /* Planned Treatment - from DM.ARM */
    if missing(TRT01P) then TRT01P = ARM;
    
    *DERIVATION_ID=ADSL-DERV-002;
    /* Actual Treatment - from DM.ACTARM */
    if missing(TRT01A) then TRT01A = ACTARM;
    
    *DERIVATION_ID=ADSL-DERV-003;
    /* Numeric treatment codes */
    select (upcase(TRT01P));
        when ('PLACEBO', 'SCREEN FAILURE') TRT01PN = 0;
        when ('TREATMENT A', 'ACTIVE TREATMENT') TRT01PN = 1;
        when ('TREATMENT B') TRT01PN = 2;
        otherwise TRT01PN = 99;
    end;
    
    *DERIVATION_ID=ADSL-DERV-004;
    select (upcase(TRT01A));
        when ('PLACEBO', 'SCREEN FAILURE') TRT01AN = 0;
        when ('TREATMENT A', 'ACTIVE TREATMENT') TRT01AN = 1;
        when ('TREATMENT B') TRT01AN = 2;
        otherwise TRT01AN = 99;
    end;
    
    *DERIVATION_ID=ADSL-DERV-005;
    /* Treatment duration in days */
    if not missing(TRTSDT) and not missing(TRTEDT) then 
        TRTDURD = TRTEDT - TRTSDT + 1;
    
    /*----------------------------------------------------------------*/
    /* STEP 5: Derive population flags with proper conditions        */
    /*----------------------------------------------------------------*/
    
    *DERIVATION_ID=ADSL-DERV-010;
    /* Safety Population Flag - randomized and received at least one dose */
    SAFFL = ifn(RANDFL='Y' and not missing(TRTSDT), 'Y', 'N');
    
    *DERIVATION_ID=ADSL-DERV-011;
    /* Intent-to-Treat Population Flag - all randomized subjects */
    ITTFL = ifn(RANDFL='Y', 'Y', 'N');
    
    *DERIVATION_ID=ADSL-DERV-012;
    /* Per-Protocol Population Flag - randomized, treated, and completed per protocol */
    /* Adjust logic based on your protocol's definition */
    PPROTFL = ifn(RANDFL='Y' and not missing(TRTSDT) and 
                  EOSSTT='COMPLETED', 'Y', 'N');
    
    *DERIVATION_ID=ADSL-DERV-013;
    /* Evaluable Population Flag - subjects with evaluable efficacy data */
    /* This typically requires additional criteria from your protocol */
    EVLFL = ifn(RANDFL='Y' and not missing(TRTSDT), 'Y', 'N');
    
    /*----------------------------------------------------------------*/
    /* STEP 6: Derive demographic groupings                          */
    /*----------------------------------------------------------------*/
    
    *DERIVATION_ID=ADSL-DERV-020;
    /* Age Group derivation */
    if missing(AGE) then AGEGRP = "UNKNOWN";
    else if AGE < 65 then AGEGRP = "<65";
    else AGEGRP = ">=65";
    
    *DERIVATION_ID=ADSL-DERV-021;
    /* Age Group 1 - alternative categorization */
    length AGEGR1 $20;
    if missing(AGE) then AGEGR1 = "UNKNOWN";
    else if AGE < 18 then AGEGR1 = "<18";
    else if AGE < 65 then AGEGR1 = "18-64";
    else if AGE < 75 then AGEGR1 = "65-74";
    else AGEGR1 = ">=75";
    
    *DERIVATION_ID=ADSL-DERV-022;
    /* Numeric age group for analysis */
    AGEGR1N = ifn(AGEGR1='<18', 1,
              ifn(AGEGR1='18-64', 2,
              ifn(AGEGR1='65-74', 3,
              ifn(AGEGR1='>=75', 4, .))));
    
    /*----------------------------------------------------------------*/
    /* STEP 7: Derive study day variables                            */
    /*----------------------------------------------------------------*/
    
    *DERIVATION_ID=ADSL-DERV-030;
    /* Reference start date - typically date of first treatment */
    if not missing(input(RFSTDTC, ?? yymmdd10.)) then 
        RFSTDT = input(RFSTDTC, yymmdd10.);
    else if not missing(TRTSDT) then
        RFSTDT = TRTSDT;
    
    *DERIVATION_ID=ADSL-DERV-031;
    /* Reference end date */
    if not missing(input(RFENDTC, ?? yymmdd10.)) then 
        RFENDT = input(RFENDTC, yymmdd10.);
    else if not missing(TRTEDT) then
        RFENDT = TRTEDT;
    
    /*----------------------------------------------------------------*/
    /* STEP 8: Apply comprehensive variable attributes               */
    /*----------------------------------------------------------------*/
    attrib
        /* Treatment Variables */
        TRT01P   length=$200  label="Planned Treatment for Period 01"
        TRT01A   length=$200  label="Actual Treatment for Period 01"
        TRT01PN  length=8     label="Planned Treatment for Period 01 (N)"
        TRT01AN  length=8     label="Actual Treatment for Period 01 (N)"
        TRTSDT   format=date9. label="Date of First Exposure to Treatment"
        TRTEDT   format=date9. label="Date of Last Exposure to Treatment"
        TRTDURD  length=8     label="Total Treatment Duration (Days)"
        
        /* Population Flags */
        SAFFL    length=$1    label="Safety Population Flag"
        ITTFL    length=$1    label="Intent-to-Treat Population Flag"
        PPROTFL  length=$1    label="Per-Protocol Population Flag"
        EVLFL    length=$1    label="Evaluable Population Flag"
        RANDFL   length=$1    label="Randomized Flag"
        
        /* Demographics */
        AGEGRP   length=$8    label="Age Group"
        AGEGR1   length=$20   label="Age Group 1"
        AGEGR1N  length=8     label="Age Group 1 (N)"
        
        /* Study Dates */
        RFSTDT   format=date9. label="Subject Reference Start Date"
        RFENDT   format=date9. label="Subject Reference End Date"
        EOSDT    format=date9. label="End of Study Date"
        EOSSTT   length=$200  label="End of Study Status"
        DCSREAS  length=$200  label="Reason for Discontinuation"
    ;
run;
%check_syscc(step=ADSL - derivations);

/*-------------------------------------------------------------------*/
/* STEP 9: Final dataset creation with one record per subject       */
/*-------------------------------------------------------------------*/
proc sort data=work.adsl_base out=adam.adsl nodupkey;
    by USUBJID;
run;
%check_syscc(step=ADSL - final dataset);

/*-------------------------------------------------------------------*/
/* STEP 10: Validation and reporting                                */
/*-------------------------------------------------------------------*/

/* Count subjects by population flags */
proc sql;
    title "ADSL Population Flag Summary";
    select 
        count(*) as Total_Subjects,
        sum(SAFFL='Y') as Safety_Pop,
        sum(ITTFL='Y') as ITT_Pop,
        sum(PPROTFL='Y') as PerProtocol_Pop,
        sum(EVLFL='Y') as Evaluable_Pop,
        sum(RANDFL='Y') as Randomized
    from adam.adsl;
quit;

/* Check for required variables */
proc contents data=adam.adsl out=work.adsl_vars(keep=name) noprint;
run;

data _null_;
    set work.adsl_vars end=eof;
    retain missing_req 0;
    array req_vars[15] $32 _temporary_ 
        ('STUDYID' 'USUBJID' 'SUBJID' 'SITEID' 'AGE' 'SEX' 'RACE'
         'TRT01P' 'TRT01A' 'SAFFL' 'ITTFL' 'RFSTDTC' 'TRTSDT' 'AGEGRP' 'RANDFL');
    
    if eof then do;
        do i = 1 to dim(req_vars);
            found = 0;
            do until (eof2);
                set work.adsl_vars end=eof2;
                if upcase(name) = upcase(req_vars[i]) then found = 1;
            end;
            if not found then do;
                put "WARNING: Required variable " req_vars[i] "not found in ADSL";
                missing_req = 1;
            end;
        end;
        if not missing_req then 
            put "NOTE: All required ADSL variables present";
    end;
run;

/* Check for subjects with missing treatment start dates */
proc sql noprint;
    select count(*) into :n_missing_trtsdt trimmed
    from adam.adsl
    where SAFFL='Y' and missing(TRTSDT);
quit;

%if &n_missing_trtsdt > 0 %then %do;
    %put WARNING: &n_missing_trtsdt subjects flagged for Safety but missing TRTSDT;
    
    proc print data=adam.adsl;
        where SAFFL='Y' and missing(TRTSDT);
        var USUBJID SAFFL RANDFL TRTSDT TRT01P TRT01A;
        title "Subjects with SAFFL=Y but Missing TRTSDT";
    run;
%end;

/* Check for duplicate subjects */
proc sql noprint;
    select count(distinct USUBJID) into :n_unique trimmed
    from adam.adsl;
    
    select count(*) into :n_total trimmed
    from adam.adsl;
quit;

%if &n_unique ne &n_total %then %do;
    %put ERROR: ADSL contains duplicate USUBJID values;
    %put ERROR: Unique subjects: &n_unique, Total records: &n_total;
%end;
%else %do;
    %put NOTE: ADSL verification complete - one record per subject;
    %put NOTE: Total subjects in ADSL: &n_unique;
%end;

%logmsg(END: ADaM ADSL);

/*-------------------------------------------------------------------*/
/* STEP 11: Log file validation                                     */
/*-------------------------------------------------------------------*/
%if %sysfunc(fileexist(%superq(ETL_LOG_PATH))) %then %do;
    %logcheck(%superq(ETL_LOG_PATH));
%end;
%else %do;
    %put [ERROR] Expected log file %superq(ETL_LOG_PATH) not found.;
    %abort cancel;
%end;