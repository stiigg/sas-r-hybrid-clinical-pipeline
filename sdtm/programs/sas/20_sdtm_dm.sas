%include "sas/include/check_manifest.sas";
%include "sas/include/logcheck.sas";
%include "sas/include/check_syscc.sas";

%include "00_setup.sas";

/* 20_sdtm_dm.sas: create SDTM-style DM from RAW.SUBJECTS_CLEAN based on spec */

%logmsg(START: SDTM DM);

/* Import SDTM DM spec */
proc import datafile="%spec_file(sdtm_dm_spec.csv)"
    out=work.sdtm_dm_spec
    dbms=csv
    replace;
    guessingrows=max;
run;
%check_syscc(step=SDTM DM - spec import);

/* Build macro variables for mapping */
proc sql noprint;
    select source_var, target_var
    into :src1-:src999, :tgt1-:tgt999
    from work.sdtm_dm_spec;
    %let nmap = &sqlobs;
quit;
%check_syscc(step=SDTM DM - mapping query);

data sdtm.dm;
    set raw.subjects_clean;

    /* Apply mappings */
    %do i = 1 %to &nmap;
        %let src = &&src&i;
        %let tgt = &&tgt&i;
        &tgt = &src;
    %end;

    STUDYID = "&studyid";
    DOMAIN  = "DM";
run;
%check_syscc(step=SDTM DM - domain build);

%logmsg(END: SDTM DM);

%if %sysfunc(fileexist(%superq(ETL_LOG_PATH))) %then %do;
  %logcheck(%superq(ETL_LOG_PATH));
%end;
%else %do;
  %put [ERROR] Expected log file %superq(ETL_LOG_PATH) not found.;
  %abort cancel;
%end;
