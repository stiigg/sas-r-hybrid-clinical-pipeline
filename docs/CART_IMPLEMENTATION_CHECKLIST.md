# CAR-T SDTM Implementation Checklist

## Overview
This checklist tracks the FDA-compliant CAR-T enhancements to the SDTM pipeline, ensuring ASTCT 2019 consensus grading standards and comprehensive safety data collection.

---

## Phase 1: Raw Data Infrastructure ☐

### Raw Data Files Creation
- [ ] Create `data/raw/adverse_events_cart_raw.csv` with all CAR-T fields
  - CRS fields: `CRS_FLAG`, `ASTCT_CRS_GRADE`, `CRS_FEVER_PRESENT`, `CRS_PEAK_TEMP_C`
  - ICANS fields: `ICANS_FLAG`, `ASTCT_ICANS_GRADE`, `ICE_SCORE`, `ICE_ORIENTATION_SCORE`
  - Infection fields: `INFECTION_FLAG`, `PATHOGEN_NAME`, `INFECTION_SITE`
  - Cytopenia fields: `CYTOPENIA_FLAG`, `NADIR_ANC_VALUE`, `CYTOPENIA_DURATION_DAYS`
  - Treatment fields: `TOCILIZUMAB_GIVEN`, `DEXAMETHASONE_FOR_ICANS`, `GCSF_ADMINISTERED`

- [ ] Create `data/raw/crs_icans_symptoms_raw.csv` for CE domain
  - Required fields: `USUBJID`, `SYMPTOM_NAME`, `SYMPTOM_START_DATE`, `SYMPTOM_END_DATE`
  - `PARENT_TOXICITY_TYPE` (CRS/ICANS), `SYMPTOM_CATEGORY`, `PARENT_AE_SEQUENCE`
  - Optional: `SYMPTOM_SEVERITY`, `SYMPTOM_VALUE`, `SYMPTOM_UNIT`

### Data Validation
- [ ] Validate all raw data has correct column headers
- [ ] Test data import into SAS with `proc import`
- [ ] Confirm date formats (YYYY-MM-DD)
- [ ] Verify numeric fields are properly formatted

---

## Phase 2: Update Core AE Program ✓

### 30_sdtm_ae.sas Enhancements
- [x] Enhanced CAR-T detection logic (STEP 3)
  - [x] CRS detection with fever validation
  - [x] ICANS detection with ICE score validation
  - [x] Infection categorization by timing (0-7, 8-30, 31-90, >90 days)
  - [x] Cytopenia classification (acute/prolonged/chronic)
  - [x] Cardiovascular event detection
  - [x] carHLH identification
  - [x] Hypogammaglobulinemia tracking

- [x] Comprehensive SUPPAE generation (STEP 5)
  - [x] `CRSASTCT` - ASTCT consensus CRS grade
  - [x] `CRSFEVER`, `CRSMAXTP` - Fever documentation
  - [x] `CRSTOCI`, `CRSSTER` - CRS treatment flags
  - [x] `ICANSAST`, `ICESCORE` - ICANS grade and ICE score
  - [x] `ICANSLOC`, `ICANSSEIZ` - ICANS clinical features
  - [x] `INFTYPE`, `PATHOGEN`, `INFSITE` - Infection details
  - [x] `CYTOPDUR`, `CYTOPNAD`, `CYTOPGF` - Cytopenia metrics

- [x] CAR-T specific QC checks (STEP 6)
  - [x] CRS without fever validation
  - [x] ICANS without ICE score validation
  - [x] CAR-T toxicity distribution report

### Testing
- [ ] Run `30_sdtm_ae.sas` with sample data
- [ ] Verify no ERROR messages in log
- [ ] Confirm SUPPAE contains all CAR-T QNAM variables
- [ ] Review QC check outputs

---

## Phase 3: Create CE Domain ☐

### 35_sdtm_ce.sas Implementation
- [x] Program created and pushed to GitHub
- [ ] Test with sample CRS/ICANS symptoms data
- [ ] Verify CECAT/CESCAT values are correct
  - `CECAT`: "CRS SIGN/SYMPTOM" or "ICANS SIGN/SYMPTOM"
  - `CESCAT`: Specific categories (FEVER, COGNITIVE, SEIZURE, etc.)
