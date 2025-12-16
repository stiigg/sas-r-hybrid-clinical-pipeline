%include "etl/sas/00_setup.sas";

/* Integrate validated RECIST 1.1 macro library */
%include "etl/adam_program_library/oncology_response/recist_11_core/derive_target_lesion_response.sas";
%include "etl/adam_program_library/oncology_response/recist_11_core/derive_non_target_lesion_response.sas";
%include "etl/adam_program_library/oncology_response/recist_11_core/derive_overall_timepoint_response.sas";
%include "etl/adam_program_library/oncology_response/recist_11_core/derive_best_overall_response.sas";

%logmsg(Building ADRECIST-compliant ADRS dataset);

/* Standardize ADTR structure for macro consumption */
proc sort data=adam.adtr out=work.adtr;
  by subjid visitnum tulnkid;
run;

data work.adtr_recist;
  set work.adtr;
  length usubjid $200 rscat $12 trloc $200 trldstyp $12 ntrgresp $40 ablfl $1;

  /* Harmonize subject identifier for macro inputs */
  usubjid = coalescec(usubjid, subjid);
  subjid  = usubjid;

  /* Normalize lesion categories for macro filters */
  rscat = upcase(strip(dtype));
  if rscat = 'NEW' then trldstyp = 'NEW LESION';
  else if not missing(rscat) then trldstyp = rscat;

  /* Basic target measurements */
  ldiam = aval;
  if visitnum = 1 and rscat = 'TARGET' then ablfl = 'Y';
  else ablfl = '';

  /* Non-target assessment placeholder when present */
  if rscat = 'NON-TARGET' then do;
    if missing(ntrgresp) then ntrgresp = 'PRESENT';
  end;

  /* Ensure ADT is a numeric SAS date */
  length adt_num 8;
  if vtype(adt) = 'C' then adt_num = input(adt, yymmdd10.);
  else adt_num = adt;
  if not missing(adt_num) then adt = adt_num;
  drop adt_num;
  format adt yymmdd10.;
run;

proc sort data=work.adtr_recist;
  by usubjid adt visitnum tulnkid;
run;

/*******************************************************************
 * STEP 1: Target Lesion Parameters (CDISC ADRECIST Pattern)
 *******************************************************************/
%derive_target_lesion_response(
    inds=work.adtr_recist,
    outds=work.target_sum,
    usubjid_var=usubjid,
    visit_var=visitnum,
    adt_var=adt,
    ldiam_var=ldiam,
    baseline_flag=ablfl
);

/* Add CRIT variables for response assessment flags */
data work.target_sum_crit;
    set work.target_sum;

    length paramcd $8 param $60 avalc $12;
    aval     = TL_SLD;
    avalc    = TL_RESP;
    base     = TL_BASE_SLD;
    chg      = aval - base;
    pchg     = TL_PCHG_BASE;
    ndrval   = TL_NADIR_SLD;
    chgndr   = TL_ABS_CHG_NAD;
    pchgndr  = TL_PCHG_NAD;

    crit1='CR response'; crit1fl=ifc(avalc='CR','Y','');
    crit2='PR response'; crit2fl=ifc(avalc='PR','Y','');
    crit3='SD response'; crit3fl=ifc(avalc='SD','Y','');
    crit4='PD response'; crit4fl=ifc(avalc='PD','Y','');
    crit5='NAE response'; crit5fl=ifc(avalc='NE','Y','');

    paramcd='TRGSLD'; param='Sum of Target Lesion Diameters';
run;

/* Target lesion response parameter */
data adam.adrs_trgrsp;
    set work.target_sum_crit;
    where avalc in ('CR','PR','SD','PD','NE');
    length paramcd $6 param $30;
    paramcd='TRGRSP'; param='Target Lesion Response';
    keep usubjid subjid adt visitnum paramcd param avalc crit:;
run;

/* Baseline target lesion count parameters */
%macro adpcparam_trgbl;
    proc sort data=work.adtr_recist out=work.target_baseline;
        by usubjid visitnum;
        where ablfl='Y' and rscat='TARGET';
    run;

    data adam.adrs_trgbl;
        set work.target_baseline;
        by usubjid;
        retain trgbl_count trgnode_count;
        if first.usubjid then do;
            trgbl_count=0; trgnode_count=0;
        end;

        trgbl_count+1;
        if upcase(trloc) = 'LYMPH NODE' then trgnode_count+1;

        if last.usubjid then do;
            paramcd='NTRGBL'; param='Number of Target Lesions at Baseline';
            aval=trgbl_count; output;

            paramcd='NTRGNDBL'; param='Number of Target Nodes at Baseline';
            aval=trgnode_count; output;
        end;
        keep usubjid subjid adt visitnum paramcd param aval;
    run;
%mend;
%adpcparam_trgbl;

/*******************************************************************
 * STEP 2: Non-Target Lesion Parameters
 *******************************************************************/
%derive_non_target_lesion_response(
    inds=work.adtr_recist,
    outds=work.nontarget_resp,
    usubjid_var=usubjid,
    visit_var=visitnum,
    adt_var=adt,
    assess_var=ntrgresp
);

