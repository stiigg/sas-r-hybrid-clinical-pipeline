/******************************************************************************
* Program: 54_sdtm_rs_master.sas
* Purpose: Master wrapper macro for disease-specific response assessment
* Author:  Christian Baghai
* Date:    2026-01-02
* 
* Description:
*   This macro routes to the appropriate indication-specific RS domain program
*   based on the trial's disease indication. Supports three validated response
*   criteria frameworks:
*     1. RECIST 1.1 (Solid Tumors) - with 2025 Enaworu enhancement
*     2. IMWG 2025 (Multiple Myeloma) - simplified CR/VGPR/PR/SD/PD
*     3. Palladini 2012 (AL Amyloidosis) - FDA-qualified NT-proBNP biomarker
*
* Usage:
*   %derive_response_domain(indication=SOLID_TUMOR);
*   %derive_response_domain(indication=MULTIPLE_MYELOMA);
*   %derive_response_domain(indication=AL_AMYLOIDOSIS);
*
* Parameters:
*   indication - Disease indication (REQUIRED)
*                Valid values: SOLID_TUMOR, RECIST, MULTIPLE_MYELOMA, 
*                             MYELOMA, AL_AMYLOIDOSIS, AMYLOIDOSIS
*
* Dependencies:
*   - 54a_sdtm_rs_recist.sas (RECIST 1.1 + Enaworu rule)
*   - 54b_sdtm_rs_myeloma.sas (IMWG 2025 criteria)
*   - 54c_sdtm_rs_amyloidosis.sas (Palladini 2012 + FDA biomarkers)
*
* Evidence Base:
*   See individual program headers for detailed references
******************************************************************************/

%macro derive_response_domain(indication=);
    
    %put NOTE: ========================================;
    %put NOTE: Disease Response Assessment Initiated;
    %put NOTE: Indication: &indication;
    %put NOTE: Program: 54_sdtm_rs_master.sas;
    %put NOTE: Date: %sysfunc(date(), yymmdd10.);
    %put NOTE: ========================================;
    
    /* Validate indication parameter */
    %if %length(&indication) = 0 %then %do;
        %put ERROR: ========================================;
        %put ERROR: INDICATION parameter is REQUIRED;
        %put ERROR: ========================================;
        %put ERROR: Valid values:;
        %put ERROR:   - SOLID_TUMOR or RECIST (for solid tumors);
        %put ERROR:   - MULTIPLE_MYELOMA or MYELOMA (for multiple myeloma);
        %put ERROR:   - AL_AMYLOIDOSIS or AMYLOIDOSIS (for AL amyloidosis);
        %put ERROR: ========================================;
        %put ERROR: Example usage:;
        %put ERROR:   %nrstr(%derive_response_domain(indication=MULTIPLE_MYELOMA););
        %put ERROR: ========================================;
        %abort cancel;
    %end;
    
    /* Route to appropriate indication-specific program */
    %if %upcase(&indication) = SOLID_TUMOR or %upcase(&indication) = RECIST %then %do;
        %put NOTE: Routing to RECIST 1.1 program (Solid Tumors);
        %put NOTE: Calling 54a_sdtm_rs_recist.sas;
        %put NOTE: Response criteria: RECIST 1.1 (2009) + Enaworu 25mm nadir rule (2025);
        %put NOTE: Applicable to: Solid tumors with measurable lesions;
        %put NOTE: Evidence: Eisenhauer 2009, Enaworu 2025;
        %include "54a_sdtm_rs_recist.sas";
    %end;
    
    %else %if %upcase(&indication) = MULTIPLE_MYELOMA or %upcase(&indication) = MYELOMA %then %do;
        %put NOTE: Routing to IMWG program (Multiple Myeloma);
        %put NOTE: Calling 54b_sdtm_rs_myeloma.sas;
        %put NOTE: Response criteria: IMWG 2025 (sCR/MR removed, MRD emphasis);
        %put NOTE: Applicable to: Multiple myeloma (RRMM, NDMM, CAR-T trials);
        %put NOTE: Evidence: IMWG Annual Summit 2025, Kubicki 2025, ASH 2025;
        %include "54b_sdtm_rs_myeloma.sas";
    %end;
    
    %else %if %upcase(&indication) = AL_AMYLOIDOSIS or %upcase(&indication) = AMYLOIDOSIS %then %do;
        %put NOTE: Routing to Palladini program (AL Amyloidosis);
        %put NOTE: Calling 54c_sdtm_rs_amyloidosis.sas;
        %put NOTE: Response criteria: Palladini 2012 + FDA-qualified NT-proBNP;
        %put NOTE: Applicable to: AL (light chain) amyloidosis;
        %put NOTE: Evidence: Palladini 2012, Merlini 2016, FDA Guidance 2016;
        %include "54c_sdtm_rs_amyloidosis.sas";
    %end;
    
    /* Invalid indication - abort with helpful error message */
    %else %do;
        %put ERROR: ========================================;
        %put ERROR: INVALID INDICATION: &indication;
        %put ERROR: ========================================;
        %put ERROR: Valid values:;
        %put ERROR:   - SOLID_TUMOR or RECIST;
        %put ERROR:   - MULTIPLE_MYELOMA or MYELOMA;
        %put ERROR:   - AL_AMYLOIDOSIS or AMYLOIDOSIS;
        %put ERROR: ========================================;
        %put ERROR: You provided: &indication;
        %put ERROR: Response domain derivation ABORTED;
        %put ERROR: ========================================;
        %abort cancel;
    %end;
    
    %put NOTE: ========================================;
    %put NOTE: Response Domain Derivation Complete;
    %put NOTE: Indication: &indication;
    %put NOTE: Check log for program-specific output details;
    %put NOTE: ========================================;
    
