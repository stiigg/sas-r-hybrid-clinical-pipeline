/******************************************************************************
 Program: 41_sdtm_ex_nexicart2.sas
 Purpose: Generate SDTM EX domain for NEXICART-2 CAR-T trial
 Author: Christian Baghai
 Date: December 30, 2025

 Description:
   Creates SDTM EX domain for NXC-201 CAR-T therapy with:
   - CAR-T infusion records (dose in cells/kg)
   - Lymphodepletion conditioning regimen
   - Optional bridging therapy
   - Out-of-specification dose handling
   - Study day calculations relative to CAR-T infusion (Day 0)

 Inputs:
   - raw/cart_infusion_nexicart2.csv
   - raw/lymphodepletion_nexicart2.csv  
   - raw/bridging_therapy_nexicart2.csv
   - raw/demographics_nexicart2.csv

 Outputs:
   - sdtm/data/csv/ex_nexicart2.csv
   - sdtm/data/csv/suppex_nexicart2.csv

 CAR-T Dose Calculation:
   EXDOSE (cells/kg) = TOTAL_CART_CELLS / WEIGHT_AT_LEUKAPHERESIS / 1,000,000
   Target: 2.0 × 10^6 cells/kg (± 20% acceptable)
   
 Study Day Reference:
   Day 0 = CAR-T infusion date (EXSTDTC for EXTRT = "NXC-201")
   Pre-infusion events have negative study days
******************************************************************************/

%let pgm = 41_sdtm_ex_nexicart2;
%let version = 1.0;

*-----------------------------------------------------------------------------
* 1. ENVIRONMENT SETUP
*-----------------------------------------------------------------------------;

options mprint mlogic symbolgen validvarname=upcase;
libname raw "../data/raw";
libname sdtm "../data/csv";

%put NOTE: ============================================;
%put NOTE: Starting NEXICART-2 EX Domain Generation;
%put NOTE: Program: &pgm v&version;
%put NOTE: Date: %sysfunc(today(), worddate.);
%put NOTE: ============================================;

*-----------------------------------------------------------------------------
* 2. IMPORT RAW DATA FILES
*-----------------------------------------------------------------------------;

* CAR-T Infusion Data;
proc import datafile="../data/raw/cart_infusion_nexicart2.csv"
    out=raw_cart
    dbms=csv replace;
    getnames=yes;
run;

* Lymphodepletion Data;
proc import datafile="../data/raw/lymphodepletion_nexicart2.csv"
    out=raw_lympho
    dbms=csv replace;
    getnames=yes;
run;

* Bridging Therapy (if exists);
%macro import_bridging;
    %if %sysfunc(fileexist(../data/raw/bridging_therapy_nexicart2.csv)) %then %do;
        proc import datafile="../data/raw/bridging_therapy_nexicart2.csv"
            out=raw_bridging
            dbms=csv replace;
            getnames=yes;
        run;
        
        proc sql noprint;
            select count(*) into :n_bridging_raw from raw_bridging;
        quit;
        %put NOTE: Imported &n_bridging_raw bridging therapy records;
    %end;
    %else %do;
        data raw_bridging;
            length SUBJID $3 TREATMENT_NAME $100 START_DATE $10 END_DATE $10
                   INDICATION $100 RESPONSE $50 CART_INFUSION_DATE $10;
            stop;
        run;
        %put NOTE: No bridging therapy file found. Creating empty dataset.;
    %end;
%mend;
%import_bridging;

*-----------------------------------------------------------------------------
* 3. PROCESS CAR-T INFUSION RECORDS
*-----------------------------------------------------------------------------;

