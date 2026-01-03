/******************************************************************************
* Macro: CALCULATE_PCHG
* Purpose: Calculate percent change from baseline and nadir
* Version: 1.0
* 
* PARAMETERS:
*   inds    - Input dataset with AVAL, BASE, NADIR
*   outds   - Output dataset with CHG and PCHG variables
*   from    - Calculate change from BASE or NADIR (default: BASE)
*
* DERIVATIONS:
*   CHG = AVAL - BASE (or AVAL - NADIR)
*   PCHG = (CHG / BASE) * 100 (or (AVAL - NADIR) / NADIR * 100)
*
* VALIDATION:
*   - Checks for missing BASE/NADIR before calculation
*   - Reports subjects with missing change values
*
* AUTHOR: Christian Baghai
* DATE: 2026-01-03
******************************************************************************/

%macro calculate_pchg(
    inds=,
    outds=,
    from=BASE
) / des="Calculate percent change from baseline or nadir";

    %let from = %upcase(&from);
    
    %if &from ne BASE and &from ne NADIR %then %do;
        %put ERROR: [CALCULATE_PCHG] FROM parameter must be BASE or NADIR;
        %return;
    %end;
    
    %put NOTE: [CALCULATE_PCHG] Calculating change from &from...;
    
    data &outds;
        set &inds;
        
        %if &from = BASE %then %do;
            /* Change from baseline */
            if not missing(AVAL) and not missing(BASE) then do;
                CHG = AVAL - BASE;
                if BASE ne 0 then PCHG = (CHG / BASE) * 100;
                else PCHG = .;
            end;
            else do;
                CHG = .;
                PCHG = .;
            end;
            
            label CHG = "Change from Baseline"
                  PCHG = "Percent Change from Baseline";
        %end;
        
        %else %if &from = NADIR %then %do;
            /* Change from nadir */
            if not missing(AVAL) and not missing(NADIR) then do;
                CHGNAD = AVAL - NADIR;
                if NADIR ne 0 then PCHGNAD = (CHGNAD / NADIR) * 100;
                else PCHGNAD = .;
            end;
            else do;
                CHGNAD = .;
                PCHGNAD = .;
            end;
            
            label CHGNAD = "Change from Nadir"
                  PCHGNAD = "Percent Change from Nadir";
        %end;
    run;
    
    /* Validation */
    proc sql noprint;
        %if &from = BASE %then %do;
            select count(*) into :n_with_pchg trimmed
            from &outds
            where not missing(PCHG);
        %end;
        %else %do;
            select count(*) into :n_with_pchg trimmed
            from &outds
            where not missing(PCHGNAD);
        %end;
        
        select count(*) into :n_total trimmed from &outds;
    quit;
    
    %put NOTE: [CALCULATE_PCHG] Validation Results:;
    %put NOTE: [CALCULATE_PCHG]   Total Records: &n_total;
    %put NOTE: [CALCULATE_PCHG]   With Percent Change: &n_with_pchg;
    %put NOTE: [CALCULATE_PCHG] Calculation complete;
    
%mend calculate_pchg;
