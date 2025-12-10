# Section 1: Introduction

## 1.1 Purpose of This Document

This Analysis Data Reviewer's Guide (ADRG) provides comprehensive documentation of the analysis datasets created for STUDY001 using R and the admiral package from the pharmaverse ecosystem.

This document demonstrates:

- **Regulatory-ready documentation** following FDA and PHUSE guidelines
- **Traceability** from SDTM source data to ADaM analysis datasets
- **Complex derivation logic** for oncology endpoints (RECIST 1.1)
- **Modern programming approaches** using validated open-source tools

For regulatory reviewers, this ADRG:

- Explains the structure and content of submitted analysis datasets
- Documents derivation algorithms and special processing
- Provides program inventory with clear input/output mappings
- Ensures understanding of how analysis datasets support statistical analyses

## 1.2 Scope

This ADRG covers **three ADaM datasets** submitted for STUDY001:

1. **ADSL** - Subject-Level Analysis Dataset
2. **ADRS** - Response Analysis Dataset (RECIST 1.1 endpoints)
3. **ADTTE** - Time-to-Event Analysis Dataset (PFS, OS)

These datasets support all efficacy and safety analyses specified in the Statistical Analysis Plan (SAP) dated 2024-09-15.

## 1.3 Document Organization

This ADRG follows the PHUSE-recommended seven-section structure:

**Section 2 - Protocol Description**: Study design, populations, and key endpoints

**Section 3 - Analysis Datasets**: Detailed specifications for ADSL, ADRS, and ADTTE

**Section 4 - ADaM Conformance**: CDISC standard compliance and version information

**Section 5 - Data Dependencies**: Flow from SDTM to ADaM with traceability maps

**Section 6 - Special Variables and Algorithms**: Complex derivations (RECIST, PFS censoring)

**Section 7 - Program Inventory**: Complete listing of production and QC programs

**Appendices**: Supplementary materials including detailed specifications

## 1.4 Key Study Information

| Attribute | Value |
|-----------|-------|
| Study ID | STUDY001 |
| Protocol | STUDY001 Protocol Amendment 3 (2024-06-01) |
| Phase | III |
| Indication | Advanced solid tumors |
| Design | Randomized, double-blind, placebo-controlled |
| Sample Size | 850 subjects randomized |
| Database Lock | 2025-06-30 |
| SDTM Version | SDTM-IG v3.4 |
| ADaM Version | ADaM-IG v1.3 |
| CDISC CT | 2023-09-29 |

## 1.5 References

**Protocol and SAP**:
- STUDY001 Protocol (Amendment 3, dated 2024-06-01)
- Statistical Analysis Plan v2.0 (dated 2024-09-15)

**CDISC Standards**:
- CDISC ADaM Implementation Guide v1.3
- CDISC SDTM Implementation Guide v3.4
- CDISC Controlled Terminology 2023-09-29

**Regulatory Guidance**:
- FDA Study Data Technical Conformance Guide (2023)
- ICH E9 Statistical Principles for Clinical Trials

**Software Documentation**:
- R Statistical Computing Environment (www.r-project.org)
- Admiral package documentation (pharmaverse.github.io/admiral)
- Package validation reports (see `validation/` folder)
