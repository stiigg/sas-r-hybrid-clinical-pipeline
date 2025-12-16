/* Quality Control Review Listing per CDISC ADRECIST Pattern */

%include "etl/sas/00_setup.sas";

/*******************************************************************
 * PURPOSE: Compare investigator-reported (RS domain) vs.
 *          algorithm-derived (ADRECIST) tumor response assessments
 *******************************************************************/

/* Get algorithm-derived responses from ADRECIST */
data work.alg_resp;
    set adam.adrecist;
    where paramcd in ('TRGRSP','NTRGRSP','OVRLRESP');

    rename avalc=alg_response;
    keep usubjid adt paramcd avalc;
run;

/* Get investigator-reported responses from SDTM RS */
data work.inv_resp;
    set sdtm.rs;

    /* Map RS domain to ADRECIST parameter codes */
    if rstestcd='TRGRESP' then paramcd='TRGRSP';
    else if rstestcd='NTRGRESP' then paramcd='NTRGRSP';
    else if rstestcd='OVRLRESP' then paramcd='OVRLRESP';

    rename rsstresc=inv_response rsdtc=adt;
    keep usubjid rsdtc paramcd rsstresc;
run;

/* Merge and flag discordance */
proc sql;
    create table work.comparison as
    select a.usubjid, a.adt, a.paramcd,
           a.alg_response, i.inv_response,
           case 
               when a.alg_response ne i.inv_response 
               then 'DISCORDANT' 
               else 'CONCORDANT' 
           end as disc_flag
    from work.alg_resp a
    left join work.inv_resp i
    on a.usubjid=i.usubjid 
    and a.adt=i.adt 
    and a.paramcd=i.paramcd;
quit;

/* Add lesion-level detail from TR domain */
proc sql;
    create table work.review_listing as
    select c.*,
           t.tulnkid as lesion_id,
           t.dtype   as lesion_category,
           t.aval    as lesion_value,
           t.trtestcd as lesion_testcd
    from work.comparison c
    left join adam.adtr t
    on c.usubjid=coalescec(t.usubjid, t.subjid)
    and c.adt=t.adt;
quit;

/* Export to Excel with highlighting */
ods excel file="qc/outputs/cl_overall_response_&sysdate9..xlsx"
          options(sheet_name='Discordance Review'
                  frozen_headers='yes'
                  autofilter='all');

proc print data=work.review_listing noobs;
    where disc_flag='DISCORDANT';
    var usubjid adt paramcd alg_response inv_response 
        lesion_id lesion_location lesion_diameter;
    title "RECIST Response Discordance Review - &sysdate9";
    footnote "Algorithm-derived vs. Investigator-reported comparison";
run;

ods excel close;

/* Summary statistics */
proc freq data=work.comparison;
    tables paramcd*disc_flag / nocum nopercent;
    title "Discordance Summary by Parameter";
run;