- [ ] Confirm PARENT_AESEQ linkage present for all records
- [ ] Validate CESTDY/CEENDY calculations
- [ ] Review SUPPCE for symptom severity and values
- [ ] Confirm CE exports to both CSV and XPT

### Quality Checks
- [ ] Run orphan CE records check (records without parent AE)
- [ ] Review CRS symptom distribution table
- [ ] Review ICANS symptom distribution table
- [ ] Verify symptom counts match expectations

---

## Phase 4: Create RELREC Domain ☐

### 60_sdtm_relrec.sas Implementation
- [x] Program created and pushed to GitHub
- [ ] Test RELREC generation logic
- [ ] Verify CE→AE relationships created (RELTYPE="COMPOF")
  - [ ] All CE records properly link to parent AE
- [ ] Verify AE→CM relationships created (RELTYPE="TREATFOR")
  - [ ] CRS → Tocilizumab linkages
  - [ ] CRS/ICANS → Steroid linkages
  - [ ] Infections → Antibiotic linkages
  - [ ] ICANS with seizures → Anti-seizure med linkages
  - [ ] Cytopenias → G-CSF linkages
- [ ] Verify CM→AE reciprocal relationships
- [ ] Run validation queries
- [ ] Review RELREC summary by relationship type
- [ ] Confirm RELREC exports correctly

### Validation Reports
- [ ] Review "CRS Treatment Linkages" report
- [ ] Review "Infection Treatment Linkages" report
- [ ] Verify relationship counts are reasonable

---

## Phase 5: Create Safety Summary Program ☐

### 70_cart_safety_summary.sas Implementation
- [x] Program created and pushed to GitHub
- [ ] Test all 6 summary tables generation
- [ ] Verify Table 1: Overall CAR-T toxicity incidence
- [ ] Verify Table 2: CRS ASTCT grade distribution
- [ ] Verify Table 3: ICANS grade with ICE scores
- [ ] Verify Table 4: Infection characteristics
- [ ] Verify Table 5: Prolonged cytopenias
- [ ] Verify Table 6: CRS treatment patterns via RELREC
- [ ] Review output RTF file formatting
- [ ] Confirm no missing data in key summaries

---

## Phase 6: Sample Data Creation ☐

### Create Representative Test Data
- [ ] Generate 20-30 sample subjects
- [ ] Include diverse CRS grades (1-4)
- [ ] Include diverse ICANS grades (1-4)
- [ ] Add infection events at different timepoints
- [ ] Add prolonged cytopenias (>30 days)
- [ ] Ensure treatment records for each toxicity
- [ ] Create CE records for 5+ symptoms per CRS/ICANS event

### Data Realism Checks
- [ ] CRS incidence ~40-90% (product-dependent)
- [ ] ICANS incidence ~20-65%
- [ ] Infection rates ~20-47%
- [ ] Prolonged cytopenia ~40%
- [ ] ICE scores range 0-10
- [ ] CRS timing: typically days 1-14 post-infusion
- [ ] ICANS timing: typically days 4-21 post-infusion

---

## Phase 7: Final Validation ☐

### CDISC Validation
- [ ] Run Pinnacle 21 Community validation on all XPT files
- [ ] Resolve all ERROR messages
- [ ] Review and address WARNING messages
- [ ] Verify all domains have correct variable order per SDTM IG v3.3
- [ ] Confirm controlled terminology compliance
- [ ] Check Define-XML generation (if applicable)

### Cross-Domain Consistency
- [ ] Verify all USUBJID values exist in DM domain
- [ ] Confirm AESEQ values sequential within subject
- [ ] Validate SUPPAE IDVARVAL matches AESEQ
- [ ] Check RELREC references valid domain.variable combinations
- [ ] Verify date consistency across domains

---

## FDA Readiness Checklist ☐

