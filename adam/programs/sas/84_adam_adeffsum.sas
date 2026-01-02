/******************************************************************************
 * Program: 84_adam_adeffsum.sas
 * Purpose: Create ADEFFSUM (Efficacy Summary Dataset) for Oncology
 * Author:  Clinical Programming Team
 * Date:    2025-01-02
 *
 * Description:
 *   Derives summary efficacy endpoints for oncology analysis:
 *   - Best Overall Response (BOR)
 *   - Overall Response Rate (ORR: CR + PR)
 *   - Disease Control Rate (DCR: CR + PR + SD)
 *   - Clinical Benefit Rate (CBR: CR + PR + SD ≥6 months)
 *   - Duration of Response (DoR)
 *   - Time to Response (TTR)
 *
 * Input Datasets:
 *   - adam.adsl        : Subject-level analysis dataset
 *   - adam.adrs_recist : Response assessment (RECIST) dataset
 *
 * Output Dataset:
 *   - adam.adeffsum    : Efficacy summary dataset
 *
 * Modifications:
 *   Date        Programmer    Description
 *   ----------  ------------  ----------------------------------------------
 *   2025-01-02  Prog Team     Initial version
 ******************************************************************************/

%let pgmname = 84_adam_adeffsum;

*--- Initialize logging ---*;
%put NOTE: ========================================;
%put NOTE: Starting program &pgmname.;
%put NOTE: ========================================;

*--- Load configuration and macros ---*;
%include "&project_root./config/config.sas";
%include "&project_root./macros/utilities.sas";

*--- Read required datasets ---*;
libname adam "&project_root./adam/datasets";

data work.adsl;
    set adam.adsl;
run;

data work.adrs;
    set adam.adrs_recist;
run;

*--- Step 1: Derive Best Overall Response (BOR) ---*;
data work.bor_data;
    set work.adrs(where=(paramcd='OVR' and anl01fl='Y'));
    by usubjid adt;
    
    *--- Rank responses (lower is better) ---*;
    select (upcase(avalc));
        when ('CR', 'COMPLETE RESPONSE')       avaln = 1;
        when ('PR', 'PARTIAL RESPONSE')        avaln = 2;
        when ('SD', 'STABLE DISEASE')          avaln = 3;
        when ('NON-CR/NON-PD')                 avaln = 4;
        when ('PD', 'PROGRESSIVE DISEASE')     avaln = 5;
        when ('NE', 'NOT EVALUABLE')           avaln = 6;
        otherwise                              avaln = 7;
    end;
run;

proc sort data=work.bor_data;
    by usubjid avaln adt;
run;

*--- Select best response ---*;
data work.bor;
    set work.bor_data;
    by usubjid avaln;
    if first.usubjid;
    
    length paramcd $8 param $200;
    paramcd = 'BOR';
    param = 'Best Overall Response';
    
    *--- Assign confirmed response ---*;
    if avaln = 1 then avalc = 'CR';
    else if avaln = 2 then avalc = 'PR';
    else if avaln = 3 then avalc = 'SD';
    else if avaln = 4 then avalc = 'NON-CR/NON-PD';
    else if avaln = 5 then avalc = 'PD';
    else avalc = 'NE';
    
    aval = avaln;
run;

*--- Step 2: Derive Overall Response Rate (ORR) ---*;
data work.orr;
    set work.bor;
    
    length paramcd $8 param $200;
    paramcd = 'ORR';
    param = 'Overall Response Rate (CR+PR)';
    
    if upcase(avalc) in ('CR' 'PR') then do;
        avalc = 'RESPONDER';
        aval = 1;
    end;
    else do;
        avalc = 'NON-RESPONDER';
        aval = 0;
    end;
run;

*--- Step 3: Derive Disease Control Rate (DCR) ---*;
data work.dcr;
    set work.bor;
    
    length paramcd $8 param $200;
    paramcd = 'DCR';
    param = 'Disease Control Rate (CR+PR+SD)';
    
    if upcase(avalc) in ('CR' 'PR' 'SD' 'NON-CR/NON-PD') then do;
        avalc = 'DISEASE CONTROL';
        aval = 1;
    end;
    else do;
        avalc = 'NO DISEASE CONTROL';
        aval = 0;
    end;
run;

*--- Step 4: Derive Duration of Response (DoR) ---*;
data work.resp_dates;
    set work.adrs(where=(upcase(avalc) in ('CR' 'PR')));
    by usubjid adt;
    
    if first.usubjid then do;
        resp_start = adt;
        retain resp_start;
    end;
