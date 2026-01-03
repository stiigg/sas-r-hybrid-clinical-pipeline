/******************************************************************************
* Macro: CLASSIFY_LESIONS
* Purpose: Classify lesions as TARGET/NON-TARGET per RECIST 1.1
* Version: 1.0
* 
* PARAMETERS:
*   tr_ds          - TR dataset with measurements
*   tu_ds          - TU dataset with lesion identification
*   outds          - Output dataset with classification
*   max_target     - Maximum target lesions per subject (default: 5)
*   max_per_organ  - Maximum target lesions per organ (default: 2)
*
* ALGORITHM:
*   - Merge TR measurements with TU lesion identification
*   - Apply RECIST 1.1 target lesion selection criteria:
*     * Measurable: ≥10mm lymph nodes, ≥20mm non-nodal lesions
*     * Maximum 5 target lesions total
*     * Maximum 2 target lesions per organ
*   - Prioritize larger, representative lesions
*   - Classify remaining as non-target
*
* VALIDATION:
*   - Verify TULINKID linkage
*   - Check measurability criteria
*   - Report target lesion counts by subject and organ
*
* REFERENCES:
*   - EORTC RECIST 1.1 (2009): Target lesion selection
*   - Reproducing RECIST Selection ML Study (2024): Inter-reader variability
*   - NRG Oncology 2025: Common RECIST errors
*
* EXAMPLE USAGE:
*   %classify_lesions(
*       tr_ds=work.tr_raw,
*       tu_ds=work.tu_raw,
*       outds=work.tr_classified,
*       max_target=5,
*       max_per_organ=2
*   );
*
* AUTHOR: Christian Baghai
* DATE: 2026-01-03
******************************************************************************/

