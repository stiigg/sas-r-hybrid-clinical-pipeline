%include "sas/include/check_manifest.sas";
%include "sas/include/logcheck.sas";
%include "sas/include/check_syscc.sas";

/* 00_setup.sas: metadata-driven environment bootstrap for the SAS ETL pipeline */

options mprint mlogic symbolgen;

%let repo_root = %sysget(PWD);
%if %superq(repo_root) = %then %do;
  %let repo_root = %sysfunc(getoption(SASINITIALFOLDER));
%end;

%global STUDY_ID ETL_VERSION ETL_LOG_PATH;
%if %length(%superq(STUDY_ID)) = 0 %then %let STUDY_ID = %sysfunc(coalescec(%sysget(STUDY_ID), %sysget(STUDYID), STUDY01));
%if %length(%superq(ETL_VERSION)) = 0 %then %let ETL_VERSION = %sysfunc(coalescec(%sysget(ETL_VERSION), DEV));

%let _program_source = %superq(SYSIN);
%if %length(&_program_source) = 0 %then %let _program_source = 00_setup.sas;
%let _program_basename = %scan(&_program_source, -1, /);
%let _program_log = %sysfunc(tranwrd(&_program_basename, .sas, .log));
%let _default_log = %sysfunc(catx(/, %superq(repo_root), logs, &_program_log));
%if %length(%superq(ETL_LOG_PATH)) = 0 %then %let ETL_LOG_PATH = %sysfunc(coalescec(%sysget(ETL_LOG), &_default_log));

%put NOTE: STUDY_ID    = &STUDY_ID.;
%put NOTE: ETL_VERSION = &ETL_VERSION.;
%put NOTE: ETL_LOG_PATH = &ETL_LOG_PATH.;

%check_required_param(STUDY_ID);
%check_required_param(ETL_VERSION);
%check_required_param(ETL_LOG_PATH);

%let path_manifest = %sysfunc(catx(/, %superq(repo_root), specs, pipeline_paths.csv));

filename pathspec "%superq(path_manifest)";

proc import datafile=pathspec
    out=work._path_manifest
    dbms=csv
    replace;
    guessingrows=max;
run;
%check_syscc(step=Path manifest import);

data _null_;
    set work._path_manifest;
    length macro_name $64 macro_value $512;
    macro_name = cats('path_', lowcase(strip(key)));
    macro_value = strip(value);
    call symputx(macro_name, macro_value, 'G');
run;
%check_syscc(step=Path manifest macro derivation);

%macro get_path(key);
    %sysfunc(catx(/, %superq(repo_root), &&path_&key))
%mend;

%macro spec_file(name);
    %sysfunc(catx(/, %get_path(spec_dir), &name))
%mend;

%macro raw_file(name);
    %sysfunc(catx(/, %get_path(raw_data_dir), &name))
%mend;

%macro output_file(subdir, name);
    %sysfunc(catx(/, %get_path(output_data_dir), &subdir, &name))
%mend;

%macro ensure_output_subdir(subdir);
    %makedir(%sysfunc(catx(/, %get_path(output_data_dir), &subdir)));
%mend;

%let studyid = &STUDY_ID.;

libname raw   "%get_path(raw_data_dir)";
libname sdtm  "%get_path(sdtm_data_dir)";
libname adam  "%get_path(adam_data_dir)";

filename specs "%get_path(spec_dir)";
filename logs  "%get_path(log_dir)";

/* Simple log macro */
%macro logmsg(msg);
  %put NOTE: &msg;
%mend;

/* Ensure known directories exist */
%macro makedir(path);
  %local resolved;
  %let resolved = %sysfunc(dequote(&path));
  %if %sysfunc(fileexist(&resolved)) = 0 %then %do;
    %sysexec mkdir -p &resolved;
  %end;
%mend;

%makedir(%get_path(raw_data_dir));
%makedir(%get_path(sdtm_data_dir));
%makedir(%get_path(adam_data_dir));
%makedir(%get_path(output_data_dir));

%if %sysfunc(fileexist(%superq(ETL_LOG_PATH))) %then %do;
  %logcheck(%superq(ETL_LOG_PATH));
%end;
%else %do;
  %put [ERROR] Expected log file %superq(ETL_LOG_PATH) not found.;
  %abort cancel;
%end;
