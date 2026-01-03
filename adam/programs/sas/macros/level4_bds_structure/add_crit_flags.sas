/******************************************************************************
 * Program: add_crit_flags.sas
 * Purpose: Add CRIT1-4 criterion flags documenting RECIST 1.1 algorithm logic
 * Author: Clinical Programming Team
 * Date: 2026-01-03
 * 
 * Research Citations:
 * - CDISC KB: ADaM BDS using CRIT variables (Updated 2024)
 *   https://www.cdisc.org/kb/examples/adam-basic-data-structure-bds-using-crit
 * - Enaworu 25mm Rule: Cureus 2025, PMC12094296
 *   https://pmc.ncbi.nlm.nih.gov/articles/PMC12094296/
 * 
 * Inputs:
 *   - adtr_in: ADTR with BASE, NADIR, AVAL, AVALC
 *   - new_lesions: Dataset with new lesion flags
 * 
 * Outputs:
 *   - adtr_out: ADTR with CRIT1-4 and CRIT1FL-4FL
 * 
 * Algorithm Logic:
 *   CRIT1: Standard RECIST 1.1 progression (≥20% AND ≥5mm from nadir)
 *   CRIT2: New lesions detected post-baseline
 *   CRIT3: Enaworu 25mm nadir rule (simplified PD criteria)
 *   CRIT4: Non-target lesion unequivocal progression
 * 
 * Parameters:
 *   - input_ds: Input ADTR dataset
 *   - output_ds: Output ADTR dataset
 *   - new_lesion_ds: New lesion detection results
 *   - enaworu_rule: Apply Enaworu 25mm rule (Y/N, default=Y)
 *****************************************************************************/

