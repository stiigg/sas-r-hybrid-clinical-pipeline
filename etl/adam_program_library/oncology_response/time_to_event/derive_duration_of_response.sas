/******************************************************************************
Macro: derive_duration_of_response
Purpose: Derive Duration of Response (DOR) per RECIST 1.1 for ADTTE
Author: Christian Baghai
Date: December 2025

Description:
Derives Duration of Response (DOR) for subjects who achieved an objective
response (CR or PR). DOR is measured from the date of first documented
response (CR/PR) until the date of first documented progression (PD) or death.

Typical definition (oncology SAPs, CDISC guidance):
- Start: Date of first CR or PR (preferably confirmed)
- Event: First PD or death
- Censoring: Last adequate tumor assessment without PD
- Population: Responders only (subjects with CR or PR as BOR)

Parameters:
  adsl          - ADSL dataset with baseline info
  adrs          - ADRS dataset with overall response and dates
  adsurv        - Optional survival dataset with death dates
  outds         - Output ADTTE dataset with DOR records
  usubjid_var   - Subject ID (default: USUBJID)
  adt_var       - Assessment date in ADRS (default: ADT)
  ovr_var       - Overall response variable (default: OVR_RESP)
  dthdt_var     - Death date variable (default: DTHDT)
  srcdthds      - Dataset containing death date (default: ADSL)
  require_conf  - Require confirmed response for DOR (Y/N, default: Y)

Output variables:
  PARAMCD  = 'DOR'
  PARAM    = 'Duration of Response'
  AVISIT   = 'DOR'
  CNSR     = 0=event, 1=censored
  AVAL     = DOR time in days
  STARTDT  = Date of first response
  EVNTDT   = Event/censoring date
  EVNTDESC = Description of event/censoring

Assumptions:
- Input ADRS contains response assessments with dates
- Only subjects with objective response (CR/PR) will have DOR records
- Confirmation status can be derived or provided in ADRS
******************************************************************************/

