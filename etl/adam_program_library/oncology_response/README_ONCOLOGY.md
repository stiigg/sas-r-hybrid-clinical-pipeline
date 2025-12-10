# Oncology Response Programming Library

## Overview

This module provides a comprehensive, production-ready SAS macro library for oncology clinical trial programming. It implements RECIST 1.1 criteria, iRECIST (immune-modified RECIST) for immunotherapy trials, and standard time-to-event endpoint derivations compliant with CDISC ADaM standards.

## Features

✅ **Full RECIST 1.1 Implementation** with regulatory traceability  
✅ **Time-to-Event Endpoints** (PFS, OS, DOR) for ADTTE datasets  
✅ **Advanced Efficacy Endpoints** (ORR, DCR) with exact confidence intervals  
✅ **iRECIST Support** for immunotherapy trials with pseudoprogression detection  
✅ **Comprehensive Documentation** with literature references and usage examples  
✅ **Quality Control Procedures** embedded in all macros  

---

## Library Structure

### 1. Core RECIST 1.1 (`recist_11_core/`)

Implements Response Evaluation Criteria in Solid Tumors version 1.1 per Eisenhauer et al. (2009).

#### `derive_target_lesion_response.sas`
- Derives target lesion response (CR/PR/SD/PD) at each timepoint
- Implements 30% threshold for PR, 20%+5mm rule for PD
- Tracks nadir (running minimum SLD) for progression assessment
- **Key outputs**: `TL_RESP`, `TL_PCHG`, `NADIR_SLD`

#### `derive_non_target_lesion_response.sas`
- Qualitative assessment of non-target lesions
- Maps assessments to CR/NON-CR/NON-PD/PD per RECIST 1.1
- **Key outputs**: `NTL_RESP`, `NTL_RESP_REASON`

#### `derive_overall_timepoint_response.sas`
- Integrates target, non-target, and new lesion assessments
- Applies RECIST 1.1 Table 4 response matrix logic
- Handles all edge cases and missing data scenarios
- **Key outputs**: `OVR_RESP`, `OVR_RESP_LOGIC`

#### `derive_best_overall_response.sas`
- Derives subject-level Best Overall Response (BOR)
- Implements confirmation logic for CR/PR (default: 28-84 day window)
- Applies minimum SD duration rule (default: 42 days)
- Excludes post-new-therapy assessments
- **Key outputs**: `BOR`, `BORDT`, `BORCONF`

**Reference**: Eisenhauer EA, et al. *Eur J Cancer.* 2009;45(2):228-247. PMID: 19097774

---

### 2. Time-to-Event Endpoints (`time_to_event/`)

ADTTE-style endpoint derivations following CDISC BDS Time-to-Event guidance.

#### `derive_progression_free_survival.sas`
- Derives Progression-Free Survival (PFS)
- **Event**: First PD or death from any cause
- **Censoring**: Last adequate tumor assessment without PD
- **Key outputs**: `PARAMCD='PFS'`, `CNSR`, `AVAL`, `EVNTDT`, `EVNTDESC`

#### `derive_duration_of_response.sas`
- Derives Duration of Response (DOR) for responders only
- **Start**: Date of first CR/PR
- **Event**: First PD or death
- **Censoring**: Last adequate assessment without PD
- **Population**: Subjects with BOR = CR or PR
- **Key outputs**: `PARAMCD='DOR'`, `STARTDT`, `AVAL`

#### `derive_overall_survival.sas`
- Derives Overall Survival (OS)
- **Start**: Randomization or treatment start date
- **Event**: Death from any cause
- **Censoring**: Last known alive date
- **Key outputs**: `PARAMCD='OS'`, `CNSR`, `AVAL`

**Reference**: CDISC ADaM Basic Data Structure for Time-to-Event Analyses v1.1

---

### 3. Advanced Endpoints (`advanced_endpoints/`)

Summary endpoints for efficacy analysis and regulatory submission.

#### `derive_objective_response_rate.sas`
- Calculates Objective Response Rate (ORR)
- **Definition**: Proportion of subjects with BOR = CR or PR
- Provides exact 95% confidence intervals (Clopper-Pearson)
- **Key outputs**: `N_RESP`, `ORR`, `ORR_PCT`, `ORR_LCL`, `ORR_UCL`

#### `derive_disease_control_rate.sas`
- Calculates Disease Control Rate (DCR)
- **Definition**: Proportion with BOR = CR, PR, or SD
- Includes exact confidence intervals
- **Key outputs**: `N_DC`, `DCR`, `DCR_PCT`, `DCR_LCL`, `DCR_UCL`

---

### 4. Immunotherapy-Specific (`immunotherapy/`)

Support for immune checkpoint inhibitor trials with atypical response patterns.

#### `derive_irecist_response.sas`
- Implements iRECIST (immune-modified RECIST) criteria
- Detects iUPD (immune Unconfirmed PD) requiring confirmation
- Derives iCPD (immune Confirmed PD) per 4-week confirmation rule
- Handles pseudoprogression scenarios
- **Key outputs**: `IRECIST_RESP`, `PSEUDO_PROG_FL`, `CONF_REQUIRED_FL`

