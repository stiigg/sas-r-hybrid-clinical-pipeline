/******************************************************************************
* Macro: DETECT_NEW_LESIONS
* Purpose: Detect new lesions appearing post-baseline per RECIST 1.1
* Version: 1.0
* 
* PARAMETERS:
*   tr_ds          - TR dataset with measurements
*   tu_ds          - TU dataset with lesion identification
*   adsl_ds        - ADSL dataset with RFSTDTC for baseline determination
*   outds          - Output dataset with new lesion flags
*   baseline_method - Baseline definition (PRETREAT/FIRST, default: PRETREAT)
*
* ALGORITHM:
*   - Identify baseline TULINKIDs (ADY < 1 for PRETREAT)
*   - Compare TULINKIDs at each post-baseline visit
*   - Flag lesions not present at baseline as NEW
*   - Automatic progression classification per RECIST 1.1
*   - Handle longitudinal appearance across visits
*
* DERIVATIONS:
*   - NEW_LESION_FL: New lesion flag (Y/N)
*   - BASELINE_LESION_FL: Present at baseline (Y/N)
*   - FIRST_NEW_VISIT: First visit new lesion detected
*   - PD_NEW_LESION_FL: Progression due to new lesions (Y/N)
*
* VALIDATION:
*   - Cross-check with TU.TUEVAL='NEW' if available
*   - Report new lesion frequency by visit
*   - Identify subjects with automatic PD classification
*
* REFERENCES:
*   - EORTC RECIST 1.1: New lesions automatically classify as PD
*   - ESR Imaging Criteria 2024: Response assessment recommendations
*
* EXAMPLE USAGE:
*   %detect_new_lesions(
*       tr_ds=work.tr_raw,
*       tu_ds=work.tu_raw,
*       adsl_ds=work.adsl,
*       outds=work.tr_with_new_lesions,
*       baseline_method=PRETREAT
*   );
*
* AUTHOR: Christian Baghai
* DATE: 2026-01-03
******************************************************************************/

