/* ---- Manifest precondition macro ---- */
%macro check_required_param(name);
    %if %length(&&&name) = 0 %then %do;
        %put [ERROR] Required parameter &name is missing or empty. Audit fail.;
        %abort cancel;
    %end;
%mend check_required_param;
