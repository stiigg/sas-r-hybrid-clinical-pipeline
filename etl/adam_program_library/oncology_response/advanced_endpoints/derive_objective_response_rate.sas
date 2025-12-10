/******************************************************************************
Macro: derive_objective_response_rate
Purpose: Derive Objective Response Rate (ORR) summary endpoint
Author: Christian Baghai
Date: December 2025

Description:
Calculates Objective Response Rate (ORR), defined as the proportion of
subjects with Best Overall Response (BOR) of Complete Response (CR) or
Partial Response (PR).

Typical definition:
- Numerator: Number of subjects with BOR = CR or PR
- Denominator: Total evaluable subjects (usually ITT or response-evaluable)
- Output: Proportion, 95% CI (Clopper-Pearson exact)

This macro produces summary statistics suitable for TLF generation.

Parameters:
  inds          - Input dataset with BOR per subject (e.g., ADRS BOR subset)
  outds         - Output summary dataset with ORR statistics
  usubjid_var   - Subject ID (default: USUBJID)
  bor_var       - Best Overall Response variable (default: BOR)
  by_vars       - Optional BY variables (e.g., TRT01P ARM, default: blank)
  alpha         - Alpha level for CI (default: 0.05 for 95% CI)

Output variables:
  N_EVAL       - Number of evaluable subjects
  N_RESP       - Number of responders (CR or PR)
  ORR          - Objective Response Rate (proportion)
  ORR_PCT      - ORR as percentage
  ORR_LCL      - Lower 95% confidence limit
  ORR_UCL      - Upper 95% confidence limit

Assumptions:
- Input contains one record per subject with BOR variable
- BOR values: 'CR', 'PR', 'SD', 'PD', 'NE'
******************************************************************************/

%macro derive_objective_response_rate(
    inds=,
    outds=,
    usubjid_var=USUBJID,
    bor_var=BOR,
    by_vars=,
    alpha=0.05
) / des="Derive Objective Response Rate (ORR)";

    %if %sysevalf(%superq(inds)=,boolean) or %sysevalf(%superq(outds)=,boolean) %then %do;
        %put ERROR: [derive_objective_response_rate] inds= and outds= are required.;
        %return;
    %end;

    /* Flag responders */
    data _orr_flag;
        set &inds;
        length BOR_STD $10 RESP_FL $1;
        BOR_STD = upcase(strip(&bor_var));

        if BOR_STD in ('CR','PR') then RESP_FL = 'Y';
        else RESP_FL = 'N';

        label RESP_FL = "Responder Flag (Y=CR/PR)";
    run;

    /* Calculate ORR by group */
    proc sort data=_orr_flag;
        %if %length(&by_vars) %then %do;
            by &by_vars;
        %end;
    run;

    proc freq data=_orr_flag noprint;
        %if %length(&by_vars) %then %do;
            by &by_vars;
        %end;
        tables RESP_FL / binomial(level='Y' exact cl=exact);
        output out=_orr_ci binomial;
    run;

    /* Format results */
    data &outds;
        set _orr_ci;

        length ENDPOINT $40;
        ENDPOINT = 'Objective Response Rate (ORR)';

        N_EVAL = _FREQ_;
        N_RESP = .;

        /* Extract responder count */
        if RESP_FL = 'Y' then N_RESP = _FREQ_;

        /* ORR proportion and percentage */
        ORR     = _BIN_;
        ORR_PCT = ORR * 100;

        /* Exact confidence limits */
        ORR_LCL = L_BIN;
        ORR_UCL = U_BIN;

        label
            ENDPOINT = "Endpoint Description"
            N_EVAL   = "Number of Evaluable Subjects"
            N_RESP   = "Number of Responders (CR/PR)"
            ORR      = "Objective Response Rate (Proportion)"
            ORR_PCT  = "Objective Response Rate (Percentage)"
            ORR_LCL  = "ORR 95% Lower Confidence Limit"
            ORR_UCL  = "ORR 95% Upper Confidence Limit";

        keep %if %length(&by_vars) %then %do; &by_vars %end; 
             ENDPOINT N_EVAL N_RESP ORR ORR_PCT ORR_LCL ORR_UCL;
    run;

    proc print data=&outds noobs label;
        title "Objective Response Rate (ORR) Summary";
    run;
    title;

    proc datasets lib=work nolist;
        delete _orr_flag _orr_ci;
    quit;

    %put NOTE: [derive_objective_response_rate] completed. Output: &outds.;

%mend derive_objective_response_rate;
