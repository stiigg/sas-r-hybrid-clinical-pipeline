/* 00_setup.sas: metadata-driven environment bootstrap for the SAS ETL pipeline */

options mprint mlogic symbolgen;

%let repo_root = %sysget(PWD);
%if %superq(repo_root) = %then %do;
  %let repo_root = %sysfunc(getoption(SASINITIALFOLDER));
%end;

%let path_manifest = %sysfunc(catx(/, %superq(repo_root), specs, pipeline_paths.csv));

filename pathspec "%superq(path_manifest)";

proc import datafile=pathspec
    out=work._path_manifest
    dbms=csv
    replace;
    guessingrows=max;
run;

data _null_;
    set work._path_manifest;
    length macro_name $64 macro_value $512;
    macro_name = cats('path_', lowcase(strip(key)));
    macro_value = strip(value);
    call symputx(macro_name, macro_value, 'G');
run;

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

%let studyid = %sysfunc(coalescec(%sysget(STUDYID), STUDY01));

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
