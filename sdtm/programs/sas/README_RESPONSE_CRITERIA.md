# SDTM Response Assessment Programs

## Overview
This directory contains disease-specific programs for deriving SDTM RS (Disease Response) domain data according to validated response criteria frameworks. Each program implements current best-practice guidelines with evidence-based enhancements published in 2024-2025.

## Program Selection Guide

| Indication | Program | Criteria | Key Endpoints | Evidence |
|------------|---------|----------|---------------|----------|
| **Solid Tumors** | `54a_sdtm_rs_recist.sas` | RECIST 1.1 (2009) + Enaworu 25mm nadir rule (2025) | Target lesion SLD, Overall response (CR/PR/SD/PD) | Eisenhauer 2009, Enaworu 2025 |
| **Multiple Myeloma** | `54b_sdtm_rs_myeloma.sas` | IMWG 2025 (sCR/MR removed, MRD emphasis) | M-protein, FLC, Bone marrow, MS-MRD at 10⁻⁵/10⁻⁶ | IMWG 2025, Kubicki 2025, ASH 2025 |
| **AL Amyloidosis** | `54c_sdtm_rs_amyloidosis.sas` | Palladini 2012 + FDA-qualified biomarkers | dFLC, NT-proBNP (>30%+>300 ng/L), Proteinuria | Palladini 2012, Merlini 2016, FDA 2016 |

## Quick Start

### Master Wrapper Macro
```sas
/* Load master wrapper */
%include "54_sdtm_rs_master.sas";

/* For solid tumor trials */
%derive_response_domain(indication=SOLID_TUMOR);

/* For myeloma CAR-T trials */
%derive_response_domain(indication=MULTIPLE_MYELOMA);

/* For AL amyloidosis trials */
%derive_response_domain(indication=AL_AMYLOIDOSIS);
```

### Direct Program Inclusion
```sas
/* Alternative: Call programs directly */
libname sdtm "../../data/csv";

/* RECIST 1.1 for solid tumors */
%include "54a_sdtm_rs_recist.sas";

/* IMWG 2025 for multiple myeloma */
%include "54b_sdtm_rs_myeloma.sas";

/* Palladini 2012 for AL amyloidosis */
%include "54c_sdtm_rs_amyloidosis.sas";
```

## Evidence Base

### RECIST 1.1 (Solid Tumors)

#### Primary References
- **Eisenhauer EA, et al.** "New response evaluation criteria in solid tumours: Revised RECIST guideline (version 1.1)." *European Journal of Cancer* 2009;45(2):228-247
  - Established 20% + 5mm PD threshold for target lesions
  - 5 target lesions maximum (2 per organ)
  - Lymph node measurement criteria (short axis ≥10mm)

#### 2025 Enhancement
- **Enaworu O, et al.** "An Innovative Approach to Target Lesion Progression in RECIST 1.1: The Enaworu 25 mm Nadir Rule." *Cureus* 2025 (published April 20, 2025)
  - **Validation**: 1,000-patient simulation showing identical classification outcomes
  - **Simplified Rule**:
    - Nadir <25mm → 5mm absolute increase = PD
    - Nadir ≥25mm → Standard 20% + 5mm = PD
  - **Impact**: Maintains diagnostic accuracy while reducing administrative burden
  - **DOI**: 10.7759/cureus.87362

#### Supporting Evidence
- **Automated RECIST Validation** (Cancers, November 2024): CNN-based reliability scoring for measurement QC
- **iRECIST for Immunotherapy** (Seminars in Oncology, October 2024): 15% pseudoprogression rate, confirmation logic

### IMWG 2025 (Multiple Myeloma)

#### September 2025 Update
- **Source**: IMWG Annual Summit 2025, International Myeloma Society Meeting
- **Major Changes**:
  - **REMOVED**: Stringent Complete Response (sCR) category
  - **REMOVED**: Minor Response (MR) category
  - **SIMPLIFIED**: CR/VGPR/PR/SD/PD classification
  - **ENHANCED**: MRD emphasis with mass spectrometry at 10⁻⁵ and 10⁻⁶ sensitivity

