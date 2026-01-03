/******************************************************************************
 * Program: add_source_trace.sas
 * Purpose: Add SRCDOM, SRCVAR, SRCSEQ for SDTM traceability
 * Author: Clinical Programming Team
 * Date: 2026-01-03
 * 
 * Research Citation:
 * - PharmaSUG 2025-DS-065: "Which ADaM Data Structure Is Most Appropriate?"
 *   Quote: "Data point traceability enables the user to go directly to the
 *   specific predecessor record(s)"
 *   https://pharmasug.org/proceedings/2025/DS/PharmaSUG-2025-DS-065.pdf
 * 
 * Traceability Rules:
 *   - LDIAM: Single TR record → SRCSEQ = TRSEQ
 *   - SDIAM/SNTLDIAM: Multiple TR records → SRCSEQ = . (document in ADRG)
 *   - BASE/NADIR: Derived from AVAL → SRCDOM='ADTR', SRCVAR='AVAL'
 *   - CHG/PCHG: Calculated parameters → document formula in SRCVAR
 * 
 * Inputs:
 *   - adtr_in: ADTR dataset with TRSEQ linkage
 * 
 * Outputs:
 *   - adtr_out: ADTR with SRCDOM, SRCVAR, SRCSEQ
 *   - _trace_documentation: ADRG documentation table
 * 
 * Parameters:
 *   - input_ds: Input ADTR dataset
 *   - output_ds: Output ADTR dataset
 *   - create_adrg_table: Generate ADRG documentation (Y/N, default=Y)
 *****************************************************************************/