data adam.adrs_ntrgrsp;
    set work.nontarget_resp;
    length paramcd $7 param $40 avalc $20;
    paramcd='NTRGRSP'; param='Non-Target Lesion Response';
    avalc = NTL_RESP;
    keep usubjid subjid adt visitnum paramcd param avalc;
run;

/*******************************************************************
 * STEP 3: New Lesion Detection
 *******************************************************************/
%macro adpcparam_newlsn;
    proc sort data=work.adtr_recist out=work.new_lesions;
        by usubjid adt;
        where rscat='NEW';
    run;

    data adam.adrs_newlsn;
        set work.new_lesions;
        by usubjid adt;
        length rscat $12;
        rscat='NEW';
        if first.adt then do;
            paramcd='NEWLSN'; param='New Lesion Detected';
            avalc='Y'; output;
        end;
        keep usubjid subjid adt visitnum paramcd param avalc;
    run;
%mend;
%adpcparam_newlsn;

/*******************************************************************
 * STEP 4: Pad Missing Parameters (CDISC ADRECIST Pattern)
 * Creates "Not Applicable" records for consistency
 *******************************************************************/
%macro adpcparam_padrcst;
    /* Get all unique visit dates per subject */
    proc sql;
        create table work.visit_grid as
        select distinct usubjid, subjid, adt, visitnum
        from work.target_sum
        union
        select distinct usubjid, subjid, adt, visitnum
        from work.nontarget_resp;
    quit;

    /* Pad non-target response for subjects with only target disease */
    proc sql;
        create table work.ntrg_padded as
        select v.usubjid, v.subjid, v.adt, v.visitnum,
               coalesce(n.NTL_RESP,'NA') as NTL_RESP,
               n.NTL_RESP_REASON
        from work.visit_grid v
        left join work.nontarget_resp n
        on v.usubjid=n.usubjid and v.adt=n.adt;
    quit;

    /* Similar padding for target response */
    proc sql;
        create table work.trg_padded as
        select v.usubjid, v.subjid, v.adt, v.visitnum,
               coalesce(t.TL_RESP,'NA') as TL_RESP,
               t.TL_RESP_REASON,
               t.TL_RESP_N
        from work.visit_grid v
        left join work.target_sum t
        on v.usubjid=t.usubjid and v.adt=t.adt;
    quit;
%mend;
%adpcparam_padrcst;

/*******************************************************************
 * STEP 5: Overall Response (RECIST 1.1 Table 4)
 *******************************************************************/
%derive_overall_timepoint_response(
    tl_ds=work.trg_padded,
    ntl_ds=work.ntrg_padded,
    nl_ds=adam.adrs_newlsn,
    outds=work.overall_resp,
    usubjid_var=usubjid,
    adt_var=adt
);

/* Add analysis day for confirmation logic */
proc sort data=work.overall_resp;
    by usubjid adt;
run;

data work.overall_resp_day;
    set work.overall_resp;
    by usubjid adt;
    retain baseadt;
    if first.usubjid then baseadt=adt;
    ady = adt - baseadt + 1;
run;

data adam.adrs_ovrlresp;
    set work.overall_resp_day;
    length paramcd $8 param $20 avalc $10;
    paramcd='OVRLRESP'; param='Overall Response';
    avalc = OVR_RESP;
run;

/*******************************************************************
 * STEP 6: Best Overall Response with Confirmation
 *******************************************************************/
%derive_best_overall_response(
    inds=work.overall_resp_day,
    outds=work.bor_resp,
    usubjid_var=usubjid,
    ady_var=ady,
    dtc_var=adt,
    ovr_var=OVR_RESP,
    conf_win_lo=28,
    conf_win_hi=84,
    sd_min_dur=42
);

/* Apply confirmation flagging per CDISC ADRECIST */
%macro adpcanlrcstcnf;
    data adam.adrs_bor;
        set work.bor_resp;

        /* ANL01FL: Confirmed response flag */
        if BOR in ('CR','PR') and BORCONF='Y' then anl01fl='Y';
        else anl01fl='';

        /* ANL02FL: Confirming response flag */
        if BOR in ('CR','PR') and BORCONF='Y' then anl02fl='Y';
        else anl02fl='';

        length paramcd $3 param $22 avalc $10;
        paramcd='BOR'; param='Best Overall Response';
        avalc = BOR;
    run;
%mend;
%adpcanlrcstcnf;

/*******************************************************************
 * STEP 7: Combine All Parameters into ADRECIST
 *******************************************************************/
data adam.adrecist;
    set adam.adrs_trgbl
        work.target_sum_crit
        adam.adrs_trgrsp
        adam.adrs_ntrgrsp
        adam.adrs_newlsn
        adam.adrs_ovrlresp
        adam.adrs_bor;
run;

proc sort data=adam.adrecist;
    by usubjid adt paramcd;
run;

%logmsg(Completed ADRECIST derivation using validated macro library);
