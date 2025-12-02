%include "etl/sas/00_setup.sas";

/* adam_adeffsum.sas: derive Best Overall Response (BOR) with confirmation */

%logmsg(Building ADEFFSUM dataset);

proc sql;
  create table adam.adeffsum as
  select subjid,
         usubjid,
         case
           when max(case when avalc='CR' and cnfrm='Y' then 1 else 0 end)=1 then 'CR'
           when max(case when avalc='PR' and cnfrm='Y' then 1 else 0 end)=1 then 'PR'
           when max(case when avalc='PD' then 1 else 0 end)=1 then 'PD'
           when max(case when avalc='SD' and intck('day', min(adt), max(adt)) >= 42 then 1 else 0 end)=1 then 'SD'
           else 'NE'
         end as bor length=2
  from adam.adrs
  group by subjid, usubjid;
quit;

%logmsg(Completed ADEFFSUM derivation);
