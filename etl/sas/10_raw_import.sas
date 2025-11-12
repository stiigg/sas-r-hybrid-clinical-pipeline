%include "sas/include/check_manifest.sas";
%include "sas/include/logcheck.sas";
%include "sas/include/check_syscc.sas";

%include "00_setup.sas";

/* 10_raw_import.sas: import raw subject-level file from EDC (CSV) */

%logmsg(START: RAW IMPORT);

/* Example import from CSV */
proc import datafile="%raw_file(source_raw_subjects_example.csv)"
    out=raw.subjects
    dbms=csv
    replace;
    guessingrows=max;
run;
%check_syscc(step=RAW IMPORT - source csv import);

/* Basic cleaning/standardization example */
data raw.subjects_clean;
    set raw.subjects;

    /* Derive USUBJID */
    length USUBJID $40;
    USUBJID = cats(STUDYID, "-", SUBJID);

    /* Standardize character vars */
    SEX     = upcase(SEX);
    COUNTRY = upcase(COUNTRY);

    /* Derive ARM/ARMCD from TRTGROUP */
    length ARM ARMCD $20;
    if TRTGROUP = 1 then do; ARMCD = "A"; ARM = "Drug A"; end;
    else if TRTGROUP = 2 then do; ARMCD = "B"; ARM = "Drug B"; end;
run;
%check_syscc(step=RAW IMPORT - subjects_clean build);

%logmsg(END: RAW IMPORT);

%if %sysfunc(fileexist(%superq(ETL_LOG_PATH))) %then %do;
  %logcheck(%superq(ETL_LOG_PATH));
%end;
%else %do;
  %put [ERROR] Expected log file %superq(ETL_LOG_PATH) not found.;
  %abort cancel;
%end;
