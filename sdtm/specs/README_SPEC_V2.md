# SDTM Specification v2 Format Guide

## Column Definitions

### seq
**Type:** Integer  
**Required:** Yes  
**Purpose:** Execution order for transformations with dependencies

**Example:**
```
1: STUDYID (no dependencies)
2: DOMAIN (no dependencies)
3: USUBJID (depends on STUDYID)
20: DMDY (depends on DMDTC and RFSTDTC)
```

### source_dataset
**Type:** Text  
**Required:** Yes  
**Purpose:** Libname.dataset reference for source data

**Valid Values:**
- `RAW.SUBJECTS_CLEAN` - Raw clinical data
- `SDTM.EX` - Exposure domain (for cross-domain derivations)
- `METADATA` - Study-level constants
- `CONSTANT` - Hard-coded values
- `DERIVED` - Calculated from other SDTM variables

### source_var
**Type:** Text  
**Required:** Conditional (not for CONSTANT)  
**Purpose:** Variable name(s) from source dataset

**Examples:**
- Single: `subject_id`
- Multiple: `"dob_year,dob_month,dob_day"` (comma-separated, quoted)
- Wildcard: `race_*` (for checkbox patterns)

### target_domain
**Type:** Text (2 characters)  
**Required:** Yes  
**Purpose:** SDTM domain abbreviation

**Valid Values:** DM, EX, AE, VS, LB, etc. (CDISC standard domains)

### target_var
**Type:** Text  
**Required:** Yes  
**Purpose:** SDTM variable name per CDISC IG

**Naming Convention:**
- Core variables: USUBJID, STUDYID, DOMAIN
- Domain-specific: --DTC, --TESTCD, --TEST, etc.
- Qualifiers: --ORRES, --STRESC, --STRESN

### target_type
**Type:** Text  
**Required:** Yes  
**Purpose:** SAS variable type

**Valid Values:**
- `Char` - Character/text
- `Num` - Numeric

### target_length
**Type:** Integer  
**Required:** Yes  
**Purpose:** Maximum variable length

**Standard Lengths:**
- STUDYID: 20
- USUBJID: 40
- DOMAIN: 2
- Date variables (--DTC): 19 (for date-time) or 10 (date only)
- Text fields: 200 (descriptions), 100 (coded values)

### transformation_type
**Type:** Text  
**Required:** Yes  
**Purpose:** Classification of transformation logic

**Valid Values:**
1. `CONSTANT` - Hard-coded value
2. `DIRECT_MAP` - 1:1 copy from source
3. `CONCAT` - Concatenate multiple fields
4. `DATE_CONSTRUCT` - Build date from components
5. `DATE_CONVERT` - Convert date format
6. `RECODE` - Value mapping/standardization
7. `CONDITIONAL` - If-then logic
8. `MULTI_CHECKBOX` - Multiple selection handling
9. `FORMAT` - Apply SAS format
10. `CROSS_DOMAIN` - Derive from another SDTM domain

### transformation_logic
**Type:** Text (SAS code)  
**Required:** Yes  
**Purpose:** Executable SAS code for transformation

**Examples by Type:**

**CONSTANT:**
```sas
STUDYID="STUDY-2024-001"
DOMAIN="DM"
```

**DIRECT_MAP:**
```sas
AGE=age_years
SUBJID=subject_id
```

**CONCAT:**
```sas
catx('-','&studyid',put(site_id,z3.),subject_id)
```

**DATE_CONSTRUCT:**
```sas
put(mdy(dob_month,dob_day,dob_year),is8601da.)
```

**DATE_CONVERT:**
```sas
put(input(consent_date,anydtdte.),is8601dt.)
```

**RECODE:**
```sas
case(upcase(sex))
  when('MALE','M') then 'M'
  when('FEMALE','F') then 'F'
  else 'U'
end
```

**CONDITIONAL:**
```sas
if AGE ne . then AGEU='YEARS'
```

### ct_codelist
**Type:** Text  
**Required:** Conditional (for coded variables)  
**Purpose:** CDISC Controlled Terminology codelist reference

**Examples:**
- `Sex` - For SEX variable
- `Race` - For RACE variable
- `Ethnicity` - For ETHNIC variable
- `Age Unit` - For AGEU variable
- `ISO 3166-1 Alpha-3` - For COUNTRY variable

