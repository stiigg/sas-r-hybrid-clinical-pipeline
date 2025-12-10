/******************************************************************************
Macro: identify_pseudoprogression
Purpose: Identify and flag pseudoprogression events in immunotherapy trials
Author: Christian Baghai
Date: December 2025

Description:
Pseudoprogression is a phenomenon unique to immunotherapy where tumors
initially appear to progress (increase in size or new lesions) due to
immune cell infiltration, followed by subsequent tumor shrinkage.

This macro identifies pseudoprogression patterns by detecting:
1. Initial progression (PD or iUPD)
2. Followed by response (CR/PR) or stable disease at later timepoint
3. Without intervening new anti-cancer therapy

Criteria for pseudoprogression identification:
- Initial assessment showing PD
- Subsequent assessment (≥4 weeks later) showing CR, PR, or SD
- No new systemic therapy between assessments
- Tumor burden reduction from initial PD measurement

Reference:
- Chiou VL, Burotto M. J Immunother Cancer. 2015;3:30
- Seymour L, et al. Lancet Oncol. 2017;18(3):e143-e152

Parameters:
  inds            - Input ADRS dataset with sequential responses
  outds           - Output dataset with pseudoprogression flags
  usubjid_var     - Subject ID (default: USUBJID)
  adt_var         - Assessment date (default: ADT)
  resp_var        - Response variable (default: IRECIST_RESP or OVR_RESP)
  sld_var         - Sum of longest diameters (default: AVAL for SLD parameter)
  nact_dt_var     - New anti-cancer therapy date (default: NACTDT)
  min_interval    - Minimum days between PD and improvement (default: 28)

Output variables:
  PSEUDO_PROG_FL       - Pseudoprogression flag (Y/N)
  PSEUDO_PROG_TYPE     - Type of pseudoprogression detected
  INITIAL_PD_DT        - Date of initial PD
  IMPROVEMENT_DT       - Date of subsequent improvement
  PSEUDO_PROG_DESC     - Description of pseudoprogression event

Assumptions:
- Input sorted by subject and assessment date
- Response variable uses standard coding (CR/PR/SD/PD)
- SLD measurements available for tumor burden assessment
******************************************************************************/

