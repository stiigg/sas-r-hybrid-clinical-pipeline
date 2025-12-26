# SDTM AE Domain Implementation Guide

## Overview
This document describes the implementation of the SDTM Adverse Events (AE) domain for the RECIST-DEMO-001 study, compliant with SDTM IG v3.3 and FDA Technical Conformance Guide v5.0.

## Standards and References
- **SDTM Implementation Guide**: Version 3.3
- **MedDRA Version**: 27.1
- **FDA Technical Conformance Guide**: Version 5.0
- **Validation Tool**: Pinnacle 21 Community

## Input Data

### Raw Data File
- **Location**: `data/raw/adverse_events_raw.csv`
- **Format**: CSV with header row
- **Required Columns**: 25 columns including MedDRA hierarchy

### Reference Data
- **DM Domain**: Required for RFSTDTC (reference start date)
- **MedDRA Dictionary**: Embedded in raw data

## Output Datasets

### AE Domain (`ae.xpt`)
- **Variables**: 30 SDTM variables
- **Key Variables**: STUDYID, DOMAIN, USUBJID, AESEQ
- **Structure**: One record per adverse event
- **Sort Order**: USUBJID, AESEQ

### SUPPAE Domain (`suppae.xpt`)
- **Variables**: 10 supplemental qualifier variables
- **Purpose**: Treatment-emergent flag (AETRTEM)
- **Structure**: One record per AE with treatment-emergent flag
- **Sort Order**: USUBJID, IDVARVAL

## Variable Specifications

### Complete Variable List (30 variables)

| Seq | Variable | Label | Type | Length | Role | Core |
|-----|----------|-------|------|--------|------|------|
| 1 | STUDYID | Study Identifier | Char | 20 | Identifier | Req |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Identifier | Req |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Identifier | Req |
| 4 | AESEQ | Sequence Number | Num | 8 | Identifier | Req |
| 5 | AETERM | Reported Term for the Adverse Event | Char | 200 | Topic | Req |
| 6 | AEDECOD | Dictionary-Derived Term | Char | 200 | Synonym | Req |
| 7 | AEPTCD | Preferred Term Code | Char | 8 | Synonym | Exp |
| 8 | AEBODSYS | Body System or Organ Class | Char | 200 | Synonym | Exp |
| 9 | AESOC | Primary System Organ Class | Char | 200 | Synonym | Exp |
| 10 | AEHLT | High Level Term | Char | 200 | Synonym | Perm |
| 11 | AEHLGT | High Level Group Term | Char | 200 | Synonym | Perm |
| 12 | AELLT | Lowest Level Term | Char | 200 | Synonym | Perm |
| 13 | AECAT | Category for Adverse Event | Char | 200 | Grouping Qual | Perm |
| 14 | AESCAT | Subcategory for Adverse Event | Char | 200 | Grouping Qual | Perm |
| 15 | AELOC | Location of Event | Char | 200 | Result Qual | Perm |
| 16 | AESEV | Severity/Intensity | Char | 8 | Result Qual | Exp |
| 17 | AESER | Serious Event | Char | 1 | Result Qual | Exp |
| 18 | AESDTH | Results in Death | Char | 1 | Result Qual | Perm |
| 19 | AESLIFE | Life Threatening Event | Char | 1 | Result Qual | Perm |
| 20 | AESHOSP | Requires or Prolongs Hospitalization | Char | 1 | Result Qual | Perm |
| 21 | AESDISAB | Significant Disability/Incapacity | Char | 1 | Result Qual | Perm |
| 22 | AESCONG | Congenital Anomaly/Birth Defect | Char | 1 | Result Qual | Perm |
| 23 | AESMIE | Medically Important Event | Char | 1 | Result Qual | Perm |
| 24 | AESOD | Overdose | Char | 1 | Result Qual | Perm |
| 25 | AEACN | Action Taken with Study Treatment | Char | 100 | Result Qual | Perm |
| 26 | AEREL | Causality | Char | 100 | Result Qual | Exp |
| 27 | AEOUT | Outcome of Adverse Event | Char | 100 | Result Qual | Perm |
| 28 | AESTDTC | Start Date/Time of Adverse Event | Char | 20 | Timing | Exp |
| 29 | AEENDTC | End Date/Time of Adverse Event | Char | 20 | Timing | Perm |
| 30 | AEDUR | Duration of Adverse Event (Days) | Num | 8 | Timing | Perm |
| 31 | AESTDY | Study Day of Start of Adverse Event | Num | 8 | Timing | Perm |
| 32 | AEENDY | Study Day of End of Adverse Event | Num | 8 | Timing | Perm |

**Legend**: Req = Required, Exp = Expected, Perm = Permissible

## Controlled Terminology

### AESEV (Non-Extensible)
- MILD
- MODERATE
- SEVERE

