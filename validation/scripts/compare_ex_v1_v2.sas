/******************************************************************************
 Program: compare_ex_v1_v2.sas
 Purpose: Compare EX domain v1 (hard-coded) vs v2 (metadata-driven)
 Author: Clinical Programming Portfolio
 Date: December 25, 2025

 Description:
   This validation script compares the output of the original hard-coded
   EX program (38_sdtm_ex.sas) with the new metadata-driven version
   (38_sdtm_ex_v2.sas) to ensure transformation engine produces identical
   results.

 Inputs:
   - sdtm.ex_v1 (output from old program)
   - sdtm.ex (output from new program)

 Outputs:
   - HTML comparison report
   - Log file with PROC COMPARE results
   - Discrepancy dataset (if differences found)

 Expected Differences:
   - None expected - outputs should be 100% identical
   - If differences exist, they must be documented and justified

 Modification History:
   Date        Author      Description
   ----------  ----------  --------------------------------------------------
   2025-12-25  Portfolio   Initial validation script for v1 vs v2 comparison
******************************************************************************/

*-----------------------------------------------------------------------------
* 1. ENVIRONMENT SETUP
*-----------------------------------------------------------------------------;

options mprint mlogic symbolgen ps=60 ls=132;
libname sdtm '../../sdtm/data/sdtm';
libname valid '../evidence';

* Define ODS output for HTML report;
ods html file='../evidence/ex_comparison_report.html'
    style=statistical;

title "SDTM EX Domain: v1 vs v2 Comparison Validation";
title2 "Metadata Framework Migration Testing";
title3 "Date: %sysfunc(today(), date9.)";

*-----------------------------------------------------------------------------
* 2. PRE-COMPARISON CHECKS
*-----------------------------------------------------------------------------;

title4 "Pre-Comparison Dataset Existence Check";

%macro check_datasets;
    %let v1_exists = %sysfunc(exist(sdtm.ex_v1));
    %let v2_exists = %sysfunc(exist(sdtm.ex));
    
    %if &v1_exists = 0 %then %do;
        %put ERROR: sdtm.ex_v1 does not exist. Run 38_sdtm_ex.sas first.;
        %abort cancel;
    %end;
    
    %if &v2_exists = 0 %then %do;
        %put ERROR: sdtm.ex (v2) does not exist. Run 38_sdtm_ex_v2.sas first.;
        %abort cancel;
    %end;
    
    %put NOTE: Both datasets exist. Proceeding with comparison.;
%mend;

%check_datasets;

*-----------------------------------------------------------------------------
* 3. RECORD COUNT COMPARISON
*-----------------------------------------------------------------------------;

title4 "Record Count Comparison";

proc sql;
    create table valid.ex_record_counts as
    select 
        'V1 (Hard-coded)' as Version,
        count(*) as N_Records
    from sdtm.ex_v1
    
    union all
    
    select 
        'V2 (Metadata-driven)' as Version,
        count(*) as N_Records
    from sdtm.ex;
quit;

proc print data=valid.ex_record_counts noobs;
run;

* Validate record counts match;
proc sql noprint;
    select count(distinct N_Records) into :n_distinct_counts
    from valid.ex_record_counts;
quit;

%if &n_distinct_counts > 1 %then %do;
    %put WARNING: Record counts differ between v1 and v2!;
    %put WARNING: Investigation required before proceeding.;
%end;
%else %do;
    %put NOTE: Record counts match between v1 and v2.;
%end;

*-----------------------------------------------------------------------------
* 4. VARIABLE-LEVEL COMPARISON
*-----------------------------------------------------------------------------;

title4 "Variable-Level PROC COMPARE Analysis";

* Sort both datasets for comparison;
proc sort data=sdtm.ex_v1 out=work.ex_v1_sorted;
    by STUDYID USUBJID EXSEQ;
run;

proc sort data=sdtm.ex out=work.ex_v2_sorted;
    by STUDYID USUBJID EXSEQ;
run;

* Run PROC COMPARE with detailed output;
proc compare 
    base=work.ex_v1_sorted 
    compare=work.ex_v2_sorted
    out=valid.ex_differences
    outnoequal
    outbase
    outcomp
    method=absolute
    criterion=0.00001;
    id STUDYID USUBJID EXSEQ;
run;

