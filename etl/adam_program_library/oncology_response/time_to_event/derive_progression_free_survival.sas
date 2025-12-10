/******************************************************************************
Macro: derive_progression_free_survival
Purpose: Derive Progression-Free Survival (PFS) endpoint for ADTTE
Author: Christian Baghai
Date: December 2025

Description:
Derives PFS time-to-event records from input data containing:
- Start date (e.g., randomization or first dose)
- Tumor assessment-based progression (PD) dates
- New lesion dates
- Death dates
- Censoring rules based on last adequate assessment

PFS definition (typical oncology SAPs, CDISC BDS-TTE guidance):
- Time from randomization (or first dose) to earliest of:
  * Objective disease progression (PD), or
  * Death from any cause
- Censored at last adequate tumor assessment without PD if no event.

Parameters:
  adsl          - ADSL-like dataset with baseline dates
  adrs          - ADRS-like dataset with OVR_RESP and dates
  adsurv        - Optional survival DS with death dates (if not in ADSL)
  outds         - Output ADTTE-style dataset with PFS records
  usubjid_var   - Subject ID (default: USUBJID)
  randdt_var    - Randomization date (default: RANDDT)
  trtsdt_var    - Treatment start date (optional, default: TRTSDT)
  adt_var       - Response assessment date in ADRS (default: ADT)
  ovr_var       - Overall response in ADRS (default: OVR_RESP)
  dthdt_var     - Death date in ADSL/ADSURV (default: DTHDT)
  srcdthds      - Dataset where DTHDT resides (ADSL or ADSURV; default: ADSL)

Output variables (core):
  PARAMCD = 'PFS'
  PARAM   = 'Progression-Free Survival'
  AVISIT  = 'PFS'
  CNSR    = 0=event, 1=censored
  AVAL    = PFS time (days)
  AVALC   = PFS time (formatted)
  EVNTDT  = event/censoring date
  EVNTFL  = 'Y' if event
  EVNTDESC= 'PD', 'Death', 'No event', etc.

This macro is intentionally simple and template-like; adapt to your trial SAP.
******************************************************************************/

