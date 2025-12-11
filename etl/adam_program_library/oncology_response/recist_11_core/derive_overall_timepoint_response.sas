/******************************************************************************
Macro: derive_overall_timepoint_response
Purpose: Integrate target, non-target, and new lesion assessments per RECIST 1.1
Author: Christian Baghai
Date: December 2025

Description:
Applies RECIST 1.1 Table 4 response matrix to derive overall response at each
timepoint by integrating:
- Target lesion response (CR/PR/SD/PD)
- Non-target lesion response (CR/NON-CR-NON-PD/PD)
- New lesion presence (Yes/No)

RECIST 1.1 Table 4 Logic:
Target=CR + NonTarget=CR + NewLesion=No → Overall=CR
Target=CR + NonTarget=NON-CR/NON-PD + NewLesion=No → Overall=PR
Target=PR + NonTarget=NON-CR/NON-PD or CR + NewLesion=No → Overall=PR
Target=SD + NonTarget=NON-CR/NON-PD or CR + NewLesion=No → Overall=SD
Target=Any + NonTarget=Any + NewLesion=Yes → Overall=PD
Target=PD + NonTarget=Any + NewLesion=Any → Overall=PD
NonTarget=PD + Target=Any + NewLesion=Any → Overall=PD

Parameters:
  tl_ds         - Target lesion response dataset
  ntl_ds        - Non-target lesion response dataset  
  nl_ds         - New lesion dataset
  outds         - Output dataset with overall response
  usubjid_var   - Subject identifier (default: USUBJID)
  adt_var       - Assessment date (default: ADT)

Output Variables:
  OVR_RESP      - Overall response (CR/PR/SD/PD/NE)
  OVR_RESP_N    - Response numeric code
  OVR_RESP_LOGIC - Detailed logic explanation
******************************************************************************/

