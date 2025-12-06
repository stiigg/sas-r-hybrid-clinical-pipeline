# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Refactored README to focus on operational documentation
- Removed career-positioning content from repository

## [1.1.0] - 2025-12-06

### Added
- Multi-study portfolio orchestration with `run_portfolio.sh`
- Portfolio dashboard for timeline visualization
- Priority-based execution filtering
- Cross-study dependency tracking

### Changed
- Switched from SAS-R hybrid to R-only pharmaverse workflow
- Updated to admiral >= 0.12.0
- Migrated SDTM processing to pharmaversesdtm package

## [1.0.0] - 2025-12-02

### Added
- RECIST 1.1 derivation library
- Oncology response endpoint calculations (BOR, ORR, DoR)
- Unit test framework with >80% coverage
- Pooled analysis support (ISS/ISE)

### Fixed
- GitHub Actions workflow YAML indentation
- System dependency installation in CI/CD

## [0.9.0] - 2025-12-01

### Added
- Initial R-based pipeline structure
- SDTM and ADaM transformation modules
- Metadata-driven configuration with YAML
- Basic QC framework

[Unreleased]: https://github.com/stiigg/sas-r-hybrid-clinical-pipeline/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/stiigg/sas-r-hybrid-clinical-pipeline/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/stiigg/sas-r-hybrid-clinical-pipeline/compare/v0.9.0...v1.0.0
[0.9.0]: https://github.com/stiigg/sas-r-hybrid-clinical-pipeline/releases/tag/v0.9.0