%macro classify_lesions(
    tr_ds=,
    tu_ds=,
    outds=,
    max_target=5,
    max_per_organ=2
) / des="Classify lesions as TARGET/NON-TARGET per RECIST 1.1";

    /* Parameter validation */
    %if %length(&tr_ds) = 0 or %length(&tu_ds) = 0 or %length(&outds) = 0 %then %do;
        %put ERROR: [CLASSIFY_LESIONS] Parameters TR_DS, TU_DS, and OUTDS are required;
        %return;
    %end;
    
    %put NOTE: [CLASSIFY_LESIONS] Starting lesion classification per RECIST 1.1;
    %put NOTE: [CLASSIFY_LESIONS] Max target lesions: &max_target (total), &max_per_organ (per organ);
    
    /* Merge TR with TU to get lesion characteristics */
    proc sql;
        create table _tr_tu_merged as
        select 
            a.*,
            b.TUEVAL as TU_EVAL,
            b.TUORRES,
            b.TULOC,
            b.TULOCCAT,
            b.TUMETHOD
        from &tr_ds as a
        left join &tu_ds as b
            on a.USUBJID = b.USUBJID
           and a.TULINKID = b.TULINKID
        where not missing(a.TULINKID);
    quit;
    
    /* For lesion diameter measurements at baseline */
    proc sql;
        create table _baseline_lesions as
        select 
            USUBJID,
            TULINKID,
            TULOCCAT,
            TULOC,
            TU_EVAL,
            max(TRSTRESN) as MAX_DIAMETER,
            /* Determine if measurable per RECIST 1.1 */
            case
                when upcase(TULOC) contains 'LYMPH' or upcase(TULOC) contains 'NODE' 
                     then case when calculated MAX_DIAMETER >= 10 then 'Y' else 'N' end
                else case when calculated MAX_DIAMETER >= 20 then 'Y' else 'N' end
            end as MEASURABLE_FL
        from _tr_tu_merged
        where TRTESTCD in ('LDIAM', 'LPERP')
        group by USUBJID, TULINKID, TULOCCAT, TULOC, TU_EVAL;
    quit;
    
    /* Rank lesions for target selection within each subject and organ */
    proc sql;
        create table _lesions_ranked as
        select *,
            monotonic() as _rank_overall,
            case 
                when MEASURABLE_FL = 'Y' and TU_EVAL = 'TARGET' 
                     then MAX_DIAMETER 
                else 0 
            end as _selection_priority
        from _baseline_lesions
        order by USUBJID, TULOCCAT, _selection_priority desc, TULINKID;
    quit;
    
    /* Apply RECIST 1.1 selection rules */
    data _lesions_classified;
        set _lesions_ranked;
        by USUBJID TULOCCAT;
        
        retain _target_count_subject _target_count_organ;
        
        /* Initialize counters */
        if first.USUBJID then _target_count_subject = 0;
        if first.TULOCCAT then _target_count_organ = 0;
        
        /* Classify lesion */
        length LESION_CLASS $20;
        
        /* Check if eligible for target */
        if MEASURABLE_FL = 'Y' and TU_EVAL = 'TARGET' then do;
            
            /* Apply maximum constraints */
            if _target_count_subject < &max_target and 
               _target_count_organ < &max_per_organ then do;
                
                LESION_CLASS = 'TARGET';
                _target_count_subject + 1;
                _target_count_organ + 1;
                
            end;
            else do;
                /* Exceeds limits, classify as non-target */
                LESION_CLASS = 'NON-TARGET';
            end;
            
        end;
        else do;
            /* Not measurable or originally non-target */
            LESION_CLASS = 'NON-TARGET';
        end;
        
        label LESION_CLASS = "Lesion Classification (TARGET/NON-TARGET)"
              MEASURABLE_FL = "Measurable per RECIST 1.1 (Y/N)";
        
        drop _rank_overall _selection_priority _target_count_subject _target_count_organ;
        
    run;
    
    /* Merge classification back to TR dataset */
    proc sql;
        create table &outds as
        select 
            a.*,
            b.LESION_CLASS,
            b.MEASURABLE_FL,
            b.TULOCCAT,
            b.TULOC
        from &tr_ds as a
        left join _lesions_classified as b
            on a.USUBJID = b.USUBJID
           and a.TULINKID = b.TULINKID
        order by USUBJID, VISITNUM, TULINKID;
    quit;
    
    /* Validation and reporting */
    proc sql;
        title "RECIST 1.1 Lesion Classification Summary";
        
        select 
            'Overall' as Level,
            count(distinct USUBJID) as N_Subjects,
            count(distinct case when LESION_CLASS='TARGET' then TULINKID end) as N_Target_Lesions,
            count(distinct case when LESION_CLASS='NON-TARGET' then TULINKID end) as N_NonTarget_Lesions
        from _lesions_classified
        
        union all
        
        select 
            TULOCCAT as Level,
            count(distinct USUBJID) as N_Subjects,
            count(distinct case when LESION_CLASS='TARGET' then TULINKID end) as N_Target_Lesions,
            count(distinct case when LESION_CLASS='NON-TARGET' then TULINKID end) as N_NonTarget_Lesions
        from _lesions_classified
        group by TULOCCAT
        order by Level;
    quit;
    
    /* Check for violations */
    proc sql noprint;
        create table _violations_max_target as
        select USUBJID, count(*) as n_target
        from _lesions_classified
        where LESION_CLASS = 'TARGET'
        group by USUBJID
        having count(*) > &max_target;
        
        create table _violations_max_organ as
        select USUBJID, TULOCCAT, count(*) as n_target_organ
        from _lesions_classified
        where LESION_CLASS = 'TARGET'
        group by USUBJID, TULOCCAT
        having count(*) > &max_per_organ;
        
        select count(*) into :n_violations_subject trimmed from _violations_max_target;
        select count(*) into :n_violations_organ trimmed from _violations_max_organ;
    quit;
    
    %if &n_violations_subject > 0 %then %do;
        %put ERROR: [CLASSIFY_LESIONS] &n_violations_subject subjects exceed &max_target target lesions;
    %end;
    
    %if &n_violations_organ > 0 %then %do;
        %put ERROR: [CLASSIFY_LESIONS] &n_violations_organ subject-organ combinations exceed &max_per_organ target lesions;
    %end;
    
    %put NOTE: [CLASSIFY_LESIONS] Classification complete;
    
    /* Clean up */
    proc datasets library=work nolist;
        delete _tr_tu_merged _baseline_lesions _lesions_ranked _lesions_classified
               _violations_max_target _violations_max_organ;
    quit;
    
    title;
    
%mend classify_lesions;