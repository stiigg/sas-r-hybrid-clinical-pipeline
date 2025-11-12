/* ---- SYSCC guard macro ---- */
%macro check_syscc(step=);
    %if &SYSCC > 4 %then %do;
        %put [ERROR] Step &step failed with SYSCC=&SYSCC.. Aborting.;
        %abort cancel;
    %end;
%mend check_syscc;