%mend derive_response_domain;

/******************************************************************************
* USAGE EXAMPLES
******************************************************************************/

/*
** Example 1: Solid Tumor Trial with RECIST 1.1
%derive_response_domain(indication=SOLID_TUMOR);
*/

/*
** Example 2: Multiple Myeloma CAR-T Trial with IMWG 2025
%derive_response_domain(indication=MULTIPLE_MYELOMA);
*/

/*
** Example 3: AL Amyloidosis Trial with Palladini Criteria
%derive_response_domain(indication=AL_AMYLOIDOSIS);
*/

/*
** Example 4: Integrated into production pipeline
libname sdtm "../../data/csv";
libname adam "../../data/adam";

** Run all SDTM domains
%include "01_sdtm_dm.sas";
%include "02_sdtm_ex.sas";
%include "03_sdtm_ae.sas";
...
%include "53_sdtm_tu.sas";
%include "53_sdtm_tr.sas";

** Derive indication-specific response domain
%include "54_sdtm_rs_master.sas";
%let INDICATION = MULTIPLE_MYELOMA;  ** Set based on protocol
%derive_response_domain(indication=&INDICATION);

** Continue with remaining domains
%include "55_sdtm_su.sas";
...
*/

/******************************************************************************
* VALIDATION CHECKLIST
*
* Before using in production:
* [ ] Verify indication matches protocol disease area
* [ ] Confirm input domains (TU/TR for RECIST, LB/MB for myeloma/amyloidosis)
* [ ] Check controlled terminology compliance (CDISC CT 2025-09-26)
* [ ] Review QC flags in program-specific output
* [ ] Validate response distribution against expected rates
* [ ] Ensure visit windows align with protocol schedule
* [ ] For CAR-T trials: Verify infusion date in EX domain
* [ ] For amyloidosis: Confirm NT-proBNP units (ng/L standardization)
* [ ] For RECIST: Verify baseline lesion selection (max 5 per organ)
******************************************************************************/

/******************************************************************************
* CDISC COMPLIANCE NOTES
*
* All programs conform to:
*   - SDTMIG v3.3 (CDISC 2024)
*   - CDISC CT 2025-09-26 (Controlled Terminology)
*   - CDISC Oncology SDS (June 2024) - Disease Response Supplement
*
* RS Domain Structure:
*   RSTESTCD: Response assessment test code
*   RSTEST:   Response assessment test name
*   RSCAT:    Response criteria framework
*   RSSTRESC: Standardized response result (CR/PR/SD/PD/VGPR/etc.)
*   RSEVAL:   Evaluator (INVESTIGATOR, IRC, COPILOT)
*
* SUPPRS Domain Usage:
*   - MRD status and methods (myeloma)
*   - Evaluability flags (amyloidosis)
*   - Day 28 CAR-T assessment flags (myeloma)
*   - QC flags and measurement reliability (RECIST)
******************************************************************************/

%put NOTE: ========================================;
%put NOTE: 54_sdtm_rs_master.sas macro loaded successfully;
%put NOTE: Ready to derive disease-specific response domains;
%put NOTE: Call: %nrstr(%derive_response_domain(indication=<INDICATION>));
%put NOTE: ========================================;
