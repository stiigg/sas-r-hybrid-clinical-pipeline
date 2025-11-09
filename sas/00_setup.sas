/* 00_setup.sas: set library references and options for hybrid SAS–R pipeline */

options mprint mlogic symbolgen;

/* Root path macro so you can move the project easily */
%let root = /project-root;
%let studyid = STUDY01;

libname raw   "&root./data/raw";
libname sdtm  "&root./data/sdtm";
libname adam  "&root./data/adam";
libname out   "&root./data/out";

filename specs "&root./specs";
filename logs  "&root./logs";

/* Simple log macro */
%macro logmsg(msg);
  %put NOTE: &msg;
%mend;

/* Example macro to ensure directories exist (Unix) */
%macro makedir(path);
  %sysexec mkdir -p &path;
%mend;
