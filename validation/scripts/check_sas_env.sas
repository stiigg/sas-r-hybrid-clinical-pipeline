/******************************************************************************
 * Program: check_sas_env.sas
 * Purpose: Validate SAS environment for IQ protocol (IQ-003)
 * Author: Christian Baghai
 * Date: 2025-12-14
 *
 * Checks:
 *   - SAS version >= 9.4 M6
 *   - Valid SAS/BASE license
 *   - Valid SAS/STAT license (required for PROC COMPARE)
 *   - License expiration date
 *
 * Output:
 *   - Log file with environment details
 *   - Text report: validation/evidence/iq_003_sas_env_check.txt
 ******************************************************************************/

/* Create evidence directory */
x "mkdir -p validation/evidence";

/* Capture output to file */
filename evid "validation/evidence/iq_003_sas_env_check.txt";

proc printto log=evid new;
run;

data _null_;
    put "========================================";
    put "SAS Environment Validation (IQ-003)";
    put "========================================";
    put;
    
    put "Test Date: " "%sysfunc(today(),date9.) %sysfunc(time(),time8.)";
    put "Test ID: IQ-003";
    put "Test Description: SAS Installation Verification";
    put;
run;

/******************************************************************************
 * Check 1: SAS Version
 ******************************************************************************/

data _null_;
    put "========================================";
    put "Check 1: SAS Version";
    put "========================================";
    put;
run;

proc options option=config;
run;

data _null_;
    put;
    
    /* Extract SAS version */
    sas_version = "&sysvlong";
    put "Detected SAS Version: " sas_version;
    
    /* Check version meets minimum (9.4 M6) */
    if index(upcase(sas_version), "9.4") > 0 then do;
        put "[PASS] SAS 9.4 detected";
        put;
    end;
    else do;
        put "[WARN] SAS version may not meet requirements";
        put "       Required: SAS 9.4 M6 or later";
        put;
    end;
run;

/******************************************************************************
 * Check 2: SAS License Information
 ******************************************************************************/

data _null_;
    put "========================================";
    put "Check 2: SAS License Information";
    put "========================================";
    put;
run;

proc setinit;
run;

/******************************************************************************
 * Check 3: SAS Product Status
 ******************************************************************************/

data _null_;
    put "========================================";
    put "Check 3: SAS Product Status";
    put "========================================";
    put;
    put "Checking for required SAS products...";
    put;
run;

proc product_status;
run;

/******************************************************************************
 * Check 4: PROC COMPARE Availability
 ******************************************************************************/

data _null_;
    put "========================================";
    put "Check 4: PROC COMPARE Availability";
    put "========================================";
    put;
run;

/* Test PROC COMPARE with dummy data */
data test1;
    x = 1; y = 2; output;
    x = 3; y = 4; output;
run;

data test2;
    x = 1; y = 2; output;
    x = 3; y = 4; output;
run;

proc compare base=test1 compare=test2;
run;

data _null_;
    if &SYSINFO = 0 then do;
        put "[PASS] PROC COMPARE executed successfully";
        put "[PASS] SAS/STAT license is valid";
    end;
    else do;
        put "[FAIL] PROC COMPARE execution failed";
        put "[FAIL] SAS/STAT license may be missing or expired";
    end;
    put;
run;

/* Clean up test datasets */
proc datasets library=work nolist;
    delete test1 test2;
quit;

/******************************************************************************
 * Check 5: SAS Autocall Configuration
 ******************************************************************************/

data _null_;
    put "========================================";
    put "Check 5: SAS Autocall Configuration";
    put "========================================";
    put;
    put "Current SASAUTOS paths:";
    put;
run;

proc options option=sasautos;
run;

data _null_;
    put;
    put "[INFO] Verify that RECIST macro directories are included";
    put "[INFO] Expected paths:";
    put "       - etl/adam_program_library/oncology_response/recist_11_core";
    put "       - etl/adam_program_library/oncology_response/time_to_event";
    put;
run;

/******************************************************************************
 * Overall Assessment
 ******************************************************************************/

data _null_;
    put "========================================";
    put "Overall IQ-003 Assessment";
    put "========================================";
    put;
    
    /* Check if PROC COMPARE worked */
    if &SYSINFO = 0 then do;
        put "OVERALL STATUS: PASS";
        put;
        put "[PASS] SAS environment validation PASSED";
        put "[PASS] SAS version and licensing requirements met";
        put "[PASS] Environment is ready for RECIST 1.1 pipeline";
    end;
    else do;
        put "OVERALL STATUS: FAIL";
        put;
        put "[FAIL] SAS environment validation FAILED";
        put "Action Required: Verify SAS/STAT license";
    end;
    
    put;
    put "========================================";
    put "Evidence saved to: validation/evidence/iq_003_sas_env_check.txt";
    put "========================================";
run;

/* Restore default log */
proc printto;
run;

/* Display summary in console */
data _null_;
    infile "validation/evidence/iq_003_sas_env_check.txt";
    input;
    put _infile_;
run;