%macro derive_overall_timepoint_response(
    tl_ds=,
    ntl_ds=,
    nl_ds=,
    outds=,
    usubjid_var=USUBJID,
    adt_var=ADT
) / des="Derive Overall Response per RECIST 1.1 Table 4";

    %if %sysevalf(%superq(tl_ds)=,boolean) %then %do;
        %put ERROR: [derive_overall_timepoint_response] tl_ds= required;
        %return;
    %end;
    
    %if %sysevalf(%superq(outds)=,boolean) %then %do;
        %put ERROR: [derive_overall_timepoint_response] outds= required;
        %return;
    %end;

    /* Step 1: Get new lesion flags by visit */
    %if %length(&nl_ds) %then %do;
        proc sql;
            create table _new_lesions as
            select distinct
                &usubjid_var,
                &adt_var,
                1 as NEW_LESION_FL,
                'Yes' as NEW_LESION length=3
            from &nl_ds
            where upcase(strip(RSCAT)) = 'NEW';
        quit;
    %end;
    %else %do;
        /* No new lesion data provided */
        data _new_lesions;
            set &tl_ds (keep=&usubjid_var &adt_var);
            NEW_LESION_FL = 0;
            NEW_LESION = 'No';
        run;
    %end;

    /* Step 2: Merge all response components */
    proc sort data=&tl_ds out=_tl_sorted;
        by &usubjid_var &adt_var;
    run;
    
    %if %length(&ntl_ds) %then %do;
        proc sort data=&ntl_ds out=_ntl_sorted;
            by &usubjid_var &adt_var;
        run;
    %end;
    
    proc sort data=_new_lesions;
        by &usubjid_var &adt_var;
    run;

    data _merged;
        merge _tl_sorted (in=a)
              %if %length(&ntl_ds) %then %do;
                  _ntl_sorted (in=b)
              %end;
              _new_lesions (in=c);
        by &usubjid_var &adt_var;
        
        if a; /* Keep all target lesion assessments */
        
        /* Fill missing values */
        if missing(NEW_LESION_FL) then NEW_LESION_FL = 0;
        if missing(NEW_LESION) then NEW_LESION = 'No';
        if missing(NTL_RESP) then NTL_RESP = 'NOT ASSESSED';
    run;

    /* Step 3: Apply RECIST 1.1 Table 4 Logic */
    data &outds;
        set _merged;
        
        length OVR_RESP $10 OVR_RESP_LOGIC $500;
        
        /* Priority 1: Any new lesion = PD */
        if NEW_LESION_FL = 1 then do;
            OVR_RESP = 'PD';
            OVR_RESP_N = 4;
            OVR_RESP_LOGIC = cats('New lesion detected → PD ',
                                   '(TL=', TL_RESP, ', NTL=', NTL_RESP, ')');
        end;
        
        /* Priority 2: Target or non-target PD */
        else if TL_RESP = 'PD' or NTL_RESP = 'PD' then do;
            OVR_RESP = 'PD';
            OVR_RESP_N = 4;
            if TL_RESP = 'PD' and NTL_RESP = 'PD' then 
                OVR_RESP_LOGIC = 'Both target and non-target PD';
            else if TL_RESP = 'PD' then 
                OVR_RESP_LOGIC = cats('Target lesion PD (', TL_RESP_REASON, ')');
            else 
                OVR_RESP_LOGIC = cats('Non-target lesion PD (', NTL_RESP_REASON, ')');
        end;
        
        /* Priority 3: CR (both target and non-target must be CR) */
        else if TL_RESP = 'CR' and NTL_RESP in ('CR', 'NOT ASSESSED') then do;
            OVR_RESP = 'CR';
            OVR_RESP_N = 1;
            OVR_RESP_LOGIC = 'Target=CR and Non-target=CR (or not present) → CR';
        end;
        
        /* Priority 4: PR */
        else if (TL_RESP = 'PR' and NTL_RESP in ('CR', 'NON-CR/NON-PD', 'NOT ASSESSED')) or
                (TL_RESP = 'CR' and NTL_RESP = 'NON-CR/NON-PD') then do;
            OVR_RESP = 'PR';
            OVR_RESP_N = 2;
            OVR_RESP_LOGIC = cats('TL=', TL_RESP, ' + NTL=', NTL_RESP, ' → PR per Table 4');
        end;
        
        /* Priority 5: SD */
        else if TL_RESP = 'SD' and NTL_RESP in ('CR', 'NON-CR/NON-PD', 'NOT ASSESSED') then do;
            OVR_RESP = 'SD';
            OVR_RESP_N = 3;
            OVR_RESP_LOGIC = cats('TL=SD + NTL=', NTL_RESP, ' → SD');
        end;
        
        /* Default: Not evaluable */
        else do;
            OVR_RESP = 'NE';
            OVR_RESP_N = 5;
            OVR_RESP_LOGIC = cats('Not evaluable: TL=', TL_RESP, ', NTL=', NTL_RESP);
        end;
        
        label
            OVR_RESP = "Overall Response (RECIST 1.1)"
            OVR_RESP_N = "Overall Response (Numeric)"
            OVR_RESP_LOGIC = "RECIST 1.1 Table 4 Logic Applied"
            NEW_LESION = "New Lesion Present (Yes/No)"
            NEW_LESION_FL = "New Lesion Flag (1=Yes, 0=No)";
    run;

    /* QC Output */
    proc freq data=&outds;
        tables OVR_RESP * TL_RESP * NTL_RESP / missing list;
        title "Overall Response by Component Responses";
    run;
    
    proc freq data=&outds;
        tables OVR_RESP / missing;
        title "Overall Response Distribution";
    run;
    title;

    /* Cleanup */
    proc datasets lib=work nolist;
        delete _tl_sorted _ntl_sorted _new_lesions _merged;
    quit;

    %put NOTE: [derive_overall_timepoint_response] Completed. Output: &outds;

%mend derive_overall_timepoint_response;
