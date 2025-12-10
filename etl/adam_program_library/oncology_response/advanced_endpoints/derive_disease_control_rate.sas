/******************************************************************************
Macro: derive_disease_control_rate
Purpose: Derive Disease Control Rate (DCR) summary endpoint
Author: Christian Baghai
Date: December 2025

Description:
Calculates Disease Control Rate (DCR), defined as the proportion of subjects
with Best Overall Response (BOR) of Complete Response (CR), Partial Response
(PR), or Stable Disease (SD) lasting at least a specified duration.

Typical definition:
- Numerator: Number of subjects with BOR = CR, PR, or SD (≥ minimum duration)
- Denominator: Total evaluable subjects
- Output: Proportion, 95% CI (Clopper-Pearson exact)

Parameters:
  inds          - Input dataset with BOR per subject
  outds         - Output summary dataset with DCR statistics
  usubjid_var   - Subject ID (default: USUBJID)
  bor_var       - Best Overall Response variable (default: BOR)
  by_vars       - Optional BY variables (default: blank)
  alpha         - Alpha level for CI (default: 0.05)

Output variables:
  N_EVAL       - Number of evaluable subjects
  N_DC         - Number with disease control (CR/PR/SD)
  DCR          - Disease Control Rate (proportion)
  DCR_PCT      - DCR as percentage
  DCR_LCL      - Lower 95% confidence limit
  DCR_UCL      - Upper 95% confidence limit

Assumptions:
- Input contains one record per subject with BOR
- BOR values: 'CR', 'PR', 'SD', 'PD', 'NE'
- SD already qualified per protocol minimum duration in BOR derivation
******************************************************************************/

%macro derive_disease_control_rate(
    inds=,
    outds=,
    usubjid_var=USUBJID,
    bor_var=BOR,
    by_vars=,
    alpha=0.05
) / des="Derive Disease Control Rate (DCR)";

    %if %sysevalf(%superq(inds)=,boolean) or %sysevalf(%superq(outds)=,boolean) %then %do;
        %put ERROR: [derive_disease_control_rate] inds= and outds= are required.;
        %return;
    %end;

    /* Flag disease control */
    data _dcr_flag;
        set &inds;
        length BOR_STD $10 DC_FL $1;
        BOR_STD = upcase(strip(&bor_var));

        if BOR_STD in ('CR','PR','SD') then DC_FL = 'Y';
        else DC_FL = 'N';

        label DC_FL = "Disease Control Flag (Y=CR/PR/SD)";
    run;

    proc sort data=_dcr_flag;
        %if %length(&by_vars) %then %do;
            by &by_vars;
        %end;
    run;

    proc freq data=_dcr_flag noprint;
        %if %length(&by_vars) %then %do;
            by &by_vars;
        %end;
        tables DC_FL / binomial(level='Y' exact cl=exact);
        output out=_dcr_ci binomial;
    run;

    data &outds;
        set _dcr_ci;

        length ENDPOINT $40;
        ENDPOINT = 'Disease Control Rate (DCR)';

        N_EVAL = _FREQ_;
        N_DC = .;

        if DC_FL = 'Y' then N_DC = _FREQ_;

        DCR     = _BIN_;
        DCR_PCT = DCR * 100;

        DCR_LCL = L_BIN;
        DCR_UCL = U_BIN;

        label
            ENDPOINT = "Endpoint Description"
            N_EVAL   = "Number of Evaluable Subjects"
            N_DC     = "Number with Disease Control (CR/PR/SD)"
            DCR      = "Disease Control Rate (Proportion)"
            DCR_PCT  = "Disease Control Rate (Percentage)"
            DCR_LCL  = "DCR 95% Lower Confidence Limit"
            DCR_UCL  = "DCR 95% Upper Confidence Limit";

        keep %if %length(&by_vars) %then %do; &by_vars %end;
             ENDPOINT N_EVAL N_DC DCR DCR_PCT DCR_LCL DCR_UCL;
    run;

    proc print data=&outds noobs label;
        title "Disease Control Rate (DCR) Summary";
    run;
    title;

    proc datasets lib=work nolist;
        delete _dcr_flag _dcr_ci;
    quit;

    %put NOTE: [derive_disease_control_rate] completed. Output: &outds.;

%mend derive_disease_control_rate;