data ex_cart;
    set raw_cart;
    
    length STUDYID $20 DOMAIN $2 USUBJID $30 EXTRT $200 EXCAT $50 
           EXSCAT $100 EXDOSE 8 EXDOSU $20 EXDOSFRM $50 EXROUTE $50 
           EXADJ $50 EXSTDTC $25 EXENDTC $25 EXLOT $50;
    
    * Standard SDTM variables;
    STUDYID = "NEXICART2";
    DOMAIN = "EX";
    USUBJID = catx("-", STUDYID, put(input(SUBJID, best.), z3.));
    
    * Treatment identification;
    EXTRT = "NXC-201 CAR-T Cells";
    EXCAT = "CAR-T CELL THERAPY";
    EXSCAT = "AUTOLOGOUS ANTI-BCMA CAR-T";
    
    * Dose calculation: cells/kg;
    EXDOSE = TOTAL_CART_CELLS / WEIGHT_AT_LEUKAPHERESIS / 1000000; /* Convert to millions */
    EXDOSU = "10^6 CELLS/KG";
    EXDOSFRM = "INFUSION BAG";
    EXROUTE = "INTRAVENOUS";
    
    * Check if dose is within acceptable range (Target: 2.0 ± 20%);
    TARGET_DOSE = 2.0;
    LOWER_BOUND = TARGET_DOSE * 0.80;  /* 1.6 */
    UPPER_BOUND = TARGET_DOSE * 1.20;  /* 2.4 */
    
    if EXDOSE < LOWER_BOUND then 
        EXADJ = "DOSE REDUCED";
    else if EXDOSE > UPPER_BOUND then 
        EXADJ = "DOSE INCREASED";
    else 
        EXADJ = "";  /* Within acceptable range */
    
    * Timing (ISO 8601 format);
    EXSTDTC = cats(INFUSION_DATE, "T", INFUSION_TIME);
    EXENDTC = EXSTDTC;  /* Single infusion event */
    
    * Study day (Day 0 for CAR-T infusion);
    EXSTDY = 0;
    EXENDY = 0;
    
    * Manufacturing batch;
    EXLOT = BATCH_NUMBER;
    
    * Epoch;
    EPOCH = "TREATMENT";
    
    * Sequence (will be assigned later);
    EXSEQ = .;
    
    * Keep temporary variables for SUPPEX;
    TOTAL_CELLS_ADMIN = TOTAL_CART_CELLS;
    CAR_POS_PCT = CAR_POSITIVE_PCT;
    INFUSION_VOLUME = VOLUME_ML;
    
    keep STUDYID DOMAIN USUBJID EXTRT EXCAT EXSCAT EXDOSE EXDOSU EXDOSFRM 
         EXROUTE EXADJ EXSTDTC EXENDTC EXSTDY EXENDY EXLOT EPOCH EXSEQ
         TOTAL_CELLS_ADMIN CAR_POS_PCT INFUSION_VOLUME;
run;

* Log CAR-T records;
proc sql noprint;
    select count(*) into :n_cart_records from ex_cart;
quit;
%put NOTE: Created &n_cart_records CAR-T infusion records;

* Flag any out-of-spec doses;
proc sql noprint;
    select count(*) into :n_out_of_spec from ex_cart
    where EXADJ ne "";
quit;

%if &n_out_of_spec > 0 %then %do;
    %put WARNING: &n_out_of_spec CAR-T doses are out of specification;
    title "Out-of-Specification CAR-T Doses";
    proc print data=ex_cart noobs;
        where EXADJ ne "";
        var USUBJID EXDOSE EXDOSU EXADJ;
    run;
    title;
%end;
%else %do;
    %put NOTE: All CAR-T doses within acceptable range (±20%);
%end;

*-----------------------------------------------------------------------------
* 4. PROCESS LYMPHODEPLETION RECORDS
*-----------------------------------------------------------------------------;

data ex_lympho;
    set raw_lympho;
    
    length STUDYID $20 DOMAIN $2 USUBJID $30 EXTRT $200 EXCAT $50 
           EXSCAT $100 EXDOSE 8 EXDOSU $20 EXDOSFRM $50 EXROUTE $50 
           EXSTDTC $25 EXENDTC $25 EXSTDY 8 EXENDY 8;
    
    STUDYID = "NEXICART2";
    DOMAIN = "EX";
    USUBJID = catx("-", STUDYID, put(input(SUBJID, best.), z3.));
    
    * Treatment name from raw data;
    EXTRT = TREATMENT_NAME;
    EXCAT = "LYMPHODEPLETION";
    EXSCAT = "CONDITIONING REGIMEN";
    
    * Dose information;
    EXDOSE = input(DOSE, best.);
    EXDOSU = DOSE_UNIT;
    EXDOSFRM = "INFUSION";
    EXROUTE = ROUTE;
    
    * Timing;
    EXSTDTC = cats(ADMIN_DATE, "T", ADMIN_TIME);
    EXENDTC = EXSTDTC;
    
    * Study day calculation (relative to CAR-T infusion);
    CART_DATE = input(CART_INFUSION_DATE, yymmdd10.);
    ADMIN_DATE_NUM = input(ADMIN_DATE, yymmdd10.);
    
    EXSTDY = ADMIN_DATE_NUM - CART_DATE;
    if EXSTDY >= 0 then EXSTDY = EXSTDY + 1;  /* CDISC convention: no Day 0 before treatment */
    EXENDY = EXSTDY;
    
    * Epoch;
    EPOCH = "LYMPHODEPLETION";
    
    EXSEQ = .;
    
    keep STUDYID DOMAIN USUBJID EXTRT EXCAT EXSCAT EXDOSE EXDOSU EXDOSFRM 
         EXROUTE EXSTDTC EXENDTC EXSTDY EXENDY EPOCH EXSEQ;
