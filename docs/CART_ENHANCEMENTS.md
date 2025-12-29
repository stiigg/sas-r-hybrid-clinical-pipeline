# CAR-T SDTM Enhancements Documentation

## Executive Summary

This document describes the comprehensive CAR-T (Chimeric Antigen Receptor T-cell) therapy enhancements implemented in the SDTM pipeline to meet FDA Biologics License Application (BLA) submission requirements.

### Key Features

✅ **ASTCT 2019 Consensus Grading**: Full implementation of American Society for Transplantation and Cellular Therapy consensus grading for CRS and ICANS  
✅ **ICE Score Validation**: Complete ICE (Immune Effector Cell-Associated Encephalopathy) scoring system (0-10 scale)  
✅ **CE Domain**: Clinical Events domain for granular CRS/ICANS symptom tracking  
✅ **RELREC Domain**: Relationship Records for treatment traceability (AE→CM, CE→AE)  
✅ **Infection Tracking**: Comprehensive pathogen documentation and timing categorization  
✅ **Cytopenia Monitoring**: Prolonged (>30 days) and chronic (>90 days) cytopenia flagging  
✅ **Safety Summary Tables**: BLA-ready ISS (Integrated Summary of Safety) tables

---

## Background: Why CAR-T Requires Special Handling

### FDA Requirements Evolution

As of 2024, FDA requires randomized controlled trials showing superiority over standard of care for CAR-T products. This shift mandates:

1. **Robust safety data collection** using standardized grading
2. **Traceability of toxicity management** (which treatment for which toxicity)
3. **Temporal relationship documentation** (when toxicities occur relative to infusion)
4. **Quality attributes linkage** (toxicity patterns to product characteristics)

### CAR-T Specific Toxicities

#### 1. Cytokine Release Syndrome (CRS)
- **Incidence**: 40-90% (product-dependent)
- **Timing**: Typically days 1-14 post-infusion
- **Grading**: ASTCT consensus (Lee et al. 2019)
- **Key Feature**: Fever is **REQUIRED** for CRS diagnosis per ASTCT
- **Management**: Tocilizumab (IL-6 inhibitor), corticosteroids

#### 2. Immune Effector Cell-Associated Neurotoxicity Syndrome (ICANS)
- **Incidence**: 20-65%
- **Timing**: Typically days 4-21 post-infusion
- **Grading**: ASTCT consensus with ICE score
- **ICE Score Components**:
  - Orientation (year, month, city, hospital): 0-4 points
  - Naming (3 objects): 0-3 points
  - Following commands: 0-1 points
  - Writing: 0-1 points
  - Attention (counting backwards): 0-1 points
  - **Total**: 0-10 (10 = normal)
- **Management**: Dexamethasone, anti-seizure medications

#### 3. Infections
- **Incidence**: 20-47%
- **Non-relapse mortality**: Up to 47.6% of deaths
- **Timing Categories**:
  - Early (0-7 days): Often catheter-related
  - Intermediate (8-30 days): Bacterial infections
  - Late (31-90 days): Opportunistic infections
  - Very late (>90 days): Chronic immune deficiency

#### 4. Cytopenias
- **Prolonged (>30 days)**: ~40% of patients
- **Chronic (>90 days)**: Requires long-term monitoring
- **Types**: Neutropenia, thrombocytopenia, anemia, pancytopenia

#### 5. Other CAR-T Toxicities
- **carHLH**: CAR-T related hemophagocytic lymphohistiocytosis (rare but severe)
- **Cardiovascular events**: Arrhythmias, heart failure, myocarditis
- **Hypogammaglobulinemia**: Chronic B-cell aplasia requiring IVIG

---

## Technical Implementation

### Architecture Overview

