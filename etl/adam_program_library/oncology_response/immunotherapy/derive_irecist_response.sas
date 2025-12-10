/******************************************************************************
Macro: derive_irecist_response
Purpose: Derive immune-modified RECIST (iRECIST) tumor response assessments
Author: Christian Baghai
Date: December 2025

Description:
Implements iRECIST (immune Response Evaluation Criteria in Solid Tumors)
for immunotherapy trials. iRECIST modifies RECIST 1.1 to account for
atypical response patterns seen with immune checkpoint inhibitors, including:

1. Pseudoprogression: Initial tumor growth followed by response
2. Delayed response: Slower kinetics than traditional therapies
3. Confirmation requirement for progression

Key iRECIST concepts:
- iUPD (immune Unconfirmed Progressive Disease): Initial PD observation
- iCPD (immune Confirmed Progressive Disease): PD confirmed ≥4 weeks later
- iCR, iPR, iSD: Immune-modified CR/PR/SD

iRECIST allows continued treatment after initial PD to assess for
pseudoprogression, with mandatory confirmation scan.

Reference:
- Seymour L, et al. Lancet Oncol. 2017;18(3):e143-e152
- PMID: 28271869

Parameters:
  inds              - Input ADRS dataset with RECIST 1.1 assessments
  outds             - Output dataset with iRECIST responses
  usubjid_var       - Subject ID (default: USUBJID)
  adt_var           - Assessment date (default: ADT)
  recist_resp_var   - RECIST 1.1 response (default: OVR_RESP)
  confirm_win_min   - Minimum days for iCPD confirmation (default: 28)
  confirm_win_max   - Maximum days for iCPD confirmation (default: 56)

Output variables:
  IRECIST_RESP     - iRECIST response (iCR/iPR/iSD/iUPD/iCPD/iNE)
  IRECIST_RESPN    - Numeric code for iRECIST response
  IRECIST_LOGIC    - Derivation logic explanation
  PSEUDO_PROG_FL   - Pseudoprogression flag (Y/N)
  CONF_REQUIRED_FL - Confirmation required flag

Assumptions:
- Input contains RECIST 1.1 responses already derived
- Assessments are in chronological order by subject
- Post-progression scans available for confirmation assessment
******************************************************************************/

