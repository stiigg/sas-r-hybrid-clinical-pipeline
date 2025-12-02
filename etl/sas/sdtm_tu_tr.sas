%include "etl/sas/00_setup.sas";

/* sdtm_tu_tr.sas: map raw imaging data into oncology SDTM TU/TR domains */

%logmsg(Starting oncology SDTM derivations for TU/TR);

/* Example import assumes RAW.TUMOR_ASSESS exists; adjust as needed for study data */
proc sort data=raw.tumor_assess out=work.tumor_assess;
  by subjid visitnum organ tuspid;
run;

/* Tumor Identification (TU) */
data sdtm.tu;
  set work.tumor_assess;
  by subjid visitnum organ;
  length domain $2 tulnkid $40 tutestcd $8 tuorres $200 tumethod $30;

  domain = 'TU';
  tulnkid = compress(subjid || '_' || tuspid);
  tutestcd = 'TUMIDENT';
  tuorres = lesion_location;
  tumethod = coalescec(scan(imaging_modality, 1), 'CT SCAN');

  /* Validation: RECIST 1.1 allows a max of 5 target lesions per organ */
  if first.organ then organ_count = 0;
  organ_count + 1;
  if tueval = 'TARGET' and organ_count > 5 then do;
    put 'ERROR: Exceeded 5 target lesions for ' subjid= organ=;
    _error_ = 1;
  end;
run;

/* Tumor Results (TR) */
data sdtm.tr;
  set work.tumor_assess;
  by subjid visitnum organ;
  length domain $2 trtestcd $8 trscat $20;

  domain = 'TR';
  tulnkid = compress(subjid || '_' || tuspid);
  trtestcd = 'LDIAM';
  trscat = coalescec(tueval, 'NOT ASSIGNED');
  trstresn = longest_diam_mm;
  trstdtc = put(assess_dt, yymmdd10.);

  /* Capture non-target and new lesion flags */
  if tueval = 'NON-TARGET' then dtype = 'NON-TARGET';
  else if new_lesion_flag = 'Y' then dtype = 'NEW';
  else dtype = 'TARGET';
run;

%logmsg(Completed oncology SDTM TU/TR derivations);
