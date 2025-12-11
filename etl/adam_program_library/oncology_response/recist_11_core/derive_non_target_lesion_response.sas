/******************************************************************************
Macro: derive_non_target_lesion_response
Purpose: Derive non-target lesion response per RECIST 1.1
Author: Christian Baghai
Date: December 2025

Description:
Maps investigator assessments of non-target lesions (non-measurable disease)
to standardized RECIST 1.1 categories:
- CR: All non-target lesions disappeared
- NON-CR/NON-PD: Persistence of one or more non-target lesions
- PD: Unequivocal progression of existing non-target lesions

Parameters:
  inds          - Input dataset with non-target lesion assessments
  outds         - Output dataset with derived responses
  usubjid_var   - Subject identifier (default: USUBJID)
  visit_var     - Visit identifier (default: AVISIT)
  adt_var       - Assessment date (default: ADT)
  assess_var    - Assessment variable (default: NTRGRESP)

Output Variables:
  NTL_RESP      - Non-target lesion response
  NTL_RESP_N    - Response numeric code
  NTL_RESP_REASON - Explanation of response assignment
******************************************************************************/

%macro derive_non_target_lesion_response(
    inds=,
    outds=,
    usubjid_var=USUBJID,
    visit_var=AVISIT,
    adt_var=ADT,
    assess_var=NTRGRESP
) / des="Derive Non-Target Lesion Response";

    %if %sysevalf(%superq(inds)=,boolean) or %sysevalf(%superq(outds)=,boolean) %then %do;
        %put ERROR: [derive_non_target_lesion_response] inds= and outds= required;
        %return;
    %end;

    /* Step 1: Aggregate non-target assessments by visit */
    data _ntl_assess;
        set &inds;
        where upcase(strip(RSCAT)) = 'NON-TARGET';
        
        length ASSESS_STD $20;
        ASSESS_STD = upcase(strip(&assess_var));
        
        /* Standardize common variations */
        if ASSESS_STD in ('ABSENT', 'COMPLETE RESPONSE', 'DISAPPEARED') then 
            ASSESS_STD = 'ABSENT';
        else if ASSESS_STD in ('PRESENT', 'PRESENT/STABLE', 'NO CHANGE', 'STABLE') then 
            ASSESS_STD = 'PRESENT';
        else if ASSESS_STD in ('UNEQUIVOCAL PROGRESSION', 'PROGRESSION', 'INCREASED') then 
            ASSESS_STD = 'PROGRESSION';
    run;

    proc sort data=_ntl_assess;
        by &usubjid_var &adt_var;
    run;

    /* Step 2: Derive worst assessment per visit (if multiple NTL) */
    data _ntl_worst;
        set _ntl_assess;
        by &usubjid_var &adt_var;
        
        /* Assign numeric severity (worst = highest) */
        if ASSESS_STD = 'ABSENT' then ASSESS_SEV = 1;
        else if ASSESS_STD = 'PRESENT' then ASSESS_SEV = 2;
        else if ASSESS_STD = 'PROGRESSION' then ASSESS_SEV = 3;
        else ASSESS_SEV = 4; /* Unknown/other */
    run;

    proc sql;
        create table _ntl_visit as
        select 
            &usubjid_var,
            &visit_var,
            &adt_var,
            max(ASSESS_SEV) as MAX_SEV,
            count(*) as NTL_COUNT
        from _ntl_worst
        group by &usubjid_var, &visit_var, &adt_var;
    quit;

    /* Step 3: Map to RECIST 1.1 non-target response */
    data &outds;
        merge _ntl_visit (in=a)
              _ntl_worst;
        by &usubjid_var &adt_var;
        if a;
        
        length NTL_RESP $20 NTL_RESP_REASON $200;
        
        /* Use worst assessment for visit */
        if first.&adt_var;
        
        /* RECIST 1.1 Non-Target Response */
        if MAX_SEV = 1 then do;
            NTL_RESP = 'CR';
            NTL_RESP_N = 1;
            NTL_RESP_REASON = 'All non-target lesions absent';
        end;
        else if MAX_SEV = 3 then do;
            NTL_RESP = 'PD';
            NTL_RESP_N = 4;
            NTL_RESP_REASON = 'Unequivocal progression of non-target lesions';
        end;
        else if MAX_SEV = 2 then do;
            NTL_RESP = 'NON-CR/NON-PD';
            NTL_RESP_N = 2;
            NTL_RESP_REASON = 'Non-target lesions present but not progressing';
        end;
        else do;
            NTL_RESP = 'NE';
            NTL_RESP_N = 5;
            NTL_RESP_REASON = 'Non-target lesions not evaluable';
        end;
        
        label
            NTL_RESP = "Non-Target Lesion Response (RECIST 1.1)"
            NTL_RESP_N = "Non-Target Lesion Response (Numeric)"
            NTL_RESP_REASON = "Reason for Non-Target Response";
    run;

    /* QC Output */
    proc freq data=&outds;
        tables NTL_RESP / missing;
        title "Non-Target Lesion Response Distribution";
    run;
    title;

    /* Cleanup */
    proc datasets lib=work nolist;
        delete _ntl_assess _ntl_worst _ntl_visit;
    quit;

    %put NOTE: [derive_non_target_lesion_response] Completed. Output: &outds;

%mend derive_non_target_lesion_response;
