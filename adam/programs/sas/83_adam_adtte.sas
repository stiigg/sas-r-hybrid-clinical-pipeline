/******************************************************************************
 * Program: 83_adam_adtte.sas
 * Purpose: Create ADTTE (Time-to-Event Analysis Dataset) for Hematologic Malignancies
 * Author:  Clinical Programming Team
 * Date:    2025-01-02
 * Updated: 2026-01-03
 *
 * Description:
 *   Derives time-to-event endpoints for hematologic malignancies and CAR-T:
 *   - Overall Survival (OS)
 *   - Progression-Free Survival (PFS)
 *   - Time to Progression (TTP)
 *   - Duration of Response (DoR) per IMWG criteria
 *   - MRD negativity integration as time-varying covariate
 *   - Competing risks classification (disease vs treatment-related)
 *   - CAR-T exposure timing (vein-to-vein, collection-to-infusion)
 *
 * Input Datasets:
 *   - adam.adsl        : Subject-level analysis dataset with CAR-T dates
 *   - adam.adrs_recist : Response assessment (RECIST/IMWG) dataset
 *   - sdtm.ds          : Disposition domain
 *   - sdtm.ae          : Adverse events (for treatment-related deaths)
 *
 * Output Dataset:
 *   - adam.adtte       : Time-to-event analysis dataset
 *
 * Modifications:
 *   Date        Programmer    Description
 *   ----------  ------------  ----------------------------------------------
 *   2025-01-02  Prog Team     Initial version
 *   2026-01-03  Prog Team     Add CAR-T/hematologic malignancy updates:
 *                             - DoR per IMWG (CR/sCR/VGPR/PR)
 *                             - MRD integration (10^-5, 10^-6)
 *                             - Competing risks (TRM vs disease)
 *                             - V2Vt stratification (<28, 28-<40, >=40d)
 *                             - CAR-T timing variables
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

*--- Duration of Response per IMWG criteria ---*;
data work.response_start;
    set work.adrs(where=(upcase(avalc) in ('CR' 'SCR' 'VGPR' 'PR')));
    by usubjid adt;
    if first.usubjid;  /* First response date */
    respdt = adt;
    resptype = avalc;  /* CR, sCR, VGPR, or PR */
    keep usubjid respdt resptype;
run;

data work.dor_events;
    merge 
        work.response_start(in=a)
        work.pd_events(keep=usubjid adt evntdesc in=b rename=(adt=pddt))
        work.events_all(keep=usubjid adt where=(paramcd='OS') in=c rename=(adt=deathdt));
    by usubjid;
    
    if a;  /* Only subjects achieving response */
    
    length paramcd $8 param $200 cnsr 8 evntdesc $200 srcdom $8 srcvar $50 resptype $20;
    
    paramcd = 'DOR';
    param = 'Duration of Response';
    srcdom = 'ADRS';
    
    *--- Reference start date is first response ---*;
    dorrefdt = respdt;
    
    *--- Event: PD or death (whichever comes first) ---*;
    if not missing(pddt) and (missing(deathdt) or pddt <= deathdt) then do;
        adt = pddt;
        cnsr = 0;
        evntdesc = 'Progressive Disease';
        srcvar = 'ADT';
    end;
    else if not missing(deathdt) then do;
        adt = deathdt;
        cnsr = 0;
        evntdesc = 'Death';
        srcvar = 'DSSTDTC';
    end;
    else do;  /* Censored at last assessment */
        if not missing(pddt) then adt = pddt;
        else if not missing(deathdt) then adt = deathdt;
        else adt = respdt;
        cnsr = 1;
        evntdesc = 'Censored - No progression/death';
        srcvar = 'TRTEDT';
    end;
    
    output;
run;

*--- Minimal Residual Disease Assessment Events ---*;
data work.mrd_assessments;
    set adam.adrs_recist(where=(upcase(paramcd)='MRD'));
    
    length mrdfl $1 mrddesc $200 mrdsens $10;
    
    *--- MRD Negativity Flag (10^-5 or 10^-6 sensitivity) ---*;
    if upcase(avalc) in ('NEGATIVE' 'NEG' 'UNDETECTABLE' 'ND') then do;
        mrdfl = 'Y';
        mrddesc = 'MRD Negative';
    end;
    else if upcase(avalc) in ('POSITIVE' 'POS' 'DETECTABLE' 'DET') then do;
        mrdfl = 'N';
        mrddesc = 'MRD Positive';
    end;
    
    *--- Capture sensitivity level ---*;
    if index(upcase(param), '10-5') > 0 or aval = 0.00001 then mrdsens = '10E-5';
    else if index(upcase(param), '10-6') > 0 or aval = 0.000001 then mrdsens = '10E-6';
    
    mrdadt = adt;
    keep usubjid mrdadt mrdfl mrddesc mrdsens aval;
    rename aval=mrdval;
