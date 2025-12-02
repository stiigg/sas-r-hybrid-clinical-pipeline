%include "etl/sas/00_setup.sas";

/* adam_adrs.sas: derive RECIST 1.1 timepoint response */

%logmsg(Building ADRS dataset);

proc sort data=adam.adtr out=work.adtr;
  by subjid visitnum tulnkid;
run;

/* Track target/non-target/new lesion signals per visit */
data work._visit_rollup;
  set work.adtr;
  by subjid visitnum tulnkid;
  retain target_sld non_target_present new_lesion;
  if first.visitnum then do;
    target_sld = 0; non_target_present = 0; new_lesion = 0;
  end;

  if dtype = 'TARGET' and not missing(aval) then target_sld + aval;
  if dtype = 'NON-TARGET' and not missing(aval) then non_target_present = 1;
  if dtype = 'NEW' then new_lesion = 1;

  if last.visitnum then output;
run;

/* Visit-level response */
data adam.adrs;
  set work._visit_rollup;
  by subjid visitnum;
  length avalc $2 cnfrm $1;
  retain prev_response prev_date baseline_sld nadir_sld;

  if first.subjid then do;
    prev_response = ''; prev_date = .; baseline_sld = .; nadir_sld = .;
  end;
  if missing(baseline_sld) then baseline_sld = target_sld;
  if missing(nadir_sld) or target_sld < nadir_sld then nadir_sld = target_sld;

  if target_sld = 0 and non_target_present = 0 and new_lesion = 0 then avalc = 'CR';
  else if new_lesion = 1 or (target_sld/nadir_sld >= 1.20 and target_sld - nadir_sld >= 5) then avalc = 'PD';
  else if target_sld/baseline_sld <= 0.70 then avalc = 'PR';
  else avalc = 'SD';

  /* Confirmation requirement for CR/PR */
  cnfrm = 'N';
  if avalc in ('CR','PR') and prev_response = avalc and intck('day', prev_date, adt) >= 28 then cnfrm = 'Y';

  prev_response = avalc;
  prev_date = adt;

  format adt yymmdd10.;
run;

%logmsg(Completed ADRS derivation);