```
Raw Data Files
│
├── adverse_events_cart_raw.csv (Enhanced with CAR-T fields)
│   ├── CRS fields (ASTCT grade, fever, temperature, hypotension, etc.)
│   ├── ICANS fields (ASTCT grade, ICE score components, seizures, etc.)
│   ├── Infection fields (pathogen, timing, site, severity)
│   ├── Cytopenia fields (nadir values, duration, G-CSF use)
│   └── Treatment fields (tocilizumab, dexamethasone, antibiotics)
│
└── crs_icans_symptoms_raw.csv (Individual symptoms for CE domain)
    ├── Symptom name, dates, severity
    ├── Quantitative values (temperature, BP, O2 saturation)
    └── Linkage to parent AE (PARENT_AE_SEQUENCE)

↓

Programs
│
├── 30_sdtm_ae.sas (Enhanced)
│   ├── CAR-T detection & categorization logic
│   ├── Comprehensive SUPPAE generation
│   └── CAR-T specific validation checks
│
├── 35_sdtm_ce.sas (NEW)
│   ├── Clinical Events domain for symptoms
│   ├── SUPPCE for symptom details
│   └── Linkage preparation for RELREC
│
├── 60_sdtm_relrec.sas (NEW)
│   ├── CE → AE relationships (COMPOF)
│   ├── AE → CM relationships (TREATFOR)
│   └── CM → AE reciprocal relationships
│
└── 70_cart_safety_summary.sas (NEW)
    ├── Table 1: Overall CAR-T toxicity incidence
    ├── Table 2: CRS ASTCT grade distribution
    ├── Table 3: ICANS grade with ICE scores
    ├── Table 4: Infection characteristics
    ├── Table 5: Prolonged cytopenias
    └── Table 6: CRS treatment patterns (via RELREC)

↓

Output SDTM Domains
│
├── AE (Adverse Events) + SUPPAE
├── CE (Clinical Events) + SUPPCE
└── RELREC (Relationship Records)
```

---

## Program Details

### 1. Enhanced 30_sdtm_ae.sas

#### CAR-T Detection Logic (STEP 3)

**CRS Detection**:
```sas
if upcase(strip(CRS_FLAG)) = 'Y' or
   index(upcase(AEDECOD), 'CYTOKINE RELEASE') > 0 then do;
    
    AECAT = 'CAR-T TOXICITY';
    AESCAT = 'CRS';
    
    /* CRITICAL: Fever required per ASTCT */
    if missing(CRS_FEVER_PRESENT) or upcase(CRS_FEVER_PRESENT) ne 'Y' then do;
        put "ERROR: CRS requires fever per ASTCT 2019";
        call symputx('validation_errors', 'YES');
    end;
    
    /* Validate ASTCT grade */
    if missing(ASTCT_CRS_GRADE) then do;
        put "ERROR: Missing ASTCT_CRS_GRADE for CRS";
        call symputx('validation_errors', 'YES');
    end;
end;
```

**ICANS Detection**:
```sas
if upcase(strip(ICANS_FLAG)) = 'Y' or
   index(upcase(AEDECOD), 'ICANS') > 0 then do;
    
    AECAT = 'CAR-T TOXICITY';
    AESCAT = 'ICANS';
    
    /* CRITICAL: ICE Score required */
    if missing(ICE_SCORE) then do;
        put "ERROR: Missing ICE_SCORE for ICANS";
        call symputx('validation_errors', 'YES');
    end;
end;
```

#### SUPPAE Variables Generated

| QNAM | QLABEL | Description | Toxicity |
|------|--------|-------------|----------|
| `CRSASTCT` | CRS ASTCT Consensus Grade | Grade 1-4 | CRS |
| `CRSFEVER` | Fever Present | Y/N | CRS |
| `CRSMAXTP` | Maximum Temperature (C) | Numeric | CRS |
| `CRSTOCI` | Tocilizumab Administered | Y/N | CRS |
| `CRSSTER` | Steroids Administered | Y/N | CRS |
| `ICANSAST` | ICANS ASTCT Consensus Grade | Grade 1-4 | ICANS |
| `ICESCORE` | ICE Score | 0-10 | ICANS |
| `ICANSLOC` | Level of Consciousness | Text | ICANS |
| `ICANSSEIZ` | Seizures Present | Y/N | ICANS |
| `ICANSDEX` | Dexamethasone Given | Y/N | ICANS |
| `INFTYPE` | Infection Type | BACTERIAL/VIRAL/FUNGAL | Infection |
| `PATHOGEN` | Pathogen Identified | Organism name | Infection |
| `INFSITE` | Site of Infection | Body location | Infection |
| `CYTOPDUR` | Cytopenia Duration Category | ACUTE/PROLONGED/CHRONIC | Cytopenia |
| `CYTOPNAD` | Nadir ANC Value | Numeric | Cytopenia |
| `CYTOPGF` | Growth Factor Given | Y/N | Cytopenia |

#### CAR-T Specific QC Checks

1. **CRS without fever**: Flags CRS events missing fever documentation (ASTCT violation)
2. **ICANS without ICE score**: Flags ICANS events missing ICE score (required for grading)
3. **CAR-T toxicity distribution**: Summary table of all CAR-T categories

