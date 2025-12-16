/* Automated RECIST dataset comparison using PROC COMPARE */

%macro compare_recist_datasets(prod_lib=adam, qc_lib=qc_adam, dataset=adrecist);
    
    /* Sort both datasets identically */
    proc sort data=&prod_lib..&dataset out=work.prod_sorted;
        by usubjid adt paramcd;
    run;
    
    proc sort data=&qc_lib..&dataset out=work.qc_sorted;
        by usubjid adt paramcd;
    run;
    
    /* Perform comparison with detailed discrepancy reporting */
    proc compare base=work.prod_sorted 
                 compare=work.qc_sorted
                 out=work.discrepancies
                 outnoequal
                 method=absolute
                 criterion=1E-6;
        id usubjid adt paramcd;
    run;
    
    /* Generate HTML discrepancy report */
    ods html file="qc/outputs/comparison_&dataset._&sysdate9..html";
    
    title "RECIST Dataset Comparison: Production vs. QC";
    title2 "Dataset: &dataset | Date: &sysdate9";
    
    proc print data=work.discrepancies (obs=100);
        var usubjid adt paramcd _type_ _obs_ avalc base compare;
        where _type_ ne 'DIF';
    run;
    
    /* Summary statistics */
    proc freq data=work.discrepancies;
        tables _type_ / missing;
        title3 "Discrepancy Type Summary";
    run;
    
    ods html close;
    
    /* Pass/Fail determination */
    proc sql noprint;
        select count(*) into :ndiscrep
        from work.discrepancies
        where _type_ ne 'DIF';
    quit;
    
    %if &ndiscrep = 0 %then %do;
        %put NOTE: ***** QC PASS: No discrepancies detected *****;
    %end;
    %else %do;
        %put WARNING: ***** QC FAIL: &ndiscrep discrepancies detected *****;
        %put WARNING: Review qc/outputs/comparison_&dataset._&sysdate9..html;
    %end;
    
%mend;

/* Execute comparison */
%compare_recist_datasets(prod_lib=adam, qc_lib=qc_adam, dataset=adrecist);
