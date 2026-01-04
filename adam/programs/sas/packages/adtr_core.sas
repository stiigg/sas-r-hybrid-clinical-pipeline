/******************************************************************************
* Package: ADTR_CORE
* Version: 1.1
* Purpose: Core macro library for ADTR derivations with integrated validation
* Author: Christian Baghai
* Date: 2026-01-04
*
* CONTENTS:
*   - Level 1: Foundation Utilities (import, validation, formatting)
*   - Level 2: Core Derivations (baseline, nadir, percent change)
*   - Level 3: Parameter-specific derivations (LDIAM, SDIAM, SNTLDIAM)
*   - Level 4: BDS structure (PARCAT, CRIT, ANL flags)
*   - QC: Validation utilities
*
* USAGE:
*   %include "packages/package_loader.sas";
*   %load_package(ADTR_CORE);
*
* DEPENDENCIES:
*   - PROJ_ROOT environment variable or macro variable must be set
*   - All macro files must exist in specified paths
******************************************************************************/

%macro load_adtr_core_package / des="Load ADTR_CORE package with all dependencies";
    
    %put NOTE: ================================================;
    %put NOTE: Loading ADTR_CORE Package v1.1;
    %put NOTE: Package Date: 2026-01-04;
    %put NOTE: ================================================;
    
    /* Verify PROJ_ROOT is set */
    %if %length(&PROJ_ROOT) = 0 %then %do;
        %put ERROR: [ADTR_CORE] PROJ_ROOT macro variable not set;
        %put ERROR: [ADTR_CORE] Set via: %%let PROJ_ROOT = /path/to/repo;
        %abort cancel;
    %end;
    
    %put NOTE: [ADTR_CORE] Project Root: &PROJ_ROOT;
    
    /* Level 1: Foundation Utilities */
    %put NOTE: [ADTR_CORE] Loading Level 1 - Foundation Utilities...;
    
    %let macro_path = &PROJ_ROOT/adam/programs/sas/macros/level1_utilities;
    
    %if %sysfunc(fileexist(&macro_path/import_tr.sas)) %then %do;
        %include "&macro_path/import_tr.sas";
        %put NOTE: [ADTR_CORE]   ✓ import_tr.sas loaded;
    %end;
    %else %do;
        %put WARNING: [ADTR_CORE]   ✗ import_tr.sas not found;
    %end;
    
    %if %sysfunc(fileexist(&macro_path/import_tu.sas)) %then %do;
        %include "&macro_path/import_tu.sas";
        %put NOTE: [ADTR_CORE]   ✓ import_tu.sas loaded;
    %end;
    %else %do;
        %put WARNING: [ADTR_CORE]   ✗ import_tu.sas not found;
    %end;
    
    %if %sysfunc(fileexist(&macro_path/import_adsl.sas)) %then %do;
        %include "&macro_path/import_adsl.sas";
        %put NOTE: [ADTR_CORE]   ✓ import_adsl.sas loaded;
    %end;
    %else %do;
        %put WARNING: [ADTR_CORE]   ✗ import_adsl.sas not found;
    %end;
    
    %if %sysfunc(fileexist(&macro_path/validate_input.sas)) %then %do;
        %include "&macro_path/validate_input.sas";
        %put NOTE: [ADTR_CORE]   ✓ validate_input.sas loaded;
    %end;
    %else %do;
        %put WARNING: [ADTR_CORE]   ✗ validate_input.sas not found;
    %end;
    
    %if %sysfunc(fileexist(&macro_path/format_dates.sas)) %then %do;
        %include "&macro_path/format_dates.sas";
        %put NOTE: [ADTR_CORE]   ✓ format_dates.sas loaded;
    %end;
    %else %do;
        %put WARNING: [ADTR_CORE]   ✗ format_dates.sas not found;
    %end;
    
    /* Level 2: Core Derivations */
    %put NOTE: [ADTR_CORE] Loading Level 2 - Core Derivations...;
    
    %let macro_path = &PROJ_ROOT/adam/programs/sas/macros/level2_derivations;
    
    %if %sysfunc(fileexist(&macro_path/derive_baseline.sas)) %then %do;
        %include "&macro_path/derive_baseline.sas";
        %put NOTE: [ADTR_CORE]   ✓ derive_baseline.sas loaded;
    %end;
    %else %do;
        %put WARNING: [ADTR_CORE]   ✗ derive_baseline.sas not found;
    %end;
    
    /* Future: Add other level 2 macros as developed */
    /* %include "&macro_path/derive_nadir.sas"; */
    /* %include "&macro_path/derive_pchg.sas"; */
    
    /* Level 3: Parameter Derivations (placeholder for future development) */
    %put NOTE: [ADTR_CORE] Level 3 - Parameter Derivations (not yet implemented);
    
    /* Level 4: BDS Structure (placeholder for future development) */
    %put NOTE: [ADTR_CORE] Level 4 - BDS Structure (not yet implemented);
    
    /* QC Validation (placeholder for future development) */
    %put NOTE: [ADTR_CORE] QC Validation utilities (not yet implemented);
    
    %put NOTE: ================================================;
    %put NOTE: ADTR_CORE Package v1.1 loaded successfully;
    %put NOTE: Macros available: import_tr, import_tu, import_adsl, validate_input, format_dates, derive_baseline;
    %put NOTE: ================================================;
    
%mend load_adtr_core_package;

/* Auto-execute alias for convenience */
%macro load_package(package_name) / des="Load specified package";
    %if %upcase(&package_name) = ADTR_CORE %then %do;
        %load_adtr_core_package;
    %end;
    %else %do;
        %put ERROR: [PACKAGE_LOADER] Unknown package: &package_name;
        %put ERROR: [PACKAGE_LOADER] Available packages: ADTR_CORE;
    %end;
%mend load_package;