### AESER (Non-Extensible)
- Y (Yes)
- N (No)
- (blank)

### AEREL (Extensible)
- NOT RELATED
- UNLIKELY RELATED
- POSSIBLY RELATED
- PROBABLY RELATED
- RELATED

### AEACN (Extensible)
- DOSE NOT CHANGED
- DOSE REDUCED
- DOSE INCREASED
- DRUG INTERRUPTED
- DRUG WITHDRAWN
- NOT APPLICABLE
- UNKNOWN
- NOT EVALUABLE

### AEOUT (Extensible)
- RECOVERED/RESOLVED
- RECOVERING/RESOLVING
- NOT RECOVERED/NOT RESOLVED
- FATAL
- RECOVERED/RESOLVED WITH SEQUELAE
- UNKNOWN

## Derivations

### Study Day Calculation (AESTDY, AEENDY)
```sas
If AE_START_DATE >= RFSTDTC then:
    AESTDY = AE_START_DATE - RFSTDTC + 1
Else:
    AESTDY = AE_START_DATE - RFSTDTC

Note: No Day 0 exists (asymmetric calculation)
```

### Duration Calculation (AEDUR)
```sas
AEDUR = AE_END_DATE - AE_START_DATE + 1
```

### Treatment-Emergent Flag (AETRTEM in SUPPAE)
```sas
If AE_START_DATE >= RFSTDTC then:
    AETRTEM = 'Y'
Else:
    AETRTEM = '' (blank)
```

## Validation Checks Performed

1. **Required Variables**: All mandatory fields populated
2. **Controlled Terminology**: AESEV, AESER, AEREL validated
3. **Duplicate Detection**: No duplicate AESEQ within subject
4. **Date Logic**: End date not before start date
5. **Study Day Logic**: AEENDY >= AESTDY
6. **Seriousness Criteria**: If AESER='Y', at least one criterion flagged
7. **MedDRA Coding**: All AEs coded with PT and SOC

## Quality Control Outputs

The program generates 7 QC checks:
1. Frequency distributions of key categorical variables
2. Descriptive statistics for numeric variables
3. MedDRA coding completeness analysis
4. Duplicate AESEQ detection
5. Missing required variables check
6. Date logic validation
7. Treatment-emergent flag distribution

## MedDRA Hierarchy Mapping

### Example: Nausea
```
LLT (Lowest Level Term)    → "Feeling queasy"
         ↓
PT (Preferred Term)        → "NAUSEA" (Code: 10028813)
         ↓
HLT (High Level Term)      → "Nausea and vomiting symptoms"
         ↓
HLGT (High Level Group)    → "Gastrointestinal signs and symptoms"
         ↓
SOC (System Organ Class)   → "GASTROINTESTINAL DISORDERS"
```

## Known Limitations

1. **MedDRA Coding**: Test data uses limited MedDRA terms (15 PTs)
2. **Partial Dates**: Not handled in current version (assumes complete dates)
3. **Multiple Causality**: Single AEREL only (multi-drug causality not supported)
4. **Grade Mapping**: CTCAE grades not implemented (only severity)

## Production Requirements

### Before FDA Submission:
1. ✅ Run Pinnacle 21 Community validation
2. ✅ Create define.xml v2.0 or higher
3. ✅ Generate Reviewer's Guide document
4. ✅ Complete all QC checks
5. ⬜ Obtain medical coding certification
6. ⬜ Validate against sponsor-specific standards

### Files Required for Submission:
- `ae.xpt` (AE domain)
- `suppae.xpt` (SUPPAE domain)
- `define.xml` (metadata)
- `reviewer-guide.pdf` (documentation)
- All other SDTM domains

## Troubleshooting

### Common Issues:

**Issue**: "DM domain not found"
- **Solution**: Run `10_sdtm_dm.sas` first to create DM domain

**Issue**: "Invalid AESEV value"
- **Solution**: Check raw data for typos in SEVERITY column

**Issue**: "Duplicate AESEQ detected"
- **Solution**: Review raw data for duplicate adverse event records

**Issue**: "AEENDY < AESTDY"
- **Solution**: Verify end dates are after start dates in source data

## References

1. CDISC SDTM Implementation Guide v3.3
2. FDA Study Data Technical Conformance Guide v5.0
3. MedDRA Coding Guidelines
4. ICH E2A Clinical Safety Data Management
5. Pinnacle 21 Community User Guide

## Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2024-12-24 | Christian Baghai | Initial version with 13 variables |
| 2.0 | 2025-12-26 | Christian Baghai | Production version with 30 variables, SUPPAE, validation |

## Contact

For questions or issues:
- **Author**: Christian Baghai
- **Email**: christian.baghai@outlook.fr
- **Repository**: https://github.com/stiigg/sas-r-hybrid-clinical-pipeline