%macro add_crit_flags(
    input_ds=work.adtr,
    output_ds=work.adtr,
    new_lesion_ds=work.new_lesions,
    enaworu_rule=Y
);

    %put %str(NOTE: [ADD_CRIT_FLAGS] Adding RECIST 1.1 criterion flags...);
    %put %str(NOTE: [ADD_CRIT_FLAGS] Enaworu 25mm rule: &enaworu_rule);

    /* Step 1: Merge new lesion detection results */
    proc sql;
        create table _crit_prep as
        select 
            a.*,
            b.NEW_LESION_FL,
            b.NEW_LESION_DT
        from &input_ds as a
        left join &new_lesion_ds as b
            on a.USUBJID=b.USUBJID and a.ADT=b.ADT
        order by USUBJID, PARAMCD, ADT;
    quit;

    /* Step 2: Derive CRIT variables and flags */
    data &output_ds;
        set _crit_prep;
        
        /* Initialize CRIT variables */
        length CRIT1 CRIT2 CRIT3 CRIT4 $200;
        length CRIT1FL CRIT2FL CRIT3FL CRIT4FL $1;
        
        /* Only evaluate CRIT for post-baseline records */
        if ADY >= 1 then do;
        
            /* CRIT1: Standard RECIST 1.1 Progression */
            /* Applies to TARGET lesions (SDIAM) only */
            CRIT1 = 'TARGET LESIONS: >=20% increase from nadir AND >=5mm absolute increase';
            
            if PARAMCD='SDIAM' and not missing(NADIR) and not missing(AVAL) then do;
                if (AVAL - NADIR) >= 5 and 
                   ((AVAL - NADIR) / NADIR) >= 0.20 then 
                    CRIT1FL = 'Y';
                else 
                    CRIT1FL = '';
            end;
            else 
                CRIT1FL = '';
            
            /* CRIT2: New Lesions Detected */
            CRIT2 = 'NEW LESIONS: Unequivocal new lesion(s) detected post-baseline';
            
            if NEW_LESION_FL='Y' then 
                CRIT2FL = 'Y';
            else 
                CRIT2FL = '';
            
            /* CRIT3: Enaworu 25mm Nadir Rule (Optional) */
            %if &enaworu_rule=Y %then %do;
                CRIT3 = 'ENAWORU RULE: Nadir >=25mm uses 20% only; <25mm uses 5mm only (Cureus 2025, PMC12094296)';
                
                if PARAMCD='SDIAM' and not missing(NADIR) and not missing(AVAL) then do;
                    /* Nadir >= 25mm: Only 20% increase required */
                    if NADIR >= 25 and ((AVAL - NADIR) / NADIR) >= 0.20 then 
                        CRIT3FL = 'Y';
                    /* Nadir < 25mm: Only 5mm absolute increase required */
                    else if NADIR < 25 and (AVAL - NADIR) >= 5 then 
                        CRIT3FL = 'Y';
                    else 
                        CRIT3FL = '';
                end;
                else 
                    CRIT3FL = '';
            %end;
            %else %do;
                CRIT3 = '';
                CRIT3FL = '';
            %end;
            
            /* CRIT4: Non-Target Lesion Progression */
            CRIT4 = 'NON-TARGET LESIONS: Unequivocal progression of existing non-target lesion(s)';
            
            if PARAMCD='SNTLDIAM' and AVALC='UNEQUIVOCAL PROGRESSION' then 
                CRIT4FL = 'Y';
            else if PARAMCD='LDIAM' and PARCAT2='NON-TARGET LESIONS' 
                and AVALC='UNEQUIVOCAL PROGRESSION' then
                CRIT4FL = 'Y';
            else 
                CRIT4FL = '';
                
        end;
        else do;
            /* Baseline records: no CRIT evaluation */
            CRIT1=''; CRIT1FL='';
            CRIT2=''; CRIT2FL='';
            CRIT3=''; CRIT3FL='';
            CRIT4=''; CRIT4FL='';
        end;
        
        /* Add variable labels */
        label
            CRIT1 = 'Criterion 1: Standard RECIST 1.1 PD'
            CRIT1FL = 'Criterion 1 Evaluation Result Flag'
            CRIT2 = 'Criterion 2: New Lesions'
            CRIT2FL = 'Criterion 2 Evaluation Result Flag'
            CRIT3 = 'Criterion 3: Enaworu 25mm Rule'
            CRIT3FL = 'Criterion 3 Evaluation Result Flag'
            CRIT4 = 'Criterion 4: Non-Target Progression'
            CRIT4FL = 'Criterion 4 Evaluation Result Flag';
            
        /* Drop temporary variables */
        drop NEW_LESION_FL NEW_LESION_DT;
    run;

    /* Step 3: QC Report - CRIT Flag Summary */
    proc freq data=&output_ds;
        where ADY >= 1;  /* Post-baseline only */
        tables PARAMCD * (CRIT1FL CRIT2FL CRIT3FL CRIT4FL) / missing nocum;
        title "QC: CRIT Flag Distribution (Post-Baseline)";
    run;

    /* Step 4: Validation - Any CRIT=Y should have AVALC containing PD */
    proc sql;
        create table _crit_validation as
        select USUBJID, PARAMCD, ADT, AVALC,
               CRIT1FL, CRIT2FL, CRIT3FL, CRIT4FL,
               'CRIT flag without PD' as ISSUE
        from &output_ds
        where ADY >= 1
          and (CRIT1FL='Y' or CRIT2FL='Y' or CRIT3FL='Y' or CRIT4FL='Y')
          and not (index(upcase(AVALC), 'PD') > 0 or index(upcase(AVALC), 'PROGRESS') > 0);
    quit;
    
    %let n_violations=&sqlobs;
    %if &n_violations > 0 %then %do;
        %put WARNING: [ADD_CRIT_FLAGS] &n_violations records have CRIT=Y without AVALC=PD;
        proc print data=_crit_validation;
            title "WARNING: CRIT Flag Inconsistencies";
        run;
    %end;
    %else %do;
        %put %str(NOTE: [ADD_CRIT_FLAGS] CRIT flag validation PASSED);
    %end;
    title;

    /* Cleanup */
    proc datasets library=work nolist;
        delete _crit_prep _crit_validation;
    quit;

    %put %str(NOTE: [ADD_CRIT_FLAGS] CRIT variables complete.);
    %put %str(NOTE: [ADD_CRIT_FLAGS] Research citations: CDISC KB 2024, Enaworu Cureus 2025);

%mend add_crit_flags;
