/****************************************************************************
MACRO: derive_imwg_response
PURPOSE: Derive IMWG response for Multiple Myeloma

KEY DIFFERENCES FROM YOUR RECIST IMPLEMENTATION:
1. Input: LB domain (M-protein values) instead of RS domain (tumor measurements)
2. Thresholds: 50% for PR, 90% for VGPR (vs 30%/20% in RECIST)
3. Additional: Bone marrow requirement (<5% plasma cells for CR)
4. Nadir tracking: 25% increase defines PD (vs 20% in RECIST)

RESPONSE HIERARCHY:
- sCR (Stringent CR): Negative immunofixation + <5% BM plasma cells + normal FLC + no clonal cells
- CR: Negative immunofixation + <5% BM plasma cells
- VGPR: ≥90% M-protein reduction OR dFLC <100 mg/L
- PR: ≥50% M-protein reduction
- SD: Not meeting other criteria
- PD: ≥25% increase from nadir + absolute increase ≥0.5 g/dL
*****************************************************************************/

%macro derive_imwg_response(
    lb_ds=,        /* LB domain with LBTESTCD = SPROT, KAPPA, LAMBDA, IMFIX */
    mb_ds=,        /* MB domain with MBTESTCD = BMPC, MRD, CLONPC */
    outds=,
    usubjid=USUBJID,
    visit_var=VISIT,
    adt_var=LBDTC,
    baseline_flag=ABLFL
);

/* STEP 1: Pivot LB domain laboratory results */
proc sql;
    create table work._lb_pivot as
    select 
        &usubjid,
        &visit_var,
        input(&adt_var, yymmdd10.) as ADT format=yymmdd10.,
        /* Extract M-protein values */
        max(case when LBTESTCD='SPROT' then input(LBSTRESC, best.) else . end) as SPROT_VALUE,
        max(case when LBTESTCD='UPROT' then input(LBSTRESC, best.) else . end) as UPROT_VALUE,
        /* Extract free light chains */
        max(case when LBTESTCD='KAPPA' then input(LBSTRESC, best.) else . end) as KAPPA_VALUE,
        max(case when LBTESTCD='LAMBDA' then input(LBSTRESC, best.) else . end) as LAMBDA_VALUE,
        /* Extract immunofixation result (categorical) */
        max(case when LBTESTCD='IMFIX' then LBSTRESC else '' end) as IMFIX_RESULT,
        max(case when &baseline_flag='Y' then 1 else 0 end) as BASELINE_FLAG
    from &lb_ds
    group by &usubjid, &visit_var, calculated ADT
    order by &usubjid, calculated ADT;
quit;

/* STEP 2: Calculate derived parameters (dFLC, FLC ratio) */
data work._lb_derived;
    set work._lb_pivot;
    by &usubjid;
    
    /* dFLC = |Involved FLC - Uninvolved FLC| */
    /* Assumption: Kappa is involved (typical for 60% of MM patients) */
    if nmiss(KAPPA_VALUE, LAMBDA_VALUE) = 0 then do;
        dFLC = abs(KAPPA_VALUE - LAMBDA_VALUE);
        FLC_RATIO = KAPPA_VALUE / LAMBDA_VALUE;
        FLC_NORMAL = (0.26 <= FLC_RATIO <= 1.65);  /* Normal range */
    end;
    
    /* Store baseline values */
    retain BASELINE_SPROT BASELINE_UPROT BASELINE_dFLC;
    if BASELINE_FLAG = 1 then do;
        BASELINE_SPROT = SPROT_VALUE;
        BASELINE_UPROT = UPROT_VALUE;
        BASELINE_dFLC = dFLC;
    end;
run;

/* STEP 3: Calculate percent changes from baseline and nadir */
data work._lb_changes;
    set work._lb_derived;
    by &usubjid;
    
    /* Percent change from baseline */
    if BASELINE_SPROT > 0 then do;
        PCHG_SPROT = ((SPROT_VALUE - BASELINE_SPROT) / BASELINE_SPROT) * 100;
        ACHG_SPROT = SPROT_VALUE - BASELINE_SPROT;
    end;
    
    if BASELINE_dFLC > 0 then do;
        PCHG_dFLC = ((dFLC - BASELINE_dFLC) / BASELINE_dFLC) * 100;
        ACHG_dFLC = dFLC - BASELINE_dFLC;
    end;
    
    /* Track nadir (lowest post-baseline value for PD determination) */
    retain NADIR_SPROT NADIR_dFLC;
    if first.&usubjid then do;
        NADIR_SPROT = .;
        NADIR_dFLC = .;
    end;
    
    if BASELINE_FLAG = 0 then do;
        if NADIR_SPROT = . or SPROT_VALUE < NADIR_SPROT then 
            NADIR_SPROT = SPROT_VALUE;
        if NADIR_dFLC = . or dFLC < NADIR_dFLC then
            NADIR_dFLC = dFLC;
    end;
    
    /* Percent change from nadir (for PD determination) */
    if NADIR_SPROT > 0 then do;
        PCHG_NAD_SPROT = ((SPROT_VALUE - NADIR_SPROT) / NADIR_SPROT) * 100;
        ACHG_NAD_SPROT = SPROT_VALUE - NADIR_SPROT;
    end;
    
    if NADIR_dFLC > 0 then do;
        PCHG_NAD_dFLC = ((dFLC - NADIR_dFLC) / NADIR_dFLC) * 100;
        ACHG_NAD_dFLC = dFLC - NADIR_dFLC;
    end;