**CT Version:** Reference latest CDISC CT (currently 2024-06-28)

### quality_check
**Type:** Text (semicolon-separated)  
**Required:** No  
**Purpose:** Validation rules for automated QC

**Available Checks:**

| Check | Syntax | Example |
|-------|--------|----------|
| Not Null | `NOT_NULL` | USUBJID required |
| Unique | `UNIQUE` | No duplicate USUBJIDs |
| Range | `RANGE:min-max` | `RANGE:18-120` for AGE |
| Exact Value | `EXACT_VALUE` | DOMAIN must be "DM" |
| Controlled Term | `CONTROLLED_TERM` | SEX in (M,F,U) |
| ISO Date | `ISO8601_DATE` | YYYY-MM-DD format |
| ISO DateTime | `ISO8601_DATETIME` | YYYY-MM-DDTHH:MM:SS |
| Length | `LENGTH_CHECK` | Max length validation |
| Pattern | `PATTERN:regex` | USUBJID format |

**Multiple Checks:**
```
NOT_NULL;UNIQUE;PATTERN:^[A-Z0-9]+-[0-9]{3}-[0-9]+$
```

### comments
**Type:** Text  
**Required:** No  
**Purpose:** Human-readable documentation

**Best Practices:**
- Explain complex logic
- Note protocol-specific rules
- Document assumptions
- Reference eCRF field names
- Flag edge cases

**Examples:**
```
"Use screening date as DM collection date"
"Screen failures get ARMCD='SCRNFAIL'"
"If multiple races selected, RACE='MULTIPLE' and create SUPPDM"
"Handle missing day/month with partial dates (YYYY-MM or YYYY)"
```

## Complete Example Row

```csv
3,RAW.SUBJECTS_CLEAN,subject_id,DM,USUBJID,Char,40,CONCAT,"catx('-','&studyid',put(site_id,z3.),subject_id)",,NOT_NULL;UNIQUE;PATTERN:^[A-Z0-9]+-[0-9]{3}-[0-9]+$,"Unique subject identifier constructed from study-site-subject"
```

**Breakdown:**
- `seq`: 3 (execute after STUDYID and DOMAIN)
- `source_dataset`: RAW.SUBJECTS_CLEAN
- `source_var`: subject_id (also uses site_id and macro &studyid)
- `target_domain`: DM
- `target_var`: USUBJID
- `target_type`: Char
- `target_length`: 40
- `transformation_type`: CONCAT
- `transformation_logic`: catx('-','&studyid',put(site_id,z3.),subject_id)
- `ct_codelist`: (empty - not a coded variable)
- `quality_check`: NOT_NULL;UNIQUE;PATTERN:^[A-Z0-9]+-[0-9]{3}-[0-9]+$
- `comments`: "Unique subject identifier constructed from study-site-subject"

## Transformation Type Usage Guide

### When to Use Each Type

#### CONSTANT
**Use for:** Study metadata, domain identifiers  
**Examples:** STUDYID, DOMAIN  
**Dependencies:** None  

#### DIRECT_MAP
**Use for:** Simple 1:1 copies where no transformation needed  
**Examples:** SUBJID=subject_id, AGE=age_years  
**Dependencies:** Source variable must exist  

#### CONCAT
**Use for:** Building composite keys  
**Examples:** USUBJID from study+site+subject  
**Dependencies:** All component variables must exist  

#### DATE_CONSTRUCT
**Use for:** Assembling dates from separate day/month/year fields  
**Examples:** BRTHDTC from dob_day, dob_month, dob_year  
**Dependencies:** All component variables  
**Notes:** Handle partial dates (missing day or month)  

#### DATE_CONVERT
**Use for:** Reformatting dates to ISO 8601  
**Examples:** Various EDC formats → YYYY-MM-DD  
**Dependencies:** Source date variable  
**Notes:** Use ANYDTDTE. informat for flexibility  

#### RECODE
**Use for:** Value mapping to controlled terminology  
**Examples:** "Male" → "M", "USA" → "USA" (standardization)  
**Dependencies:** Source variable  
**Notes:** Handle all possible input variants  

#### CONDITIONAL
**Use for:** Business logic with if-then rules  
**Examples:** Populate AGEU only when AGE exists  
**Dependencies:** Conditional source variable(s)  

