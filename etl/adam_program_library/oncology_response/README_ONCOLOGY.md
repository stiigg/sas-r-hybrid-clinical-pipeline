# Oncology Response Programming Library

This module contains production-grade SAS macros for RECIST 1.1-based tumor response derivations and will be expanded with time-to-event and advanced oncology endpoints.

Current contents:
- `recist_11_core/derive_target_lesion_response.sas`
- `recist_11_core/derive_non_target_lesion_response.sas`
- `recist_11_core/derive_overall_timepoint_response.sas`

Planned extensions include:
- Best overall response and confirmation logic
- PFS/OS/DoR/TTR time-to-event macros
- Advanced endpoints (ORR, DCR, depth of response)
- iRECIST for immunotherapy trials
