/******************************************************************************
Macro: derive_overall_survival
Purpose: Derive Overall Survival (OS) endpoint for ADTTE
Author: Christian Baghai
Date: December 2025

Description:
Derives Overall Survival (OS) records for all subjects.
OS is defined as time from randomization (or treatment start) to death from
any cause. Subjects who are alive at last contact are censored.

Typical definition (oncology SAPs, CDISC BDS-TTE guidance):
- Start: Randomization date (RANDDT) or treatment start date (TRTSDT)
- Event: Death from any cause
- Censoring: Last known alive date if no death recorded

Parameters:
  adsl          - ADSL dataset with baseline and death info
  outds         - Output ADTTE dataset with OS records
  usubjid_var   - Subject ID (default: USUBJID)
  randdt_var    - Randomization date (default: RANDDT)
  trtsdt_var    - Treatment start date (default: TRTSDT)
  dthdt_var     - Death date (default: DTHDT)
  lstalvdt_var  - Last known alive date (default: LSTALVDT)

Output variables:
  PARAMCD  = 'OS'
  PARAM    = 'Overall Survival'
  AVISIT   = 'OS'
  CNSR     = 0=death, 1=censored
  AVAL     = OS time in days
  STARTDT  = Analysis start date
  EVNTDT   = Death/censoring date
  EVNTDESC = 'Death' or 'Censored'

Assumptions:
- ADSL contains one record per subject
- Death date and last alive date are pre-derived in ADSL
- If no LSTALVDT, fallback to RANDDT/TRTSDT as censoring date
******************************************************************************/

%macro derive_overall_survival(
    adsl=,
    outds=,
    usubjid_var=USUBJID,
    randdt_var=RANDDT,
    trtsdt_var=TRTSDT,
    dthdt_var=DTHDT,
    lstalvdt_var=LSTALVDT
) / des="Derive Overall Survival (OS) ADTTE endpoint";

    %if %sysevalf(%superq(adsl)=,boolean) or %sysevalf(%superq(outds)=,boolean) %then %do;
        %put ERROR: [derive_overall_survival] adsl= and outds= are required.;
        %return;
    %end;

    data &outds;
        set &adsl(keep=&usubjid_var &randdt_var &trtsdt_var &dthdt_var &lstalvdt_var);

        length PARAMCD $8 PARAM $40 AVISIT $10 EVNTFL $1 EVNTDESC $100;
        format STARTDT EVNTDT &dthdt_var &lstalvdt_var yymmdd10.;

        PARAMCD = 'OS';
        PARAM   = 'Overall Survival';
        AVISIT  = 'OS';

        /* Determine analysis start date */
        if not missing(&randdt_var) then STARTDT = &randdt_var;
        else STARTDT = &trtsdt_var;

        /* Initialize event variables */
        EVNTDT = .;
        EVNTDESC = '';
        EVNTFL = 'N';
        CNSR = 1;

        /* Death is the event */
        if not missing(&dthdt_var) and &dthdt_var >= STARTDT then do;
            EVNTDT   = &dthdt_var;
            EVNTDESC = 'Death';
            EVNTFL   = 'Y';
            CNSR     = 0;
        end;
        else do;
            /* No death: censor at last known alive */
            if not missing(&lstalvdt_var) and &lstalvdt_var >= STARTDT then do;
                EVNTDT   = &lstalvdt_var;
                EVNTDESC = 'Censored at last known alive date';
            end;
            else do;
                /* Fallback: censor at start if no follow-up info */
                EVNTDT   = STARTDT;
                EVNTDESC = 'Censored at start (no follow-up)';
            end;
        end;

        /* Calculate OS time in days */
        if not missing(EVNTDT) and not missing(STARTDT) then
            AVAL = EVNTDT - STARTDT + 1;
        else AVAL = .;

        length AVALC $20;
        if not missing(AVAL) then AVALC = strip(put(AVAL, best.));

        label
            PARAMCD  = "Parameter Code"
            PARAM    = "Parameter"
            AVISIT   = "Analysis Visit"
            STARTDT  = "OS Start Date (Randomization/Treatment Start)"
            CNSR     = "Censoring Indicator (0=death,1=censor)"
            AVAL     = "Overall Survival (Days)"
            AVALC    = "Overall Survival (Character)"
            EVNTFL   = "Event Flag (Y/N)"
            EVNTDT   = "OS Event/Censoring Date"
            EVNTDESC = "Description of OS Event/Censoring";
    run;

    proc freq data=&outds;
        tables CNSR EVNTDESC / missing;
        title "Overall Survival: Event vs Censoring";
    run;
    title;

    proc means data=&outds n mean min p25 median p75 max;
        class CNSR;
        var AVAL;
        title "Overall Survival (Days) by Censoring";
    run;
    title;

    %put NOTE: [derive_overall_survival] completed. Output: &outds.;

%mend derive_overall_survival;
