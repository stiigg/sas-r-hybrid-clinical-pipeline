%include "../sas/00_setup.sas";

/* 30_adam_adsl.sas: create ADaM-style ADSL from SDTM.DM using spec */

%logmsg(START: ADaM ADSL);

/* Read ADSL spec */
proc import datafile="&root./specs/adam_adsl_spec.csv"
    out=work.adam_adsl_spec
    dbms=csv
    replace;
    guessingrows=max;
run;

proc sql noprint;
    select source_domain, source_var, target_var
    into :srcdom1-:srcdom999,
         :srcvar1-:srcvar999,
         :tgtvar1-:tgtvar999
    from work.adam_adsl_spec;
    %let nmap = &sqlobs;
quit;

/* For simplicity we only use DM as source in this example */
proc sort data=sdtm.dm; by USUBJID; run;

data adam.adsl;
    merge sdtm.dm (in=indt);
    by USUBJID;
    if not indt then delete;

    length SAFFL $1;

    /* Map variables from DM to ADSL */
    %do i = 1 %to &nmap;
        %let srcdom = &&srcdom&i;
        %let srcvar = &&srcvar&i;
        %let tgtvar = &&tgtvar&i;

        %if &srcdom = DM %then %do;
            &tgtvar = &&srcvar;
        %end;
    %end;

    /* Derived safety flag */
    SAFFL = "Y";
run;

%logmsg(END: ADaM ADSL);
