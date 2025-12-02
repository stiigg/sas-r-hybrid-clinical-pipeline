%include "etl/sas/00_setup.sas";

/* adam_adtte.sas: derive time-to-event endpoints (PFS/OS) */

%logmsg(Building ADTTE dataset);

proc sort data=adam.adrs out=work.adrs; by subjid; run;
proc sort data=sdtm.ds out=work.ds; by subjid; run;

/* Progression-Free Survival */
data work.adtte_pfs;
  merge work.adrs(where=(avalc='PD') keep=subjid adt rename=(adt=evntdt))
        work.ds(where=(dsdecod='DEATH') keep=subjid dsstdtc rename=(dsstdtc=evntdt));
  by subjid;
  length paramcd $4 param $40;
  paramcd = 'PFS';
  param = 'Progression-Free Survival';
  startdt = input(rfstdtc, yymmdd10.);

  if not missing(evntdt) then do;
    cnsr = 0;
    adt = evntdt;
  end;
  else do;
    cnsr = 1;
    adt = max_adequate_assess_dt;
  end;

  aval = intck('day', startdt, adt);
  format adt startdt yymmdd10.;
run;

/* OS placeholder; extend as needed */
proc sql;
  create table work.adtte_os as
  select subjid,
         'OS' as paramcd length=3,
         'Overall Survival' as param length=40,
         input(rfstdtc, yymmdd10.) as startdt format=yymmdd10.,
         input(coalescec(dthdtc, dsstdtc), yymmdd10.) as adt format=yymmdd10.,
         (calculated adt = .) as cnsr,
         intck('day', calculated startdt, calculated adt) as aval
  from work.ds;
quit;

/* Combine endpoints */
data adam.adtte;
  set work.adtte_pfs work.adtte_os;
run;

%logmsg(Completed ADTTE derivation);