%macro derive_duration_of_response(
    adsl=,
    adrs=,
    adsurv=,
    outds=,
    usubjid_var=USUBJID,
    adt_var=ADT,
    ovr_var=OVR_RESP,
    dthdt_var=DTHDT,
    srcdthds=ADSL,
    require_conf=Y
) / des="Derive Duration of Response (DOR) ADTTE endpoint";

    %if %sysevalf(%superq(adsl)=,boolean) or %sysevalf(%superq(adrs)=,boolean) or %sysevalf(%superq(outds)=,boolean) %then %do;
        %put ERROR: [derive_duration_of_response] adsl=, adrs= and outds= are required.;
        %return;
    %end;

    /* Step 1: Get death dates */
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

    /* Step 2: Identify first CR or PR date (response start) */
    data _resp;
        set &adrs(keep=&usubjid_var &adt_var &ovr_var);
        length OVR_STD $10;
        OVR_STD = upcase(strip(&ovr_var));
        if OVR_STD in ('CR','PR');
    run;

    proc sort data=_resp; by &usubjid_var &adt_var; run;

    data _first_resp;
        set _resp;
        by &usubjid_var &adt_var;
        if first.&usubjid_var;
        rename &adt_var = RESPDT;
        keep &usubjid_var &adt_var;
    run;

    /* Step 3: Identify first PD date */
    data _pd;
        set &adrs(keep=&usubjid_var &adt_var &ovr_var);
        length OVR_STD $10;
        OVR_STD = upcase(strip(&ovr_var));
        if OVR_STD = 'PD';
    run;

    proc sort data=_pd; by &usubjid_var &adt_var; run;

    data _first_pd;
        set _pd;
        by &usubjid_var &adt_var;
        if first.&usubjid_var;
        rename &adt_var = PDDT;
        keep &usubjid_var &adt_var;
    run;

    /* Step 4: Last adequate assessment (non-PD) for censoring */
    data _last_nonpd;
        set &adrs(keep=&usubjid_var &adt_var &ovr_var);
        length OVR_STD $10;
        OVR_STD = upcase(strip(&ovr_var));
        if OVR_STD ne 'PD';
    run;

    proc sort data=_last_nonpd; by &usubjid_var &adt_var; run;

    data _last_nonpd_dt;
        set _last_nonpd;
        by &usubjid_var &adt_var;
        if last.&usubjid_var;
        rename &adt_var = LASTNPD_DT;
        keep &usubjid_var &adt_var;
    run;

    /* Step 5: Merge response start, PD, death, last assessment */
    proc sort data=&adsl out=_adsl;
        by &usubjid_var;
    run;

    data _dor_base;
        merge _adsl(in=a keep=&usubjid_var)
              _first_resp
              _first_pd
              _dth
              _last_nonpd_dt;
        by &usubjid_var;
        if a;

        /* Only keep subjects who had a response */
        if not missing(RESPDT);

        label
            RESPDT      = "Date of First CR/PR"
            PDDT        = "Date of First PD"
            &dthdt_var  = "Death Date"
            LASTNPD_DT  = "Last Non-PD Assessment Date";
    run;

    /* Step 6: Derive DOR event and censoring */
    data &outds;
        set _dor_base;

        length PARAMCD $8 PARAM $40 AVISIT $10 EVNTFL $1 EVNTDESC $100;
        format EVNTDT RESPDT PDDT LASTNPD_DT &dthdt_var yymmdd10.;

        PARAMCD = 'DOR';
        PARAM   = 'Duration of Response';
        AVISIT  = 'DOR';
        STARTDT = RESPDT;

        /* Initialize event variables */
        EVNTDT = .;
        EVNTDESC = '';
        EVNTFL = 'N';
        CNSR = 1;

        /* Candidate event dates (must be after response start) */
        length _cand_pd _cand_dth 8;
        _cand_pd  = .;
        _cand_dth = .;

        if not missing(PDDT) and PDDT >= RESPDT then _cand_pd = PDDT;
        if not missing(&dthdt_var) and &dthdt_var >= RESPDT then _cand_dth = &dthdt_var;

        /* Pick earliest event */
        if not missing(_cand_pd) and not missing(_cand_dth) then do;
            if _cand_pd <= _cand_dth then do;
                EVNTDT   = _cand_pd;
                EVNTDESC = 'Progressive Disease';
            end;
            else do;
                EVNTDT   = _cand_dth;
                EVNTDESC = 'Death';
            end;
        end;
        else if not missing(_cand_pd) then do;
            EVNTDT   = _cand_pd;
            EVNTDESC = 'Progressive Disease';
        end;
        else if not missing(_cand_dth) then do;
            EVNTDT   = _cand_dth;
            EVNTDESC = 'Death';
        end;

        if not missing(EVNTDT) then do;
            EVNTFL = 'Y';
            CNSR   = 0;
        end;

        /* Censoring at last non-PD assessment */
        if CNSR = 1 then do;
            if not missing(LASTNPD_DT) and LASTNPD_DT >= RESPDT then do;
                EVNTDT   = LASTNPD_DT;
                EVNTDESC = 'Censored at last adequate assessment without PD';
            end;
            else do;
                EVNTDT   = RESPDT;
                EVNTDESC = 'Censored at response date (no subsequent assessment)';
            end;
        end;

        /* Calculate duration in days */
        if not missing(EVNTDT) and not missing(STARTDT) then
            AVAL = EVNTDT - STARTDT + 1;
        else AVAL = .;

        length AVALC $20;
        if not missing(AVAL) then AVALC = strip(put(AVAL, best.));

        label
            PARAMCD  = "Parameter Code"
            PARAM    = "Parameter"
            AVISIT   = "Analysis Visit"
            STARTDT  = "DOR Start Date (First Response)"
            CNSR     = "Censoring Indicator (0=event,1=censor)"
            AVAL     = "Duration of Response (Days)"
            AVALC    = "Duration of Response (Character)"
            EVNTFL   = "Event Flag (Y/N)"
            EVNTDT   = "DOR Event/Censoring Date"
            EVNTDESC = "Description of DOR Event/Censoring";
    run;

    proc freq data=&outds;
        tables CNSR EVNTDESC / missing;
        title "Duration of Response: Event vs Censoring";
    run;
    title;

    proc means data=&outds n mean min p25 median p75 max;
        class CNSR;
        var AVAL;
        title "Duration of Response (Days) by Censoring";
    run;
    title;

    proc datasets lib=work nolist;
        delete _dth _resp _first_resp _pd _first_pd _last_nonpd _last_nonpd_dt _adsl _dor_base;
    quit;

    %put NOTE: [derive_duration_of_response] completed. Output: &outds (responders only).;

%mend derive_duration_of_response;