#### MULTI_CHECKBOX
**Use for:** Multiple checkbox selections (race, medical history)  
**Examples:** race_white=1, race_black=1 → RACE='MULTIPLE'  
**Dependencies:** All checkbox variables  
**Notes:** May require SUPPDM for full details  

#### FORMAT
**Use for:** Applying SAS formats  
**Examples:** Zero-padding site numbers (001, 002, ...)  
**Dependencies:** Source numeric variable  

#### CROSS_DOMAIN
**Use for:** Deriving from other SDTM domains  
**Examples:** RFSTDTC = MIN(EXSTDTC) from EX domain  
**Dependencies:** Source domain must be created first  
**Notes:** Update `seq` to execute after dependency  

## Quality Check Implementation

The QC framework automatically validates during execution:

```sas
/* Auto-generated from quality_check column */
proc sql;
  create table work.qc_violations as
  select 
    'USUBJID' as variable,
    USUBJID as value,
    'NOT_NULL violation' as issue
  from sdtm.dm
  where USUBJID is missing
  
  union all
  
  select 
    'USUBJID' as variable,
    USUBJID as value,
    'UNIQUE violation' as issue
  from sdtm.dm
  group by USUBJID
  having count(*) > 1;
quit;
```

## Best Practices

1. **Order by Dependencies**
   - Use `seq` to ensure parent variables created first
   - USUBJID needs STUDYID → STUDYID gets lower seq

2. **Document Complex Logic**
   - Use `comments` field extensively
   - Reference protocol sections
   - Note edge cases

3. **Validate Controlled Terminology**
   - Always specify `ct_codelist` for coded variables
   - Check against current CDISC CT version
   - Document version in spec header

4. **Handle Missing Data**
   - Distinguish between "not done" vs "unknown"
   - Use appropriate null flavors
   - Document assumptions in comments

5. **Test Edge Cases**
   - Partial dates
   - Multiple selections
   - Protocol deviations
   - Screen failures

6. **Version Control**
   - Include version in filename (sdtm_dm_spec_v2.csv)
   - Track changes in Git
   - Document rationale for changes

## Advanced Transformation Types (v2.1)

### BASELINE_FLAG
Derives baseline flags (VSBLFL, LBLFL, EGBLFL) using 3-step algorithm:
1. Subset records ≤ RFSTDTC
2. Identify MAX(date+time) per test/position
3. Flag matching records with 'Y'

**Usage in Spec:**
```
seq,target_var,transformation_type,transformation_logic
26,VSBLFL,BASELINE_FLAG,test_var=VSTESTCD|dtc_var=VSDTC|ref_start=RFSTDTC|position_var=VSPOS
```

**Logic Flow:**
```
Input: All VS records for USUBJID=001, VSTESTCD=SYSBP, VSPOS=SITTING
   2024-01-10 09:00 → Eligible (before RFSTDTC)
   2024-01-14 14:30 → Eligible (before RFSTDTC)  
   2024-01-15 09:00 → Eligible (equal to RFSTDTC) ← LATEST
   2024-01-16 10:00 → Not eligible (after RFSTDTC)
Output: Only 2024-01-15 09:00 gets VSBLFL='Y'
```

### UNIT_CONVERSION
Converts laboratory results from collected units to standard units (typically SI).

**Requires:** `unit_conversion_factors.csv` in reference_data/

**Usage in Spec:**
```
seq,target_var,transformation_type,transformation_logic
15,LBSTRESN,UNIT_CONVERSION,lookup_file=unit_conversion_factors.csv|test_var=LBTESTCD|unit_var=LBORRESU|result_var=LBORRES
```

**Example Conversions:**
- Glucose: 100 mg/dL → 5.55 mmol/L (factor: 0.0555)
- Creatinine: 1.2 mg/dL → 106 µmol/L (factor: 88.4)

### REFERENCE_DATA_LOOKUP
Joins external reference tables (e.g., lab normal ranges by age/sex).

**Usage in Spec:**
```
seq,target_var,transformation_type,transformation_logic
20,LBSTNRLO|LBSTNRHI,REFERENCE_DATA_LOOKUP,lookup_file=lab_reference_ranges.csv|join_keys=LBTESTCD,SEX,AGE|target_vars=LBSTNRLO,LBSTNRHI,LBSTNRC
```
