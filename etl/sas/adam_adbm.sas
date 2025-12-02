%include "etl/sas/00_setup.sas";

/* adam_adbm.sas: biomarker analysis dataset (PD-L1, TMB, MSI) */

%logmsg(Building ADBM dataset);

proc sort data=sdtm.bm out=work.bm; by usubjid bmtestcd visit; run;

data adam.adbm;
  set work.bm;
  by usubjid bmtestcd visit;
  length avalc $10 param $60;

  if bmtestcd = 'PDL1TPS' then do;
    aval = input(bmorres, best.);
    if aval < 1 then avalc = '<1%';
    else if aval < 50 then avalc = '1-49%';
    else avalc = '>=50%';
    param = 'PD-L1 Tumor Proportion Score';
  end;
  else if bmtestcd = 'TMB' then do;
    aval = input(bmorres, best.);
    if aval >= 10 then avalc = 'TMB-High';
    else avalc = 'TMB-Low';
    param = 'Tumor Mutational Burden';
  end;
  else if bmtestcd = 'MSI' then do;
    avalc = bmorres;
    if upcase(avalc) = 'MSI-H' then aval = 1;
    else aval = 0;
    param = 'Microsatellite Instability';
  end;
run;

%logmsg(Completed ADBM derivation);
