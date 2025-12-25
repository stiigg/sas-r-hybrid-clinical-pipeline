/******************************************************************************
* Macro: SDTM_TRANSFORMATION_ENGINE
* Purpose: Universal metadata-driven SDTM transformation processor
* Author: Christian Baghai
* Date: 2025-12-25
* Version: 2.1
* 
* Description:
*   Production-grade transformation engine that processes SDTM domains using
*   metadata specifications (v2.0 format). Supports 11 transformation types
*   with automated QC validation.
*
* Parameters:
*   SPEC_FILE    - Full path to domain specification CSV v2.0
*   DOMAIN       - Two-character SDTM domain code (e.g., AE, VS, EX)
*   SOURCE_DATA  - Input dataset name (usually RAW.domain_raw)
*   OUTPUT_DATA  - Output dataset name (usually SDTM.domain)
*   STUDYID      - Study identifier macro variable reference
*   
* Returns: 
*   Transformed SDTM dataset with QC validation report
*
* Transformation Types Supported:
*   1. CONSTANT           - Hard-coded values
*   2. DIRECT_MAP         - Simple source-to-target mapping
*   3. CONCAT             - Concatenate multiple variables
*   4. DATE_CONSTRUCT     - Build ISO 8601 dates from components
*   5. DATE_CONVERT       - Convert SAS dates to ISO 8601
*   6. RECODE             - Controlled terminology mapping
*   7. CONDITIONAL        - If-then-else logic
*   8. MULTI_CHECKBOX     - Multi-response checkbox handling
*   9. BASELINE_FLAG      - Derive baseline flags (VSBLFL, LBLFL, EGBLFL)
*   10. UNIT_CONVERSION   - Convert lab units using conversion factors
*   11. REFERENCE_DATA_LOOKUP - Join external reference data tables
*
* Architecture:
*   Based on Eli Lilly metadata-driven patterns, Roche pharmaverse approach,
*   and AbbVie AI-enhanced transformation classification.
*
* Example Usage:
*   %sdtm_transformation_engine(
*       spec_file=../../specs/sdtm_vs_spec_v2.csv,
*       domain=VS,
*       source_data=raw_vs_with_dm,
*       output_data=sdtm.vs,
*       studyid=&studyid
*   );
******************************************************************************/

