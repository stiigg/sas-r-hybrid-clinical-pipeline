/******************************************************************************
* Macro: APPLY_ENAWORU_RULE
* Purpose: Apply 25mm nadir threshold rule for progression assessment
* Version: 1.0
* 
* PARAMETERS:
*   inds           - Input dataset with AVAL, BASE, NADIR
*   outds          - Output dataset with ENAWORU_FL flag
*   threshold_mm   - Nadir threshold in millimeters (default: 25)
*   abs_increase   - Absolute increase threshold (default: 5mm)
*   pct_increase   - Percentage increase threshold (default: 0.20)
*
* ALGORITHM - ENAWORU 25mm NADIR RULE (Cureus 2025):
*   If NADIR < 25mm:
*     - Progression requires ≥5mm absolute increase only
*     - No percentage requirement
*   
*   If NADIR ≥ 25mm:
*     - Progression requires ≥20% relative increase only
*     - No absolute minimum requirement
*   
*   RATIONALE: Eliminates dual criteria complexity, reduces ambiguity
*
* DERIVATIONS:
*   - ENAWORU_FL: Flag indicating rule application (Y/N)
*   - ENAWORU_CRIT: Criterion met (ABSOLUTE/PERCENTAGE/NONE)
*   - PD_ENAWORU_FL: Progressive disease per Enaworu rule (Y/N)
*
* REFERENCES:
*   - Enaworu et al. Cureus 2025 (March 31): PMC12094296
*   - Title: "An Innovative Approach to Target Lesion Progression in RECIST 1.1"
*   - DOI: 10.7759/cureus.353893
*
* EXAMPLE USAGE:
*   %apply_enaworu_rule(
*       inds=work.adtr_with_nadir,
*       outds=work.adtr_with_enaworu,
*       threshold_mm=25,
*       abs_increase=5,
*       pct_increase=0.20
*   );
*
* AUTHOR: Christian Baghai
* DATE: 2026-01-03
******************************************************************************/