run;

data work.pd_dates;
    set work.adrs(where=(upcase(avalc) in ('PD' 'PROGRESSIVE DISEASE')));
    by usubjid adt;
    if first.usubjid then pd_date = adt;
    keep usubjid pd_date;
run;

data work.dor;
    merge 
        work.resp_dates(keep=usubjid resp_start where=(not missing(resp_start)))
        work.pd_dates
        work.adsl(keep=usubjid trtedt);
    by usubjid;
    
    if not missing(resp_start);
    
    length paramcd $8 param $200;
    paramcd = 'DOR';
    param = 'Duration of Response';
    
    *--- Calculate duration ---*;
    if not missing(pd_date) then do;
        adt = pd_date;
        aval = pd_date - resp_start + 1;
        cnsr = 0;  /* Event */
        avalc = 'PROGRESSED';
    end;
    else do;
        if not missing(trtedt) then adt = trtedt;
        else adt = resp_start;
        aval = adt - resp_start + 1;
        cnsr = 1;  /* Censored */
        avalc = 'CENSORED';
    end;
    
    *--- Convert to months ---*;
    avalm = aval / 30.4375;
    
    format resp_start adt pd_date date9.;
run;

*--- Step 5: Derive Time to Response (TTR) ---*;
data work.ttr;
    merge 
        work.adsl(keep=usubjid trtsdt)
        work.resp_dates(keep=usubjid resp_start);
    by usubjid;
    
    if not missing(resp_start) and not missing(trtsdt);
    
    length paramcd $8 param $200;
    paramcd = 'TTR';
    param = 'Time to Response';
    
    adt = resp_start;
    aval = resp_start - trtsdt + 1;
    avalm = aval / 30.4375;
    avalc = 'RESPONDER';
    
    format adt trtsdt date9.;
run;

*--- Combine all endpoints ---*;
data work.adeffsum_all;
    set work.bor 
        work.orr 
        work.dcr 
        work.dor 
        work.ttr;
run;

proc sort data=work.adeffsum_all;
    by usubjid paramcd;
run;

*--- Merge with ADSL for demographics ---*;
data work.adeffsum;
    merge 
        work.adeffsum_all
        work.adsl(keep=usubjid trtsdt trtedt randdt 
                  trt01p trt01pn trt01a trt01an
                  age agegr1 agegr1n sex race ethnic
                  siteid country saffl efficfl);
    by usubjid;
    
    *--- Derive PARAMN ---*;
    select (paramcd);
        when ('BOR') paramn = 1;
        when ('ORR') paramn = 2;
        when ('DCR') paramn = 3;
        when ('DOR') paramn = 4;
        when ('TTR') paramn = 5;
        when ('CBR') paramn = 6;
        otherwise paramn = .;
    end;
    
    *--- Analysis flags ---*;
    anl01fl = 'Y';
    if efficfl = 'Y' then anl02fl = 'Y';
    else anl02fl = 'N';
    
    label
        usubjid  = 'Unique Subject Identifier'
        paramcd  = 'Parameter Code'
        param    = 'Parameter'
        paramn   = 'Parameter Number'
        aval     = 'Analysis Value'
        avalc    = 'Analysis Value (Character)'
        avalm    = 'Analysis Value (Months)'
        adt      = 'Analysis Date'
        cnsr     = 'Censor Flag'
        anl01fl  = 'Analysis Flag 01'
        anl02fl  = 'Analysis Flag 02 (Efficacy)';
run;

proc sort data=work.adeffsum;
    by usubjid paramn;
run;

*--- Create final ADEFFSUM ---*;
data adam.adeffsum;
    set work.adeffsum;
run;

*--- Generate summary statistics ---*;
proc freq data=adam.adeffsum;
    tables paramcd*avalc / nocol nopercent;
    title "ADEFFSUM: Efficacy Endpoint Summary";
run;

proc means data=adam.adeffsum(where=(paramcd in ('DOR' 'TTR'))) 
           n mean median min max;
    class paramcd;
    var aval avalm;
    title "ADEFFSUM: Duration/Time Summary Statistics";
run;

*--- Verify critical variables ---*;
%check_required_vars(
    dsn=adam.adeffsum,
    vars=USUBJID PARAMCD PARAM AVAL
);

*--- Log completion ---*;
%put NOTE: ========================================;
%put NOTE: Program &pgmname completed successfully;
%put NOTE: Output: adam.adeffsum;
%put NOTE: ========================================;
