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

/* Build macro variables for mapping */
proc sql noprint;
    select source_var, target_var
    into :src1-:src999, :tgt1-:tgt999
    from work.sdtm_dm_spec;
    %let nmap = &sqlobs;
quit;

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

%logmsg(END: SDTM DM);