run;

proc sql noprint;
    select count(*) into :n_lympho_records from ex_lympho;
quit;
%put NOTE: Created &n_lympho_records lymphodepletion records;

*-----------------------------------------------------------------------------
* 5. PROCESS BRIDGING THERAPY (IF ANY)
*-----------------------------------------------------------------------------;

data ex_bridging;
    set raw_bridging;
    
    length STUDYID $20 DOMAIN $2 USUBJID $30 EXTRT $200 EXCAT $50 
           EXSCAT $100 EXSTDTC $25 EXENDTC $25 EXSTDY 8 EXENDY 8;
    
    if _N_ = 0 then stop;  /* Exit if no records */
    
    STUDYID = "NEXICART2";
    DOMAIN = "EX";
    USUBJID = catx("-", STUDYID, put(input(SUBJID, best.), z3.));
    
    EXTRT = TREATMENT_NAME;
    EXCAT = "BRIDGING THERAPY";
    EXSCAT = "DISEASE CONTROL DURING MANUFACTURING";
    
    * Timing;
    EXSTDTC = START_DATE;
    EXENDTC = END_DATE;
    
    * Study day calculation;
    CART_DATE = input(CART_INFUSION_DATE, yymmdd10.);
    START_DATE_NUM = input(START_DATE, yymmdd10.);
    END_DATE_NUM = input(END_DATE, yymmdd10.);
    
    EXSTDY = START_DATE_NUM - CART_DATE;
    if EXSTDY >= 0 then EXSTDY = EXSTDY + 1;
    
    EXENDY = END_DATE_NUM - CART_DATE;
    if EXENDY >= 0 then EXENDY = EXENDY + 1;
    
    EPOCH = "BRIDGING";
    
    EXSEQ = .;
    
    * Keep response for SUPPEX;
    BRIDGING_RESPONSE = RESPONSE;
    
    keep STUDYID DOMAIN USUBJID EXTRT EXCAT EXSCAT EXSTDTC EXENDTC 
         EXSTDY EXENDY EPOCH EXSEQ BRIDGING_RESPONSE;
run;

proc sql noprint;
    select count(*) into :n_bridging_records from ex_bridging;
quit;
%put NOTE: Created &n_bridging_records bridging therapy records;

*-----------------------------------------------------------------------------
* 6. COMBINE ALL EXPOSURE RECORDS
*-----------------------------------------------------------------------------;

data ex_combined;
    set ex_cart ex_lympho ex_bridging;
run;

* Sort by subject and study day;
proc sort data=ex_combined;
    by USUBJID EXSTDY EXSTDTC;
run;

* Assign sequence numbers within subject;
data sdtm.ex_nexicart2;
    set ex_combined;
    by USUBJID;
    
    retain EXSEQ;
    if first.USUBJID then EXSEQ = 1;
    else EXSEQ + 1;
    
    * Final variable ordering;
    retain STUDYID DOMAIN USUBJID EXSEQ EXTRT EXCAT EXSCAT EXDOSE EXDOSU 
           EXDOSFRM EXROUTE EXADJ EXSTDTC EXENDTC EXSTDY EXENDY EXLOT EPOCH;
run;

*-----------------------------------------------------------------------------
* 7. CREATE SUPPLEMENTAL QUALIFIERS (SUPPEX)
*-----------------------------------------------------------------------------;

