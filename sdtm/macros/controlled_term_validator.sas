/******************************************************************************
* Macro: VALIDATE_CONTROLLED_TERM
* Purpose: Validate SDTM variables against CDISC Controlled Terminology
* Author: Christian Baghai  
* Date: 2025-12-25
* Version: 2.0
*
* Description:
*   Validates SDTM variable values against CDISC Controlled Terminology (CT)
*   codelists. Identifies non-conformant values and generates compliance report.
*
* Parameters:
*   INPUT_DATA    - Dataset to validate
*   VARIABLE      - Variable name to validate
*   CODELIST      - CDISC codelist name (e.g., 'Severity/Intensity')
*   ALLOWED_VALUES- Pipe-delimited list of valid values (e.g., 'MILD|MODERATE|SEVERE')
*   CASE_SENSITIVE- Whether validation is case-sensitive (YES/NO)
*
* Output:
*   - Printed validation report
*   - Returns warning for non-conformant values
*   - Optionally aborts on failures
*
* Example:
*   %validate_controlled_term(
*       input_data=sdtm.ae,
*       variable=AESEV,
*       codelist=Severity/Intensity,
*       allowed_values=MILD|MODERATE|SEVERE,
*       case_sensitive=NO
*   );
*
* Notes:
*   - In production, could integrate with CDISC Library API for dynamic CT
*   - Currently uses static allowed_values list from specification
******************************************************************************/

%macro validate_controlled_term(
    input_data=,
    variable=,
    codelist=,
    allowed_values=,
    case_sensitive=NO
);

    %put NOTE: Validating &variable against CT: &codelist;
    
    /* Parse allowed values into array */
    data _ct_allowed;
        length allowed_value $200;
        allowed_list = "&allowed_values";
        do i = 1 to countw(allowed_list, '|');
            allowed_value = scan(allowed_list, i, '|');
            %if %upcase(&case_sensitive) = NO %then %do;
                allowed_value = upcase(strip(allowed_value));
            %end;
            output;
        end;
        keep allowed_value;
    run;
    
    /* Find non-conformant values */
    proc sql;
        create table _ct_violations as
        select distinct
            "&variable" as variable length=32,
            "&codelist" as codelist length=100,
            %if %upcase(&case_sensitive) = NO %then %do;
                upcase(&variable) as value_found length=200,
            %end;
            %else %do;
                &variable as value_found length=200,
            %end;
            count(*) as occurrence_count
        from &input_data
        where not missing(&variable)
            and %if %upcase(&case_sensitive) = NO %then %do;
                upcase(&variable)
            %end;
            %else %do;
                &variable
            %end;
            not in (select allowed_value from _ct_allowed)
        group by calculated value_found;
    quit;
    
    /* Report violations */
    proc sql noprint;
        select count(*) into :violation_count
        from _ct_violations;
    quit;
    
    %if &violation_count > 0 %then %do;
        %put WARNING: &violation_count non-conformant values found in &variable;
        %put WARNING: Codelist: &codelist;
        %put WARNING: Allowed values: &allowed_values;
        
        title "Controlled Terminology Violations: &variable";
        title2 "Codelist: &codelist";
        proc print data=_ct_violations noobs;
            var variable codelist value_found occurrence_count;
        run;
        title;
    %end;
    %else %do;
        %put NOTE: All values in &variable conform to CT: &codelist;
    %end;
    
    /* Cleanup */
    proc datasets library=work nolist;
        delete _ct_allowed _ct_violations;
    quit;

%mend validate_controlled_term;