%macro apply_enaworu_rule(
    inds=,
    outds=,
    threshold_mm=25,
    abs_increase=5,
    pct_increase=0.20
) / des="Apply 25mm nadir threshold rule per Enaworu Cureus 2025";

    /* Parameter validation */
    %if %length(&inds) = 0 or %length(&outds) = 0 %then %do;
        %put ERROR: [APPLY_ENAWORU_RULE] Parameters INDS and OUTDS are required;
        %return;
    %end;
    
    %put NOTE: [APPLY_ENAWORU_RULE] Applying Enaworu 25mm nadir rule (Cureus 2025);
    %put NOTE: [APPLY_ENAWORU_RULE] Threshold: &threshold_mm mm;
    %put NOTE: [APPLY_ENAWORU_RULE] Absolute increase: &abs_increase mm;
    %put NOTE: [APPLY_ENAWORU_RULE] Percentage increase: %sysevalf(&pct_increase * 100)%;
    
    data &outds;
        set &inds;
        
        /* Initialize variables */
        length ENAWORU_FL $1 ENAWORU_CRIT $20 PD_ENAWORU_FL $1;
        
        /* Only apply to records with valid AVAL and NADIR */
        if not missing(AVAL) and not missing(NADIR) then do;
            
            ENAWORU_FL = 'Y';  /* Rule is applicable */
            
            /* Calculate changes from nadir */
            _abs_change = AVAL - NADIR;
            _pct_change = (_abs_change / NADIR);
            
            /* Apply Enaworu 25mm rule */
            if NADIR < &threshold_mm then do;
                
                /* Small nadir: Use absolute increase criterion only */
                if _abs_change >= &abs_increase then do;
                    ENAWORU_CRIT = 'ABSOLUTE';
                    PD_ENAWORU_FL = 'Y';
                end;
                else do;
                    ENAWORU_CRIT = 'NONE';
                    PD_ENAWORU_FL = 'N';
                end;
                
            end;
            else do;
                
                /* Large nadir: Use percentage increase criterion only */
                if _pct_change >= &pct_increase then do;
                    ENAWORU_CRIT = 'PERCENTAGE';
                    PD_ENAWORU_FL = 'Y';
                end;
                else do;
                    ENAWORU_CRIT = 'NONE';
                    PD_ENAWORU_FL = 'N';
                end;
                
            end;
            
        end;
        else do;
            /* Rule not applicable */
            ENAWORU_FL = 'N';
            ENAWORU_CRIT = '';
            PD_ENAWORU_FL = '';
        end;
        
        label 
            ENAWORU_FL = "Enaworu 25mm Rule Applicable (Y/N)"
            ENAWORU_CRIT = "Enaworu Criterion Met (ABSOLUTE/PERCENTAGE/NONE)"
            PD_ENAWORU_FL = "Progressive Disease per Enaworu Rule (Y/N)";
        
        drop _abs_change _pct_change;
        
    run;
    
    /* Summary statistics */
    proc sql;
        title "Enaworu 25mm Nadir Rule Application Summary";
        
        select 
            'Total Assessments' as Category,
            count(*) as N,
            sum(case when ENAWORU_FL='Y' then 1 else 0 end) as N_Applicable,
            sum(case when PD_ENAWORU_FL='Y' then 1 else 0 end) as N_Progressive
        from &outds
        
        union all
        
        select 
            'Nadir <25mm (Absolute Rule)' as Category,
            sum(case when NADIR < &threshold_mm then 1 else 0 end) as N,
            sum(case when NADIR < &threshold_mm and ENAWORU_FL='Y' then 1 else 0 end) as N_Applicable,
            sum(case when NADIR < &threshold_mm and PD_ENAWORU_FL='Y' then 1 else 0 end) as N_Progressive
        from &outds
        where not missing(NADIR)
        
        union all
        
        select 
            'Nadir ≥25mm (Percentage Rule)' as Category,
            sum(case when NADIR >= &threshold_mm then 1 else 0 end) as N,
            sum(case when NADIR >= &threshold_mm and ENAWORU_FL='Y' then 1 else 0 end) as N_Applicable,
            sum(case when NADIR >= &threshold_mm and PD_ENAWORU_FL='Y' then 1 else 0 end) as N_Progressive
        from &outds
        where not missing(NADIR);
    quit;
    
    /* Validation: Compare with standard RECIST criteria */
    data _comparison;
        set &outds;
        where not missing(AVAL) and not missing(NADIR);
        
        /* Standard RECIST 1.1: Both 20% AND 5mm required */
        _abs_increase = AVAL - NADIR;
        _pct_increase = (_abs_increase / NADIR);
        
        if _pct_increase >= 0.20 and _abs_increase >= 5 then 
            PD_STANDARD_FL = 'Y';
        else 
            PD_STANDARD_FL = 'N';
        
        /* Flag discordance */
        if PD_ENAWORU_FL ne PD_STANDARD_FL then DISCORDANT_FL = 'Y';
        else DISCORDANT_FL = 'N';
        
    run;
    
    proc sql noprint;
        select count(*) into :n_discordant trimmed
        from _comparison
        where DISCORDANT_FL = 'Y';
        
        select count(*) into :n_total_assessments trimmed
        from _comparison;
    quit;
    
    %if &n_total_assessments > 0 %then %do;
        %let pct_discordant = %sysevalf((&n_discordant / &n_total_assessments) * 100);
        %put NOTE: [APPLY_ENAWORU_RULE] Discordance with standard RECIST:;
        %put NOTE: [APPLY_ENAWORU_RULE]   Total assessments: &n_total_assessments;
        %put NOTE: [APPLY_ENAWORU_RULE]   Discordant: &n_discordant (%sysfunc(putn(&pct_discordant, 5.1))%);
        
        %if &n_discordant > 0 %then %do;
            %put NOTE: [APPLY_ENAWORU_RULE] Enaworu rule provides simplified, clinically meaningful assessment;
        %end;
    %end;
    
    %put NOTE: [APPLY_ENAWORU_RULE] Rule application complete;
    %put NOTE: [APPLY_ENAWORU_RULE] Reference: Enaworu et al. Cureus 2025 (PMC12094296);
    
    /* Clean up */
    proc datasets library=work nolist;
        delete _comparison;
    quit;
    
    title;
    
%mend apply_enaworu_rule;