/* ---- SAS log scanner macro ---- */
%macro logcheck(logfile);
    %local _fail;
    %let _fail = 0;

    %put NOTE: Running logcheck on &logfile.;

    data _null_;
        infile "&logfile." end=done;
        input;
        _line = upcase(_infile_);
        if index(_line, 'ERROR')
           or index(_line, 'WARNING')
           or index(_line, 'UNRESOLVED MACRO') then do;
            put "LOGCHECK ISSUE: " _infile_;
            call symputx('_fail', 1, 'G');
        end;
    run;

    %if &_fail = 1 %then %do;
        %put [ERROR] logcheck FAILED for &logfile.. Aborting for audit safety.;
        %abort cancel;
    %end;
    %else %do;
        %put NOTE: logcheck PASSED for &logfile.;
    %end;
%mend logcheck;
