# Migration Guide: Dedicated SDTM/ADaM Directory Structure

This branch (`feature/dedicated-sdtm-directory-structure`) reorganizes the repository into separate, dedicated directories for SDTM and ADaM processing.

## What Changed

### Before (ETL-centric structure)
```
etl/
├── R/
│   ├── 01_build_sdtm_pharmaverse.R
│   └── 02_build_adam_pharmaverse.R
└── sas/
    ├── 20_sdtm_dm.sas
    ├── 30_adam_adsl.sas
    └── adam_*.sas
```

### After (Dedicated structure)
```
sdtm/
├── programs/
│   ├── sas/
│   │   ├── 20_sdtm_dm.sas
│   │   └── sdtm_tu_tr.sas
│   └── R/
│       └── 01_build_sdtm_pharmaverse.R
├── data/
│   ├── input/
│   └── output/
└── README.md

adam/
├── programs/
│   ├── sas/
│   │   ├── 30_adam_adsl.sas
│   │   └── adam_*.sas
│   └── R/
│       └── 02_build_adam_pharmaverse.R
├── data/
│   ├── input/
│   └── output/
└── README.md
```

## Benefits

1. **Clear Separation**: SDTM and ADaM logic are completely independent
2. **Easier Navigation**: Each directory is self-contained with its own programs, data, and documentation
3. **Team Collaboration**: SDTM and ADaM developers can work independently
4. **Portfolio Ready**: Easy to showcase "Here's my complete SDTM implementation"
5. **Follows Industry Standards**: Mirrors FDA eCTD Module 5 structure

## Migration Steps

### File Movements

#### SDTM Programs
- `etl/sas/20_sdtm_dm.sas` → `sdtm/programs/sas/20_sdtm_dm.sas`
- `etl/sas/sdtm_tu_tr.sas` → `sdtm/programs/sas/sdtm_tu_tr.sas`
- `etl/R/01_build_sdtm_pharmaverse.R` → `sdtm/programs/R/01_build_sdtm_pharmaverse.R`

#### ADaM Programs
- `etl/sas/30_adam_adsl.sas` → `adam/programs/sas/30_adam_adsl.sas`
- `etl/sas/adam_*.sas` → `adam/programs/sas/adam_*.sas`
- `etl/R/02_build_adam_pharmaverse.R` → `adam/programs/R/02_build_adam_pharmaverse.R`

#### Support Files
- `etl/sas/00_setup.sas` → Kept in root or moved to utilities
- `etl/sas/10_raw_import.sas` → Moved to `sdtm/programs/sas/` (preprocessing)

### Path Updates Required

After migration, you'll need to update file paths in:
- Master runner scripts (`run_all.R`)
- Program references to input/output data locations
- Automation scripts in `automation/` directory

## Next Steps

1. Review the new structure in this branch
2. Test the SDTM pipeline: `source("sdtm/run_sdtm_all.R")`
3. Test the ADaM pipeline: `source("adam/run_adam_all.R")`
4. Update any external documentation or workflows
5. Merge to main when ready

## Questions?

This restructure maintains all existing functionality while providing clearer organization. Each directory (`sdtm/` and `adam/`) now has its own README with specific documentation.
