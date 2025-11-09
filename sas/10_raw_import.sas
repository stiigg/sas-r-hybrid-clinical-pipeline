%include "00_setup.sas";

/* 10_raw_import.sas: import raw subject-level file from EDC (CSV) */

%logmsg(START: RAW IMPORT);

/* Example import from CSV */
proc import datafile="&root./data/source_raw_subjects_example.csv"
    out=raw.subjects
    dbms=csv
    replace;
    guessingrows=max;
run;

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

%logmsg(END: RAW IMPORT);
