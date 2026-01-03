/******************************************************************************
* File: packages/package_loader.sas
* Purpose: SAS Package Framework - Core loader with dependency management
* Author: Christian Baghai
* Date: 2026-01-03
* Version: 1.0
*
* Description:
*   Implements SAS Packages framework per PharmaSUG 2025-SD-116 for modular,
*   reusable component management. Provides automatic dependency resolution,
*   version control, and hierarchical macro loading.
*
* Usage:
*   %include "./packages/package_loader.sas";
*   %load_package(ADTR_CORE);
*
* References:
*   - PharmaSUG 2025-SD-116: SAS Packages framework for reusability
*   - PharmaSUG 2024-SD-211: Utility macros best practices
******************************************************************************/

%macro load_package(package_name) / des="Load SAS package with dependencies";
    
    %put NOTE: ================================================;
    %put NOTE: Loading Package: &package_name;
    %put NOTE: ================================================;
    
    %let _pkg_start = %sysfunc(datetime());
    
    /* Validate package name */
    %if %length(&package_name) = 0 %then %do;
        %put ERROR: [PACKAGE_LOADER] Package name is required;
        %return;
    %end;
    
    /* Convert to uppercase for consistency */
    %let package_name = %upcase(&package_name);
    
    /* Load package based on name */
    %if &package_name = ADTR_CORE %then %do;
        %include "&PROJ_ROOT/adam/programs/sas/packages/adtr_core.sas";
        %package_adtr_core(action=LOAD);
    %end;
    %else %do;
        %put ERROR: [PACKAGE_LOADER] Unknown package: &package_name;
        %put ERROR: [PACKAGE_LOADER] Available packages: ADTR_CORE;
        %return;
    %end;
    
    %let _pkg_end = %sysfunc(datetime());
    %let _pkg_elapsed = %sysevalf(&_pkg_end - &_pkg_start);
    
    %put NOTE: ------------------------------------------------;
    %put NOTE: Package &package_name loaded successfully;
    %put NOTE: Load time: %sysfunc(putn(&_pkg_elapsed, 8.2)) seconds;
    %put NOTE: ================================================;
    
%mend load_package;

%macro package_info(package_name) / des="Display package information";
    
    %if %length(&package_name) = 0 %then %do;
        %put ERROR: [PACKAGE_INFO] Package name is required;
        %return;
    %end;
    
    %let package_name = %upcase(&package_name);
    
    %if &package_name = ADTR_CORE %then %do;
        %include "&PROJ_ROOT/adam/programs/sas/packages/adtr_core.sas";
        %package_adtr_core(action=INFO);
    %end;
    %else %do;
        %put ERROR: [PACKAGE_INFO] Unknown package: &package_name;
    %end;
    
%mend package_info;

%put NOTE: Package Loader v1.0 initialized;
%put NOTE: Available macros: %nrstr(%load_package), %nrstr(%package_info);