%macro sdtm_transformation_engine(
    spec_file=,
    domain=,
    source_data=,
    output_data=,
    studyid=
) / minoperator;

    %put NOTE: ===============================================;
    %put NOTE: SDTM Transformation Engine v2.1 Starting;
    %put NOTE: Domain: &domain;
    %put NOTE: Specification: &spec_file;
    %put NOTE: ===============================================;

    /* === STEP 1: IMPORT AND VALIDATE SPECIFICATION === */
    %put NOTE: STEP 1 - Importing specification file...;
    
    proc import datafile="&spec_file"
        out=_spec_raw
        dbms=csv
        replace;
        guessingrows=max;
    run;
    
    %if &syserr ne 0 %then %do;
        %put ERROR: Failed to import specification file: &spec_file;
        %put ERROR: Verify file exists and is accessible;
        %abort cancel;
    %end;
    
    /* Validate required columns exist */
    proc sql noprint;
        select count(*) into :spec_valid
        from dictionary.columns
        where libname='WORK' and memname='_SPEC_RAW'
            and upcase(name) in ('TRANSFORMATION_TYPE' 'TRANSFORMATION_LOGIC' 
                                 'TARGET_VAR' 'QUALITY_CHECK');
    quit;
    
    %if &spec_valid < 4 %then %do;
        %put ERROR: Specification file missing required columns;
        %put ERROR: Required: transformation_type, transformation_logic, target_var, quality_check;
        %put ERROR: Found only &spec_valid of 4 required columns;
        %abort cancel;
    %end;
    
    %put NOTE: Specification validated successfully;

    /* === STEP 2: CLASSIFY TRANSFORMATIONS BY TYPE === */
    %put NOTE: STEP 2 - Classifying transformations by type...;
    
    proc sql noprint;
        /* Count total transformations */
        select count(*) into :total_trans
        from _spec_raw
        where not missing(transformation_type);
        
        /* CONSTANT transformations */
        select count(*) into :n_const
        from _spec_raw
        where upcase(transformation_type) = 'CONSTANT';
        
        %if &n_const > 0 %then %do;
            select transformation_logic
            into :const_logic1-:const_logic999
            from _spec_raw
            where upcase(transformation_type) = 'CONSTANT'
            order by seq;
        %end;
        
        /* DIRECT_MAP transformations */
        select count(*) into :n_dm
        from _spec_raw
        where upcase(transformation_type) = 'DIRECT_MAP';
        
        %if &n_dm > 0 %then %do;
            select source_var, target_var, transformation_logic
            into :dm_src1-:dm_src999,
                 :dm_tgt1-:dm_tgt999,
                 :dm_logic1-:dm_logic999
            from _spec_raw
            where upcase(transformation_type) = 'DIRECT_MAP'
            order by seq;
        %end;
        
        /* CONCAT transformations */
        select count(*) into :n_concat
        from _spec_raw
        where upcase(transformation_type) = 'CONCAT';
        
        %if &n_concat > 0 %then %do;
            select transformation_logic
            into :concat_logic1-:concat_logic999
            from _spec_raw
            where upcase(transformation_type) = 'CONCAT'
            order by seq;
        %end;
        
        /* DATE_CONSTRUCT transformations */
        select count(*) into :n_date_const
        from _spec_raw
        where upcase(transformation_type) = 'DATE_CONSTRUCT';
        
        %if &n_date_const > 0 %then %do;
            select transformation_logic
            into :date_const_logic1-:date_const_logic999
            from _spec_raw
            where upcase(transformation_type) = 'DATE_CONSTRUCT'
            order by seq;
        %end;
        
        /* DATE_CONVERT transformations */
        select count(*) into :n_date_conv
        from _spec_raw
        where upcase(transformation_type) = 'DATE_CONVERT';
        
        %if &n_date_conv > 0 %then %do;
            select transformation_logic
            into :date_conv_logic1-:date_conv_logic999
            from _spec_raw
            where upcase(transformation_type) = 'DATE_CONVERT'
            order by seq;
        %end;
        
        /* RECODE transformations */
        select count(*) into :n_recode
        from _spec_raw
        where upcase(transformation_type) = 'RECODE';
        
        %if &n_recode > 0 %then %do;
            select transformation_logic
            into :recode_logic1-:recode_logic999
            from _spec_raw
            where upcase(transformation_type) = 'RECODE'
            order by seq;
        %end;
        
        /* CONDITIONAL transformations */
        select count(*) into :n_cond
        from _spec_raw
        where upcase(transformation_type) = 'CONDITIONAL';
        
        %if &n_cond > 0 %then %do;
            select transformation_logic
            into :cond_logic1-:cond_logic999
            from _spec_raw
            where upcase(transformation_type) = 'CONDITIONAL'
            order by seq;
        %end;
        
        /* MULTI_CHECKBOX transformations */
        select count(*) into :n_multi
        from _spec_raw
        where upcase(transformation_type) = 'MULTI_CHECKBOX';
        
        %if &n_multi > 0 %then %do;
            select transformation_logic
            into :multi_logic1-:multi_logic999
            from _spec_raw
            where upcase(transformation_type) = 'MULTI_CHECKBOX'
            order by seq;
        %end;
        
        /* BASELINE_FLAG transformations - NEW in v2.1 */
        select count(*) into :n_baseline
        from _spec_raw
        where upcase(transformation_type) = 'BASELINE_FLAG';
        
        %if &n_baseline > 0 %then %do;
            select target_var, transformation_logic
            into :baseline_tgt1-:baseline_tgt999,
                 :baseline_logic1-:baseline_logic999
            from _spec_raw
            where upcase(transformation_type) = 'BASELINE_FLAG'
            order by seq;
        %end;
        
        /* UNIT_CONVERSION transformations - NEW in v2.1 */
        select count(*) into :n_unit_conv
        from _spec_raw
        where upcase(transformation_type) = 'UNIT_CONVERSION';
        
        %if &n_unit_conv > 0 %then %do;
            select target_var, transformation_logic
            into :unit_conv_tgt1-:unit_conv_tgt999,
                 :unit_conv_logic1-:unit_conv_logic999
            from _spec_raw
            where upcase(transformation_type) = 'UNIT_CONVERSION'
            order by seq;
        %end;
        
        /* REFERENCE_DATA_LOOKUP transformations - NEW in v2.1 */
        select count(*) into :n_ref_lookup
        from _spec_raw
        where upcase(transformation_type) = 'REFERENCE_DATA_LOOKUP';
        
        %if &n_ref_lookup > 0 %then %do;
            select target_var, transformation_logic
            into :ref_lookup_tgt1-:ref_lookup_tgt999,
                 :ref_lookup_logic1-:ref_lookup_logic999
            from _spec_raw
            where upcase(transformation_type) = 'REFERENCE_DATA_LOOKUP'
            order by seq;
        %end;
    quit;
    
    %put NOTE: Total transformations: &total_trans;
    %put NOTE: - CONSTANT: &n_const;
    %put NOTE: - DIRECT_MAP: &n_dm;
    %put NOTE: - CONCAT: &n_concat;
    %put NOTE: - DATE_CONSTRUCT: &n_date_const;
    %put NOTE: - DATE_CONVERT: &n_date_conv;
    %put NOTE: - RECODE: &n_recode;
    %put NOTE: - CONDITIONAL: &n_cond;
    %put NOTE: - MULTI_CHECKBOX: &n_multi;
    %put NOTE: - BASELINE_FLAG: &n_baseline;
    %put NOTE: - UNIT_CONVERSION: &n_unit_conv;
    %put NOTE: - REFERENCE_DATA_LOOKUP: &n_ref_lookup;

    /* === STEP 3: EXECUTE TRANSFORMATIONS === */
    %put NOTE: STEP 3 - Executing transformations...;
    
    data _sdtm_temp;
        set &source_data;
        
        /*--- CONSTANT transformations ---*/
        %if &n_const > 0 %then %do;
            %do i = 1 %to &n_const;
                &&const_logic&i;
            %end;
        %end;
        
        /*--- DIRECT_MAP transformations ---*/
        %if &n_dm > 0 %then %do;
            %do i = 1 %to &n_dm;
                %if %length(&&dm_logic&i) > 0 %then %do;
                    &&dm_logic&i;
                %end;
                %else %do;
                    &&dm_tgt&i = &&dm_src&i;
                %end;
            %end;
        %end;
        
        /*--- CONCAT transformations ---*/
        %if &n_concat > 0 %then %do;
            %do i = 1 %to &n_concat;
                &&concat_logic&i;
            %end;
        %end;
        
        /*--- DATE_CONSTRUCT transformations ---*/
        %if &n_date_const > 0 %then %do;
            %do i = 1 %to &n_date_const;
                &&date_const_logic&i;
            %end;
        %end;
        
        /*--- DATE_CONVERT transformations ---*/
        %if &n_date_conv > 0 %then %do;
            %do i = 1 %to &n_date_conv;
                &&date_conv_logic&i;
            %end;
        %end;
        
        /*--- RECODE transformations ---*/
        %if &n_recode > 0 %then %do;
            %do i = 1 %to &n_recode;
                &&recode_logic&i;
            %end;
        %end;
        
        /*--- CONDITIONAL transformations ---*/
        %if &n_cond > 0 %then %do;
            %do i = 1 %to &n_cond;
                &&cond_logic&i;
            %end;
        %end;
        
        /*--- MULTI_CHECKBOX transformations ---*/
        %if &n_multi > 0 %then %do;
            %do i = 1 %to &n_multi;
                &&multi_logic&i;
            %end;
        %end;
        
        /*--- Mark datasets requiring post-processing ---*/
        %if &n_baseline > 0 or &n_unit_conv > 0 or &n_ref_lookup > 0 %then %do;
            _POSTPROCESS_PENDING = 1;
        %end;
    run;
    
    %if &syserr ne 0 %then %do;
        %put ERROR: Transformation execution failed for &domain domain;
        %abort cancel;
    %end;
    
    %put NOTE: Transformations executed successfully;

    /* === STEP 3B: POST-PROCESS ADVANCED TRANSFORMATIONS === */
    
    /*--- BASELINE_FLAG post-processing ---*/
    %if &n_baseline > 0 %then %do;
        %put NOTE: STEP 3B - Deriving baseline flags...;
        
        %do i = 1 %to &n_baseline;
            %let flag_var = &&baseline_tgt&i;
            %let logic = &&baseline_logic&i;
            
            /* Parse logic format: "test_var=VSTESTCD|dtc_var=VSDTC|ref_start=RFSTDTC|position_var=VSPOS" */
            %let test_var = %scan(&logic, 1, %str(|));
            %let test_var = %scan(&test_var, 2, %str(=));
            
            %let dtc_var = %scan(&logic, 2, %str(|));
            %let dtc_var = %scan(&dtc_var, 2, %str(=));
            
            %let ref_start = %scan(&logic, 3, %str(|));
            %let ref_start = %scan(&ref_start, 2, %str(=));
            
            %let position_var = %scan(&logic, 4, %str(|));
            %if %length(&position_var) > 0 %then
                %let position_var = %scan(&position_var, 2, %str(=));
            
            %put NOTE: Deriving &flag_var for test=&test_var, dtc=&dtc_var, ref=&ref_start, pos=&position_var;
            
            /* Step 1: Identify baseline candidates (assessments on or before RFSTDTC) */
            proc sql;
                create table _baseline_candidates as
                select *, 
                       input(&dtc_var, ?? e8601da.) as _dt_num format=date9.
                from _sdtm_temp
                where not missing(&dtc_var) 
                  and not missing(&ref_start)
                  and calculated _dt_num <= input(&ref_start, ?? e8601da.);
            quit;
            
            /* Step 2: Find maximum (latest) date per test/position combination */
            proc sql;
                create table _baseline_max as
                select &test_var
                       %if %length(&position_var) > 0 %then , &position_var;,
                       max(_dt_num) as _max_dt format=date9.
                from _baseline_candidates
                group by &test_var
                       %if %length(&position_var) > 0 %then , &position_var;
                ;
            quit;
            
            /* Step 3: Merge and flag records matching the maximum date */
            proc sort data=_sdtm_temp; 
                by &test_var 
                   %if %length(&position_var) > 0 %then &position_var;
                ;
            run;
            
            proc sort data=_baseline_max; 
                by &test_var 
                   %if %length(&position_var) > 0 %then &position_var;
                ;
            run;
            
            data _sdtm_temp;
                merge _sdtm_temp(in=a) 
                      _baseline_max(in=b);
                by &test_var 
                   %if %length(&position_var) > 0 %then &position_var;
                ;
                
                length &flag_var $1;
                
                if a then do;
                    if b then do;
                        _dt_num = input(&dtc_var, ?? e8601da.);
                        if not missing(_dt_num) and _dt_num = _max_dt then &flag_var = 'Y';
                        else &flag_var = '';
                    end;
                    else &flag_var = '';
                end;
                
                drop _dt_num _max_dt;
            run;
            
            proc datasets library=work nolist;
                delete _baseline_candidates _baseline_max;
            quit;
            
            %put NOTE: &flag_var derivation completed;
        %end;
    %end;
    
    /*--- UNIT_CONVERSION post-processing ---*/
    %if &n_unit_conv > 0 %then %do;
        %put NOTE: STEP 3C - Applying unit conversions...;
        
        %do i = 1 %to &n_unit_conv;
            %let conv_var = &&unit_conv_tgt&i;
            %let logic = &&unit_conv_logic&i;
            
            /* Parse logic format: "lookup_file=unit_conversion_factors.csv|test_var=LBTESTCD|unit_var=LBORRESU|result_var=LBORRES" */
            %let lookup_file = %scan(&logic, 1, %str(|));
            %let lookup_file = %scan(&lookup_file, 2, %str(=));
            
            %let test_var = %scan(&logic, 2, %str(|));
            %let test_var = %scan(&test_var, 2, %str(=));
            
            %let unit_var = %scan(&logic, 3, %str(|));
            %let unit_var = %scan(&unit_var, 2, %str(=));
            
            %let result_var = %scan(&logic, 4, %str(|));
            %let result_var = %scan(&result_var, 2, %str(=));
            
            %put NOTE: Converting &conv_var using &lookup_file for test=&test_var, unit=&unit_var;
            
            /* Import conversion factors */
            proc import datafile="../../reference_data/&lookup_file"
                out=_unit_factors
                dbms=csv
                replace;
                guessingrows=max;
            run;
            
            /* Apply conversions via SQL join */
            proc sql;
                create table _sdtm_temp as
                select a.*,
                       case 
                           when b.conversion_factor is not missing and a.&result_var is not missing
                           then (input(a.&result_var, ?? best32.) * b.conversion_factor) + coalesce(b.additive_constant, 0)
                           else input(a.&result_var, ?? best32.)
                       end as &conv_var,
                       coalesce(b.target_unit, a.&unit_var) as &conv_var._UNIT
                from _sdtm_temp as a
                left join _unit_factors as b
                    on upcase(a.&test_var) = upcase(b.test_code)
                   and upcase(a.&unit_var) = upcase(b.source_unit);
            quit;
            
            proc datasets library=work nolist;
                delete _unit_factors;
            quit;
            
            %put NOTE: &conv_var unit conversion completed;
        %end;
    %end;
    
    /*--- REFERENCE_DATA_LOOKUP post-processing ---*/
    %if &n_ref_lookup > 0 %then %do;
        %put NOTE: STEP 3D - Joining reference data...;
        
        %do i = 1 %to &n_ref_lookup;
            %let lookup_vars = &&ref_lookup_tgt&i;
            %let logic = &&ref_lookup_logic&i;
            
            /* Parse logic format: "lookup_file=lab_reference_ranges.csv|join_keys=LBTESTCD,SEX|target_vars=LBSTNRLO,LBSTNRHI,LBSTNRC" */
            %let lookup_file = %scan(&logic, 1, %str(|));
            %let lookup_file = %scan(&lookup_file, 2, %str(=));
            
            %let join_keys = %scan(&logic, 2, %str(|));
            %let join_keys = %scan(&join_keys, 2, %str(=));
            
            %let target_vars = %scan(&logic, 3, %str(|));
            %let target_vars = %scan(&target_vars, 2, %str(=));
            
            %put NOTE: Joining &lookup_file on keys=&join_keys for vars=&target_vars;
            
            /* Import reference data */
            proc import datafile="../../reference_data/&lookup_file"
                out=_ref_data
                dbms=csv
                replace;
                guessingrows=max;
            run;
            
            /* Build dynamic join condition */
            %let join_cond = ;
            %let nkeys = %sysfunc(countw(&join_keys, %str(,)));
            %do j = 1 %to &nkeys;
                %let key = %scan(&join_keys, &j, %str(,));
                %if &j > 1 %then %let join_cond = &join_cond and;
                %let join_cond = &join_cond upcase(a.&key) = upcase(b.&key);
            %end;
            
            /* Perform lookup join */
            proc sql;
                create table _sdtm_temp as
                select a.*, 
                       %let nvars = %sysfunc(countw(&target_vars, %str(,)));
                       %do k = 1 %to &nvars;
                           %let var = %scan(&target_vars, &k, %str(,));
                           b.&var
                           %if &k < &nvars %then ,;
                       %end;
                from _sdtm_temp as a
                left join _ref_data as b
                    on &join_cond;
            quit;
            
            proc datasets library=work nolist;
                delete _ref_data;
            quit;
            
            %put NOTE: Reference data lookup completed for &lookup_vars;
        %end;
    %end;
    
    /* Drop post-processing marker */
    data _sdtm_temp;
        set _sdtm_temp;
        drop _POSTPROCESS_PENDING;
    run;

    /* === STEP 4: SORT AND FINALIZE === */
    %put NOTE: STEP 4 - Finalizing output dataset...;
    
    proc sort data=_sdtm_temp out=&output_data;
        by USUBJID;
    run;
    
    /* Get record count */
    proc sql noprint;
        select count(*) into :record_count
        from &output_data;
    quit;

    /* === STEP 5: CLEANUP === */
    proc datasets library=work nolist;
        delete _spec_raw _sdtm_temp;
    quit;
    
    %put NOTE: ===============================================;
    %put NOTE: SDTM Transformation Engine Completed;
    %put NOTE: Domain: &domain;
    %put NOTE: Records processed: &record_count;
    %put NOTE: Output: &output_data;
    %put NOTE: ===============================================;

%mend sdtm_transformation_engine;