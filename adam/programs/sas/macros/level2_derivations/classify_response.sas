/******************************************************************************
* Macro: CLASSIFY_RESPONSE
* Purpose: Derive AVALC (CR/PR/SD/PD) from CRIT flags and measurements
* Version: 1.0
* 
* PARAMETERS:
*   inds           - Input dataset with AVAL, BASE, NADIR, CRIT flags
*   outds          - Output dataset with AVALC response classification
*   paramcd        - Parameter code to classify (default: SDIAM)
*
* ALGORITHM - RECIST 1.1 RESPONSE CRITERIA:
*   CR (Complete Response):
*     - Target lesions: Disappearance (SDIAM = 0)
*     - Non-target: Disappearance of all
*     - No new lesions
*   
*   PR (Partial Response):
*     - Target lesions: ≥30% decrease from baseline
*     - Must be confirmed at subsequent visit (≥4 weeks)
*   
*   PD (Progressive Disease):
*     - Target lesions: ≥20% increase from nadir AND ≥5mm absolute
*       (or Enaworu rule if CRIT3FL='Y')
*     - OR new lesions detected (CRIT2FL='Y')
*     - OR unequivocal progression of non-target (CRIT4FL='Y')
*   
*   SD (Stable Disease):
*     - Neither PR nor PD criteria met
*
* REFERENCES:
*   - EORTC RECIST 1.1 (2009): Response evaluation criteria
*   - JAMA Oncology 2024: PD pattern classification and prognosis
*   - PharmaSUG 2025-SA-287: Efficacy analysis roadmap
*
* EXAMPLE USAGE:
*   %classify_response(
*       inds=work.adtr_with_crit,
*       outds=work.adtr_with_response,
*       paramcd=SDIAM
*   );
*
* AUTHOR: Christian Baghai
* DATE: 2026-01-03
******************************************************************************/

%macro classify_response(
    inds=,
    outds=,
    paramcd=SDIAM
) / des="Derive AVALC response classification per RECIST 1.1";

    /* Parameter validation */
    %if %length(&inds) = 0 or %length(&outds) = 0 %then %do;
        %put ERROR: [CLASSIFY_RESPONSE] Parameters INDS and OUTDS are required;
        %return;
    %end;
    
    %put NOTE: [CLASSIFY_RESPONSE] Classifying response per RECIST 1.1;
    %put NOTE: [CLASSIFY_RESPONSE] Parameter: &paramcd;
    
    data &outds;
        set &inds;
        
        /* Filter to specified parameter if provided */
        %if %length(&paramcd) > 0 %then %do;
            where PARAMCD = "&paramcd";
        %end;
        
        length AVALC $20;
        
        /* Only classify post-baseline assessments with valid AVAL */
        if not missing(AVAL) and not missing(BASE) and ADY >= 1 then do;
            
            /* Calculate changes from baseline and nadir */
            if not missing(BASE) then do;
                _pchg_base = ((AVAL - BASE) / BASE) * 100;
            end;
            
            if not missing(NADIR) then do;
                _pchg_nadir = ((AVAL - NADIR) / NADIR) * 100;
                _abs_change_nadir = AVAL - NADIR;
            end;
            
            /* Initialize response classification */
            AVALC = 'SD';  /* Default to stable disease */
            
            /* Check for Progressive Disease (highest priority) */
            if (CRIT1FL = 'Y') or          /* Standard RECIST progression */
               (CRIT2FL = 'Y') or          /* New lesions detected */
               (CRIT3FL = 'Y') or          /* Enaworu rule progression */
               (CRIT4FL = 'Y') or          /* Non-target progression */
               (PD_NEW_LESION_FL = 'Y') or /* New lesion flag */
               (PD_ENAWORU_FL = 'Y') then do; /* Enaworu rule flag */
                
                AVALC = 'PD';
                
                /* Classify PD pattern per JAMA Oncology 2024 */
                length PD_PATTERN $50;
                
                if CRIT1FL='Y' and CRIT2FL='Y' and CRIT4FL='Y' then 
                    PD_PATTERN = 'TARGET+NONTARGET+NEW';
                else if CRIT1FL='Y' and CRIT2FL='Y' then 
                    PD_PATTERN = 'TARGET+NEW';
                else if CRIT1FL='Y' and CRIT4FL='Y' then 
                    PD_PATTERN = 'TARGET+NONTARGET';
                else if CRIT2FL='Y' and CRIT4FL='Y' then 
                    PD_PATTERN = 'NONTARGET+NEW';
                else if CRIT1FL='Y' or CRIT3FL='Y' then 
                    PD_PATTERN = 'TARGET ONLY';
                else if CRIT2FL='Y' then 
                    PD_PATTERN = 'NEW ONLY';
                else if CRIT4FL='Y' then 
                    PD_PATTERN = 'NONTARGET ONLY';
                else 
                    PD_PATTERN = 'UNSPECIFIED';
                
                label PD_PATTERN = "Progressive Disease Pattern (JAMA Onc 2024)";
                
            end;
            
            /* Check for Complete Response (if not PD) */
            else if AVALC ne 'PD' and AVAL = 0 then do;
                AVALC = 'CR';
            end;
            
            /* Check for Partial Response (if not PD or CR) */
            else if AVALC ne 'PD' and AVALC ne 'CR' then do;
                if not missing(_pchg_base) and _pchg_base <= -30 then do;
                    AVALC = 'PR';
                end;
            end;
            
            /* Default remains SD if no other criteria met */
            
        end;
        else if missing(AVAL) then do;
            AVALC = 'NE';  /* Not evaluable */
        end;
        else if ADY < 1 then do;
            AVALC = 'BASELINE';  /* Baseline assessment */
        end;
        
        label AVALC = "Analysis Value Character (CR/PR/SD/PD/NE)";
        
        drop _pchg_base _pchg_nadir _abs_change_nadir;
        
    run;
    
    /* Summary statistics */
    proc sql;
        title "RECIST 1.1 Response Classification Summary";
        
        select 
            AVALC as Response,
            count(*) as N_Assessments,
            count(distinct USUBJID) as N_Subjects,
            calculated N_Assessments / (select count(*) from &outds where not missing(AVALC)) * 100 
                as Pct_Assessments format=5.1
        from &outds
        where not missing(AVALC)
        group by AVALC
        order by 
            case AVALC
                when 'CR' then 1
                when 'PR' then 2
                when 'SD' then 3
                when 'PD' then 4
                when 'NE' then 5
                when 'BASELINE' then 6
                else 7
            end;
        
        %if %sysfunc(exist(&outds)) %then %do;
            %let dsid = %sysfunc(open(&outds));
            %let varnum = %sysfunc(varnum(&dsid, PD_PATTERN));
            %let rc = %sysfunc(close(&dsid));
            
            %if &varnum > 0 %then %do;
                title2 "Progressive Disease Pattern Distribution";
                select 
                    PD_PATTERN,
                    count(*) as N_Assessments,
                    count(distinct USUBJID) as N_Subjects
                from &outds
                where AVALC = 'PD' and not missing(PD_PATTERN)
                group by PD_PATTERN
                order by N_Subjects desc;
            %end;
        %end;
    quit;
    
    %put NOTE: [CLASSIFY_RESPONSE] Response classification complete;
    
    title;
    
%mend classify_response;