%macro derive_irecist_response(
    inds=,
    outds=,
    usubjid_var=USUBJID,
    adt_var=ADT,
    recist_resp_var=OVR_RESP,
    confirm_win_min=28,
    confirm_win_max=56
) / des="Derive iRECIST (Immune-Modified RECIST) Response";

    %if %sysevalf(%superq(inds)=,boolean) or %sysevalf(%superq(outds)=,boolean) %then %do;
        %put ERROR: [derive_irecist_response] inds= and outds= are required.;
        %return;
    %end;

    %put NOTE: ============================================================;
    %put NOTE: Macro: derive_irecist_response;
    %put NOTE: Implementing iRECIST criteria per Seymour 2017;
    %put NOTE: Input: &inds;
    %put NOTE: Output: &outds;
    %put NOTE: ============================================================;

    /* Step 1: Prepare input with RECIST responses */
    data _irecist_prep;
        set &inds;
        length RECIST_STD $10;
        RECIST_STD = upcase(strip(&recist_resp_var));
    run;

    proc sort data=_irecist_prep;
        by &usubjid_var &adt_var;
    run;

    /* Step 2: Identify initial PD (iUPD candidates) and track confirmation */
    data _irecist_pd;
        set _irecist_prep;
        by &usubjid_var &adt_var;

        retain FIRST_PD_DT PD_CONFIRMED_DT;
        length FIRST_PD_DT PD_CONFIRMED_DT 8;
        format FIRST_PD_DT PD_CONFIRMED_DT yymmdd10.;

        if first.&usubjid_var then do;
            FIRST_PD_DT = .;
            PD_CONFIRMED_DT = .;
        end;

        /* Track first PD date (potential iUPD) */
        if RECIST_STD = 'PD' and missing(FIRST_PD_DT) then
            FIRST_PD_DT = &adt_var;

        /* Check for PD confirmation within window */
        if not missing(FIRST_PD_DT) then do;
            if RECIST_STD = 'PD' and 
               &adt_var >= FIRST_PD_DT + &confirm_win_min and
               &adt_var <= FIRST_PD_DT + &confirm_win_max then do;
                PD_CONFIRMED_DT = &adt_var;
            end;
        end;

        label
            FIRST_PD_DT = "Date of First PD (iUPD Candidate)"
            PD_CONFIRMED_DT = "Date of Confirmed PD (iCPD)";
    run;

    /* Step 3: Derive iRECIST response */
    data &outds;
        set _irecist_pd;
        by &usubjid_var &adt_var;

        length IRECIST_RESP $10 IRECIST_LOGIC $300 PSEUDO_PROG_FL CONF_REQUIRED_FL $1;
        length IRECIST_RESPN 8;

        /* Default values */
        PSEUDO_PROG_FL = 'N';
        CONF_REQUIRED_FL = 'N';

        /* iRECIST Response Logic */

        /* Case 1: Non-PD responses map directly with 'i' prefix */
        if RECIST_STD in ('CR','PR','SD') then do;
            IRECIST_RESP = compress('i' || RECIST_STD);
            IRECIST_LOGIC = compress('iRECIST ' || RECIST_STD || 
                ' (no progression, direct mapping from RECIST 1.1)');

            select (IRECIST_RESP);
                when ('iCR') IRECIST_RESPN = 1;
                when ('iPR') IRECIST_RESPN = 2;
                when ('iSD') IRECIST_RESPN = 3;
                otherwise IRECIST_RESPN = .;
            end;
        end;

        /* Case 2: First PD observation = iUPD (Unconfirmed PD) */
        else if RECIST_STD = 'PD' then do;

            /* Check if this is first PD for subject */
            if &adt_var = FIRST_PD_DT then do;
                IRECIST_RESP = 'iUPD';
                IRECIST_RESPN = 6;
                CONF_REQUIRED_FL = 'Y';
                IRECIST_LOGIC = compress('iUPD (Immune Unconfirmed PD): ' ||
                    'First PD at Day ' || strip(put(&adt_var, 8.)) ||
                    '. Requires confirmation ≥' || strip(put(&confirm_win_min, 3.)) ||
                    ' days later.');
            end;

            /* Check if PD is confirmed (iCPD) */
            else if not missing(PD_CONFIRMED_DT) and &adt_var = PD_CONFIRMED_DT then do;
                IRECIST_RESP = 'iCPD';
                IRECIST_RESPN = 7;
                IRECIST_LOGIC = compress('iCPD (Immune Confirmed PD): ' ||
                    'PD confirmed ' || strip(put(&adt_var - FIRST_PD_DT, 3.)) ||
                    ' days after initial iUPD.');
            end;

            /* Post-iUPD, pre-confirmation */
            else if not missing(FIRST_PD_DT) and missing(PD_CONFIRMED_DT) then do;
                if RECIST_STD = 'PD' then do;
                    IRECIST_RESP = 'iUPD';
                    IRECIST_RESPN = 6;
                    CONF_REQUIRED_FL = 'Y';
                    IRECIST_LOGIC = 'iUPD pending confirmation';
                end;
            end;

            /* Detect pseudoprogression: improvement after initial PD */
            else if not missing(FIRST_PD_DT) and RECIST_STD in ('CR','PR','SD') then do;
                PSEUDO_PROG_FL = 'Y';
                IRECIST_RESP = compress('i' || RECIST_STD);
                IRECIST_LOGIC = compress('Pseudoprogression detected: ' ||
                    RECIST_STD || ' after initial iUPD at Day ' ||
                    strip(put(FIRST_PD_DT, 8.)));

                select (IRECIST_RESP);
                    when ('iCR') IRECIST_RESPN = 1;
                    when ('iPR') IRECIST_RESPN = 2;
                    when ('iSD') IRECIST_RESPN = 3;
                    otherwise IRECIST_RESPN = .;
                end;
            end;

            else do;
                IRECIST_RESP = 'iUPD';
                IRECIST_RESPN = 6;
                IRECIST_LOGIC = 'iUPD (default classification for PD)';
            end;
        end;

        /* Case 3: Not Evaluable */
        else if RECIST_STD = 'NE' then do;
            IRECIST_RESP = 'iNE';
            IRECIST_RESPN = 8;
            IRECIST_LOGIC = 'Not evaluable per RECIST 1.1';
        end;

        /* Fallback */
        else do;
            IRECIST_RESP = 'iNE';
            IRECIST_RESPN = 8;
            IRECIST_LOGIC = compress('Unexpected RECIST response: ' || RECIST_STD);
        end;

        label
            IRECIST_RESP = "iRECIST Response (Immune-Modified)"
            IRECIST_RESPN = "iRECIST Response (Numeric)"
            IRECIST_LOGIC = "iRECIST Derivation Logic"
            PSEUDO_PROG_FL = "Pseudoprogression Detected (Y/N)"
            CONF_REQUIRED_FL = "Confirmation Required for iUPD (Y/N)";
    run;

    /* Step 4: Quality checks */
    proc freq data=&outds;
        tables IRECIST_RESP PSEUDO_PROG_FL CONF_REQUIRED_FL / missing;
        title "iRECIST Response Distribution";
    run;

    proc freq data=&outds;
        tables RECIST_STD*IRECIST_RESP / missing list;
        title "RECIST 1.1 vs iRECIST Response Cross-Tabulation";
    run;
    title;

    /* Clean up */
    proc datasets lib=work nolist;
        delete _irecist_prep _irecist_pd;
    quit;

    %put NOTE: ============================================================;
    %put NOTE: Macro derive_irecist_response completed;
    %put NOTE: Output: &outds;
    %put NOTE: ============================================================;

%mend derive_irecist_response;
