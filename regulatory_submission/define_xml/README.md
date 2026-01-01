# Define-XML v2.1 Generation

Automated Define-XML generation for SDTM and ADaM datasets using Pinnacle 21 Community + metadata enrichment.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: Pinnacle 21 Community                              │
│  - Generate XPT files from SDTM datasets                    │
│  - Create Excel metadata template                           │
│  - Extract structural metadata (types, lengths, labels)     │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 2: Enrichment from SDTM Specs                         │
│  - Load sdtm/specs/*_spec_v2.csv files                      │
│  - Map transformation logic to variables                    │
│  - Add derivation methods                                   │
│  - Extract controlled terminology codelists                 │
│  - Generate value-level metadata                            │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 3: Define-XML v2.1 Generation                         │
│  - Create ODM 1.3.2 structure                               │
│  - Add ItemGroupDef (datasets)                              │
│  - Add ItemDef (variables)                                  │
│  - Add MethodDef (derivations)                              │
│  - Add CodeList (controlled terminology)                    │
│  - Generate compliant XML file                              │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 4: Validation                                         │
│  - Validate with Pinnacle 21 Community                      │
│  - Generate validation report                               │
│  - Check Define-XML 2.1 schema compliance                   │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Generate SDTM Define-XML

```bash
# From project root
Rscript regulatory_submission/define_xml/generate_define_sdtm.R
```

### 2. Manual Pinnacle 21 Step (First Time)

When prompted:
1. Open Pinnacle 21 Community
2. Select: **Define-XML → Create Spec**
3. Point to: `regulatory_submission/define_xml/metadata/xpt_files/`
4. Select standard: **SDTMIG 3.4**
5. Export to: `regulatory_submission/define_xml/metadata/pinnacle21_spec.xlsx`
6. Return and press ENTER to continue

### 3. Validate Output

```bash
bash regulatory_submission/define_xml/scripts/04_validate_define.sh
```

## Integration with run_all.R

The Define-XML generation is integrated into the main pipeline:

```r
source("run_all.R")
```

This will:
1. Generate SDTM datasets
2. Generate ADaM datasets
3. Run validation
4. **Generate Define-XML for SDTM**
5. **Generate Define-XML for ADaM**
6. Run QC automation

## Output Files

### Metadata (Intermediate)
- `metadata/xpt_files/*.xpt` - SAS transport files
- `metadata/pinnacle21_spec.xlsx` - Pinnacle 21 export
- `metadata/enriched_metadata_complete.rds` - Final metadata
- `metadata/*.csv` - Human-readable metadata

### Final Outputs
- `outputs/define_sdtm.xml` - SDTM Define-XML v2.1
- `outputs/define_adam.xml` - ADaM Define-XML v2.1
- `outputs/validation_reports/` - Pinnacle 21 reports

## Configuration

Edit `config/study_config.yml` to customize:
- Study metadata (ID, name, protocol)
- CDISC standard versions (SDTMIG 3.4, ADaMIG 1.3)
- Controlled terminology versions
- File paths
- Pinnacle 21 settings

**Example Configuration:**
```yaml
study:
  id: "STUDY001"
  name: "STUDY001 Clinical Trial"
  protocol: "STUDY001-Protocol-v1.0"

standards:
  sdtm:
    name: "SDTMIG"
    version: "3.4"
    ct_version: "SDTM 2024-06-28"

define_xml:
  version: "2.1"
  context: "Submission"
```

## Requirements

### R Packages
```r
install.packages(c(
  "yaml", "xml2", "dplyr", "readr", "readxl",
  "xportr", "haven", "purrr", "tidyr", "janitor",
  "cli", "logger", "here", "writexl"
))
```

### External Tools
- **Pinnacle 21 Community** (free): https://www.pinnacle21.com/downloads
- Java 8+ (for Pinnacle 21)

## Features

✅ **Automated Metadata Extraction**: Pinnacle 21 handles structural metadata  
✅ **Spec Integration**: Enriches with derivation logic from `sdtm/specs/`  
✅ **FDA Compliant**: Generate Define-XML v2.1 (required since March 2023)  
✅ **Full Traceability**: From raw data → specs → Define-XML  
✅ **Validation**: Integrated Pinnacle 21 validation  
✅ **CI/CD Ready**: GitHub Actions workflow included  

## Workflow Details

### Phase 1: XPT Generation & Pinnacle 21 Baseline

**Script**: `scripts/01_extract_pinnacle21_metadata.R`

**Actions**:
1. Read SDTM datasets from `sdtm/data/`
2. Generate XPT transport files using `xportr`
3. Save to `metadata/xpt_files/`
4. Prompt for manual Pinnacle 21 spec generation
5. Parse Pinnacle 21 Excel output
6. Extract baseline metadata (types, lengths, labels, core status)

**Outputs**:
- XPT files (SAS v5 transport format)
- `pinnacle21_spec.xlsx` (manual export from P21)
- `pinnacle21_parsed.rds` (parsed baseline metadata)

### Phase 2: Enrichment from SDTM Specs

**Script**: `scripts/02_enrich_from_specs.R`

**Actions**:
1. Load all `sdtm/specs/*_spec_v2.csv` files
2. Join with Pinnacle 21 baseline on (dataset, variable)
3. Add transformation logic and derivation methods
4. Extract controlled terminology codelists
5. Generate value-level metadata for conditional derivations
6. Create QC validation rules

**Enrichment Mapping**:
```
Pinnacle 21 Provides:     SDTM Specs Add:
- Variable names          - Transformation logic
- Data types              - Source datasets
- Lengths                 - Derivation algorithms  
- Core status             - Controlled terminology
- CDISC roles             - QC validation rules
```

**Outputs**:
- `enriched_metadata_complete.rds`
- `define_variables_enriched.csv`
- `define_codelists.csv`
- `define_value_level_metadata.csv`

### Phase 3: Define-XML v2.1 Generation

**Script**: `scripts/03_generate_define_xml_v2_1.R`

**Actions**:
1. Create ODM 1.3.2 root structure
2. Add Study and MetaDataVersion elements
3. Generate ItemGroupDef for each dataset
4. Generate ItemDef for each variable
5. Create MethodDef for derivations
6. Add CodeList definitions
7. Include Comments and Documentation
8. Write compliant XML file

**XML Structure**:
```xml
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     xmlns:def="http://www.cdisc.org/ns/def/v2.1">
  <Study OID="STUDY001">
    <MetaDataVersion def:DefineVersion="2.1"
                     def:StandardName="SDTMIG"
                     def:StandardVersion="3.4">
      
      <!-- Dataset Definitions (ItemGroupDef) -->
      <ItemGroupDef OID="IG.DM" Name="DM" 
                    def:Class="SUBJECT LEVEL"
                    def:Structure="One record per subject">
        <ItemRef ItemOID="IT.DM.USUBJID" Mandatory="Yes"/>
        ...
      </ItemGroupDef>
      
      <!-- Variable Definitions (ItemDef) -->
      <ItemDef OID="IT.DM.USUBJID" Name="USUBJID" 
               DataType="text" Length="40">
        <Description>
          <TranslatedText xml:lang="en">Unique Subject Identifier</TranslatedText>
        </Description>
        <def:Origin Type="Derived"/>
        <def:MethodRef MethodOID="MT.DM.USUBJID"/>
      </ItemDef>
      
      <!-- Derivation Methods (MethodDef) -->
      <def:MethodDef OID="MT.DM.USUBJID" Type="Computation">
        <Description>
          <TranslatedText xml:lang="en">
            CONCAT: catx('-','&amp;studyid',put(site_id,z3.),subject_id)
          </TranslatedText>
        </Description>
      </def:MethodDef>
      
      <!-- Controlled Terminology (CodeList) -->
      <CodeList OID="CL.SEX" Name="Sex" DataType="text"
                def:StandardOID="SDTM 2024-06-28">
        <Description>
          <TranslatedText xml:lang="en">Sex codelist</TranslatedText>
        </Description>
        <def:ExternalCodeList Dictionary="SDTM" Version="2024-06-28"/>
      </CodeList>
      
    </MetaDataVersion>
  </Study>
</ODM>
```

**Outputs**:
- `define_sdtm.xml` (compliant Define-XML v2.1)
- `define_generation_summary.txt`

### Phase 4: Validation

**Script**: `scripts/04_validate_define.sh`

**Actions**:
1. Locate Pinnacle 21 Community installation
2. Run validation against SDTMIG 3.4
3. Check Define-XML 2.1 schema compliance
4. Generate HTML validation report
5. Open report in browser

**Validation Checks**:
- Define-XML schema conformance
- ODM version compatibility
- Dataset-variable consistency
- Controlled terminology references
- Derivation method completeness

**Outputs**:
- `validation_reports/validation_report.html`
- `validation_reports/validation_log.txt`

## Troubleshooting

### Pinnacle 21 Not Found

**Error**: `⚠ Pinnacle 21 Community not found`

**Solution**:
```yaml
# Update config/study_config.yml
pinnacle21:
  community_path: "/path/to/P21Community.jar"
```

### XPT Generation Fails

**Error**: `No SDTM datasets found`

**Solution**:
```bash
# Check SDTM datasets exist
ls sdtm/data/*.sas7bdat

# Or generate them
Rscript run_all.R
```

### Validation Errors

**Error**: Multiple CORE/DD issues in Pinnacle 21 report

**Solution**:
1. Open validation report:
   ```bash
   open regulatory_submission/define_xml/outputs/validation_reports/validation_report.html
   ```
2. Review specific errors (CORE rules, controlled terminology)
3. Update `sdtm/specs/*_spec_v2.csv` to fix derivations
4. Regenerate Define-XML

### Missing Controlled Terminology

**Error**: `Codelist references not found`

**Solution**:
```csv
# Update config/ct_packages.csv with correct CT version
codelist,ct_package,ct_version,external_ref
Sex,SDTM,SDTM 2024-06-28,C66731
Race,SDTM,SDTM 2024-06-28,C74457
```

## Advanced Usage

### Custom Metadata Templates

Create reusable metadata functions in `templates/`:

```r
# templates/define_helpers.R

create_method_def <- function(oid, description, code) {
  list(
    oid = oid,
    type = "Computation",
    description = description,
    formal_expression = code
  )
}

generate_codelist <- function(name, ct_version, terms) {
  list(
    name = name,
    ct_version = ct_version,
    terms = terms
  )
}
```

### Value-Level Metadata

For variables with conditional derivations:

```r
# Example: AVAL calculation depends on PARAMCD
vlm <- tibble(
  dataset = "ADRS",
  variable = "AVAL",
  where_clause = "PARAMCD = 'BESTRSPI'",
  origin = "Derived",
  method = "Best response per RECIST 1.1"
)
```

### Multiple Define-XML Versions

Generate both SDTM and ADaM Define-XML:

```bash
# SDTM
Rscript regulatory_submission/define_xml/generate_define_sdtm.R

# ADaM  
Rscript regulatory_submission/define_xml/generate_define_adam.R
```

## Regulatory Submission Checklist

- [ ] Generate all XPT files (SDTM + ADaM)
- [ ] Create Define-XML for SDTM datasets
- [ ] Create Define-XML for ADaM datasets
- [ ] Validate with Pinnacle 21 Community
- [ ] Review all CORE errors (target: 0 errors)
- [ ] Verify controlled terminology versions
- [ ] Check derivation method completeness
- [ ] Include analysis results metadata (if applicable)
- [ ] Download define2-1-0.xsl stylesheet from CDISC
- [ ] Package Define-XML + XPT + stylesheet for eCTD

## References

### CDISC Standards
- [CDISC Define-XML v2.1 Specification](https://www.cdisc.org/standards/data-exchange/define-xml)
- [SDTM Implementation Guide v3.4](https://www.cdisc.org/standards/foundational/sdtmig)
- [ADaM Implementation Guide v1.3](https://www.cdisc.org/standards/foundational/adam)
- [CDISC Controlled Terminology](https://www.cdisc.org/standards/terminology)

### Tools
- [Pinnacle 21 Community](https://www.pinnacle21.com/downloads) - Free validation tool
- [xportr Package](https://atorus-research.github.io/xportr/) - R package for XPT generation
- [pharmaverse](https://pharmaverse.org/) - Open source pharma R packages

### Regulatory Guidance
- [FDA eCTD Specifications](https://www.fda.gov/drugs/electronic-regulatory-submission-and-review/electronic-common-technical-document-ectd)
- [FDA Study Data Technical Conformance Guide](https://www.fda.gov/media/88173/download)
- [EMA Data Standards](https://www.ema.europa.eu/en/human-regulatory/research-development/data-medicines-iso-idmp-standards/data-standardisation)

## Support

For questions or issues:
1. Check [troubleshooting section](#troubleshooting)
2. Review generation logs: `logs/define_xml_YYYY-MM-DD.log`
3. Consult Pinnacle 21 validation report
4. Refer to CDISC Define-XML v2.1 specification

## License

This implementation follows CDISC Define-XML v2.1 open standards.