#### Response Criteria (2025)
| Category | Definition |
|----------|------------|
| **CR** | Negative immunofixation, normal FLC ratio (0.26-1.65), <5% plasma cells in bone marrow |
| **VGPR** | ≥90% reduction in M-protein |
| **PR** | ≥50% reduction in M-protein |
| **SD** | Does not meet CR, VGPR, PR, or PD criteria |
| **PD** | ≥25% increase from nadir AND ≥0.5 g/dL absolute increase, OR new extramedullary disease |

#### MRD Assessment (2025)
- **Kubicki T, et al.** "Minimal residual disease measurement in blood by mass spectrometry identifies long-term responders in multiple myeloma." *Blood Neoplasia* May 2025
  - Blood-based MS-MRD validation (>3,000 samples)
  - 10⁻⁶ sensitivity threshold for ultra-sensitive detection
  - Less invasive alternative to bone marrow aspiration

- **ASH 2025 Abstracts** (November 2025):
  - GMMG-HD7 trial: MALDI-TOF mass spectrometry
  - Clonotypic peptide tracking (EasyM platform)
  - Sustained MRD negativity (≥12 months) as prognostic marker

#### CAR-T Specific
- **Day 28 Primary Response**: Assessment window Day 21-35 post-infusion
- **Lymphodepletion Baseline**: Pre-CAR-T nadir reference

### Palladini 2012 (AL Amyloidosis)

#### Hematologic Response
- **Palladini G, et al.** "New criteria for response to treatment in immunoglobulin light chain amyloidosis based on free light chain measurement and cardiac biomarkers." *Leukemia* 2012;26(10):2200-2214
  - **Complete Response**: Normal FLC ratio (0.26-1.65) + negative immunofixation
  - **Partial Response**: ≥50% reduction in dFLC
  - **dFLC**: Difference between involved and uninvolved free light chains

#### FDA-Qualified Cardiac Biomarker
- **Merlini G, et al.** "Rationale, application and clinical qualification for NT-proBNP as a surrogate endpoint for survival in AL amyloidosis." *Leukemia* 2016;30(10):1979-1986
  - **FDA-Qualified Response**: BOTH >30% decrease AND >300 ng/L absolute decrease
  - **Evaluability Threshold**: Baseline NT-proBNP ≥650 ng/L
  - **Validation**: Consistent predictive value across multiple intervention trials
  - **Mechanism**: Direct regulation by cardiac LC signaling (MAPK activation)

- **FDA Guidance** (December 2016): "AL Amyloidosis: Developing Drugs for Treatment"
  - Composite endpoint structure (hematologic + organ response)
  - NT-proBNP as surrogate biomarker for cardiac survival
  - Proteinuria evaluability: ≥0.5 g/24h at baseline

#### Renal Response
- **Criteria**: ≥30% proteinuria decrease WITHOUT ≥25% eGFR worsening
- **Evaluability**: Baseline proteinuria ≥0.5 g/24h per FDA guidance

#### Composite Multi-Domain Endpoint
| Composite Category | Definition |
|-------------------|------------|
| **Composite CR** | Hematologic CR + any organ response (cardiac or renal) |
| **Composite PR** | Hematologic PR + any organ response (cardiac or renal) |
| **Hematologic Only** | Hematologic response without organ response |
| **No Response** | No hematologic or organ response |

## Data Sources by Indication

### RECIST (Solid Tumors)
**Input Domains**: 
- `TU` (Tumor Identification) - Target lesion identification and location
- `TR` (Tumor Results) - Lesion measurements at each assessment

**Derived Logic**:
1. Calculate Sum of Longest Diameters (SLD) for target lesions
2. Identify baseline SLD (first assessment)
3. Track nadir SLD (minimum post-baseline)
4. Apply RECIST 1.1 thresholds:
   - CR: All target lesions disappear
   - PR: ≥30% decrease from baseline
   - PD: Enaworu 25mm rule (nadir <25mm: +5mm absolute; nadir ≥25mm: +20% + 5mm)
   - SD: Does not meet CR/PR/PD