#### `identify_pseudoprogression.sas`
- Identifies pseudoprogression patterns (initial PD → subsequent improvement)
- Flags subjects with atypical immunotherapy response kinetics
- Excludes cases with intervening new anti-cancer therapy
- **Key outputs**: `PSEUDO_PROG_FL`, `PSEUDO_PROG_TYPE`, `PSEUDO_PROG_DESC`

**Reference**: Seymour L, et al. *Lancet Oncol.* 2017;18(3):e143-e152. PMID: 28271869

---

## Usage Examples

### Example 1: Derive Overall Response at Each Timepoint

```sas
/* Step 1: Target lesion response */
%derive_target_lesion_response(
    inds=adtr_sld,
    outds=adtr_tl_resp,
    sld_param=SLDINV
);

/* Step 2: Non-target lesion response */
%derive_non_target_lesion_response(
    inds=adtr_ntl,
    outds=adtr_ntl_resp,
    ntl_assess_var=NTRGRESP
);

/* Step 3: Overall response integration */
%derive_overall_timepoint_response(
    tl_ds=adtr_tl_resp,
    ntl_ds=adtr_ntl_resp,
    nl_ds=adtr_new_lesions,
    outds=adrs_timepoint
);
```

### Example 2: Derive Best Overall Response

```sas
%derive_best_overall_response(
    inds=adrs_timepoint,
    outds=adrs_bor,
    conf_win_lo=28,   /* Min days for CR/PR confirmation */
    conf_win_hi=84,   /* Max days for CR/PR confirmation */
    sd_min_dur=42     /* Min SD duration from baseline */
);
```

### Example 3: Derive PFS Endpoint

```sas
%derive_progression_free_survival(
    adsl=adsl,
    adrs=adrs_timepoint,
    outds=adtte_pfs,
    randdt_var=RANDDT,
    dthdt_var=DTHDT
);
```

### Example 4: Calculate ORR and DCR

```sas
/* Objective Response Rate */
%derive_objective_response_rate(
    inds=adrs_bor,
    outds=summary_orr,
    by_vars=TRT01P  /* By treatment arm */
);

/* Disease Control Rate */
%derive_disease_control_rate(
    inds=adrs_bor,
    outds=summary_dcr,
    by_vars=TRT01P
);
```

### Example 5: iRECIST for Immunotherapy Trial

```sas
/* Derive iRECIST responses */
%derive_irecist_response(
    inds=adrs_timepoint,
    outds=adrs_irecist,
    recist_resp_var=OVR_RESP,
    confirm_win_min=28,
    confirm_win_max=56
);

/* Identify pseudoprogression */
%identify_pseudoprogression(
    inds=adrs_irecist,
    outds=adrs_pseudo,
    resp_var=IRECIST_RESP,
    min_interval=28
);
```

---

## Macro Parameter Conventions

All macros follow consistent naming conventions:

- `inds` / `outds`: Input and output datasets
- `usubjid_var`: Subject identifier (default: `USUBJID`)
- `adt_var`: Assessment date (default: `ADT`)
- `aval_var`: Analysis value (default: `AVAL`)
- `by_vars`: Optional BY variables for stratified analyses

---

## Quality Control Features

Each macro includes:

1. **Parameter validation** with informative error messages
2. **Embedded QC procedures** (`PROC FREQ`, `PROC MEANS`) for result verification
3. **Derivation logic variables** explaining why each response was assigned
4. **Comprehensive labeling** for all derived variables
5. **Automatic cleanup** of temporary datasets

---

## CDISC Compliance

- **ADaM IG v1.3** compliant variable naming and structure
- **SDTM IG v3.4** compatible with RS (Disease Response) domain
- **Controlled Terminology** aligned with NCI Thesaurus
- **Define-XML ready** with complete variable metadata

---

## References

1. Eisenhauer EA, Therasse P, Bogaerts J, et al. New response evaluation criteria in solid tumours: Revised RECIST guideline (version 1.1). *Eur J Cancer.* 2009;45(2):228-247. [PMID: 19097774](https://pubmed.ncbi.nlm.nih.gov/19097774/)

2. Seymour L, Bogaerts J, Perrone A, et al. iRECIST: guidelines for response criteria for use in trials testing immunotherapeutics. *Lancet Oncol.* 2017;18(3):e143-e152. [PMID: 28271869](https://pubmed.ncbi.nlm.nih.gov/28271869/)

3. CDISC Analysis Data Model (ADaM) v1.3. https://www.cdisc.org/standards/foundational/adam

4. CDISC ADaM Basic Data Structure for Time-to-Event Analyses v1.1. https://www.cdisc.org/standards/foundational/adam

---

## Future Enhancements

Planned additions:
- Time to Response (TTR) derivation
- Time to Progression (TTP) derivation
- Clinical Benefit Rate (CBR) calculation
- Depth of Response analysis
- Waterfall plot data preparation
- Swimmer plot data preparation
- Complete ADRS/ADTTE dataset templates

---

## Author

Christian Baghai  
Clinical Statistical Programmer  
December 2025

---

## License

MIT License - See repository root for details