%macro identify_pseudoprogression(
    inds=,
    outds=,
    usubjid_var=USUBJID,
    adt_var=ADT,
    resp_var=IRECIST_RESP,
    sld_var=AVAL,
    nact_dt_var=NACTDT,
    min_interval=28
) / des="Identify Pseudoprogression in Immunotherapy Trials";

    %if %sysevalf(%superq(inds)=,boolean) or %sysevalf(%superq(outds)=,boolean) %then %do;
        %put ERROR: [identify_pseudoprogression] inds= and outds= are required.;
        %return;
    %end;

    %put NOTE: ============================================================;
    %put NOTE: Macro: identify_pseudoprogression;
    %put NOTE: Detecting pseudoprogression patterns in immunotherapy data;
    %put NOTE: Minimum interval for improvement: &min_interval days;
    %put NOTE: ============================================================;

    /* Step 1: Prepare input and track PD events */
    data _pseudo_prep;
        set &inds;
        length RESP_STD $10;
        RESP_STD = upcase(strip(&resp_var));
    run;

    proc sort data=_pseudo_prep;
        by &usubjid_var &adt_var;
    run;

    /* Step 2: Identify PD followed by improvement */
    data _pseudo_track;
        set _pseudo_prep;
        by &usubjid_var &adt_var;

        retain FIRST_PD_DT FIRST_PD_SLD IMPROVEMENT_DT IMPROVEMENT_RESP PD_DETECTED;
        length FIRST_PD_DT IMPROVEMENT_DT 8;
        length IMPROVEMENT_RESP $10;
        format FIRST_PD_DT IMPROVEMENT_DT yymmdd10.;

        if first.&usubjid_var then do;
            FIRST_PD_DT = .;
            FIRST_PD_SLD = .;
            IMPROVEMENT_DT = .;
            IMPROVEMENT_RESP = '';
            PD_DETECTED = 0;
        end;

        /* Track first PD */
        if RESP_STD in ('PD','iUPD') and PD_DETECTED = 0 then do;
            FIRST_PD_DT = &adt_var;
            FIRST_PD_SLD = &sld_var;
            PD_DETECTED = 1;
        end;

        /* Detect improvement after PD */
        if PD_DETECTED = 1 and not missing(FIRST_PD_DT) then do;
            if &adt_var >= FIRST_PD_DT + &min_interval then do;
                /* Check for response or stability */
                if RESP_STD in ('CR','PR','SD','iCR','iPR','iSD') then do;
                    if missing(IMPROVEMENT_DT) then do;
                        IMPROVEMENT_DT = &adt_var;
                        IMPROVEMENT_RESP = RESP_STD;
                    end;
                end;
            end;
        end;

        label
            FIRST_PD_DT = "Date of Initial PD"
            FIRST_PD_SLD = "Tumor Burden at Initial PD"
            IMPROVEMENT_DT = "Date of Subsequent Improvement"
            IMPROVEMENT_RESP = "Response at Improvement";
    run;

    /* Step 3: Flag pseudoprogression cases */
    data &outds;
        set _pseudo_track;

        length PSEUDO_PROG_FL $1 PSEUDO_PROG_TYPE $50 PSEUDO_PROG_DESC $300;

        PSEUDO_PROG_FL = 'N';
        PSEUDO_PROG_TYPE = '';
        PSEUDO_PROG_DESC = '';

        /* Criteria: PD followed by improvement without new therapy */
        if not missing(FIRST_PD_DT) and not missing(IMPROVEMENT_DT) then do;

            /* Check for new therapy between PD and improvement */
            %if %length(&nact_dt_var) %then %do;
                if missing(&nact_dt_var) or &nact_dt_var > IMPROVEMENT_DT then do;
                    PSEUDO_PROG_FL = 'Y';
                end;
            %end;
            %else %do;
                PSEUDO_PROG_FL = 'Y';
            %end;

            if PSEUDO_PROG_FL = 'Y' then do;
                /* Classify type based on improvement response */
                if IMPROVEMENT_RESP in ('CR','iCR') then
                    PSEUDO_PROG_TYPE = 'Pseudoprogression with CR';
                else if IMPROVEMENT_RESP in ('PR','iPR') then
                    PSEUDO_PROG_TYPE = 'Pseudoprogression with PR';
                else if IMPROVEMENT_RESP in ('SD','iSD') then
                    PSEUDO_PROG_TYPE = 'Pseudoprogression with SD';
                else
                    PSEUDO_PROG_TYPE = 'Pseudoprogression - improvement observed';

                PSEUDO_PROG_DESC = compress('Initial PD at Day ' ||
                    strip(put(FIRST_PD_DT, 8.)) ||
                    ', followed by ' || strip(IMPROVEMENT_RESP) ||
                    ' at Day ' || strip(put(IMPROVEMENT_DT, 8.)) ||
                    ' (' || strip(put(IMPROVEMENT_DT - FIRST_PD_DT, 3.)) ||
                    ' days later)');
            end;
        end;

        label
            PSEUDO_PROG_FL = "Pseudoprogression Flag (Y/N)"
            PSEUDO_PROG_TYPE = "Type of Pseudoprogression Pattern"
            PSEUDO_PROG_DESC = "Pseudoprogression Event Description";
    run;

    /* Step 4: Summary reporting */
    proc freq data=&outds;
        tables PSEUDO_PROG_FL PSEUDO_PROG_TYPE / missing;
        title "Pseudoprogression Detection Summary";
    run;

    proc print data=&outds(where=(PSEUDO_PROG_FL='Y')) noobs;
        var &usubjid_var FIRST_PD_DT IMPROVEMENT_DT IMPROVEMENT_RESP 
            PSEUDO_PROG_TYPE PSEUDO_PROG_DESC;
        title "Subjects with Detected Pseudoprogression";
    run;
    title;

    /* Clean up */
    proc datasets lib=work nolist;
        delete _pseudo_prep _pseudo_track;
    quit;

    %put NOTE: ============================================================;
    %put NOTE: Macro identify_pseudoprogression completed;
    %put NOTE: Output: &outds;
    %put NOTE: ============================================================;

%mend identify_pseudoprogression;
