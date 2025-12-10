/******************************************************************************
Macro: derive_best_overall_response
Purpose: Derive Best Overall Response (BOR) per RECIST 1.1, with confirmation
Author: Christian Baghai
Date: December 2025

Description:
Derives Best Overall Response (BOR) for each subject using longitudinal
RECIST 1.1 overall timepoint responses (e.g., ADRS-level records).

Key features:
- Implements RECIST 1.1 hierarchy: CR > PR > SD > PD > NE
- Applies confirmation logic for CR/PR (confirmation within a window)
- Allows specification of minimum SD duration window (e.g., 6 or 8 weeks)
- Excludes assessments after start of new anti-cancer therapy, if provided

Typical input: per-subject, per-visit dataset with OVR_RESP and dates.

Core rules (RECIST 1.1) [Eisenhauer 2009][PharmaSUG oncology papers]:
- CR/PR must be confirmed by a subsequent assessment no earlier than
  CONF_WIN_LO (e.g., 28 days) and no later than CONF_WIN_HI (e.g., 84 days).
- SD requires at least SD_MIN_DUR (e.g., 42 days) from baseline to qualify.
- BOR excludes assessments after new anti-cancer therapy.

Parameters:
  inds          - Input dataset (overall timepoint responses)
  outds         - Output dataset with one record per subject and BOR
  usubjid_var   - Subject identifier (default: USUBJID)
  ady_var       - Analysis day variable (default: ADY)
  dtc_var       - Assessment date variable (default: ADT)
  ovr_var       - Overall response variable (default: OVR_RESP)
  trt_end_var   - Date of new anti-cancer therapy (optional, default: NACTDT)
  conf_win_lo   - Min days between response and confirm (default: 28)
  conf_win_hi   - Max days between response and confirm (default: 84)
  sd_min_dur    - Min baseline-to-SD duration in days (default: 42)

Output:
  One record per subject with:
  - BOR        : Best Overall Response (CR/PR/SD/PD/NE)
  - BORN       : Numeric ranking (1=CR,2=PR,3=SD,4=PD,5=NE)
  - BORDT      : Date of BOR
  - BOR_SRC    : Short text explaining basis of BOR
  - BORCONF    : Flag if BOR was confirmed (Y/N for CR/PR)

Assumptions:
- OVR_RESP uses standard levels: CR, PR, SD, PD, NE
- ADY/ADT increase monotonically within subject
- If trt_end_var is present, post-treatment assessments are ignored.
******************************************************************************/

