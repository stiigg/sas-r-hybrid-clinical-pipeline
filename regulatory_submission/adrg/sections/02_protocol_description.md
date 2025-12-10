# Section 2: Protocol Description

## 2.1 Study Overview

STUDY001 is a Phase III, randomized, double-blind, placebo-controlled trial evaluating the efficacy and safety of an investigational oncology treatment in patients with advanced solid tumors who have received 1-2 prior lines of systemic therapy.

**ClinicalTrials.gov**: NCT0XXXXXXX

**Study Period**: 
- First Patient First Visit: 2023-01-15
- Last Patient Last Visit: 2025-05-30
- Database Lock: 2025-06-30

## 2.2 Study Design

### Randomization

**Ratio**: 1:1 (Treatment : Placebo)

**Stratification Factors**:
1. **Prior lines of therapy**: 1 vs 2+
2. **ECOG Performance Status**: 0 vs 1

**Sample Size**: 
- Planned: 850 subjects
- Randomized: 850 subjects (425 per arm)
- Safety Population: 845 subjects (received ≥1 dose)

### Study Schema

```
Screening         Randomization              Treatment Period                  Follow-up
(-28 to -1 days)  (Day 1)                    (Until progression/toxicity)      (30 days + survival)

                  ↓
        /-----------------------\
        |                       |
    Treatment Arm           Placebo Arm
    (n=425)                 (n=425)
        |                       |
    Investigational         Matching Placebo
    Agent IV q3weeks        IV q3weeks
        |                       |
    Tumor Assessments q8weeks (RECIST 1.1)
    Safety Assessments per protocol
        |                       |
    Until progression, toxicity, or withdrawal
        ↓                       ↓
    30-day safety follow-up
    Long-term survival follow-up q12weeks
```

## 2.3 Study Objectives and Endpoints

### Primary Objective

To evaluate the efficacy of investigational treatment compared to placebo as measured by Progression-Free Survival (PFS).

**Primary Endpoint**: 
- **PFS** - Time from randomization to disease progression per RECIST 1.1 or death from any cause

**Primary Analysis**:
- Kaplan-Meier analysis with log-rank test (stratified by randomization factors)
- Cox proportional hazards model for hazard ratio estimation
- Planned at 350 PFS events (88% power to detect HR=0.70)

### Secondary Objectives

1. Evaluate Overall Survival (OS)
2. Assess Objective Response Rate (ORR)
3. Evaluate Duration of Response (DoR)
4. Assess safety and tolerability

**Secondary Endpoints**:

| Endpoint | Definition | Analysis |
|----------|------------|----------|
| OS | Time from randomization to death from any cause | Kaplan-Meier, log-rank test, Cox model |
| ORR | Proportion with confirmed CR or PR per RECIST 1.1 | Exact binomial test |
| DoR | Time from first response to progression or death | Kaplan-Meier (responders only) |
| Safety | Incidence of AEs, SAEs, deaths | Descriptive statistics |

## 2.4 Study Population

### Key Inclusion Criteria

1. Adults ≥18 years with histologically confirmed advanced solid tumors
2. Measurable disease per RECIST 1.1 (at least one target lesion)
3. Received 1-2 prior lines of systemic therapy
4. ECOG Performance Status 0 or 1
5. Adequate organ function (hematology, hepatic, renal)
6. Life expectancy ≥3 months

### Key Exclusion Criteria

1. Brain metastases (unless treated and stable)
2. Prior exposure to investigational agent class
3. Active second malignancy
4. Significant cardiovascular disease
5. Uncontrolled intercurrent illness

## 2.5 Treatment

### Investigational Treatment Arm

- **Agent**: Investigational oncology compound
- **Dose**: 10 mg/kg IV
- **Schedule**: Every 3 weeks (21-day cycles)
- **Route**: Intravenous infusion over 60 minutes
- **Duration**: Until disease progression, unacceptable toxicity, or withdrawal

### Placebo Arm

- **Agent**: Matching placebo (same appearance as active treatment)
- **Dose/Schedule/Route**: Same as investigational arm

### Dose Modifications

- **Dose Reduction**: Up to 2 levels (to 7.5 mg/kg, then 5 mg/kg) for toxicity
- **Dose Delay**: Treatment may be delayed up to 3 weeks for AE resolution
- **Permanent Discontinuation**: For Grade 4 toxicity or specific Grade 3 events