---

### 2. New 35_sdtm_ce.sas - Clinical Events Domain

#### Purpose

The CE domain captures **protocol-specified clinical endpoints** - in this case, individual signs and symptoms that comprise CRS and ICANS events. This allows:

- Granular analysis of toxicity patterns
- FDA adjudication of complex cases
- Symptom-level timeline reconstruction
- Linkage to parent AE via RELREC

#### Example: CRS Event Decomposition

**AE Domain Record**:
```
USUBJID=CART-001, AESEQ=1, AETERM=CYTOKINE RELEASE SYNDROME, 
AECAT=CAR-T TOXICITY, AESCAT=CRS, AESTDTC=2024-03-15
```

**CE Domain Records** (linked via RELREC):
```
CESEQ=1, CETERM=FEVER, CECAT=CRS SIGN/SYMPTOM, CESCAT=FEVER, 
        PARENT_AESEQ=1, CESTDTC=2024-03-15

CESEQ=2, CETERM=HYPOTENSION, CECAT=CRS SIGN/SYMPTOM, CESCAT=HEMODYNAMIC, 
        PARENT_AESEQ=1, CESTDTC=2024-03-15

CESEQ=3, CETERM=HYPOXIA, CECAT=CRS SIGN/SYMPTOM, CESCAT=RESPIRATORY, 
        PARENT_AESEQ=1, CESTDTC=2024-03-15
```

**SUPPCE Records** (quantitative values):
```
QNAM=CEVAL, QVAL=39.2, QNAM=CEUNIT, QVAL=CELSIUS     (for fever)
QNAM=CEVAL, QVAL=85, QNAM=CEUNIT, QVAL=MMHG_SYSTOLIC (for hypotension)
QNAM=CEVAL, QVAL=88, QNAM=CEUNIT, QVAL=SPO2_PERCENT  (for hypoxia)
```

#### CE Domain Variables

| Variable | Description | Example |
|----------|-------------|----------|
| `CESEQ` | Sequence number | 1, 2, 3... |
| `CETERM` | Clinical event term | FEVER, CONFUSION, SEIZURE |
| `CECAT` | Category | CRS SIGN/SYMPTOM, ICANS SIGN/SYMPTOM |
| `CESCAT` | Subcategory | FEVER, COGNITIVE, MOTOR, SEIZURE |
| `CEOCCUR` | Occurrence indicator | Y (always Y for observed events) |
| `CESTDTC` | Start date | 2024-03-15 |
| `CEENDTC` | End date | 2024-03-18 |
| `PARENT_AESEQ` | Link to parent AE | 1 (AESEQ from AE domain) |

---

### 3. New 60_sdtm_relrec.sas - Relationship Records

#### Purpose

RELREC establishes **bidirectional traceability** between domains, critical for FDA review of:

- Which medications were given FOR which adverse events
- Which symptoms COMPRISE which toxicity syndromes
- Temporal relationships between exposures and outcomes

#### Relationship Types Implemented

##### 1. CE → AE: Component Relationships

```
RDOMAIN=CE, IDVAR=CESEQ, IDVARVAL=1, RELTYPE=COMPOF, RELID=AE.AESEQ=1

Translation: "CE symptom #1 (FEVER) is a COMPONENT OF AE #1 (CRS)"
```

##### 2. AE → CM: Treatment Relationships

```
RDOMAIN=AE, IDVAR=AESEQ, IDVARVAL=1, RELTYPE=TREATFOR, RELID=CM.CMSEQ=5

Translation: "AE #1 (CRS) was TREATED WITH CM #5 (Tocilizumab)"
```

##### 3. CM → AE: Reciprocal Treatment Relationships

```
RDOMAIN=CM, IDVAR=CMSEQ, IDVARVAL=5, RELTYPE=TREATFOR, RELID=AE.AESEQ=1

Translation: "CM #5 (Tocilizumab) was given to TREAT AE #1 (CRS)"
```

#### Treatment Linkage Logic

The program automatically identifies treatment relationships based on:

**CRS Treatments**:
- Tocilizumab (IL-6 receptor antagonist)
- Dexamethasone / Methylprednisolone
- Anakinra (IL-1 receptor antagonist)

**ICANS Treatments**:
- Dexamethasone
- Anti-seizure medications (levetiracetam, phenytoin, lorazepam)

**Infection Treatments**:
- Antibiotics (meropenem, vancomycin, ceftriaxone, piperacillin)
- Antivirals
- Antifungals