5. Integrate non-target lesions and new lesions
6. Derive overall response

**QC Checks**:
- Implausible SLD increases (>50% single-visit change)
- Prolonged stable disease (≥6 months)
- Measurement consistency validation

### IMWG (Multiple Myeloma)
**Input Domains**:
- `LB` (Laboratory) - M-protein (SPEP), FLC (kappa/lambda), immunofixation, MRD assays
- `MB` (Microbiology/Bone Marrow) - Plasma cell percentage
- `TR` (Tumor Results) - Extramedullary disease measurements (if applicable)
- `EX` (Exposure) - CAR-T infusion date for Day 28 flagging

**Derived Logic**:
1. Extract M-protein and FLC measurements
2. Calculate baseline and nadir M-protein
3. Apply IMWG 2025 thresholds:
   - VGPR: ≥90% M-protein reduction
   - PR: ≥50% M-protein reduction
   - PD: ≥25% increase from nadir + ≥0.5 g/dL absolute
4. Integrate immunofixation for CR determination
5. Confirm CR with bone marrow (<5% plasma cells)
6. Check for new extramedullary disease (overrides lab response)
7. Flag MRD status (10⁻⁵ and 10⁻⁶ thresholds)
8. Identify Day 28 post-CAR-T primary assessment window

**SUPPRS Variables**:
- `MRD`: MRD status (MRD_NEG_10E5, MRD_NEG_10E6, MRD_POS)
- `MRDMETH`: MRD assessment method (MRDFLOW, MRDNGS, MSMRD)
- `SUSTMRD`: Sustained MRD negativity (≥12 months)
- `DAY28`: Day 28 primary response flag (Y/N)
- `CARTDAYS`: Days from CAR-T infusion

### Palladini (AL Amyloidosis)
**Input Domains**:
- `LB` (Laboratory) - FLC (kappa/lambda/ratio), immunofixation, NT-proBNP, proteinuria (24h), eGFR

**Derived Logic**:
1. Calculate dFLC (involved - uninvolved FLC)
2. Derive hematologic response:
   - CR: Normal FLC ratio (0.26-1.65) + negative immunofixation
   - PR: ≥50% dFLC reduction
3. Derive cardiac response (NT-proBNP):
   - Evaluable: Baseline ≥650 ng/L
   - Response: >30% decrease AND >300 ng/L absolute decrease
4. Derive renal response (proteinuria):
   - Evaluable: Baseline ≥0.5 g/24h
   - Response: ≥30% proteinuria decrease WITHOUT ≥25% eGFR worsening
5. Create **separate RS records** for each domain:
   - Record 1: Hematologic response (RSTESTCD=HEMAT)
   - Record 2: Cardiac response (RSTESTCD=CARDIAC)
   - Record 3: Renal response (RSTESTCD=RENAL)
   - Record 4: Composite multi-domain response (RSTESTCD=COMPOSITE)

**SUPPRS Variables**:
- `CARDEVAL`: Cardiac evaluability flag (Y/N)
- `CARDREASON`: Reason for non-evaluability (e.g., "Baseline NT-proBNP <650 ng/L")
- `CARDTHRS`: FDA threshold description
- `CARDMAG`: Response magnitude for responders (e.g., "45% decrease, 500 ng/L decrease")
- `RENALEVAL`: Renal evaluability flag (Y/N)
- `RENREASON`: Reason for non-evaluability
- `RENALQC`: eGFR decline QC flag (if eGFR decreases >15%)

## CDISC Compliance

### Standards Conformance
All programs conform to:
- **SDTMIG v3.3** (CDISC 2024) - Standard implementation guide
- **CDISC CT 2025-09-26** (Controlled Terminology) - Latest codelist version
- **CDISC Oncology SDS** (June 2024) - Disease Response Supplement