%macro derive_progression_free_survival(
    adsl=,
    adrs=,
    adsurv=,
    outds=,
    usubjid_var=USUBJID,
    randdt_var=RANDDT,
    trtsdt_var=TRTSDT,
    adt_var=ADT,
    ovr_var=OVR_RESP,
    dthdt_var=DTHDT,
    srcdthds=ADSL
) / des="Derive PFS ADTTE-style endpoint";

    %if %sysevalf(%superq(adsl)=,boolean) or %sysevalf(%superq(adrs)=,boolean) or %sysevalf(%superq(outds)=,boolean) %then %do;
        %put ERROR: [derive_progression_free_survival] adsl=, adrs= and outds= are required.;
        %return;
    %end;

    /* Step 1: Death date source */
    %if %upcase(&srcdthds) = ADSL %then %do;
        data _dth;
            set &adsl(keep=&usubjid_var &dthdt_var);
        run;
    %end;
    %else %do;
        data _dth;
            set &adsurv(keep=&usubjid_var &dthdt_var);
        run;
    %end;

    proc sort data=_dth; by &usubjid_var; run;

    /* Step 2: First PD / progression date from ADRS */
    data _pd;
        set &adrs(keep=&usubjid_var &adt_var &ovr_var);
        length OVR_STD $10;
        OVR_STD = upcase(strip(&ovr_var));
        if OVR_STD = 'PD';
    run;

    proc sort data=_pd; by &usubjid_var &adt_var; run;

    data _pd_first;
        set _pd;
        by &usubjid_var &adt_var;
        if first.&usubjid_var;
        rename &adt_var = PDDT;
        keep &usubjid_var &adt_var;
    run;

    /* Step 3: Last adequate assessment date (no PD) for censoring */
    data _last_nonpd;
        set &adrs(keep=&usubjid_var &adt_var &ovr_var);
        length OVR_STD $10;
        OVR_STD = upcase(strip(&ovr_var));
        if OVR_STD ne 'PD';
    run;

    proc sort data=_last_nonpd; by &usubjid_var &adt_var; run;

    data _last_nonpd_last;
        set _last_nonpd;
        by &usubjid_var &adt_var;
        if last.&usubjid_var;
        rename &adt_var = LASTNPD_DT;
        keep &usubjid_var &adt_var;
    run;

    /* Step 4: Merge ADSL (start), PD, death, and last non-PD */
    proc sort data=&adsl out=_adsl;
        by &usubjid_var;
    run;

    data _pfs_base;
        merge _adsl(in=a keep=&usubjid_var &randdt_var &trtsdt_var)
              _pd_first
              _dth
              _last_nonpd_last;
        by &usubjid_var;
        if a;

        /* Choose analysis start date: randomization preferred, else treatment start */
        if not missing(&randdt_var) then PFS_STARTDT = &randdt_var;
        else PFS_STARTDT = &trtsdt_var;

        label
            PFS_STARTDT = "PFS Analysis Start Date"
            PDDT        = "First PD Date"
            &dthdt_var  = "Death Date"
            LASTNPD_DT  = "Last Non-PD Assessment Date";
    run;

    /* Step 5: Determine event type and event/censoring date */
    data &outds;
        set _pfs_base;

        length PARAMCD $8 PARAM $40 AVISIT $10 EVNTFL $1 EVNTDESC $40;
        format EVNTDT PFS_STARTDT PDDT LASTNPD_DT &dthdt_var yymmdd10.;

        PARAMCD = 'PFS';
        PARAM   = 'Progression-Free Survival';
        AVISIT  = 'PFS';

        /* Determine earliest event date among PD and death (if after start) */
        EVNTDT = .;
        EVNTDESC = '';
        EVNTFL = 'N';
        CNSR = 1;

        /* Candidate event dates */
        length _cand_pd _cand_dth 8;
        _cand_pd  = .;
        _cand_dth = .;

        if not missing(PDDT)  and PDDT  >= PFS_STARTDT then _cand_pd  = PDDT;
        if not missing(&dthdt_var) and &dthdt_var >= PFS_STARTDT then _cand_dth = &dthdt_var;

        /* Pick earliest non-missing */
        if not missing(_cand_pd) and not missing(_cand_dth) then do;
            if _cand_pd <= _cand_dth then do;
                EVNTDT   = _cand_pd;
                EVNTDESC = 'PD';
            end;
            else do;
                EVNTDT   = _cand_dth;
                EVNTDESC = 'Death';
            end;
        end;
        else if not missing(_cand_pd) then do;
            EVNTDT   = _cand_pd;
            EVNTDESC = 'PD';
        end;
        else if not missing(_cand_dth) then do;
            EVNTDT   = _cand_dth;
            EVNTDESC = 'Death';
        end;

        if not missing(EVNTDT) then do;
            EVNTFL = 'Y';
            CNSR   = 0;
        end;

        /* If no event, censor at last adequate assessment if available */
        if CNSR = 1 then do;
            if not missing(LASTNPD_DT) and LASTNPD_DT >= PFS_STARTDT then do;
                EVNTDT   = LASTNPD_DT;
                EVNTDESC = 'Censored at last non-PD';
            end;
            else do;
                /* Fallback: censor at start date if nothing else */
                EVNTDT   = PFS_STARTDT;
                EVNTDESC = 'No post-baseline assessment; censored at start';
            end;
        end;

        /* Derive time in days */
        if not missing(EVNTDT) and not missing(PFS_STARTDT) then
            AVAL = EVNTDT - PFS_STARTDT + 1;
        else AVAL = .;

        length AVALC $20;
        if not missing(AVAL) then AVALC = strip(put(AVAL, best.));

        label
            PARAMCD  = "Parameter Code"
            PARAM    = "Parameter"
            AVISIT   = "Analysis Visit"
            CNSR     = "Censoring Indicator (0=event,1=censor)"
            AVAL     = "PFS Time (Days)"
            AVALC    = "PFS Time (Character)"
            EVNTFL   = "Event Flag (Y/N)"
            EVNTDT   = "PFS Event/Censoring Date"
            EVNTDESC = "Description of Event/Censoring";
    run;

    proc freq data=&outds;
        tables CNSR EVNTDESC / missing;
        title "PFS Endpoint: Event vs Censoring";
    run;
    title;

    proc means data=&outds n mean min p25 median p75 max;
        class CNSR;
        var AVAL;
        title "PFS Time (Days) by Censoring";
    run;
    title;

    proc datasets lib=work nolist;
        delete _dth _pd _pd_first _last_nonpd _last_nonpd_last _adsl _pfs_base;
    quit;

    %put NOTE: [derive_progression_free_survival] completed. Output: &outds.;

%mend derive_progression_free_survival;