### ASTCT Consensus Compliance
- [ ] All CRS events have ASTCT grade documented (`CRSASTCT`)
- [ ] All CRS events have fever documentation (`CRSFEVER`)
- [ ] All ICANS events have ASTCT grade documented (`ICANSAST`)
- [ ] All ICANS events have ICE score (0-10) documented (`ICESCORE`)
- [ ] ICE score components properly captured (orientation, naming, commands, writing, attention)

### Treatment Traceability
- [ ] Grade 3-4 CRS events have treatment documented
- [ ] Grade 3-4 ICANS events have treatment documented
- [ ] Tocilizumab linked to CRS events via RELREC
- [ ] Dexamethasone linked to CRS/ICANS via RELREC
- [ ] Antibiotics linked to infection events via RELREC
- [ ] Anti-seizure meds linked to ICANS with seizures via RELREC

### Safety Data Completeness
- [ ] Infections have pathogen data where available (`PATHOGEN`)
- [ ] Infections categorized by timing (early/intermediate/late/very late)
- [ ] Prolonged cytopenias (>30 days) are flagged
- [ ] Chronic cytopenias (>90 days) are flagged
- [ ] Nadir values captured for cytopenias
- [ ] Supportive care documented (G-CSF, transfusions)

### Data Standards
- [ ] All dates in ISO 8601 format (YYYY-MM-DD)
- [ ] All study day calculations correct (no day 0)
- [ ] Treatment emergent flags properly derived
- [ ] Serious event criteria properly flagged
- [ ] MedDRA coding complete and current version

---

## Documentation Complete ☐

### Program Documentation
- [x] All programs have headers with author, date, purpose
- [ ] All programs generate clean log files (no errors)
- [ ] README updated with CAR-T enhancements description
- [ ] This checklist maintained and up-to-date

### Technical Documentation
- [ ] Data dictionary updated with new variables
- [ ] Define-XML reflects all CAR-T enhancements
- [ ] RELREC relationships documented
- [ ] Validation reports saved and reviewed

### Study Documentation
- [ ] CAR-T enhancement specifications documented
- [ ] Deviation reports (if any) completed
- [ ] QC review signatures obtained
- [ ] Final datasets locked and archived

---

## Implementation Timeline

| Phase | Estimated Time | Status |
|-------|----------------|--------|
| Phase 1: Raw Data | 1 day | ☐ |
| Phase 2: Update AE | 1 day | ✓ |
| Phase 3: CE Domain | 1 day | ☐ |
| Phase 4: RELREC | 1 day | ☐ |
| Phase 5: Safety Summary | 1 day | ☐ |
| Phase 6: Sample Data | 1 day | ☐ |
| Phase 7: Validation | 1-2 days | ☐ |
| **Total** | **7-8 days** | **In Progress** |

---

## Key References

### FDA Guidance
- FDA Chemistry, Manufacturing, and Control (CMC) Information for CAR-T Products (2021)
- FDA Technical Conformance Guide v5.0

### ASTCT Standards
- Lee et al. ASTCT Consensus Grading for CRS and Neurologic Toxicity (2019)
- Biology of Blood and Marrow Transplantation 25(4):625-638

### CDISC Standards
- SDTM Implementation Guide v3.3
- SDTM v1.7
- Controlled Terminology (latest version)

---

## Notes

### Common Issues and Solutions
1. **Missing ICE Scores**: All ICANS events MUST have ICE score. If missing, request from site.
2. **CRS without Fever**: Per ASTCT, fever is REQUIRED for CRS diagnosis. Flag for medical review.
3. **Treatment Timing**: Ensure CM start dates align with or follow AE start dates for RELREC.
4. **Pathogen Identification**: Document "NOT IDENTIFIED" if cultures negative, don't leave blank.
5. **Cytopenia Duration**: Calculate from onset to resolution or data cutoff date.

### Contact Information
- **Lead Programmer**: Christian Baghai (christian.baghai@outlook.fr)
- **Repository**: https://github.com/stiigg/sas-r-hybrid-clinical-pipeline
- **Branch**: cart-enhancements

---

**Last Updated**: 2025-12-29  
**Version**: 1.0