### RS Domain Structure
```sas
data rs;
    length STUDYID $20 DOMAIN $2 USUBJID $40;
    length RSSEQ 8 RSTESTCD $8 RSTEST $40 RSCAT $100;
    length RSORRES $200 RSSTRESC $8 RSEVAL $40;
    length RSDTC $20 VISIT $40 VISITNUM 8 EPOCH $40;
    
    /* Core variables */
    STUDYID = "STUDY-001";  /* Trial identifier */
    DOMAIN = "RS";          /* Disease Response domain */
    USUBJID = "001-001";    /* Unique subject ID */
    RSSEQ = 1;              /* Sequence number */
    
    /* Test identification */
    RSTESTCD = "RECIST";           /* Response test code */
    RSTEST = "RECIST 1.1 Response";  /* Response test name */
    RSCAT = "RECIST 1.1 2009";     /* Response criteria category */
    
    /* Response result */
    RSORRES = "Partial Response";  /* Original result */
    RSSTRESC = "PR";               /* Standardized result */
    
    /* Evaluator and timing */
    RSEVAL = "INVESTIGATOR";  /* Evaluator (or IRC, COPILOT) */
    RSDTC = "2026-01-15";     /* Assessment date (ISO 8601) */
    
    /* Visit context */
    VISIT = "Week 12";        /* Visit name */
    VISITNUM = 4;             /* Visit number */
    EPOCH = "TREATMENT";      /* Study epoch */
run;
```

### Controlled Terminology
| Variable | Valid Values | Codelist |
|----------|--------------|----------|
| `RSTESTCD` | RECIST, IMWGRESP, HEMAT, CARDIAC, RENAL, COMPOSITE | C117754 |
| `RSSTRESC` (RECIST) | CR, PR, SD, PD, NE | C117755 |
| `RSSTRESC` (IMWG) | CR, VGPR, PR, SD, PD, NE | C117756 |
| `RSSTRESC` (Amyloid) | HEMAT_CR, HEMAT_PR, CARDIAC_RESPONSE, RENAL_RESPONSE, COMPOSITE_CR, etc. | Custom |
| `RSEVAL` | INVESTIGATOR, INDEPENDENT ASSESSOR, IRC | C82556 |

## Quality Control

### Automated QC Checks

#### RECIST Programs
- **Implausible SLD increases**: >50% increase in single visit
- **Prolonged stable disease**: SD duration ≥6 months (consider volumetric RECIST)
- **Measurement reliability**: Flag lesions with high variability
- **Baseline lesion selection**: Max 5 target lesions (2 per organ)
- **Lymph node criteria**: Short axis ≥10mm for target nodes

#### IMWG Programs
- **Missing MRD data**: Flag patients without MRD assessment
- **Discordant responses**: M-protein vs. bone marrow disagreement
- **Extramedullary disease**: Override lab response if new EMD detected
- **CAR-T timing**: Verify Day 28 window (Day 21-35)
- **Sustained MRD**: Validate ≥12-month negativity duration

#### Palladini Programs
- **Evaluability flags**: NT-proBNP <650 ng/L, proteinuria <0.5 g/24h
- **Unit standardization**: Convert NT-proBNP to ng/L
- **eGFR safety**: Flag renal responders with >15% eGFR decline
- **dFLC calculation**: Validate involved/uninvolved chain determination
- **Composite logic**: Ensure hematologic response precedes organ response

### Validation Checklist
Before production use:
- [ ] Verify indication matches protocol disease area
- [ ] Confirm input domains exist (TU/TR, LB/MB)
- [ ] Check controlled terminology compliance (CDISC CT 2025-09-26)
- [ ] Review QC flags in program output
- [ ] Validate response distribution against expected rates
- [ ] Ensure visit windows align with protocol schedule
- [ ] For CAR-T trials: Verify infusion date in EX domain
- [ ] For amyloidosis: Confirm NT-proBNP units (ng/L)
- [ ] For RECIST: Verify baseline lesion selection
- [ ] Run Pinnacle 21 validation checks
- [ ] Compare with previous SDTM releases (if applicable)

## Version History