**Cytopenia Treatments**:
- G-CSF (filgrastim, pegfilgrastim)
- Blood/platelet transfusions

#### Validation Reports

The program generates validation tables:

1. **CRS Treatment Linkages**: Shows which tocilizumab/steroid doses linked to which CRS events
2. **Infection Treatment Linkages**: Shows which antibiotics linked to which infections
3. **RELREC Summary**: Counts by relationship type and domain

---

### 4. New 70_cart_safety_summary.sas - Safety Summary Tables

#### Table Specifications

##### Table 1: Overall CAR-T Toxicity Incidence

| Toxicity Type | N Patients | % Patients | Total Events | Serious Events | Grade ≥3 | Fatal |
|---------------|-----------|------------|--------------|----------------|---------|-------|
| CRS | 15 | 75.0 | 15 | 8 | 5 | 0 |
| ICANS | 10 | 50.0 | 10 | 7 | 4 | 1 |
| carHLH | 1 | 5.0 | 1 | 1 | 1 | 1 |

##### Table 2: CRS ASTCT Grade Distribution

| ASTCT Grade | N Patients | % of CRS | Mean Onset (Days) | Mean Duration (Days) | Tocilizumab | Steroids |
|-------------|-----------|----------|-------------------|---------------------|-------------|----------|
| 1 | 6 | 40.0 | 3.2 | 2.5 | 0 | 0 |
| 2 | 5 | 33.3 | 4.1 | 3.8 | 3 | 1 |
| 3 | 3 | 20.0 | 5.0 | 5.2 | 3 | 3 |
| 4 | 1 | 6.7 | 6.0 | 7.0 | 1 | 1 |

##### Table 3: ICANS Grade with ICE Scores

| ASTCT Grade | N Patients | % of ICANS | Mean ICE | SD ICE | Min ICE | Max ICE | Seizures |
|-------------|-----------|------------|----------|--------|---------|---------|----------|
| 1 | 4 | 40.0 | 7.8 | 0.5 | 7 | 8 | 0 |
| 2 | 3 | 30.0 | 5.3 | 0.6 | 5 | 6 | 1 |
| 3 | 2 | 20.0 | 2.5 | 0.7 | 2 | 3 | 2 |
| 4 | 1 | 10.0 | 0.0 | - | 0 | 0 | 1 |

##### Table 4: Infection Characteristics

| Timing | N Patients | Total Infections | Serious | Fatal | Pathogen ID | % ID Rate |
|--------|-----------|------------------|---------|-------|-------------|----------|
| Early (0-7 days) | 5 | 5 | 2 | 0 | 4 | 80.0 |
| Intermediate (8-30 days) | 8 | 10 | 6 | 1 | 7 | 70.0 |
| Late (31-90 days) | 4 | 5 | 3 | 1 | 2 | 40.0 |

##### Table 5: Prolonged Cytopenias

| Type | Duration | N | Mean (Days) | Median (Days) | Min | Max | G-CSF |
|------|----------|---|-------------|---------------|-----|-----|-------|
| Neutropenia | Prolonged (31-90 days) | 6 | 52.3 | 48.0 | 32 | 85 | 5 |
| Thrombocytopenia | Prolonged (31-90 days) | 4 | 45.8 | 42.0 | 33 | 67 | 0 |
| Neutropenia | Chronic (>90 days) | 2 | 125.5 | 125.5 | 95 | 156 | 2 |

##### Table 6: CRS Treatment Patterns (via RELREC)

| Treatment | N Treated | % of CRS Pts | Mean Day Tx Given |
|-----------|-----------|--------------|-------------------|
| Tocilizumab | 7 | 46.7 | 4.3 |
| Dexamethasone | 4 | 26.7 | 5.8 |
| Methylprednisolone | 2 | 13.3 | 6.0 |

---

## Raw Data Requirements

### File 1: adverse_events_cart_raw.csv

**Required Fields** (in addition to standard AE fields):

#### CRS Fields
```
CRS_FLAG                    # Y/N
ASTCT_CRS_GRADE            # 1/2/3/4
CRS_FEVER_PRESENT          # Y/N (REQUIRED if CRS_FLAG=Y)
CRS_PEAK_TEMP_C            # Numeric (e.g., 39.2)
CRS_HYPOTENSION_GRADE      # NONE/VASOPRESSOR_SINGLE/VASOPRESSOR_MULTIPLE
CRS_HYPOXIA_GRADE          # NONE/LOW_FLOW/HIGH_FLOW/POSITIVE_PRESSURE
TOCILIZUMAB_GIVEN          # Y/N
TOCILIZUMAB_START_DATE     # YYYY-MM-DD
STEROIDS_GIVEN_FOR_CRS     # Y/N
```

