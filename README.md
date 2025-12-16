# RECIST 1.1 Implementation in SAS

Working implementation of RECIST 1.1 (Response Evaluation Criteria in Solid Tumors) tumor response derivations in SAS with validated test cases for oncology clinical trials.

## What This Repository Contains

**Working Code:**
- 4 SAS macros implementing RECIST 1.1 target lesion response, overall response, and Best Overall Response
- Functional demo with 3 synthetic test subjects (CR, PR, PD scenarios)
- SDTM-to-ADaM derivation pipeline for tumor response endpoints

**Current Status:** Core RECIST 1.1 implementation complete and tested with basic scenarios. Additional modules (time-to-event, iRECIST) are code-complete but not yet validated with test data.

---

## Quick Start

### Run the Working Demo

```bash
# Clone repository
git clone https://github.com/stiigg/sas-r-hybrid-clinical-pipeline.git
cd sas-r-hybrid-clinical-pipeline/demo

# Run demo (requires SAS 9.4+)
sas simple_recist_demo.sas

# Expected output: 3 subjects with BOR
# - Subject 001-001: PR (Partial Response)
# - Subject 001-002: CR (Complete Response)  
# - Subject 001-003: PD (Progressive Disease)
```

**What the demo validates:**
- Target lesion Sum of Longest Diameters (SLD) calculation
- RECIST 1.1 response thresholds (30% decrease for PR, 20%+5mm increase for PD)
- Best Overall Response with confirmation window logic (28-84 days)
- Nadir tracking and percent change calculations

---

## Repository Structure

```
sas-r-hybrid-clinical-pipeline/
├── demo/                                    # ✅ Working demonstration
│   ├── simple_recist_demo.sas              # Executable demo script
│   ├── data/
│   │   ├── test_sdtm_rs.csv                # 3 test subjects (input)
│   │   └── expected_bor.csv                # Expected results (validation)
│   └── README.md                            # Demo documentation
│
├── etl/adam_program_library/oncology_response/
│   └── recist_11_core/                      # ✅ Core RECIST macros (tested)
│       ├── derive_target_lesion_response.sas
│       ├── derive_non_target_lesion_response.sas
│       ├── derive_overall_timepoint_response.sas
│       └── derive_best_overall_response.sas
│
├── etl/adam_program_library/oncology_response/
│   ├── time_to_event/                       # ⚠️ Code complete, untested
│   ├── advanced_endpoints/                  # ⚠️ Code complete, untested
│   └── immunotherapy/                       # ⚠️ Code complete, untested
│
├── STATUS.md                                # Detailed implementation status
└── README.md                                # This file
```

**Note:** Directories for `validation/`, `qc/`, `automation/`, and `studies/` contain design templates and scaffolding but are not fully functional. See [STATUS.md](STATUS.md) for detailed module-by-module status.

---

## RECIST 1.1 Core Macros

### 1. Target Lesion Response (`derive_target_lesion_response.sas`)

Calculates Sum of Longest Diameters (SLD) and assigns response category at each timepoint.

**Input:** SDTM RS domain  
**Output:** Dataset with SLD, baseline, nadir, percent changes, and response (CR/PR/SD/PD)

**Usage:**
```sas
%include "etl/adam_program_library/oncology_response/recist_11_core/derive_target_lesion_response.sas";

%derive_target_lesion_response(
    inds=sdtm.rs,
    outds=work.adrs_target,
    usubjid_var=USUBJID,
    visit_var=VISIT,
    adt_var=RSDTC,
    ldiam_var=RSSTRESC,
    baseline_flag=ABLFL
);
```

### 2. Overall Timepoint Response (`derive_overall_timepoint_response.sas`)

Combines target lesion, non-target lesion, and new lesion assessments per RECIST 1.1 Table 4.

**Input:** Target response, non-target response, new lesion indicators  
**Output:** Overall response at each timepoint

### 3. Best Overall Response (`derive_best_overall_response.sas`)

Determines Best Overall Response (BOR) with confirmation window logic.

**Confirmation Rules:**
- CR requires confirmation 28-84 days after initial CR
- PR requires confirmation 28-84 days after initial PR
- SD must be maintained ≥42 days from baseline
- PD requires no confirmation

**Usage:**
```sas
%derive_best_overall_response(
    inds=work.adrs_timepoint,
    outds=work.adrs_bor,
    usubjid_var=USUBJID,
    ady_var=RSDY,
    dtc_var=RSDTC,
    ovr_var=OVERALL_RESP,
    conf_win_lo=28,
    conf_win_hi=84,
    sd_min_dur=42
);
```

---

## Test Cases

The demo includes 3 synthetic subjects covering basic RECIST 1.1 scenarios:

| Subject ID | Baseline SLD | Follow-up | Expected BOR | Confirmation |
|------------|--------------|-----------|--------------|--------------|
| 001-001    | 100mm        | 65mm (Day 56), 65mm (Day 84) | PR | Confirmed Day 84 |
| 001-002    | 80mm         | 0mm (Day 70), 0mm (Day 154) | CR | Confirmed Day 154 |
| 001-003    | 120mm        | 120mm (Day 56), 150mm (Day 112) | PD | N/A (no confirmation needed) |

