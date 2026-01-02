/******************************************************************************
 * Program: 83_adam_adtte.sas
 * Purpose: Create ADTTE (Time-to-Event Analysis Dataset) for Oncology
 * Author:  Clinical Programming Team
 * Date:    2025-01-02
 *
 * Description:
 *   Derives time-to-event endpoints for oncology efficacy analysis:
 *   - Progression-Free Survival (PFS)
 *   - Overall Survival (OS)
 *   - Time to Progression (TTP)
 *   - Duration of Response (DoR)
 *
 * Input Datasets:
 *   - adam.adsl        : Subject-level analysis dataset
 *   - adam.adrs_recist : Response assessment (RECIST) dataset
 *   - sdtm.ds          : Disposition domain
 *   - sdtm.ae          : Adverse events (for deaths)
 *
 * Output Dataset:
 *   - adam.adtte       : Time-to-event analysis dataset
 *
 * Modifications:
 *   Date        Programmer    Description
 *   ----------  ------------  ----------------------------------------------
 *   2025-01-02  Prog Team     Initial version
 ******************************************************************************/

%let pgmname = 83_adam_adtte;

*--- Initialize logging ---*;
%put NOTE: ========================================;
%put NOTE: Starting program &pgmname.;
%put NOTE: ========================================;

*--- Load configuration and macros ---*;
%include "&project_root./config/config.sas";
%include "&project_root./macros/utilities.sas";

*--- Read required datasets ---*;
libname adam "&project_root./adam/datasets";
libname sdtm "&project_root./sdtm/datasets";

data work.adsl;
    set adam.adsl;
run;

data work.adrs;
    set adam.adrs_recist;
run;

data work.ds;
    set sdtm.ds;
run;

data work.ae;
    set sdtm.ae(where=(aeser='Y' and upcase(aeout)='FATAL'));
run;

*--- Derive study day for events ---*;
data work.events_all;
    length usubjid $50 paramcd $8 param $200 cnsr 8 
           evntdesc $200 srcdom $8 srcvar $50;
    
    *--- Death events from DS ---*;
    set work.ds(where=(upcase(dsdecod)='DEATH'));
    
    usubjid = usubjid;
    paramcd = 'OS';
    param = 'Overall Survival';
    adt = dsstdtc;
    cnsr = 0;  /* Event occurred */
    evntdesc = 'Death';
    srcdom = 'DS';
    srcvar = 'DSSTDTC';
    output;
run;

*--- Progressive Disease from ADRS ---*;
data work.pd_events;
    set work.adrs(where=(upcase(avalc) in ('PD' 'PROGRESSIVE DISEASE')));
    
    length paramcd $8 param $200 cnsr 8 evntdesc $200;
    
    by usubjid adt;
    if first.usubjid;  /* First PD event */
    
    *--- PFS event ---*;
    paramcd = 'PFS';
    param = 'Progression-Free Survival';
    cnsr = 0;
    evntdesc = 'Progressive Disease';
    srcdom = 'ADRS';
    srcvar = 'ADT';
    output;
    
    *--- TTP event ---*;
    paramcd = 'TTP';
    param = 'Time to Progression';
    cnsr = 0;
    evntdesc = 'Progressive Disease';
    srcdom = 'ADRS';
    srcvar = 'ADT';
    output;
run;

*--- Combine all events ---*;
data work.all_events;
    set work.events_all work.pd_events;
run;

proc sort data=work.all_events;
    by usubjid paramcd adt;
run;

