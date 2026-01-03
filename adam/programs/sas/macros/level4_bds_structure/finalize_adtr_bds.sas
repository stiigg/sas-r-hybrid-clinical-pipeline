/******************************************************************************
 * Program: finalize_adtr_bds.sas
 * Purpose: Integration wrapper for Level 4 BDS structure macros
 * Author: Clinical Programming Team
 * Date: 2026-01-03
 * 
 * Description:
 *   Executes all Level 4 macros in sequence to finalize ADTR with:
 *   - PARCAT1/2/3: Parameter categorization
 *   - CRIT1-4 + flags: RECIST 1.1 criterion documentation
 *   - ANL01FL-04FL: Analysis subset flags
 *   - SRCDOM/SRCVAR/SRCSEQ: SDTM source traceability
 * 
 * Prerequisites:
 *   - Level 1-3 macros completed (BASE, NADIR, PARAMCD, AVAL, AVALC)
 *   - SDTM domains: TR (measurements), TU (classification)
 *   - ADSL with population flags (SAFFL, ITTFL, PPROTFL)
 *   - New lesion detection results
 * 
 * Usage:
 *   %finalize_adtr_bds(
 *       input_ds=work.adtr,
 *       output_ds=work.adtr_final,
 *       adsl_ds=work.adsl,
 *       tu_ds=work.tu,
 *       new_lesion_ds=work.new_lesions,
 *       enaworu_rule=Y
 *   );
 * 
 * Parameters:
 *   - input_ds: Input ADTR dataset from Level 3
 *   - output_ds: Final ADTR dataset with BDS variables
 *   - adsl_ds: ADSL with population flags
 *   - tu_ds: TU domain with organ/location/classification
 *   - new_lesion_ds: New lesion detection results
 *   - enaworu_rule: Apply Enaworu 25mm rule (Y/N, default=Y)
 *   - create_adrg: Generate ADRG documentation (Y/N, default=Y)
 *****************************************************************************/

