# Analysis Data Reviewer's Guide (ADRG) Framework

## Purpose

This directory contains a complete **Analysis Data Reviewer's Guide (ADRG)** for STUDY001, following PHUSE and FDA recommendations for regulatory submissions.

The ADRG serves as the primary documentation that helps regulatory reviewers:
- Understand the structure and content of analysis datasets (ADaM)
- Trace derivations back to source data (SDTM)
- Verify compliance with CDISC standards
- Review complex algorithms (RECIST 1.1, time-to-event, etc.)
- Locate specific programs and their outputs

## Structure

The ADRG follows the recommended 7-section format:

### Section 1: Introduction
- Purpose of the ADRG
- Study overview
- Document organization

### Section 2: Protocol Description
- Study design
- Objectives and endpoints
- Analysis populations
- Key protocol amendments affecting analysis

### Section 3: Analysis Datasets
- Detailed description of each ADaM dataset
- Variable listings with labels and derivations
- Dataset relationships and keys
- Record counts and statistics

### Section 4: ADaM Conformance
- CDISC ADaM IG version used
- Self-assessment against ADaM principles
- Deviations and rationale (if any)
- Controlled terminology usage

### Section 5: Data Dependencies and Flow
- SDTM → ADaM traceability
- Dataset dependency graph
- Input/output mappings
- Cross-dataset derivations

### Section 6: Special Variables and Algorithms
- Complex derivation logic (BOR, PFS, etc.)
- RECIST 1.1 implementation details
- Censoring rules for time-to-event
- Population flag derivations
- Custom functions and macros

### Section 7: Program Inventory
- Complete listing of all programs
- Production vs QC programs
- Input/output for each program
- Execution sequence and dependencies
- Version control information

## Files in This Directory

```
regulatory_submission/adrg/
├── README_ADRG.md                    # This file
├── ADRG_STUDY001_template.md         # Master ADRG document
├── sections/
│   ├── 01_introduction.md
│   ├── 02_protocol_description.md
│   ├── 03_analysis_datasets.md       # Detailed dataset specs
│   ├── 04_adam_conformance.md
│   ├── 05_data_dependencies.md
│   ├── 06_special_variables.md       # Algorithms and derivations
│   └── 07_program_inventory.md       # Complete program listing
└── appendices/
    ├── A_adam_specification_summary.xlsx
    └── B_derivation_algorithms.md
```

## Integration with Repository

The ADRG references actual files and outputs from this repository:

### Programs Referenced
- `etl/adam_r_admiral/programs/ad_adsl.R`
- `etl/adam_r_admiral/programs/ad_adrs.R`
- `etl/adam_r_admiral/programs/ad_adtte.R`
- `qc/r/adam/qc_adam_*.R` (QC programs)

### Outputs Referenced
- `outputs/adam/adsl.rds`
- `outputs/adam/adrs.rds`
- `outputs/adam/adtte.rds`
- `regulatory_submission/define_xml/outputs/*.xpt`

### Specifications Referenced
- `specs/adam/` (ADaM specifications)
- `regulatory_submission/define_xml/dataset_specifications/`

## Usage

### For Demonstration/Interview Purposes

```r
# Generate all ADaM datasets
source("run_all.R")

# Review ADRG sections
file.show("regulatory_submission/adrg/ADRG_STUDY001_template.md")
file.show("regulatory_submission/adrg/sections/06_special_variables.md")
```

### For Actual Submission

In a real regulatory submission:

1. **Compile sections** into single ADRG document
2. **Convert to PDF** (searchable, with bookmarks)
3. **Include in eCTD Module 5.3.5.3** alongside:
   - ADaM XPT files
   - define.xml
   - Dataset specifications
4. **Ensure version alignment** with actual datasets (database lock date)

## Lead Programmer Competencies Demonstrated

This ADRG framework showcases:

### Technical Skills
- ✅ Deep understanding of CDISC ADaM standards
- ✅ Complex derivation logic documentation (RECIST, TTE)
- ✅ Traceability and lineage mapping
- ✅ Quality control integration
- ✅ Metadata management

### Regulatory Knowledge
- ✅ FDA/EMA submission requirements
- ✅ ADRG structure and content expectations
- ✅ Define.xml coordination
- ✅ Inspection readiness

### Documentation Skills
- ✅ Clear, reviewer-friendly writing
- ✅ Appropriate level of technical detail
- ✅ Cross-referencing and navigation
- ✅ Version control and change tracking

### Leadership Capabilities
- ✅ Program inventory management
- ✅ Cross-functional coordination (stats, DM, reg affairs)
- ✅ Timeline and dependency management
- ✅ Deliverable packaging

## Customization for Other Studies

To adapt this ADRG template for other studies:

1. **Copy the structure**:
   ```bash
   cp -r regulatory_submission/adrg studies/STUDY002/adrg
   ```

2. **Update study-specific content**:
   - Protocol description (Section 2)
   - Dataset descriptions (Section 3)
   - Program paths (Section 7)

3. **Maintain consistent format**:
   - Keep 7-section structure
   - Use same heading hierarchy
   - Follow PHUSE template conventions

## References

### PHUSE Resources
- [ADRG Template](https://advance.phuse.global/display/WEL/Analysis+Data+Reviewer+s+Guide+ADRG+Package)
- [ADaM Documentation Best Practices](https://phuse.s3.eu-central-1.amazonaws.com/Deliverables/Data+Visualisation+%26+Open+Source+Technology/WP063.pdf)

### FDA Guidance
- [Study Data Technical Conformance Guide](https://www.fda.gov/media/88173/download)
- [Data Standards and Submission](https://www.fda.gov/industry/fda-data-standards-advisory-board/study-data-standards-resources)

### CDISC Standards
- [ADaM Implementation Guide v1.3](https://www.cdisc.org/standards/foundational/adam/adam-implementation-guide-v1-3)
- [Define-XML v2.1](https://www.cdisc.org/standards/data-exchange/define-xml)

## Quality Control

Before submission, validate the ADRG:

- [ ] All 7 sections complete
- [ ] Program paths verified against repository
- [ ] Dataset descriptions match actual outputs
- [ ] Record counts accurate
- [ ] Cross-references to define.xml correct
- [ ] No placeholder text ("TBD", "TODO") remaining
- [ ] PDF conversion successful with bookmarks
- [ ] File size < 50 MB
- [ ] Searchable text (not scanned images)

## Support

For questions about this ADRG framework:
1. Review the individual section files in `sections/`
2. Check the PHUSE ADRG template for comparison
3. Consult the FDA Technical Conformance Guide
4. Open an issue in this repository with specific questions

---

**Note**: This ADRG is part of a demonstration portfolio for clinical programming job applications. While it follows industry standards and best practices, it represents a mock study (STUDY001) and should be adapted for real submission work.