*--- Derive censoring for subjects without events ---*;
data work.adtte_base;
    merge 
        work.adsl(in=a keep=usubjid randdt trtsdt trtedt)
        work.all_events(in=b);
    by usubjid;
    
    if a;
    
    *--- Set reference date ---*;
    if not missing(trtsdt) then refdt = trtsdt;
    else refdt = randdt;
    
    *--- If no event, create censored record ---*;
    if not b then do;
        *--- OS censored at last known alive date ---*;
        paramcd = 'OS';
        param = 'Overall Survival';
        if not missing(trtedt) then adt = trtedt;
        else adt = trtsdt;
        cnsr = 1;
        evntdesc = 'Censored - Last known alive';
        srcdom = 'ADSL';
        srcvar = 'TRTEDT';
        output;
        
        *--- PFS censored at last assessment ---*;
        paramcd = 'PFS';
        param = 'Progression-Free Survival';
        if not missing(trtedt) then adt = trtedt;
        else adt = trtsdt;
        cnsr = 1;
        evntdesc = 'Censored - No PD observed';
        srcdom = 'ADSL';
        srcvar = 'TRTEDT';
        output;
        
        *--- TTP censored ---*;
        paramcd = 'TTP';
        param = 'Time to Progression';
        if not missing(trtedt) then adt = trtedt;
        else adt = trtsdt;
        cnsr = 1;
        evntdesc = 'Censored - No progression';
        srcdom = 'ADSL';
        srcvar = 'TRTEDT';
        output;
    end;
    else output;
run;

proc sort data=work.adtte_base;
    by usubjid paramcd adt;
run;

*--- Keep first event per parameter ---*;
data work.adtte_events;
    set work.adtte_base;
    by usubjid paramcd;
    if first.paramcd;
run;

*--- Derive analysis variables ---*;
data work.adtte;
    merge 
        work.adtte_events
        work.adsl(keep=usubjid trtsdt trtedt randdt 
                  trt01p trt01pn trt01a trt01an
                  age agegr1 agegr1n sex race ethnic
                  siteid country saffl efficfl);
    by usubjid;
    
    *--- Derive ADY (analysis day) ---*;
    if not missing(adt) and not missing(refdt) then do;
        ady = adt - refdt + (adt >= refdt);
    end;
    
    *--- Derive AVAL (analysis value in days) ---*;
    aval = ady;
    
    *--- Derive AVAL in months ---*;
    if not missing(aval) then avalm = aval / 30.4375;
    
    *--- Analysis flags ---*;
    anl01fl = 'Y';  /* General analysis flag */
    
    if efficfl = 'Y' then anl02fl = 'Y';  /* Efficacy population */
    else anl02fl = 'N';
    
    *--- Event indicator (opposite of censor) ---*;
    if cnsr = 0 then evntfl = 'Y';
    else evntfl = 'N';
    
    *--- Derive PARAMN ---*;
    select (paramcd);
        when ('OS')  paramn = 1;
        when ('PFS') paramn = 2;
        when ('TTP') paramn = 3;
        when ('DOR') paramn = 4;
        otherwise paramn = .;
    end;
    
    format adt refdt trtsdt trtedt randdt date9.;
    label
        usubjid  = 'Unique Subject Identifier'
        paramcd  = 'Parameter Code'
        param    = 'Parameter'
        paramn   = 'Parameter Number'
        aval     = 'Analysis Value (Days)'
        avalm    = 'Analysis Value (Months)'
        adt      = 'Analysis Date'
        ady      = 'Analysis Relative Day'
        cnsr     = 'Censor (0=Event, 1=Censored)'
        evntfl   = 'Event Flag'
        evntdesc = 'Event Description'
        anl01fl  = 'Analysis Flag 01'
        anl02fl  = 'Analysis Flag 02 (Efficacy)'
        srcdom   = 'Source Domain'
        srcvar   = 'Source Variable'
        refdt    = 'Reference Start Date';
run;

proc sort data=work.adtte;
    by usubjid paramn adt;
run;

*--- Create final ADTTE ---*;
data adam.adtte;
    set work.adtte;
run;

*--- Generate summary statistics ---*;
proc freq data=adam.adtte;
    tables paramcd*cnsr / nocol nopercent;
    title "ADTTE: Event and Censoring Summary";
run;

proc means data=adam.adtte n mean median min max;
    class paramcd;
    var aval avalm;
    title "ADTTE: Time-to-Event Summary Statistics";
run;

*--- Verify critical variables ---*;
%check_required_vars(
    dsn=adam.adtte,
    vars=USUBJID PARAMCD PARAM AVAL ADT CNSR EVNTFL
);

*--- Log completion ---*;
%put NOTE: ========================================;
%put NOTE: Program &pgmname completed successfully;
%put NOTE: Output: adam.adtte;
%put NOTE: ========================================;
