/****************************************************************************
MACRO: derive_al_cardiac_response
PURPOSE: Derive AL amyloidosis cardiac response per Palladini 2022 graded criteria

CARDIAC RESPONSE CATEGORIES (NT-proBNP based):
- CarCR:   NT-proBNP <300 ng/L (if baseline <650) OR >50% reduction (if baseline ≥650)
- CarVGPR: >60% reduction in NT-proBNP with absolute reduction ≥300 ng/L
- CarPR:   >30% reduction in NT-proBNP with absolute reduction ≥300 ng/L
- CarNR:   Not meeting PR criteria

REFERENCE: Palladini et al. Blood 2022;139(13):2013-2023
           Sidana et al. Blood Advances 2020;4(7):1353-1361
*****************************************************************************/

%macro derive_al_cardiac_response(
    lb_ds=,
    outds=,
    usubjid=USUBJID,
    visit_var=VISIT,
    baseline_flag=ABLFL
);

/* Extract NT-proBNP values from LB domain */
proc sql;
    create table work._ntbnp_data as
    select 
        &usubjid,
        &visit_var,
        input(LBDTC, yymmdd10.) as ADT format=yymmdd10.,
        input(LBSTRESC, best.) as NTBNP_VALUE,
        max(case when &baseline_flag='Y' then 1 else 0 end) as BASELINE_FLAG
    from &lb_ds
    where upcase(LBTESTCD) = 'NTBNP'
    group by &usubjid, &visit_var, calculated ADT, calculated NTBNP_VALUE
    order by &usubjid, calculated ADT;
quit;

/* Calculate percent and absolute changes */
data &outds;
    set work._ntbnp_data;
    by &usubjid;
    
    retain BASELINE_NTBNP;
    if BASELINE_FLAG = 1 then BASELINE_NTBNP = NTBNP_VALUE;
    
    /* Percent change from baseline */
    if BASELINE_NTBNP > 0 then do;
        PCHG_NTBNP = ((NTBNP_VALUE - BASELINE_NTBNP) / BASELINE_NTBNP) * 100;
        ACHG_NTBNP = NTBNP_VALUE - BASELINE_NTBNP;
    end;
    
    /* Assign cardiac response per Palladini 2022 criteria */
    length CAR_RESP $10 CAR_LOGIC $200;
    
    /* CarCR: Two different criteria based on baseline level */
    if (BASELINE_NTBNP < 650 and NTBNP_VALUE < 300) or
       (BASELINE_NTBNP >= 650 and PCHG_NTBNP <= -50) then do;
        CAR_RESP = 'CarCR';
        CAR_LOGIC = cats('Cardiac CR: ',
                         ifc(BASELINE_NTBNP < 650,
                             'NT-proBNP <300 ng/L',
                             cats('>50% reduction (', put(abs(PCHG_NTBNP), 5.1), '%)')));
    end;
    
    /* CarVGPR: >60% reduction + absolute ≥300 ng/L */
    else if PCHG_NTBNP <= -60 and ACHG_NTBNP <= -300 then do;
        CAR_RESP = 'CarVGPR';
        CAR_LOGIC = cats('Cardiac VGPR: ', put(abs(PCHG_NTBNP), 5.1),
                         '% reduction + ', put(abs(ACHG_NTBNP), 6.0), ' ng/L absolute decrease');
    end;
    
    /* CarPR: >30% reduction + absolute ≥300 ng/L */
    else if PCHG_NTBNP <= -30 and ACHG_NTBNP <= -300 then do;
        CAR_RESP = 'CarPR';
        CAR_LOGIC = cats('Cardiac PR: ', put(abs(PCHG_NTBNP), 5.1),
                         '% reduction + ', put(abs(ACHG_NTBNP), 6.0), ' ng/L absolute decrease');
    end;
    
    /* CarNR: No response */
    else do;
        CAR_RESP = 'CarNR';
        CAR_LOGIC = 'Cardiac No Response: Not meeting PR criteria';
    end;
    
    label
        CAR_RESP = 'Cardiac Response Category (AL Amyloidosis)'
        CAR_LOGIC = 'Cardiac Response Logic'
        NTBNP_VALUE = 'NT-proBNP Value (ng/L)'
        BASELINE_NTBNP = 'Baseline NT-proBNP (ng/L)'
        PCHG_NTBNP = '% Change in NT-proBNP from Baseline'
        ACHG_NTBNP = 'Absolute Change in NT-proBNP (ng/L)';
run;

/* Frequency distribution */
proc freq data=&outds;
    tables CAR_RESP / nocum;
    title "Cardiac Response Distribution (AL Amyloidosis)";
run;
title;

/* Clean up */
proc datasets library=work nolist;
    delete _ntbnp_data;
quit;

%mend derive_al_cardiac_response;
