%include "etl/sas/00_setup.sas";

/* adam_adtr.sas: lesion-level tumor assessments with RECIST change metrics */

%logmsg(Building ADTR dataset);

proc sort data=sdtm.tu out=work.tu;
  by subjid tulnkid visitnum;
run;
proc sort data=sdtm.tr out=work.tr;
  by subjid tulnkid visitnum;
run;

/* Merge TU/TR and derive baseline and changes */
data adam.adtr;
  merge work.tu(keep=subjid tulnkid visitnum tueval trgrpid rename=(tueval=dtype))
        work.tr(keep=subjid tulnkid visitnum trstresn trstdtc trtestcd rename=(trstresn=aval trstdtc=adt));
  by subjid tulnkid visitnum;
  length dtype $12;

  /* Baseline is first investigator assessment */
  retain base;
  if first.tulnkid then base = .;
  if visitnum = 1 and dtype in ('TARGET','NON-TARGET') then base = aval;

  if not missing(base) then do;
    chg  = aval - base;
    pchg = (chg / base) * 100;
  end;

  format adt yymmdd10.;
run;

%logmsg(Completed ADTR derivation);
