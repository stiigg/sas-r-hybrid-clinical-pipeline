/******************************************************************************
Macro: derive_target_lesion_response
Purpose: Derive target lesion response (CR/PR/SD/PD) per RECIST 1.1
Author: Christian Baghai
Date: December 2025

Description:
Calculates sum of longest diameters (SLD) for target lesions at each visit
and derives categorical response using RECIST 1.1 thresholds:
- CR: All target lesions disappeared
- PR: >=30% decrease from baseline SLD
- PD: >=20% increase from nadir + >=5mm absolute increase
- SD: Neither PR nor PD criteria met

Parameters:
  inds          - Input dataset with target lesion measurements
  outds         - Output dataset with derived responses
  usubjid_var   - Subject identifier (default: USUBJID)
  visit_var     - Visit identifier (default: AVISIT)
  adt_var       - Assessment date (default: ADT)
  ldiam_var     - Longest diameter variable (default: LDIAM)
  baseline_flag - Baseline flag variable (default: ABLFL)

Output Variables:
  TL_SLD       - Sum of Longest Diameters at visit
  TL_BASE_SLD  - Baseline SLD
  TL_NADIR_SLD - Nadir (minimum) SLD to date
  TL_PCHG_BASE - Percent change from baseline
  TL_PCHG_NAD  - Percent change from nadir
  TL_RESP      - Target lesion response (CR/PR/SD/PD)
  TL_RESP_N    - Response numeric code (1-4)
******************************************************************************/

%macro derive_target_lesion_response(
    inds=,
    outds=,
    usubjid_var=USUBJID,
    visit_var=AVISIT,
    adt_var=ADT,
    ldiam_var=LDIAM,
    baseline_flag=ABLFL
) / des="Derive RECIST 1.1 Target Lesion Response";

    %if %sysevalf(%superq(inds)=,boolean) or %sysevalf(%superq(outds)=,boolean) %then %do;
        %put ERROR: [derive_target_lesion_response] inds= and outds= required;
        %return;
    %end;

    /* Step 1: Calculate SLD at each visit */
    proc sql;
        create table _tl_sld as
        select 
            &usubjid_var,
            &visit_var,
            &adt_var,
            sum(&ldiam_var) as TL_SLD,
            count(*) as TL_NUM_LESIONS
        from &inds
        where not missing(&ldiam_var) 
          and upcase(strip(RSCAT)) = 'TARGET'
        group by &usubjid_var, &visit_var, &adt_var
        order by &usubjid_var, &adt_var;
    quit;

    /* Step 2: Get baseline SLD */
    proc sql;
        create table _tl_baseline as
        select 
            &usubjid_var,
            TL_SLD as TL_BASE_SLD
        from _tl_sld
        where &baseline_flag = 'Y';
    quit;

    /* Step 3: Calculate running nadir (minimum SLD) */
    data _tl_with_nadir;
        merge _tl_sld (in=a)
              _tl_baseline (in=b);
        by &usubjid_var;
        
        if a and b;
        
        retain TL_NADIR_SLD;
        
        if first.&usubjid_var then do;
            TL_NADIR_SLD = TL_BASE_SLD;
        end;
        
        /* Update nadir with current visit if smaller */
        if TL_SLD < TL_NADIR_SLD and not missing(TL_SLD) then do;
            TL_NADIR_SLD = TL_SLD;
        end;
        
        /* Calculate percent changes */
        if TL_BASE_SLD > 0 then do;
            TL_PCHG_BASE = ((TL_SLD - TL_BASE_SLD) / TL_BASE_SLD) * 100;
        end;
        else TL_PCHG_BASE = .;
        
        if TL_NADIR_SLD > 0 then do;
            TL_PCHG_NAD = ((TL_SLD - TL_NADIR_SLD) / TL_NADIR_SLD) * 100;
        end;
        else TL_PCHG_NAD = .;
        
        TL_ABS_CHG_NAD = TL_SLD - TL_NADIR_SLD;
        
        label
            TL_SLD = "Target Lesion Sum of Longest Diameters"
            TL_BASE_SLD = "Baseline Target Lesion SLD"
            TL_NADIR_SLD = "Nadir (Minimum) Target Lesion SLD"
            TL_PCHG_BASE = "Percent Change from Baseline (%)"
            TL_PCHG_NAD = "Percent Change from Nadir (%)"
            TL_ABS_CHG_NAD = "Absolute Change from Nadir (mm)";
    run;

    /* Step 4: Derive RECIST 1.1 target lesion response */
    data &outds;
        set _tl_with_nadir;
        
        length TL_RESP $10 TL_RESP_REASON $200;
        
        /* RECIST 1.1 Target Lesion Response Logic */
        
        /* CR: All target lesions disappeared (SLD = 0) */
        if TL_SLD = 0 then do;
            TL_RESP = 'CR';
            TL_RESP_N = 1;
            TL_RESP_REASON = 'All target lesions disappeared (SLD=0)';
        end;
        
        /* PD: >=20% increase from nadir AND >=5mm absolute increase */
        else if not missing(TL_PCHG_NAD) and TL_PCHG_NAD >= 20 
            and TL_ABS_CHG_NAD >= 5 then do;
            TL_RESP = 'PD';
            TL_RESP_N = 4;
            TL_RESP_REASON = cats('>=20% increase from nadir (', 
                                   put(TL_PCHG_NAD, 5.1), 
                                   '%) and >=5mm increase (', 
                                   put(TL_ABS_CHG_NAD, 5.1), 'mm)');
        end;
        
        /* PR: >=30% decrease from baseline */
        else if not missing(TL_PCHG_BASE) and TL_PCHG_BASE <= -30 then do;
            TL_RESP = 'PR';
            TL_RESP_N = 2;
            TL_RESP_REASON = cats('>=30% decrease from baseline (', 
                                   put(TL_PCHG_BASE, 5.1), '%)');
        end;
        
        /* SD: Neither PR nor PD criteria met */
        else do;
            TL_RESP = 'SD';
            TL_RESP_N = 3;
            TL_RESP_REASON = 'Neither PR nor PD criteria met';
        end;
        
        label
            TL_RESP = "Target Lesion Response (RECIST 1.1)"
            TL_RESP_N = "Target Lesion Response (Numeric)"
            TL_RESP_REASON = "Reason for Target Lesion Response";
    run;

    /* QC Output */
    proc freq data=&outds;
        tables TL_RESP / missing;
        title "Target Lesion Response Distribution";
    run;
    
    proc means data=&outds n mean std min max median;
        var TL_SLD TL_PCHG_BASE TL_PCHG_NAD;
        title "Target Lesion Measurements Summary";
    run;
    title;

    /* Cleanup */
    proc datasets lib=work nolist;
        delete _tl_sld _tl_baseline _tl_with_nadir;
    quit;

    %put NOTE: [derive_target_lesion_response] Completed. Output: &outds;

%mend derive_target_lesion_response;