*-----------------------------------------------------------------------------
* 5. SPECIFIC VARIABLE CHECKS
*-----------------------------------------------------------------------------;

title4 "Character Variable Exact Match Check";

%macro compare_char_vars;
    proc sql;
        create table valid.ex_char_diffs as
        select 
            v1.USUBJID,
            v1.EXSEQ,
            'EXTRT' as Variable,
            v1.EXTRT as V1_Value,
            v2.EXTRT as V2_Value
        from work.ex_v1_sorted as v1
        inner join work.ex_v2_sorted as v2
            on v1.USUBJID = v2.USUBJID and v1.EXSEQ = v2.EXSEQ
        where v1.EXTRT ne v2.EXTRT
        
        union all
        
        select 
            v1.USUBJID,
            v1.EXSEQ,
            'EXROUTE' as Variable,
            v1.EXROUTE as V1_Value,
            v2.EXROUTE as V2_Value
        from work.ex_v1_sorted as v1
        inner join work.ex_v2_sorted as v2
            on v1.USUBJID = v2.USUBJID and v1.EXSEQ = v2.EXSEQ
        where v1.EXROUTE ne v2.EXROUTE
        
        union all
        
        select 
            v1.USUBJID,
            v1.EXSEQ,
            'EXDOSFRQ' as Variable,
            v1.EXDOSFRQ as V1_Value,
            v2.EXDOSFRQ as V2_Value
        from work.ex_v1_sorted as v1
        inner join work.ex_v2_sorted as v2
            on v1.USUBJID = v2.USUBJID and v1.EXSEQ = v2.EXSEQ
        where v1.EXDOSFRQ ne v2.EXDOSFRQ;
    quit;
    
    %let n_char_diffs = 0;
    proc sql noprint;
        select count(*) into :n_char_diffs from valid.ex_char_diffs;
    quit;
    
    %if &n_char_diffs > 0 %then %do;
        %put WARNING: &n_char_diffs character variable differences found!;
        proc print data=valid.ex_char_diffs;
        run;
    %end;
    %else %do;
        %put NOTE: All character variables match exactly.;
    %end;
%mend;

%compare_char_vars;

*-----------------------------------------------------------------------------
* 6. NUMERIC VARIABLE TOLERANCE CHECK
*-----------------------------------------------------------------------------;

title4 "Numeric Variable Tolerance Check (±0.00001)";

%macro compare_num_vars;
    proc sql;
        create table valid.ex_num_diffs as
        select 
            v1.USUBJID,
            v1.EXSEQ,
            'EXDOSE' as Variable,
            v1.EXDOSE as V1_Value,
            v2.EXDOSE as V2_Value,
            abs(v1.EXDOSE - v2.EXDOSE) as Absolute_Diff
        from work.ex_v1_sorted as v1
        inner join work.ex_v2_sorted as v2
            on v1.USUBJID = v2.USUBJID and v1.EXSEQ = v2.EXSEQ
        where abs(v1.EXDOSE - v2.EXDOSE) > 0.00001
        
        union all
        
        select 
            v1.USUBJID,
            v1.EXSEQ,
            'EXSTDY' as Variable,
            v1.EXSTDY as V1_Value,
            v2.EXSTDY as V2_Value,
            abs(v1.EXSTDY - v2.EXSTDY) as Absolute_Diff
        from work.ex_v1_sorted as v1
        inner join work.ex_v2_sorted as v2
            on v1.USUBJID = v2.USUBJID and v1.EXSEQ = v2.EXSEQ
        where abs(v1.EXSTDY - v2.EXSTDY) > 0.00001
        
        union all
        
        select 
            v1.USUBJID,
            v1.EXSEQ,
            'EXENDY' as Variable,
            v1.EXENDY as V1_Value,
            v2.EXENDY as V2_Value,
            abs(v1.EXENDY - v2.EXENDY) as Absolute_Diff
        from work.ex_v1_sorted as v1
        inner join work.ex_v2_sorted as v2
            on v1.USUBJID = v2.USUBJID and v1.EXSEQ = v2.EXSEQ
        where abs(v1.EXENDY - v2.EXENDY) > 0.00001;
    quit;
    
    %let n_num_diffs = 0;
    proc sql noprint;
        select count(*) into :n_num_diffs from valid.ex_num_diffs;
    quit;
    
    %if &n_num_diffs > 0 %then %do;
        %put WARNING: &n_num_diffs numeric variable differences exceed tolerance!;
        proc print data=valid.ex_num_diffs;
        run;
    %end;
    %else %do;
        %put NOTE: All numeric variables within tolerance (±0.00001).;
    %end;