run;

/* STEP 4: Merge bone marrow data */
proc sql;
    create table work._response_data as
    select 
        a.*,
        b.MBSTRESN as BMPC_PERCENT,
        c.MBSTRESC as MRD_RESULT,
        d.MBSTRESC as CLONPC_RESULT
    from work._lb_changes a
    left join (select * from &mb_ds where MBTESTCD='BMPC') b
        on a.&usubjid = b.&usubjid and a.&visit_var = b.VISIT
    left join (select * from &mb_ds where MBTESTCD='MRD') c
        on a.&usubjid = c.&usubjid and a.&visit_var = c.VISIT
    left join (select * from &mb_ds where MBTESTCD='CLONPC') d
        on a.&usubjid = d.&usubjid and a.&visit_var = d.VISIT
    order by a.&usubjid, a.ADT;
quit;

/* STEP 5: Assign IMWG response categories (hierarchical logic) */
data &outds;
    set work._response_data;
    length IMWG_RESP $10 IMWG_LOGIC $500;
    
    /* Default: Not Evaluable */
    IMWG_RESP = 'NE';
    IMWG_LOGIC = 'Not Evaluable - insufficient data';
    
    /* PROGRESSIVE DISEASE (PD) - Check first (highest priority) */
    if PCHG_NAD_SPROT >= 25 and ACHG_NAD_SPROT >= 0.5 then do;
        IMWG_RESP = 'PD';
        IMWG_LOGIC = cats('PD: ', put(PCHG_NAD_SPROT, 5.1), 
                          '% increase from nadir (', put(ACHG_NAD_SPROT, 5.2), ' g/dL)');
    end;
    
    /* STRINGENT COMPLETE RESPONSE (sCR) */
    else if IMFIX_RESULT = 'NEGATIVE' and 
            BMPC_PERCENT < 5 and 
            FLC_NORMAL = 1 and
            upcase(CLONPC_RESULT) in ('ABSENT', 'NEGATIVE') then do;
        IMWG_RESP = 'sCR';
        IMWG_LOGIC = cats('sCR: Negative IMFIX + <5% BM plasma cells (', 
                          put(BMPC_PERCENT, 5.1), '%) + normal FLC + no clonal cells');
    end;
    
    /* COMPLETE RESPONSE (CR) */
    else if IMFIX_RESULT = 'NEGATIVE' and BMPC_PERCENT < 5 then do;
        IMWG_RESP = 'CR';
        IMWG_LOGIC = cats('CR: Negative IMFIX + <5% BM plasma cells (', 
                          put(BMPC_PERCENT, 5.1), '%)');
    end;
    
    /* VERY GOOD PARTIAL RESPONSE (VGPR) */
    else if PCHG_SPROT <= -90 or dFLC < 100 then do;
        IMWG_RESP = 'VGPR';
        IMWG_LOGIC = cats('VGPR: ', 
                          ifc(PCHG_SPROT <= -90, 
                              cats(put(abs(PCHG_SPROT), 5.1), '% M-protein reduction'),
                              cats('dFLC <100 mg/L (', put(dFLC, 6.1), ')')));
    end;
    
    /* PARTIAL RESPONSE (PR) */
    else if PCHG_SPROT <= -50 then do;
        IMWG_RESP = 'PR';
        IMWG_LOGIC = cats('PR: ', put(abs(PCHG_SPROT), 5.1), '% M-protein reduction');
    end;
    
    /* STABLE DISEASE (SD) */
    else if nmiss(SPROT_VALUE, BASELINE_SPROT) = 0 then do;
        IMWG_RESP = 'SD';
        IMWG_LOGIC = 'SD: Not meeting criteria for CR/VGPR/PR/PD';
    end;
    
    label 
        IMWG_RESP = 'IMWG Response Category'
        IMWG_LOGIC = 'Response Assignment Logic'
        PCHG_SPROT = '% Change in M-Protein from Baseline'
        PCHG_NAD_SPROT = '% Change in M-Protein from Nadir'
        dFLC = 'Difference in Free Light Chains (mg/L)'
        FLC_RATIO = 'Free Light Chain Ratio (Kappa/Lambda)'
        BMPC_PERCENT = 'Bone Marrow Plasma Cell %';
run;

/* Print frequency distribution */
proc freq data=&outds;
    tables IMWG_RESP / nocum;
    title "IMWG Response Distribution";
run;
title;

/* Clean up */
proc datasets library=work nolist;
    delete _lb_pivot _lb_derived _lb_changes _response_data;
quit;

%mend derive_imwg_response;
