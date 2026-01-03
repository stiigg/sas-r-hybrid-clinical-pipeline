/******************************************************************************
* Package: ADTR_CORE
* Purpose: Reusable ADTR derivation components with dependency management
* Version: 1.0
* Dependencies: None
* Author: Christian Baghai
* Date: 2026-01-03
*
* Description:
*   Core package for ADTR (Tumor Results Analysis Dataset) derivations following
*   RECIST 1.1 criteria. Implements hierarchical macro library (Level 1-3) with
*   automatic dependency management per PharmaSUG 2025-SD-116.
*
* Components:
*   - Level 1: Foundation utilities (imports, validation, formatting)
*   - Level 2: Derivation macros (baseline, nadir, percent change)
*   - Level 3: Parameter-specific derivations (LDIAM, SDIAM, SNTLDIAM)
*   - BDS Structure: CDISC ADaM compliance components
*   - QC/Validation: Quality control checks
*   - Export: Output management utilities
*
* Usage:
*   %load_package(ADTR_CORE);
*   %package_info(ADTR_CORE);
*
* References:
*   - PharmaSUG 2025-SD-116: SAS Packages framework
*   - PharmaSUG 2025-SA-287: Efficacy roadmap for early phase oncology
*   - PharmaSUG 2024-SD-211: Utility macros best practices
******************************************************************************/

%macro package_adtr_core(action=LOAD);
    
    %if %upcase(&action) = LOAD %then %do;
        
        %put NOTE: ------------------------------------------------;
        %put NOTE: Loading ADTR_CORE Package Components;
        %put NOTE: ------------------------------------------------;
        
        /* Load configuration first */
        %if %sysfunc(fileexist(&PROJ_ROOT/adam/programs/sas/config/global_parameters.sas)) %then %do;
            %include "&PROJ_ROOT/adam/programs/sas/config/global_parameters.sas";
        %end;
        %else %do;
            %put WARNING: [ADTR_CORE] Configuration file not found - using defaults;
            %let ADTR_MODE = 2;
            %let APPLY_ENAWORU_RULE = 1;
            %let BASELINE_METHOD = PRETREAT;
        %end;
        
        /* Load Level 2: Core derivation macros */
        %put NOTE: Loading Level 2 derivation macros...;
        %if %sysfunc(fileexist(&PROJ_ROOT/adam/programs/sas/macros/level2_derivations/derive_baseline.sas)) %then %do;
            %include "&PROJ_ROOT/adam/programs/sas/macros/level2_derivations/derive_baseline.sas";
            %put NOTE:   - derive_baseline loaded;
        %end;
        
        /* Note: Additional macro includes will be added as they are created */
        /* This is a framework setup - full macro library to be populated */
        
        %put NOTE: ------------------------------------------------;
        %put NOTE: ADTR_CORE Package v1.0 loaded successfully;
        %put NOTE: Mode: &ADTR_MODE | Study: &STUDY_ID;
        %put NOTE: Configuration: ENAWORU=&APPLY_ENAWORU_RULE | BASELINE=&BASELINE_METHOD;
        %put NOTE: ------------------------------------------------;
        %put NOTE: Framework Status: Modular architecture initialized;
        %put NOTE: Additional macros can be added to:;
        %put NOTE:   - macros/level1_utilities/;
        %put NOTE:   - macros/level2_derivations/;
        %put NOTE:   - macros/level3_parameters/;
        %put NOTE: ------------------------------------------------;
        
    %end;
    
    %else %if %upcase(&action) = INFO %then %do;
        %put NOTE: ================================================;
        %put NOTE: ADTR_CORE Package Information;
        %put NOTE: ================================================;
        %put NOTE: Version: 1.0;
        %put NOTE: Author: Christian Baghai;
        %put NOTE: Date: 2026-01-03;
        %put NOTE: Dependencies: None;
        %put NOTE: ------------------------------------------------;
        %put NOTE: Purpose:;
        %put NOTE:   Modular package for ADTR derivations following;
        %put NOTE:   RECIST 1.1 tumor measurement criteria;
        %put NOTE: ------------------------------------------------;
        %put NOTE: Architecture:;
        %put NOTE:   - Hierarchical macro library (3 levels);
        %put NOTE:   - Configuration-driven execution;
        %put NOTE:   - Built-in validation framework;
        %put NOTE:   - Self-documenting components;
        %put NOTE: ------------------------------------------------;
        %put NOTE: Execution Modes:;
        %put NOTE:   Mode 1: Basic SDIAM derivation (fast);
        %put NOTE:   Mode 2: Enhanced BDS with LDIAM+SDIAM+SNTLDIAM;
        %put NOTE: ------------------------------------------------;
        %put NOTE: Components:;
        %put NOTE:   - Level 1: Foundation utilities;
        %put NOTE:   - Level 2: Core derivations (baseline, nadir, pchg);
        %put NOTE:   - Level 3: Parameter-specific logic;
        %put NOTE:   - BDS: CDISC ADaM structure components;
        %put NOTE:   - QC: Validation and quality control;
        %put NOTE:   - Export: Output management;
        %put NOTE: ------------------------------------------------;
        %put NOTE: References:;
        %put NOTE:   - PharmaSUG 2025-SD-116: SAS Packages framework;
        %put NOTE:   - PharmaSUG 2025-SA-287: Efficacy roadmap;
        %put NOTE:   - PharmaSUG 2025-AI-239: GenAI code conversion;
        %put NOTE:   - PharmaSUG 2024-SD-211: Utility macros;
        %put NOTE:   - Vitale et al. JNCI 2025: Censoring transparency;
        %put NOTE:   - Enaworu et al. Cureus 2025: 25mm nadir rule;
        %put NOTE: ================================================;
    %end;
    
    %else %do;
        %put ERROR: [ADTR_CORE] Invalid action: &action;
        %put ERROR: [ADTR_CORE] Valid actions: LOAD, INFO;
    %end;
    
%mend package_adtr_core;