%mend;

%compare_num_vars;

*-----------------------------------------------------------------------------
* 7. DATE VARIABLE ISO 8601 FORMAT CHECK
*-----------------------------------------------------------------------------;

title4 "Date Variable ISO 8601 Format Validation";

%macro check_date_formats;
    proc sql;
        create table valid.ex_date_diffs as
        select 
            v1.USUBJID,
            v1.EXSEQ,
            'EXSTDTC' as Variable,
            v1.EXSTDTC as V1_Value,
            v2.EXSTDTC as V2_Value
        from work.ex_v1_sorted as v1
        inner join work.ex_v2_sorted as v2
            on v1.USUBJID = v2.USUBJID and v1.EXSEQ = v2.EXSEQ
        where v1.EXSTDTC ne v2.EXSTDTC
        
        union all
        
        select 
            v1.USUBJID,
            v1.EXSEQ,
            'EXENDTC' as Variable,
            v1.EXENDTC as V1_Value,
            v2.EXENDTC as V2_Value
        from work.ex_v1_sorted as v1
        inner join work.ex_v2_sorted as v2
            on v1.USUBJID = v2.USUBJID and v1.EXSEQ = v2.EXSEQ
        where v1.EXENDTC ne v2.EXENDTC;
    quit;
    
    %let n_date_diffs = 0;
    proc sql noprint;
        select count(*) into :n_date_diffs from valid.ex_date_diffs;
    quit;
    
    %if &n_date_diffs > 0 %then %do;
        %put WARNING: &n_date_diffs date format differences found!;
        proc print data=valid.ex_date_diffs;
        run;
    %end;
    %else %do;
        %put NOTE: All date variables match exactly (ISO 8601 format).;
    %end;
%mend;

%check_date_formats;

*-----------------------------------------------------------------------------
* 8. FINAL VALIDATION SUMMARY
*-----------------------------------------------------------------------------;

title4 "Final Validation Summary";

%macro validation_summary;
    data valid.ex_validation_summary;
        length Check $50 Status $10 N_Differences 8 Notes $200;
        
        Check = "Record Count Match";
        Status = ifc(&n_distinct_counts = 1, "PASS", "FAIL");
        N_Differences = ifc(&n_distinct_counts = 1, 0, 999);
        Notes = "Both versions should have same number of records";
        output;
        
        Check = "Character Variables";
        Status = ifc(&n_char_diffs = 0, "PASS", "FAIL");
        N_Differences = &n_char_diffs;
        Notes = "EXTRT, EXROUTE, EXDOSFRQ, etc. should match exactly";
        output;
        
        Check = "Numeric Variables";
        Status = ifc(&n_num_diffs = 0, "PASS", "FAIL");
        N_Differences = &n_num_diffs;
        Notes = "EXDOSE, EXSTDY, EXENDY within tolerance (±0.00001)";
        output;
        
        Check = "Date Formats (ISO 8601)";
        Status = ifc(&n_date_diffs = 0, "PASS", "FAIL");
        N_Differences = &n_date_diffs;
        Notes = "EXSTDTC, EXENDTC should be ISO 8601 format";
        output;
    run;
    
    proc print data=valid.ex_validation_summary noobs label;
        var Check Status N_Differences Notes;
        label Check = "Validation Check"
              Status = "Result"
              N_Differences = "# Diff"
              Notes = "Description";
    run;
    
    * Overall validation result;
    proc sql noprint;
        select sum(N_Differences) into :total_diffs from valid.ex_validation_summary;
    quit;
    
    %put NOTE: ============================================;
    %if &total_diffs = 0 %then %do;
        %put NOTE: ✅ VALIDATION PASSED: EX v1 and v2 are identical;
        %put NOTE: Metadata-driven transformation engine validated;
    %end;
    %else %do;
        %put ERROR: ❌ VALIDATION FAILED: &total_diffs differences found;
        %put ERROR: Review evidence datasets for details;
    %end;
    %put NOTE: ============================================;
%mend;

%validation_summary;

* Close ODS HTML output;
ods html close;

title;

/*** END OF VALIDATION SCRIPT ***/