**What's Not Yet Tested:**
- Non-target lesion integration (CR/NON-CR-NON-PD/PD)
- New lesion detection (automatic PD)
- Edge cases (borderline 30%/20% thresholds)
- Unconfirmed responses (PD before confirmation window)
- Complex response sequences (CR→PR→PD)

See [demo/README.md](demo/README.md) for detailed test case descriptions.

---

## Additional Modules (Code-Complete, Needs Testing)

### Time-to-Event Endpoints
- `derive_progression_free_survival.sas` - PFS calculation
- `derive_duration_of_response.sas` - DoR calculation
- `derive_overall_survival.sas` - OS calculation

### Advanced Endpoints
- `derive_objective_response_rate.sas` - ORR with confidence intervals
- `derive_disease_control_rate.sas` - DCR calculation

### Immunotherapy (iRECIST)
- `derive_irecist_response.sas` - iRECIST confirmation logic
- `identify_pseudoprogression.sas` - Pseudoprogression detection

**Status:** These macros exist and are syntactically correct but lack test data and validation. Estimated effort to validate: 15-25 hours.

---

## What This Repository Is NOT

To be completely transparent:

❌ **Not production-ready** - Requires expanded test coverage, formal validation, and QC automation  
❌ **Not a complete pipeline** - Multi-study orchestration, automation, and Shiny dashboard are design concepts only  
❌ **Not comprehensively tested** - Only 3 basic test subjects; need 20-25 covering edge cases  
❌ **Not validated per regulatory standards** - No IQ/OQ/PQ documentation executed

**Purpose:** This is a code demonstration showcasing RECIST 1.1 implementation expertise, suitable for portfolio/interview purposes. Production deployment would require 40-60 hours of additional testing and validation work.

---

## RECIST 1.1 Reference

### Response Criteria

| Response | Target Lesion Criteria |
|----------|------------------------|
| **CR** (Complete Response) | All target lesions disappeared (SLD = 0) |
| **PR** (Partial Response) | ≥30% decrease in SLD from baseline |
| **PD** (Progressive Disease) | ≥20% increase AND ≥5mm absolute increase from nadir |
| **SD** (Stable Disease) | Neither PR nor PD criteria met |

### RECIST 1.1 Table 4: Overall Response

| Target | Non-Target | New Lesions | Overall |
|--------|------------|-------------|---------|
| CR | CR | No | CR |
| CR | Non-CR/Non-PD | No | PR |
| PR | Non-PD or not evaluated | No | PR |
| SD | Non-PD or not evaluated | No | SD |
| Any | Any | Yes | PD |
| PD | Any | Any | PD |

**Reference:** Eisenhauer EA, et al. New response evaluation criteria in solid tumours: Revised RECIST guideline (version 1.1). *Eur J Cancer*. 2009;45(2):228-247. [PubMed](https://pubmed.ncbi.nlm.nih.gov/19097774/)

---

## CDISC Standards

This implementation follows:
- **SDTM Implementation Guide** v3.4 (RS domain for tumor response)
- **ADaM Implementation Guide** v1.3 (BDS structure for ADRS)
- **RECIST 1.1** per Eisenhauer et al., 2009

---

## Detailed Status Documentation

For complete module-by-module implementation status, testing coverage, known gaps, and development roadmap, see:

**[STATUS.md](STATUS.md)** - Detailed implementation tracker with:
- Completion status for all 11 macro files
- Test coverage matrix
- Required work for production readiness (estimated 40-60 hours)
- Priority action items and timeline

---

## Running Tests (When Available)

```bash
# Planned testing framework (not yet implemented)
Rscript tests/testthat.R
Rscript -e "testthat::test_file('tests/testthat/test-recist-derivations.R')"
```

**Current Testing Status:** Manual validation only via `demo/simple_recist_demo.sas`. Automated unit testing planned but not implemented. See STATUS.md for testing roadmap.

---

## Prerequisites

- SAS 9.4 or later
- Basic familiarity with CDISC SDTM (particularly RS domain)
- Understanding of oncology clinical trial endpoints

**Optional (for R-based modules):**
- R >= 4.2
- pharmaverse packages: `admiral`, `pharmaversesdtm`, `metacore`

---

## License

MIT License - See LICENSE file

---

## About

This repository demonstrates implementation knowledge of oncology clinical trial programming standards, CDISC data models, and RECIST 1.1 tumor response criteria. Created as portfolio work by Christian Baghai.

**Contact:**  
- GitHub: [@stiigg](https://github.com/stiigg)
- Repository: [github.com/stiigg/sas-r-hybrid-clinical-pipeline](https://github.com/stiigg/sas-r-hybrid-clinical-pipeline)

For questions about RECIST implementation methodology or clinical programming approaches, feel free to open an issue.

---

**Last Updated:** December 16, 2024  
**Repository Status:** Core RECIST 1.1 implementation functional with basic demo | Additional modules code-complete but untested