run;

*--- Combine all events ---*;
data work.all_events;
    set work.events_all work.pd_events work.dor_events;
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

*--- Competing Risks Classification for CAR-T Studies ---*;
data work.adtte_comprisk;
    set work.adtte_events;
    
    length compevnt $100 compfl $1 cuminc_grp $1;
    
    *--- Classify competing event types ---*;
    if cnsr = 0 then do;
        *--- For OS: distinguish treatment-related vs disease mortality ---*;
        if paramcd = 'OS' then do;
            if index(upcase(evntdesc), 'TOXICITY') > 0 or 
               index(upcase(evntdesc), 'CRS') > 0 or
               index(upcase(evntdesc), 'ICANS') > 0 or
               index(upcase(evntdesc), 'INFECTION') > 0 then do;
                compevnt = 'Treatment-Related Mortality';
                compfl = 'Y';
                cuminc_grp = '1';  /* Competing risk group 1 */
            end;
            else do;
                compevnt = 'Disease-Related Mortality';
                compfl = 'N';
                cuminc_grp = '2';  /* Competing risk group 2 */
            end;
        end;
        *--- For PFS/TTP: progression is primary event ---*;
        else if paramcd in ('PFS' 'TTP') then do;
            compevnt = 'Disease Progression';
            compfl = 'N';
            cuminc_grp = '2';
        end;
        *--- For DOR: PD or death ---*;
        else if paramcd = 'DOR' then do;
            if index(upcase(evntdesc), 'DEATH') > 0 then do;
                compevnt = 'Death';
                compfl = 'N';
                cuminc_grp = '2';
            end;
            else do;
                compevnt = 'Progressive Disease';
                compfl = 'N';
                cuminc_grp = '2';
            end;
        end;
    end;
    else do;
        *--- Censored observations ---*;
        cuminc_grp = '9';
    end;
    
    label
        compevnt = 'Competing Event Description'
        compfl = 'Competing Risk Flag (Y=TRM, N=Disease)'
        cuminc_grp = 'Cumulative Incidence Group';
run;

*--- Derive analysis variables with CAR-T timing ---*;
data work.adtte;
    merge 
        work.adtte_comprisk
        work.adsl(keep=usubjid trtsdt trtedt randdt 
                  trt01p trt01pn trt01a trt01an
                  age agegr1 agegr1n sex race ethnic
                  siteid country saffl efficfl
                  /* CAR-T specific dates if available */
                  cart_coll_dt cart_inf_dt);
    by usubjid;
    
    length v2vt_cat $15 respdepth $10;
    
    *--- Set reference date ---*;
    if not missing(trtsdt) then refdt = trtsdt;
    else refdt = randdt;
    
    *--- CAR-T Alternative Reference Dates ---*;
    if not missing(cart_inf_dt) then refdt_inf = cart_inf_dt;    /* Infusion */
    if not missing(cart_coll_dt) then refdt_coll = cart_coll_dt; /* Collection */
    
    *--- Derive ADY from treatment start ---*;
    if not missing(adt) and not missing(refdt) then do;
        ady = adt - refdt + (adt >= refdt);
    end;
    
    *--- Derive ADY from CAR-T specific dates ---*;
    if not missing(adt) and not missing(cart_coll_dt) then do;
        ady_coll = adt - cart_coll_dt + (adt >= cart_coll_dt);
    end;
    
    if not missing(adt) and not missing(cart_inf_dt) then do;
        ady_inf = adt - cart_inf_dt + (adt >= cart_inf_dt);
    end;
    
    *--- Vein-to-vein time (collection to infusion) ---*;
    if not missing(cart_coll_dt) and not missing(cart_inf_dt) then do;
        vein2vein = cart_inf_dt - cart_coll_dt;
        
        *--- Categorical V2Vt per 2025 research thresholds ---*;
        if vein2vein < 28 then v2vt_cat = '<28 days';
        else if vein2vein < 40 then v2vt_cat = '28-<40 days';
        else v2vt_cat = '>=40 days';
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
    
    *--- Response depth at event (for DoR analysis) ---*;
    if paramcd = 'DOR' and not missing(resptype) then do;
        if upcase(resptype) in ('CR' 'SCR') then respdepth = 'CR';
        else if upcase(resptype) = 'VGPR' then respdepth = 'VGPR';
        else if upcase(resptype) = 'PR' then respdepth = 'PR';
    end;
    
    *--- Derive PARAMN ---*;
    select (paramcd);
        when ('OS')  paramn = 1;
        when ('PFS') paramn = 2;
        when ('TTP') paramn = 3;
        when ('DOR') paramn = 4;
        otherwise paramn = .;
    end;
    
    format adt refdt refdt_inf refdt_coll trtsdt trtedt randdt 
           cart_coll_dt cart_inf_dt dorrefdt date9.;
    label
        usubjid    = 'Unique Subject Identifier'
        paramcd    = 'Parameter Code'
        param      = 'Parameter'
        paramn     = 'Parameter Number'
        aval       = 'Analysis Value (Days)'
        avalm      = 'Analysis Value (Months)'
        adt        = 'Analysis Date'
        ady        = 'Analysis Relative Day'
        ady_coll   = 'Analysis Day from T-Cell Collection'
        ady_inf    = 'Analysis Day from CAR-T Infusion'
        cnsr       = 'Censor (0=Event, 1=Censored)'
        evntfl     = 'Event Flag'
        evntdesc   = 'Event Description'
        anl01fl    = 'Analysis Flag 01'
        anl02fl    = 'Analysis Flag 02 (Efficacy)'
        srcdom     = 'Source Domain'
        srcvar     = 'Source Variable'
        refdt      = 'Reference Start Date'
        refdt_inf  = 'Reference Date: CAR-T Infusion'
        refdt_coll = 'Reference Date: T-Cell Collection'
        dorrefdt   = 'DoR Reference Date (First Response)'
        vein2vein  = 'Vein-to-Vein Time (Days)'
        v2vt_cat   = 'Vein-to-Vein Time Category'
        respdepth  = 'Depth of Response (CR/VGPR/PR)'
        resptype   = 'Response Type at Start';
