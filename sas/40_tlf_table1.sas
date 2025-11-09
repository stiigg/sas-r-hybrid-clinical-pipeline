%include "00_setup.sas";

/* 40_tlf_table1.sas: simple TLF - subject count by treatment */

%logmsg(START: TLF TABLE 1);

proc freq data=adam.adsl noprint;
    tables TRT01A / out=work.counts;
run;

/* Produce a basic RTF table */
ods rtf file="&root./data/out/tlf_table1_subject_counts.rtf" style=journal;
title "Table 1. Subject Disposition by Treatment";

proc report data=work.counts nowd;
    column TRT01A COUNT PERCENT;
    define TRT01A / "Treatment" order;
    define COUNT  / "N";
    define PERCENT / "Percent";
run;

ods rtf close;

%logmsg(END: TLF TABLE 1);