%macro derive_best_overall_response(
    inds=,
    outds=,
    usubjid_var=USUBJID,
    ady_var=ADY,
    dtc_var=ADT,
    ovr_var=OVR_RESP,
    trt_end_var=NACTDT,
    conf_win_lo=28,
    conf_win_hi=84,
    sd_min_dur=42
) / des="Derive RECIST 1.1 Best Overall Response";

    %if %sysevalf(%superq(inds)=,boolean) or %sysevalf(%superq(outds)=,boolean) %then %do;
        %put ERROR: [derive_best_overall_response] inds= and outds= are required.;
        %return;
    %end;

    /* Step 1: Prepare input and standardize responses */
    data _bor_in;
        set &inds;
        length OVR_STD $10;
        OVR_STD = upcase(strip(&ovr_var));

        /* Optional: drop records after new anti-cancer treatment */
        %if %length(&trt_end_var) %then %do;
            if not missing(&trt_end_var) and &dtc_var > &trt_end_var then delete;
        %end;
    run;

    proc sort data=_bor_in;
        by &usubjid_var &dtc_var;
    run;

    /* Step 2: Identify confirmed CR/PR and qualifying SD */
    data _bor_flagged;
        set _bor_in;
        by &usubjid_var &dtc_var;

        retain FIRST_CRDT FIRST_PRDT;
        length RESP_CLASS $10;

        /* Classify */
        RESP_CLASS = OVR_STD;

        /* Track first CR/PR date */
        if first.&usubjid_var then do;
            FIRST_CRDT = .;
            FIRST_PRDT = .;
        end;

        if RESP_CLASS = 'CR' and missing(FIRST_CRDT) then FIRST_CRDT = &dtc_var;
        if RESP_CLASS = 'PR' and missing(FIRST_PRDT) then FIRST_PRDT = &dtc_var;

        /* SD qualification: need baseline to SD duration >= sd_min_dur */
        length SD_QUAL $1;
        SD_QUAL = 'N';
        if RESP_CLASS = 'SD' and &ady_var >= &sd_min_dur then SD_QUAL = 'Y';

        label
            RESP_CLASS = "Standardized Overall Response"
            SD_QUAL    = "Flag: SD meets minimum duration";
    run;

    /* Step 3: Derive confirmation for CR/PR using a second pass */
    data _bor_conf;
        set _bor_flagged;
        by &usubjid_var &dtc_var;

        retain CR_CONF_DT PR_CONF_DT;
        length CR_CONF PR_CONF $1;

        if first.&usubjid_var then do;
            CR_CONF_DT = .;
            PR_CONF_DT = .;
            CR_CONF    = 'N';
            PR_CONF    = 'N';
        end;

        /* Check if this visit confirms an earlier CR */
        if not missing(FIRST_CRDT) then do;
            if &dtc_var > FIRST_CRDT + &conf_win_lo - 1 and
               &dtc_var <= FIRST_CRDT + &conf_win_hi and
               RESP_CLASS in ('CR','PR','SD') then do;
                CR_CONF_DT = &dtc_var;
                CR_CONF    = 'Y';
            end;
        end;

        /* Check if this visit confirms an earlier PR */
        if not missing(FIRST_PRDT) then do;
            if &dtc_var > FIRST_PRDT + &conf_win_lo - 1 and
               &dtc_var <= FIRST_PRDT + &conf_win_hi and
               RESP_CLASS in ('CR','PR','SD') then do;
                PR_CONF_DT = &dtc_var;
                PR_CONF    = 'Y';
            end;
        end;

        label
            CR_CONF    = "CR confirmed within window (Y/N)"
            PR_CONF    = "PR confirmed within window (Y/N)";
    run;

    /* Step 4: Summarize to subject-level BOR following RECIST hierarchy */
    proc sort data=_bor_conf;
        by &usubjid_var &dtc_var;
    run;

    data &outds;
        set _bor_conf;
        by &usubjid_var &dtc_var;

        retain BOR BORN BORDT BOR_SRC BORCONF;
        length BOR $10 BOR_SRC $200 BORCONF $1;

        if first.&usubjid_var then do;
            BOR     = 'NE';
            BORN    = 5;
            BORDT   = .;
            BOR_SRC = 'No evaluable response';
            BORCONF = 'N';
        end;

        /* Apply hierarchy only if not already CR */
        if RESP_CLASS in ('CR','PR','SD','PD') then do;

            /* CR (confirmed preferred) */
            if RESP_CLASS = 'CR' then do;
                if CR_CONF = 'Y' then do;
                    BOR     = 'CR';
                    BORN    = 1;
                    BORDT   = &dtc_var;
                    BORCONF = 'Y';
                    BOR_SRC = 'Confirmed CR';
                end;
                else if BOR ne 'CR' then do;
                    /* Provisional CR if nothing better so far */
                    BOR     = 'CR';
                    BORN    = 1;
                    BORDT   = &dtc_var;
                    BORCONF = 'N';
                    BOR_SRC = 'Unconfirmed CR';
                end;
            end;

            /* PR (confirmed preferred) */
            else if RESP_CLASS = 'PR' then do;
                if (BOR not in ('CR')) then do;
                    if PR_CONF = 'Y' then do;
                        BOR     = 'PR';
                        BORN    = 2;
                        BORDT   = &dtc_var;
                        BORCONF = 'Y';
                        BOR_SRC = 'Confirmed PR';
                    end;
                    else if BOR not in ('PR') then do;
                        BOR     = 'PR';
                        BORN    = 2;
                        BORDT   = &dtc_var;
                        BORCONF = 'N';
                        BOR_SRC = 'Unconfirmed PR';
                    end;
                end;
            end;

            /* SD: only if no CR/PR and SD qualifies duration */
            else if RESP_CLASS = 'SD' and SD_QUAL = 'Y' then do;
                if BOR not in ('CR','PR','SD') then do;
                    BOR     = 'SD';
                    BORN    = 3;
                    BORDT   = &dtc_var;
                    BORCONF = 'N';
                    BOR_SRC = cats('SD with duration >=', &sd_min_dur, ' days');
                end;
            end;

            /* PD: only if nothing better than PD yet and no CR/PR/SD */
            else if RESP_CLASS = 'PD' then do;
                if BOR not in ('CR','PR','SD','PD') then do;
                    BOR     = 'PD';
                    BORN    = 4;
                    BORDT   = &dtc_var;
                    BORCONF = 'N';
                    BOR_SRC = 'Best response is PD (no CR/PR/SD)';
                end;
            end;
        end;

        if last.&usubjid_var;

        label
            BOR     = "Best Overall Response per RECIST 1.1"
            BORN    = "Best Overall Response (Numeric)"
            BORDT   = "Date of Best Overall Response"
            BOR_SRC = "Basis for Best Overall Response"
            BORCONF = "CR/PR Best Overall Response Confirmed (Y/N)";
    run;

    proc freq data=&outds;
        tables BOR BORCONF / missing;
        title "Best Overall Response Distribution";
    run;
    title;

    proc datasets lib=work nolist;
        delete _bor_in _bor_flagged _bor_conf;
    quit;

    %put NOTE: [derive_best_overall_response] completed. Output: &outds.;

%mend derive_best_overall_response;