%macro add_source_trace(
    input_ds=work.adtr,
    output_ds=work.adtr,
    create_adrg_table=Y
);

    %put %str(NOTE: [ADD_SOURCE_TRACE] Adding source traceability variables...);
    %put %str(NOTE: [ADD_SOURCE_TRACE] Input dataset: &input_ds);

    data &output_ds;
        set &input_ds;
        
        length SRCDOM $8 SRCVAR $40;
        
        /* SRCDOM: Source data domain */
        if PARAMCD in ('LDIAM', 'SDIAM', 'SNTLDIAM') then 
            SRCDOM = 'TR';  /* Tumor Results domain */
        else if PARAMCD in ('BASE', 'NADIR', 'CHG', 'PCHG') then
            SRCDOM = 'ADTR';  /* Derived from ADTR itself */
        else 
            SRCDOM = '';
            
        /* SRCVAR: Source variable name */
        if PARAMCD in ('LDIAM', 'SDIAM', 'SNTLDIAM') then 
            SRCVAR = 'TRSTRESN';  /* Numeric result from TR */
        else if PARAMCD in ('BASE', 'NADIR') then
            SRCVAR = 'AVAL';  /* Derived from AVAL */
        else if PARAMCD='CHG' then
            SRCVAR = 'AVAL - BASE';  /* Change formula */
        else if PARAMCD='PCHG' then
            SRCVAR = '(AVAL - BASE) / BASE * 100';  /* Percent change formula */
        else 
            SRCVAR = '';
            
        /* SRCSEQ: Source sequence number */
        /* Only populated for single-source derivations */
        if PARAMCD='LDIAM' and not missing(TRSEQ) then 
            SRCSEQ = TRSEQ;  /* Direct 1:1 link to TR record */
        else if PARAMCD in ('SDIAM', 'SNTLDIAM') then 
            SRCSEQ = .;  /* Multiple TR records, cannot specify single SEQ */
        else if PARAMCD in ('BASE', 'NADIR', 'CHG', 'PCHG') then
            SRCSEQ = .;  /* Derived parameters, not direct SDTM link */
        else 
            SRCSEQ = .;
            
        /* Add variable labels */
        label
            SRCDOM = 'Source Data Domain'
            SRCVAR = 'Source Variable'
            SRCSEQ = 'Source Sequence Number';
    run;

    /* QC Report: Source traceability summary */
    proc freq data=&output_ds;
        tables PARAMCD * SRCDOM * SRCVAR / list missing;
        title "QC: Source Traceability by Parameter";
    run;
    
    proc sql;
        select distinct PARAMCD, SRCDOM, SRCVAR,
               case when SRCSEQ is not missing then 'YES' else 'NO' end as HAS_SRCSEQ
        from &output_ds
        where not missing(PARAMCD)
        order by PARAMCD;
    quit;
    title;
    
    /* Validation: LDIAM should always have SRCSEQ */
    proc sql;
        create table _trace_validation as
        select USUBJID, PARAMCD, ADT, TRSEQ, SRCSEQ,
               'LDIAM missing SRCSEQ' as ISSUE
        from &output_ds
        where PARAMCD='LDIAM' 
          and not missing(TRSEQ) 
          and missing(SRCSEQ);
    quit;
    
    %let n_violations=&sqlobs;
    %if &n_violations > 0 %then %do;
        %put WARNING: [ADD_SOURCE_TRACE] &n_violations LDIAM records missing SRCSEQ;
        proc print data=_trace_validation;
            title "WARNING: Missing Source Traceability";
        run;
    %end;
    %else %do;
        %put %str(NOTE: [ADD_SOURCE_TRACE] Source traceability validation PASSED);
    %end;
    title;

    /* Create traceability documentation for ADRG */
    %if &create_adrg_table=Y %then %do;
        data _trace_documentation;
            length PARAMCD $8 SRCDOM $8 SRCVAR $40 DERIVATION_LOGIC $500;
            
            PARAMCD='LDIAM'; SRCDOM='TR'; SRCVAR='TRSTRESN'; 
            DERIVATION_LOGIC='Direct copy from TR.TRSTRESN for individual lesion. SRCSEQ=TRSEQ for 1:1 traceability.';
            output;
            
            PARAMCD='SDIAM'; SRCDOM='TR'; SRCVAR='TRSTRESN';
            DERIVATION_LOGIC='Sum of TR.TRSTRESN for all TARGET lesions (max 5 total, max 2 per organ per RECIST 1.1). SRCSEQ=. (multiple source records).';
            output;
            
            PARAMCD='SNTLDIAM'; SRCDOM='TR'; SRCVAR='TRSTRESN';
            DERIVATION_LOGIC='Sum of TR.TRSTRESN for all NON-TARGET lesions. SRCSEQ=. (multiple source records).';
            output;
            
            PARAMCD='BASE'; SRCDOM='ADTR'; SRCVAR='AVAL';
            DERIVATION_LOGIC='Last non-missing AVAL where ADY < 1 using PRETREAT method (Vitale 2025, PMC12094296). Derived within ADTR.';
            output;
            
            PARAMCD='NADIR'; SRCDOM='ADTR'; SRCVAR='AVAL';
            DERIVATION_LOGIC='Minimum AVAL where ADY >= 1 (Vitale 2025 method, PMC12094296). On-treatment nadir for PD assessment.';
            output;
            
            PARAMCD='CHG'; SRCDOM='ADTR'; SRCVAR='AVAL - BASE';
            DERIVATION_LOGIC='Change from baseline: AVAL - BASE. Calculated within ADTR.';
            output;
            
            PARAMCD='PCHG'; SRCDOM='ADTR'; SRCVAR='(AVAL - BASE) / BASE * 100';
            DERIVATION_LOGIC='Percent change from baseline: (AVAL - BASE) / BASE * 100. Calculated within ADTR.';
            output;
        run;
        
        proc print data=_trace_documentation noobs;
            title "Source Traceability Documentation for ADRG (Analysis Data Reviewer Guide)";
            title2 "Research Citation: PharmaSUG 2025-DS-065";
        run;
        title;
    %end;

    /* Cleanup */
    proc datasets library=work nolist;
        delete _trace_validation;
    quit;

    %put %str(NOTE: [ADD_SOURCE_TRACE] Traceability variables complete.);
    %put %str(NOTE: [ADD_SOURCE_TRACE] Research citation: PharmaSUG 2025-DS-065);

%mend add_source_trace;