%macro finalize_adtr_bds(
    input_ds=work.adtr,
    output_ds=work.adtr_final,
    adsl_ds=work.adsl,
    tu_ds=work.tu,
    new_lesion_ds=work.new_lesions,
    enaworu_rule=Y,
    create_adrg=Y
);

    %put %str(============================================================);
    %put %str(NOTE: [FINALIZE_ADTR_BDS] Starting Level 4 BDS finalization);
    %put %str(NOTE: [FINALIZE_ADTR_BDS] Input: &input_ds);
    %put %str(NOTE: [FINALIZE_ADTR_BDS] Output: &output_ds);
    %put %str(============================================================);

    /* Store start time */
    %let start_time = %sysfunc(datetime());

    /* ========================================
     * STEP 1: Add PARCAT variables
     * ======================================== */
    %put %str( );
    %put %str(NOTE: [FINALIZE_ADTR_BDS] STEP 1/4: Adding PARCAT1/2/3...);
    
    %add_parcat_vars(
        input_ds=&input_ds,
        output_ds=work._adtr_step1,
        tu_class=&tu_ds
    );
    
    /* QC Checkpoint */
    proc sql noprint;
        select count(*) into :n_step1 from work._adtr_step1;
    quit;
    %put %str(NOTE: [FINALIZE_ADTR_BDS] STEP 1 Complete: &n_step1 records);

    /* ========================================
     * STEP 2: Add CRIT flags
     * ======================================== */
    %put %str( );
    %put %str(NOTE: [FINALIZE_ADTR_BDS] STEP 2/4: Adding CRIT1-4 flags...);
    
    %add_crit_flags(
        input_ds=work._adtr_step1,
        output_ds=work._adtr_step2,
        new_lesion_ds=&new_lesion_ds,
        enaworu_rule=&enaworu_rule
    );
    
    /* QC Checkpoint */
    proc sql noprint;
        select count(*) into :n_step2 from work._adtr_step2;
    quit;
    %put %str(NOTE: [FINALIZE_ADTR_BDS] STEP 2 Complete: &n_step2 records);

    /* ========================================
     * STEP 3: Add ANL flags
     * ======================================== */
    %put %str( );
    %put %str(NOTE: [FINALIZE_ADTR_BDS] STEP 3/4: Adding ANL01FL-04FL...);
    
    %add_anl_flags(
        input_ds=work._adtr_step2,
        output_ds=work._adtr_step3,
        adsl_ds=&adsl_ds
    );
    
    /* QC Checkpoint */
    proc sql noprint;
        select count(*) into :n_step3 from work._adtr_step3;
    quit;
    %put %str(NOTE: [FINALIZE_ADTR_BDS] STEP 3 Complete: &n_step3 records);

    /* ========================================
     * STEP 4: Add source traceability
     * ======================================== */
    %put %str( );
    %put %str(NOTE: [FINALIZE_ADTR_BDS] STEP 4/4: Adding SRCDOM/SRCVAR/SRCSEQ...);
    
    %add_source_trace(
        input_ds=work._adtr_step3,
        output_ds=&output_ds,
        create_adrg_table=&create_adrg
    );
    
    /* Final QC Checkpoint */
    proc sql noprint;
        select count(*) into :n_final from &output_ds;
    quit;
    %put %str(NOTE: [FINALIZE_ADTR_BDS] STEP 4 Complete: &n_final records);

    /* ========================================
     * FINAL QC SUMMARY
     * ======================================== */
    %put %str( );
    %put %str(============================================================);
    %put %str(NOTE: [FINALIZE_ADTR_BDS] FINAL QC SUMMARY);
    %put %str(============================================================);
    
    proc contents data=&output_ds varnum short;
        title "Final ADTR Variable List";
    run;
    title;
    
    proc sql;
        /* Variable counts by category */
        select 
            'Level 4 BDS Variables' as CATEGORY,
            count(*) as N_VARIABLES
        from dictionary.columns
        where libname='WORK' and memname=upcase(scan("&output_ds", 2, '.'))
          and upcase(name) in (
              'PARCAT1', 'PARCAT2', 'PARCAT3',
              'CRIT1', 'CRIT1FL', 'CRIT2', 'CRIT2FL', 'CRIT3', 'CRIT3FL', 'CRIT4', 'CRIT4FL',
              'ANL01FL', 'ANL02FL', 'ANL03FL', 'ANL04FL',
              'SRCDOM', 'SRCVAR', 'SRCSEQ'
          );
        
        /* Record counts by key groups */
        select 
            'Total Records' as METRIC,
            count(*) as N format=comma12.
        from &output_ds
        union all
        select 
            'Unique Subjects' as METRIC,
            count(distinct USUBJID) as N format=comma12.
        from &output_ds
        union all
        select 
            'Unique Parameters' as METRIC,
            count(distinct PARAMCD) as N format=comma12.
        from &output_ds;
        
        /* BDS variable completeness */
        select 
            'PARCAT1 populated' as VARIABLE,
            sum(case when not missing(PARCAT1) then 1 else 0 end) as N_POPULATED format=comma12.,
            calculated N_POPULATED / count(*) * 100 as PCT_COMPLETE format=5.1
        from &output_ds
        union all
        select 
            'CRIT flags (post-BL)' as VARIABLE,
            sum(case when ADY>=1 and not missing(CRIT1FL) then 1 else 0 end) as N_POPULATED format=comma12.,
            calculated N_POPULATED / sum(case when ADY>=1 then 1 else 0 end) * 100 as PCT_COMPLETE format=5.1
        from &output_ds
        union all
        select 
            'ANL flags populated' as VARIABLE,
            sum(case when not missing(ANL01FL) or not missing(ANL02FL) or 
                          not missing(ANL03FL) or not missing(ANL04FL) then 1 else 0 end) as N_POPULATED format=comma12.,
            calculated N_POPULATED / count(*) * 100 as PCT_COMPLETE format=5.1
        from &output_ds
        union all
        select 
            'SRCDOM populated' as VARIABLE,
            sum(case when not missing(SRCDOM) then 1 else 0 end) as N_POPULATED format=comma12.,
            calculated N_POPULATED / count(*) * 100 as PCT_COMPLETE format=5.1
        from &output_ds;
    quit;

    /* ========================================
     * CLEANUP INTERMEDIATE DATASETS
     * ======================================== */
    proc datasets library=work nolist;
        delete _adtr_step1 _adtr_step2 _adtr_step3;
    quit;

    /* Calculate elapsed time */
    %let end_time = %sysfunc(datetime());
    %let elapsed = %sysevalf(&end_time - &start_time);
    %let elapsed_min = %sysevalf(&elapsed / 60);
    
    %put %str( );
    %put %str(============================================================);
    %put %str(NOTE: [FINALIZE_ADTR_BDS] Level 4 BDS finalization COMPLETE);
    %put %str(NOTE: [FINALIZE_ADTR_BDS] Final dataset: &output_ds);
    %put %str(NOTE: [FINALIZE_ADTR_BDS] Record count: &n_final);
    %put %str(NOTE: [FINALIZE_ADTR_BDS] Elapsed time: %sysfunc(putn(&elapsed_min, 5.2)) minutes);
    %put %str(============================================================);
    %put %str( );
    
    %put %str(NOTE: [FINALIZE_ADTR_BDS] Research Citations:);
    %put %str(NOTE: [FINALIZE_ADTR_BDS] - CDISC ADaM Guide 2026 (PARCAT));
    %put %str(NOTE: [FINALIZE_ADTR_BDS] - CDISC KB 2024 (CRIT flags));
    %put %str(NOTE: [FINALIZE_ADTR_BDS] - Enaworu Cureus 2025 PMC12094296 (25mm rule));
    %put %str(NOTE: [FINALIZE_ADTR_BDS] - PharmaSUG 2025-DS-065 (SRCDOM traceability));
    %put %str( );

%mend finalize_adtr_bds;