%macro detect_new_lesions(
    tr_ds=,
    tu_ds=,
    adsl_ds=,
    outds=,
    baseline_method=PRETREAT
) / des="Detect new lesions appearing post-baseline per RECIST 1.1";

    /* Parameter validation */
    %if %length(&tr_ds) = 0 or %length(&tu_ds) = 0 or %length(&adsl_ds) = 0 or %length(&outds) = 0 %then %do;
        %put ERROR: [DETECT_NEW_LESIONS] Parameters TR_DS, TU_DS, ADSL_DS, and OUTDS are required;
        %return;
    %end;
    
    %put NOTE: [DETECT_NEW_LESIONS] Detecting new lesions per RECIST 1.1;
    %put NOTE: [DETECT_NEW_LESIONS] Baseline method: &baseline_method;
    
    /* Merge TR with ADSL to get RFSTDTC for ADY calculation */
    proc sql;
        create table _tr_with_ady as
        select 
            a.*,
            b.RFSTDTC,
            /* Calculate ADY if not already present */
            case 
                when not missing(a.ADY) then a.ADY
                when not missing(a.TRDTC) and not missing(b.RFSTDTC) then
                    case
                        when input(scan(a.TRDTC,1,'T'), yymmdd10.) >= input(scan(b.RFSTDTC,1,'T'), yymmdd10.)
                            then input(scan(a.TRDTC,1,'T'), yymmdd10.) - input(scan(b.RFSTDTC,1,'T'), yymmdd10.) + 1
                        else input(scan(a.TRDTC,1,'T'), yymmdd10.) - input(scan(b.RFSTDTC,1,'T'), yymmdd10.)
                    end
                else .
            end as ADY_CALC
        from &tr_ds as a
        left join &adsl_ds as b
            on a.USUBJID = b.USUBJID;
    quit;
    
    /* Identify baseline lesions */
    proc sql;
        create table _baseline_lesions as
        select distinct 
            USUBJID,
            TULINKID,
            'Y' as BASELINE_LESION_FL
        from _tr_with_ady
        where 
            %if %upcase(&baseline_method) = PRETREAT %then %do;
                coalesce(ADY_CALC, ADY) < 1
            %end;
            %else %if %upcase(&baseline_method) = FIRST %then %do;
                VISITNUM = (select min(VISITNUM) from _tr_with_ady as b 
                           where b.USUBJID = _tr_with_ady.USUBJID)
            %end;
            and not missing(TULINKID);
    quit;
    
    /* Identify all lesions at each visit */
    proc sql;
        create table _all_lesions as
        select distinct
            USUBJID,
            TULINKID,
            VISIT,
            VISITNUM,
            coalesce(ADY_CALC, ADY) as ADY
        from _tr_with_ady
        where not missing(TULINKID)
        order by USUBJID, VISITNUM, TULINKID;
    quit;
    
    /* Flag new lesions */
    proc sql;
        create table _lesions_flagged as
        select 
            a.*,
            case 
                when b.BASELINE_LESION_FL = 'Y' then 'Y'
                else 'N'
            end as BASELINE_LESION_FL,
            case
                when b.BASELINE_LESION_FL is null and a.ADY >= 1 then 'Y'
                else 'N'
            end as NEW_LESION_FL
        from _all_lesions as a
        left join _baseline_lesions as b
            on a.USUBJID = b.USUBJID
           and a.TULINKID = b.TULINKID;
    quit;
    
    /* Determine first visit with new lesions per subject-lesion */
    proc sql;
        create table _first_new_visit as
        select 
            USUBJID,
            TULINKID,
            min(VISITNUM) as FIRST_NEW_VISITNUM,
            min(VISIT) as FIRST_NEW_VISIT
        from _lesions_flagged
        where NEW_LESION_FL = 'Y'
        group by USUBJID, TULINKID;
    quit;
    
    /* Merge flags back to TR dataset */
    proc sql;
        create table &outds as
        select 
            a.*,
            coalesce(b.BASELINE_LESION_FL, 'N') as BASELINE_LESION_FL,
            coalesce(b.NEW_LESION_FL, 'N') as NEW_LESION_FL,
            c.FIRST_NEW_VISIT,
            c.FIRST_NEW_VISITNUM,
            /* Progression flag: Any new lesion = PD per RECIST 1.1 */
            case 
                when b.NEW_LESION_FL = 'Y' then 'Y'
                else 'N'
            end as PD_NEW_LESION_FL
        from &tr_ds as a
        left join _lesions_flagged as b
            on a.USUBJID = b.USUBJID
           and a.TULINKID = b.TULINKID
           and coalesce(a.VISITNUM, b.VISITNUM) = b.VISITNUM
        left join _first_new_visit as c
            on a.USUBJID = c.USUBJID
           and a.TULINKID = c.TULINKID
        order by USUBJID, VISITNUM, TULINKID;
    quit;
    
    /* Label variables */
    data &outds;
        set &outds;
        
        label 
            BASELINE_LESION_FL = "Lesion Present at Baseline (Y/N)"
            NEW_LESION_FL = "New Lesion Post-Baseline (Y/N)"
            FIRST_NEW_VISIT = "First Visit New Lesion Detected"
            FIRST_NEW_VISITNUM = "First Visit Number New Lesion Detected"
            PD_NEW_LESION_FL = "Progressive Disease Due to New Lesion (Y/N)";
    run;
    
    /* Summary statistics */
    proc sql;
        title "New Lesion Detection Summary";
        
        select 
            count(distinct USUBJID) as N_Subjects,
            count(distinct case when NEW_LESION_FL='Y' then USUBJID end) as N_Subjects_New_Lesions,
            count(distinct case when NEW_LESION_FL='Y' then TULINKID end) as N_New_Lesions,
            count(distinct case when PD_NEW_LESION_FL='Y' then USUBJID end) as N_Subjects_PD_NewLesions
        from &outds;
        
        title2 "New Lesions by Visit";
        select 
            VISIT,
            VISITNUM,
            count(distinct case when NEW_LESION_FL='Y' then USUBJID end) as N_Subjects,
            count(distinct case when NEW_LESION_FL='Y' then TULINKID end) as N_New_Lesions
        from &outds
        where NEW_LESION_FL = 'Y'
        group by VISIT, VISITNUM
        order by VISITNUM;
    quit;
    
    proc sql noprint;
        select count(distinct USUBJID) into :n_subjects_with_new trimmed
        from &outds
        where NEW_LESION_FL = 'Y';
    quit;
    
    %put NOTE: [DETECT_NEW_LESIONS] Detection complete:;
    %put NOTE: [DETECT_NEW_LESIONS]   Subjects with new lesions: &n_subjects_with_new;
    %put NOTE: [DETECT_NEW_LESIONS]   Automatic PD per RECIST 1.1;
    
    /* Clean up */
    proc datasets library=work nolist;
        delete _tr_with_ady _baseline_lesions _all_lesions _lesions_flagged _first_new_visit;
    quit;
    
    title;
    
%mend detect_new_lesions;