## 2.6 Efficacy Assessments

### Tumor Assessments

**Timing**: 
- Baseline (within 28 days of randomization)
- Every 8 weeks (±7 days) from randomization
- At treatment discontinuation
- Every 8 weeks during post-treatment follow-up until progression

**Method**: 
- CT or MRI per RECIST 1.1
- Same modality used throughout study
- Independent central review (primary efficacy assessment)
- Investigator assessment (sensitivity analysis)

**RECIST 1.1 Response Criteria**:

| Response | Definition |
|----------|------------|
| CR (Complete Response) | Disappearance of all target and non-target lesions |
| PR (Partial Response) | ≥30% decrease in sum of target lesion diameters |
| SD (Stable Disease) | Neither PR nor PD criteria met |
| PD (Progressive Disease) | ≥20% increase (≥5mm absolute) in sum OR new lesions |
| NE (Not Evaluable) | Assessment not possible |

**Confirmation Requirements**:
- CR or PR must be confirmed by repeat assessment ≥28 days later
- Unconfirmed responses do not count toward ORR

### Survival Follow-Up

- **Post-Progression**: Subjects followed for survival every 12 weeks
- **Duration**: Until death, withdrawal of consent, or study closure
- **Data Collection**: Date and cause of death

## 2.7 Analysis Populations

### Intent-to-Treat (ITT) Population

**Definition**: All randomized subjects

**Usage**: Primary efficacy analyses (PFS, OS, ORR)

**Analysis Principle**: Subjects analyzed as randomized (regardless of treatment received)

### Safety Population

**Definition**: All subjects who received ≥1 dose of study treatment

**Usage**: All safety analyses

**Analysis Principle**: Subjects analyzed according to treatment received

### Per-Protocol (PP) Population

**Definition**: ITT subjects without major protocol deviations affecting efficacy

**Usage**: Sensitivity analyses for primary endpoint

**Major Deviations** (examples):
- No baseline measurable disease
- No post-baseline tumor assessment
- Received prohibited concomitant therapy
- <80% treatment compliance

### Pharmacokinetic (PK) Population

**Definition**: Subjects with ≥1 evaluable PK sample

**Usage**: PK analyses (not included in this ADRG)

## 2.8 Protocol Amendments

This ADRG reflects Protocol Amendment 3 (dated 2024-06-01).

**Key Amendment Impacting Analysis**:

**Amendment 2 (2024-03-15)**:
- Changed PFS event threshold from 300 to 350 events
- Rationale: Lower-than-expected event rate in interim analysis
- Impact: Extended follow-up period; no impact on dataset structure

**Amendment 3 (2024-06-01)**:
- Added exploratory biomarker substudy
- No impact on efficacy or safety analysis datasets

## 2.9 Statistical Analysis Plan (SAP)

**SAP Version**: 2.0 (finalized 2024-09-15, prior to database lock)

**Key Analysis Specifications**:

- **Significance Level**: α = 0.05 (two-sided) for primary endpoint
- **Multiplicity Adjustment**: Hochberg procedure for secondary endpoints
- **Missing Data**: 
  - Tumor assessments: Missing = not evaluable (NE)
  - Deaths: Date of death collected; censored if lost to follow-up
- **Interim Analysis**: One interim analysis at 230 PFS events (O'Brien-Fleming spending)
- **Subgroup Analyses**: 
  - Prior lines (1 vs 2+)
  - ECOG (0 vs 1)
  - Age (<65 vs ≥65)
  - Baseline tumor burden (median split)

**Censoring Rules for PFS**:

1. **No progression, ongoing on study**: Censor at last adequate tumor assessment
2. **Started new anti-cancer therapy**: Censor at last assessment before new therapy
3. **Lost to follow-up**: Censor at last contact date
4. **Withdrew consent**: Censor at date of withdrawal
5. **Death without documented progression**: Event (not censored)

## 2.10 Data Monitoring

**Data Monitoring Committee (DMC)**: Independent DMC reviewed unblinded safety and efficacy data

**Interim Analysis**: Conducted at 230 PFS events (2024-12-15); DMC recommended study continuation

**Database Lock**: Performed 2025-06-30 after 350 PFS events accrued