#### ICANS Fields
```
ICANS_FLAG                 # Y/N
ASTCT_ICANS_GRADE          # 1/2/3/4
ICE_SCORE                  # 0-10 (REQUIRED if ICANS_FLAG=Y)
ICE_ORIENTATION_SCORE      # 0-4
ICE_NAMING_SCORE           # 0-3
ICE_FOLLOWING_COMMANDS_SCORE # 0-1
ICE_WRITING_SCORE          # 0-1
ICE_ATTENTION_SCORE        # 0-1
ICANS_CONSCIOUSNESS_LEVEL  # Text description
ICANS_SEIZURE_PRESENT      # Y/N
DEXAMETHASONE_FOR_ICANS    # Y/N
```

#### Infection Fields
```
INFECTION_FLAG             # Y/N
INFECTION_TYPE             # BACTERIAL/VIRAL/FUNGAL/PARASITIC
PATHOGEN_NAME              # Organism (e.g., KLEBSIELLA_PNEUMONIAE)
INFECTION_SITE             # BLOODSTREAM/RESPIRATORY/URINARY/CNS
INFECTION_ONSET_DAY_POST_INFUSION # Numeric
```

#### Cytopenia Fields
```
CYTOPENIA_FLAG             # Y/N
CYTOPENIA_TYPE             # NEUTROPENIA/THROMBOCYTOPENIA/ANEMIA
NADIR_ANC_VALUE            # Numeric (cells/μL)
CYTOPENIA_DURATION_DAYS    # Numeric
GCSF_ADMINISTERED          # Y/N
```

### File 2: crs_icans_symptoms_raw.csv

**Required Fields**:
```
USUBJID                    # Subject ID
SYMPTOM_NAME               # e.g., FEVER, CONFUSION, TREMOR
SYMPTOM_START_DATE         # YYYY-MM-DD
SYMPTOM_END_DATE           # YYYY-MM-DD
SYMPTOM_SEVERITY           # MILD/MODERATE/SEVERE
SYMPTOM_VALUE              # Numeric (for quantifiable symptoms)
SYMPTOM_UNIT               # Unit (CELSIUS, MMHG_SYSTOLIC, SPO2_PERCENT)
PARENT_TOXICITY_TYPE       # CRS/ICANS
SYMPTOM_CATEGORY           # FEVER/COGNITIVE/MOTOR/SEIZURE/etc.
PARENT_AE_SEQUENCE         # AESEQ from AE domain
```

---

## Validation Strategy

### Level 1: Program-Level Validation

Each program includes built-in QC checks:

**30_sdtm_ae.sas**:
- CRS without fever check
- ICANS without ICE score check
- ASTCT grade validation (1-4 only)
- ICE score range validation (0-10)

**35_sdtm_ce.sas**:
- Orphan CE records (symptoms without parent AE)
- Symptom distribution by category
- Study day calculation validation

**60_sdtm_relrec.sas**:
- Relationship summary by type
- Treatment linkage validation tables
- Bidirectional relationship verification

### Level 2: Cross-Domain Validation

1. **USUBJID Consistency**: All subjects in AE/CE/RELREC exist in DM
2. **Sequence Integrity**: AESEQ, CESEQ, CMSEQ are sequential within subject
3. **Date Logic**: Start dates ≤ End dates, RELREC references valid dates
4. **RELREC Referential Integrity**: All RELID references point to existing records

### Level 3: CDISC Conformance

**Pinnacle 21 Validation**:
- Variable names conform to SDTM IG v3.3
- Variable lengths within limits
- Controlled terminology compliance
- Required variables present
- Variable order correct

### Level 4: Clinical Validation

**Medical Review**:
- Grade 3-4 CRS have treatment documented
- Grade 3-4 ICANS have treatment documented
- ICE score aligns with ICANS grade
- Infection timing aligns with known CAR-T patterns
- Cytopenia severity aligns with nadir values

---

## FDA Submission Readiness

### ISS (Integrated Summary of Safety) Components