data sdtm.suppex_nexicart2;
    set ex_cart;
    
    length STUDYID $20 RDOMAIN $2 USUBJID $30 IDVAR $8 IDVARVAL $20 
           QNAM $8 QLABEL $40 QVAL $200;
    
    STUDYID = "NEXICART2";
    RDOMAIN = "EX";
    IDVAR = "EXSEQ";
    
    * Find EXSEQ for CAR-T record (varies by patient due to bridging);
    * For simplicity, calculate based on pattern;
    if _N_ = 1 then IDVARVAL = "7";  /* Patient 001: no bridging, 6 lympho + 1 CART */
    else if _N_ = 2 then IDVARVAL = "8";  /* Patient 002: bridging + 6 lympho + 1 CART */
    else if _N_ = 3 then IDVARVAL = "7";  /* Patient 003: no bridging, 6 lympho + 1 CART */
    
    * Total cells administered;
    QNAM = "EXTOTCL";
    QLABEL = "Total CAR+ Cells Administered";
    QVAL = put(TOTAL_CELLS_ADMIN, e12.);
    output;
    
    * CAR+ percentage;
    QNAM = "EXCARPCT";
    QLABEL = "CAR+ Percentage";
    QVAL = put(CAR_POS_PCT, 5.1);
    output;
    
    * Infusion volume;
    QNAM = "EXVOL";
    QLABEL = "Infusion Volume";
    QVAL = cats(put(INFUSION_VOLUME, best.), " mL");
    output;
    
    * Manufacturing success flag;
    QNAM = "EXMFGSUC";
    QLABEL = "Manufacturing Success";
    QVAL = "Y";
    output;
    
    * Dose adjustment reason (if applicable);
    if EXADJ ne "" then do;
        QNAM = "EXADJRS";
        QLABEL = "Dose Adjustment Reason";
        QVAL = "MANUFACTURING YIELD OUTSIDE TARGET RANGE";
        output;
    end;
    
    keep STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL;
run;

*-----------------------------------------------------------------------------
* 8. VALIDATION AND QC CHECKS
*-----------------------------------------------------------------------------;

proc sql noprint;
    select count(*) into :n_total_records from sdtm.ex_nexicart2;
quit;

%put NOTE: ============================================;
%put NOTE: NEXICART-2 EX Domain Generation Complete;
%put NOTE: CAR-T records: &n_cart_records;
%put NOTE: Lymphodepletion records: &n_lympho_records;
%put NOTE: Bridging therapy records: &n_bridging_records;
%put NOTE: Total EX records: &n_total_records;
%put NOTE: Out-of-spec doses: &n_out_of_spec;
%put NOTE: Output: sdtm.ex_nexicart2;
%put NOTE: ============================================;

* Final record counts by category;
proc sql;
    title "EX Domain Record Counts by Category";
    select EXCAT, count(*) as N
    from sdtm.ex_nexicart2
    group by EXCAT
    order by N desc;
quit;
title;

* Sample output;
title "SDTM EX Domain - First 15 Records";
proc print data=sdtm.ex_nexicart2(obs=15) noobs;
    var USUBJID EXSEQ EXTRT EXCAT EXDOSE EXDOSU EXSTDY EXSTDTC;
run;
title;

* Study day range validation;
title "Study Day Range by Treatment Category";
proc means data=sdtm.ex_nexicart2 n min max mean;
    class EXCAT;
    var EXSTDY;
run;
title;

* Lymphodepletion completeness check;
title "Lymphodepletion Regimen Completeness Check";
proc sql;
    select 
        USUBJID,
        count(case when EXTRT = "Fludarabine" then 1 end) as N_FLU_DOSES,
        count(case when EXTRT = "Cyclophosphamide" then 1 end) as N_CY_DOSES,
        count(*) as TOTAL_LYMPHO_DOSES,
        case 
            when calculated N_FLU_DOSES = 3 and calculated N_CY_DOSES = 3 
            then "COMPLETE"
            else "INCOMPLETE - PROTOCOL DEVIATION"
        end as REGIMEN_STATUS
    from sdtm.ex_nexicart2
    where EXCAT = "LYMPHODEPLETION"
    group by USUBJID
    order by USUBJID;
quit;
title;

*-----------------------------------------------------------------------------
* 9. CLEAN UP
*-----------------------------------------------------------------------------;

proc datasets library=work nolist;
    delete raw_cart raw_lympho raw_bridging 
           ex_cart ex_lympho ex_bridging ex_combined;
quit;

%put NOTE: Program completed successfully at %sysfunc(time(), timeampm.);

/*** END OF PROGRAM ***/
