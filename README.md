# SAS-R Hybrid Clinical Pipeline - Multi-Study Portfolio Edition

**Demonstrates Senior Statistical Programmer Competencies:**
- ✅ Portfolio management across 3 concurrent Phase I-III oncology studies
- ✅ Program-level standardization with reusable RECIST 1.1 derivation library
- ✅ Integrated Safety/Efficacy analyses (ISS/ISE) coordination
- ✅ Multi-study resource allocation and timeline management
- ✅ Interactive portfolio dashboard for stakeholder communication

## Portfolio Capabilities

This repository showcases real-world multi-study leadership scenarios:

### **Active Study Portfolio**
- **STUDY001** (Phase III, n=850): Pivotal NDA trial - Priority 1
- **STUDY002** (Phase II, n=120): Supporting efficacy - Priority 2  
- **STUDY003** (Phase I, n=45): Completed, legacy SDTM 1.5 - Priority 3

### **Pooled Analyses**
- **ISS** (Integrated Safety Summary): 1,015 patients across 3 studies
- **ISE** (Integrated Efficacy Summary): 970 patients (Phase II-III)

## Quick Start: Portfolio Mode

Run all active studies simultaneously:

```
./run_portfolio.sh
```

Run high-priority studies only:

```
PRIORITY_THRESHOLD=1 ./run_portfolio.sh
```

Launch portfolio dashboard:

```
Rscript -e "shiny::runApp('app/app.R')"
```

## Resume-Ready Features

This pipeline demonstrates:

1. **Multi-Study Coordination**: Orchestrates 3 concurrent trials with different phases, timelines, and CDISC versions
2. **Technical Leadership**: Program-level ADaM library with standardized RECIST 1.1 derivations and unit tests
3. **Resource Management**: Allocation tracking across internal team and CRO vendors
4. **Strategic Planning**: Gantt charts, dependency networks, priority queuing
5. **Stakeholder Communication**: Executive dashboards with study status, timelines, and milestones

## Interview Talking Points

**Q: How do you manage competing priorities across multiple studies?**

*"I built a portfolio orchestration system using YAML-based study registries and automated dependency tracking. When Study 001's database lock shifted 2 weeks, the system immediately flagged downstream impacts to the pooled ISS analysis. This allowed proactive stakeholder communication 3 weeks before the deadline, avoiding a crisis."* 

[Demo: Show `portfolio_registry.yml` and `run_portfolio.sh`]

---

## Directory Structure (Multi-Study)

```
studies/
├── portfolio_registry.yml          # Master portfolio configuration
├── STUDY001/                       # Phase III pivotal trial
│   ├── config/study_metadata.yml
│   ├── data/{raw,sdtm,adam}/
│   ├── outputs/
│   └── logs/
├── STUDY002/                       # Phase II supporting study
├── STUDY003/                       # Phase I completed study
└── pooled_analyses/
    ├── ISS/                        # Integrated Safety
    └── ISE/                        # Integrated Efficacy

etl/adam_program_library/           # Program-level standardization
├── oncology_response/
│   ├── recist_11_macros.R         # RECIST 1.1 BOR, ORR, DoR
│   └── README.md
├── time_to_event/
└── safety_standards/

automation/
├── portfolio_runner.R              # Multi-study orchestration
└── dependencies.R                  # Cross-study dependency tracking

app/modules/
└── portfolio_dashboard.R           # Interactive management dashboard
```