✅ **Table 14.3.1**: Overview of Adverse Events (standard)  
✅ **Table 14.3.1.1**: CAR-T Specific Toxicities (Table 1 from this implementation)  
✅ **Table 14.3.1.2**: CRS ASTCT Grading Summary (Table 2)  
✅ **Table 14.3.1.3**: ICANS ASTCT Grading Summary (Table 3)  
✅ **Table 14.3.1.4**: Infections by Timing and Pathogen (Table 4)  
✅ **Table 14.3.1.5**: Prolonged Cytopenias (Table 5)  
✅ **Table 14.3.1.6**: Toxicity Management Patterns (Table 6)

### Datasets for Submission

```
submission/
├── datasets/
│   ├── ae.xpt          (Enhanced with CAR-T categorization)
│   ├── suppae.xpt      (CAR-T specific QNAM variables)
│   ├── ce.xpt          (Clinical Events for symptoms)
│   ├── suppce.xpt      (Symptom quantitative values)
│   ├── relrec.xpt      (Relationship traceability)
│   └── ...(other standard domains)
├── define.xml      (Define-XML v2.0 with CAR-T variables)
└── adrg.pdf        (Analysis Data Reviewer's Guide)
```

### Reviewer Expectations

FDA reviewers will look for:

1. **ASTCT Compliance**: All CRS/ICANS graded per 2019 consensus
2. **ICE Score Completeness**: Every ICANS event has ICE score
3. **Treatment Traceability**: RELREC links Grade 3-4 events to treatments
4. **Temporal Patterns**: Toxicities occur within expected timeframes
5. **Data Quality**: No missing data for critical variables
6. **Consistency**: Grading aligns with clinical features

---

## Future Enhancements

### Planned Features

1. **Biomarker Integration**: Link cytokine levels to CRS severity
2. **Product Quality Attributes**: Correlate CAR-T cell characteristics with toxicity
3. **Long-term Follow-up**: Extend cytopenia tracking to 1+ years
4. **Survival Analysis**: Time-to-event for toxicity onset
5. **Comparative Analysis**: Cross-product toxicity benchmarking

### Integration with ADaM

ADaM datasets for analysis:

- **ADAE**: Analysis dataset for adverse events with CAR-T flags
- **ADTTE**: Time-to-event for CRS, ICANS, infections
- **ADLB**: Laboratory data linking to cytopenia events
- **ADCM**: Concomitant meds with toxicity management focus

---

## References

### Primary Literature

1. **Lee DW et al.** ASTCT Consensus Grading for Cytokine Release Syndrome and Neurologic Toxicity Associated with Immune Effector Cells. *Biology of Blood and Marrow Transplantation* 2019;25(4):625-638.

2. **Hayden PJ et al.** Management of adults and children receiving CAR T-cell therapy: 2021 best practice recommendations of the European Society for Blood and Marrow Transplantation (EBMT) and the Joint Accreditation Committee of ISCT and EBMT (JACIE) and the European Haematology Association (EHA). *Annals of Oncology* 2022;33(3):259-275.

3. **Freyer CW et al.** Risk factors and management of cytokine release syndrome and neurotoxicity in pediatric patients receiving tisagenlecleucel. *Blood Advances* 2020;4(24):6203-6213.

### FDA Guidance Documents

4. **FDA**. Chemistry, Manufacturing, and Control (CMC) Information for Human Gene Therapy Investigational New Drug Applications (INDs). January 2020.

5. **FDA**. Considerations for the Development of Chimeric Antigen Receptor (CAR) T Cell Products. February 2024 (Draft).

6. **FDA**. Study Data Technical Conformance Guide: Technical Specifications Document. Version 5.0, March 2023.

### CDISC Standards

7. **CDISC**. Study Data Tabulation Model Implementation Guide: Human Clinical Trials. Version 3.3, November 2020.

8. **CDISC**. Study Data Tabulation Model (SDTM). Version 1.7, December 2017.

9. **CDISC**. SDTM Controlled Terminology. (Updated quarterly)

---

## Contact & Support

**Primary Developer**: Christian Baghai  
**Email**: christian.baghai@outlook.fr  
**GitHub**: https://github.com/stiigg/sas-r-hybrid-clinical-pipeline  
**Branch**: cart-enhancements

**For Implementation Questions**:
1. Review [CART_IMPLEMENTATION_CHECKLIST.md](CART_IMPLEMENTATION_CHECKLIST.md)
2. Check program logs for specific error messages
3. Validate raw data against specifications above
4. Submit GitHub issue with log excerpt and data sample

---

**Document Version**: 1.0  
**Last Updated**: 2025-12-29  
**Status**: Production Ready
