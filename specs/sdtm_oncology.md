# SDTM Oncology Domains

Adds CDISC oncology tumor domains for RECIST/iRECIST workflows.

- **TU**: Tumor Identification. Includes `TULNKID`, lesion location, evaluation type (`TUEVAL`), and modality.
- **TR**: Tumor Results. Stores longitudinal lesion measurements (`TRSTRESN`) with `TULNKID` linkages and new lesion indicators.
- **DS**: Disposition. Used for death events that feed ADTTE derivations.

The SAS ETL program `etl/sas/sdtm_tu_tr.sas` reads raw imaging extracts and enforces RECIST limits (≤5 target lesions per organ).