run;

proc sort data=work.adtte;
    by usubjid paramn adt;
run;

*--- Merge most recent MRD status before event ---*;
proc sql;
    create table work.adtte_mrd as
    select a.*, 
           b.mrdfl, 
           b.mrddesc, 
           b.mrdadt, 
           b.mrdval,
           b.mrdsens
    from work.adtte a
    left join work.mrd_assessments b
    on a.usubjid = b.usubjid 
    and b.mrdadt <= a.adt
    group by a.usubjid, a.paramcd
    having b.mrdadt = max(b.mrdadt);  /* Most recent MRD before event */
quit;

*--- Create final ADTTE with all enhancements ---*;
data adam.adtte;
    set work.adtte_mrd;
    
    label
        mrdfl = 'MRD Negative Flag (Most Recent Before Event)'
        mrddesc = 'MRD Description'
        mrdadt = 'MRD Assessment Date'
        mrdval = 'MRD Value'
        mrdsens = 'MRD Sensitivity Level';
    
    format mrdadt date9.;
run;

proc sort data=adam.adtte;
    by usubjid paramn adt;
run;

*--- Generate summary statistics ---*;
proc freq data=adam.adtte;
    tables paramcd*cnsr / nocol nopercent;
    title "ADTTE: Event and Censoring Summary";
run;

proc freq data=adam.adtte;
    where paramcd = 'DOR';
    tables respdepth*cnsr / nocol nopercent missing;
    title "ADTTE: Duration of Response by Response Depth";
run;

proc freq data=adam.adtte;
    where not missing(v2vt_cat);
    tables v2vt_cat*paramcd*cnsr / nocol nopercent;
    title "ADTTE: Events by Vein-to-Vein Time Category";
run;

proc freq data=adam.adtte;
    where not missing(mrdfl);
    tables mrdfl*paramcd*cnsr / nocol nopercent;
    title "ADTTE: Events by MRD Status";
run;

proc freq data=adam.adtte;
    where paramcd = 'OS' and cnsr = 0;
    tables compevnt / missing;
    title "ADTTE: Competing Risk Event Types";
run;

proc means data=adam.adtte n mean median min max;
    class paramcd;
    var aval avalm;
    title "ADTTE: Time-to-Event Summary Statistics";
run;

proc means data=adam.adtte n mean median min max;
    where not missing(vein2vein);
    var vein2vein;
    title "ADTTE: Vein-to-Vein Time Distribution";
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
%put NOTE: New features: DoR, MRD, Competing Risks, V2Vt;
%put NOTE: ========================================;