### v2.0 (2026-01-02) - Multi-Indication Expansion
**NEW PROGRAMS**:
- `54b_sdtm_rs_myeloma.sas` - IMWG 2025 criteria for multiple myeloma
- `54c_sdtm_rs_amyloidosis.sas` - Palladini 2012 + FDA criteria for AL amyloidosis
- `54_sdtm_rs_master.sas` - Master wrapper macro for indication routing

**ENHANCEMENTS**:
- Added Enaworu 25mm nadir rule to RECIST program (54a)
- Automated measurement reliability QC flags (RECIST)
- Mass spectrometry MRD at 10⁻⁵ and 10⁻⁶ sensitivity (IMWG)
- CAR-T Day 28 primary response assessment window (IMWG)
- FDA-qualified NT-proBNP cardiac endpoint (Palladini)
- Multi-domain composite response structure (Palladini)

**EVIDENCE BASE**:
- Enaworu O, et al. Cureus 2025 (RECIST enhancement)
- IMWG Annual Summit 2025 (sCR/MR removal)
- Kubicki T, et al. Blood Neoplasia 2025 (MS-MRD validation)
- ASH 2025 abstracts (10⁻⁶ MRD threshold)
- FDA Guidance December 2016 (NT-proBNP qualification)

### v1.0 (2025-12-24) - Initial RECIST Implementation
- `54_sdtm_rs.sas` (renamed to `54a_sdtm_rs_recist.sas` in v2.0)
- RECIST 1.1 (2009) baseline implementation
- Target lesion SLD calculation
- Overall response derivation (CR/PR/SD/PD)
- Basic QC checks

## Contact & Support

### Questions on Response Criteria Selection
For clinical questions about which criteria framework to use:
- Consult protocol indication and primary endpoint definition
- Review study statistician's Statistical Analysis Plan (SAP)
- Confirm with medical monitor for hematologic malignancies

### SDTM Implementation Questions
For technical questions about SDTM RS domain structure:
- Review SDTMIG v3.3 Section 6.3.4 (Disease Response)
- Consult CDISC Oncology SDS (June 2024)
- Check CDISC Controlled Terminology browser

### Programming Support
For questions about SAS code implementation:
- Christian Baghai (clinical statistical programmer)
- GitHub repository: https://github.com/stiigg/sas-r-hybrid-clinical-pipeline

## References

### RECIST 1.1
1. Eisenhauer EA, et al. New response evaluation criteria in solid tumours: Revised RECIST guideline (version 1.1). *Eur J Cancer* 2009;45(2):228-247.
2. Enaworu O, et al. An Innovative Approach to Target Lesion Progression in RECIST 1.1: The Enaworu 25 mm Nadir Rule. *Cureus* 2025. DOI: 10.7759/cureus.87362
3. Seymour L, et al. iRECIST: guidelines for response criteria for use in trials testing immunotherapeutics. *Lancet Oncol* 2017;18(3):e143-e152.

### IMWG (Multiple Myeloma)
4. Kumar S, et al. International Myeloma Working Group consensus criteria for response and minimal residual disease assessment in multiple myeloma. *Lancet Oncol* 2016;17(8):e328-e346.
5. IMWG Annual Summit 2025. Updated uniform response criteria (September 2025).
6. Kubicki T, et al. Minimal residual disease measurement in blood by mass spectrometry identifies long-term responders in multiple myeloma. *Blood Neoplasia* 2025.

### Palladini (AL Amyloidosis)
7. Palladini G, et al. New criteria for response to treatment in immunoglobulin light chain amyloidosis. *Leukemia* 2012;26(10):2200-2214.
8. Merlini G, et al. Rationale, application and clinical qualification for NT-proBNP as a surrogate endpoint for survival in AL amyloidosis. *Leukemia* 2016;30(10):1979-1986.
9. FDA. AL Amyloidosis: Developing Drugs for Treatment - Guidance for Industry. December 2016.

### CDISC Standards
10. CDISC. Study Data Tabulation Model Implementation Guide (SDTMIG) v3.3. 2024.
11. CDISC. Controlled Terminology (CT) Package 2025-09-26. September 2025.
12. CDISC. Oncology Supplement to the Disease Response Supplement. June 2024.
