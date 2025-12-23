%include "sas/include/check_manifest.sas";
%include "sas/include/logcheck.sas";
%include "sas/include/check_syscc.sas";

%include "00_setup.sas";

/* 30_adam_adsl.sas: create ADaM-style ADSL from SDTM.DM using spec */

%logmsg(START: ADaM ADSL);

/* Read ADSL spec */
proc import datafile="%spec_file(adam_adsl_spec.csv)"
    out=work.adam_adsl_spec
    dbms=csv
    replace;
    guessingrows=max;
run;
%check_syscc(step=ADSL - spec import);

proc sql noprint;
    select source_domain, source_var, target_var
    into :srcdom1-:srcdom999,
         :srcvar1-:srcvar999,
         :tgtvar1-:tgtvar999
    from work.adam_adsl_spec;
    %let nmap = &sqlobs;
quit;
%check_syscc(step=ADSL - mapping query);

/* For simplicity we only use DM as source in this example */
proc sort data=sdtm.dm; by USUBJID; run;
%check_syscc(step=ADSL - SDTM.DM sort);

data adam.adsl;
    merge sdtm.dm (in=indt);
    by USUBJID;
    if not indt then delete;

    length SAFFL $1 AGEGRP $8;

    /* Map variables from DM to ADSL */
    %do i = 1 %to &nmap;
        %let srcdom = &&srcdom&i;
        %let srcvar = &&srcvar&i;
        %let tgtvar = &&tgtvar&i;

        %if &srcdom = DM %then %do;
            &tgtvar = &&srcvar;
        %end;
    %end;

    /* Derivations are tagged so they can be reconciled with
       specs/common/derivations.yml during QC. */

    *DERIVATION_ID=ADSL-DERV-001;
    if missing(AGE) then AGEGRP = "UNKNOWN";
    else if AGE < 65 then AGEGRP = "<65";
    else AGEGRP = ">=65";

    *DERIVATION_ID=ADSL-DERV-010;
    SAFFL = "Y";
run;
%check_syscc(step=ADSL - dataset build);

%logmsg(END: ADaM ADSL);

%if %sysfunc(fileexist(%superq(ETL_LOG_PATH))) %then %do;
  %logcheck(%superq(ETL_LOG_PATH));
%end;
%else %do;
  %put [ERROR] Expected log file %superq(ETL_LOG_PATH) not found.;
  %abort cancel;
%end;
