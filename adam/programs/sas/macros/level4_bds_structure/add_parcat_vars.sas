/******************************************************************************
 * Program: add_parcat_vars.sas
 * Purpose: Add CDISC ADaM BDS parameter categorization variables (PARCAT1/2/3)
 * Author: Clinical Programming Team
 * Date: 2026-01-03
 * 
 * Research Citation:
 * - CDISC ADaM Implementation Guide 2026: Parameter categorization structure
 *   https://intuitionlabs.ai/articles/cdisc-sdtm-adam-guide
 * 
 * Inputs:
 *   - adtr_in: ADTR dataset with PARAMCD, PARAM
 *   - tu_class: TU domain with lesion classification (TARGET/NON-TARGET)
 * 
 * Outputs:
 *   - adtr_out: ADTR with PARCAT1, PARCAT2, PARCAT3
 * 
 * Parameters:
 *   - input_ds: Input dataset name (default: work.adtr)
 *   - output_ds: Output dataset name (default: work.adtr)
 *   - tu_class: TU classification dataset (default: work.tu)
 * 
 * Categorization Logic:
 *   PARCAT1: Data structure level (INDIVIDUAL LESION vs SUM OF DIAMETERS)
 *   PARCAT2: Organ system (LDIAM) or lesion type (TARGET/NON-TARGET for sums)
 *   PARCAT3: Specific anatomic location + TARGET/NON-TARGET classification
 *****************************************************************************/

%macro add_parcat_vars(
    input_ds=work.adtr,
    output_ds=work.adtr,
    tu_class=work.tu
);

    %put %str(NOTE: [ADD_PARCAT_VARS] Starting parameter categorization...);
    %put %str(NOTE: [ADD_PARCAT_VARS] Input dataset: &input_ds);
    %put %str(NOTE: [ADD_PARCAT_VARS] TU classification: &tu_class);

    /* Step 1: Merge lesion classification from TU domain */
    proc sql;
        create table _parcat_prep as
        select 
            a.*,
            b.TULOCCAT as ORGAN_SYSTEM,
            b.TULOC as SPECIFIC_LOCATION,
            case 
                when b.TUTESTCD='TUMIDENT' and b.TUSTRESC='TARGET' 
                    then 'TARGET'
                when b.TUTESTCD='TUMIDENT' and b.TUSTRESC='NON-TARGET' 
                    then 'NON-TARGET'
                else ''
            end as LESION_CLASS
        from &input_ds as a
        left join &tu_class as b
            on a.USUBJID=b.USUBJID 
            and a.TRLNKID=b.TULNKID
        order by USUBJID, PARAMCD, ADT;
    quit;

    /* Step 2: Assign PARCAT1/2/3 (Highest level categorization) */
    data &output_ds;
        set _parcat_prep;
        
        /* PARCAT1: Data structure level */
        length PARCAT1 $200;
        if PARAMCD='LDIAM' then 
            PARCAT1 = 'INDIVIDUAL LESION';
        else if PARAMCD in ('SDIAM', 'SNTLDIAM') then 
            PARCAT1 = 'SUM OF DIAMETERS';
        else 
            PARCAT1 = '';
            
        /* PARCAT2: Lesion type or anatomic category */
        length PARCAT2 $200;
        if PARAMCD='LDIAM' then do;
            /* Individual lesions: use organ system */
            PARCAT2 = upcase(ORGAN_SYSTEM);
        end;
        else if PARAMCD='SDIAM' then 
            PARCAT2 = 'TARGET LESIONS';
        else if PARAMCD='SNTLDIAM' then 
            PARCAT2 = 'NON-TARGET LESIONS';
        else 
            PARCAT2 = '';
            
        /* PARCAT3: Detailed classification */
        length PARCAT3 $200;
        if PARAMCD='LDIAM' then do;
            /* Individual lesions: specific location + classification */
            if not missing(SPECIFIC_LOCATION) and not missing(LESION_CLASS) then
                PARCAT3 = catx(': ', upcase(SPECIFIC_LOCATION), LESION_CLASS);
            else if not missing(LESION_CLASS) then
                PARCAT3 = LESION_CLASS;
            else
                PARCAT3 = '';
        end;
        else 
            PARCAT3 = '';
            
        /* Add variable labels */
        label 
            PARCAT1 = 'Parameter Category 1'
            PARCAT2 = 'Parameter Category 2'
            PARCAT3 = 'Parameter Category 3';
            
        /* Drop temporary merge variables */
        drop ORGAN_SYSTEM SPECIFIC_LOCATION LESION_CLASS;
    run;

    /* Step 3: QC Report - PARCAT distribution */
    proc freq data=&output_ds;
        tables PARAMCD*PARCAT1*PARCAT2 / list missing;
        title "QC: PARCAT Variable Distribution";
    run;
    
    proc sql;
        select distinct PARAMCD, PARCAT1, PARCAT2, PARCAT3
        from &output_ds
        where not missing(PARCAT1)
        order by PARAMCD, PARCAT1, PARCAT2;
    quit;
    title;

    /* Step 4: Validation - Check for missing PARCAT1 */
    proc sql noprint;
        select count(*) into :n_missing_parcat
        from &output_ds
        where PARAMCD in ('LDIAM', 'SDIAM', 'SNTLDIAM')
          and missing(PARCAT1);
    quit;
    
    %if &n_missing_parcat > 0 %then %do;
        %put WARNING: [ADD_PARCAT_VARS] &n_missing_parcat records missing PARCAT1;
    %end;
    %else %do;
        %put %str(NOTE: [ADD_PARCAT_VARS] PARCAT validation PASSED);
    %end;

    /* Cleanup */
    proc datasets library=work nolist;
        delete _parcat_prep;
    quit;

    %put %str(NOTE: [ADD_PARCAT_VARS] Categorization complete.);
    %put %str(NOTE: [ADD_PARCAT_VARS] Research citation: CDISC ADaM Guide 2026);

%mend add_parcat_vars;
