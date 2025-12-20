# AI/ML Implementation Guide

Comprehensive technical guide for implementing AI/ML components in clinical trial data management.

## Table of Contents

1. [Overview](#overview)
2. [Technology Stack](#technology-stack)
3. [Project 1: Progression Prediction](#project-1-progression-prediction)
4. [Project 2: Quality Monitoring Dashboard](#project-2-quality-monitoring-dashboard)
5. [Project 3: NLP Adverse Events](#project-3-nlp-adverse-events)
6. [Integration with RECIST Pipeline](#integration-with-recist-pipeline)
7. [Testing & Validation](#testing--validation)
8. [Deployment Considerations](#deployment-considerations)

---

## Overview

This module demonstrates practical implementation of AI/ML technologies transforming clinical data management in 2024-2025:

- **Natural Language Processing**: Automated adverse event extraction and medical coding
- **Predictive Analytics**: Machine learning for progression risk assessment
- **Quality Monitoring**: Risk-based quality management (RBQM) with Key Risk Indicators (KRIs)
- **Data Integration**: Connecting ML outputs with CDISC standards (SDTM/ADaM)

### Why These Technologies Matter

According to recent research:
- Phase III trials now generate 3.6M data points (3x increase since 2011)
- AI-based medical coding saves 69+ hours per 1,000 coded terms
- ML models can predict progression with 80-85% accuracy
- RBQM reduces monitoring costs by 20-30% while improving data quality

**References:**
- Dovepress: "Bridging the Past and Future of Clinical Data Management" (2025)
- Applied Clinical Trials: "Real-World AI Medical Coding" (2022)
- ASCO: "ML Prediction of RECIST Progression Events" (2023)

---

## Technology Stack

### R Packages

**Core:**
- `tidyverse` - Data manipulation and visualization
- `data.table` - High-performance data operations
- `lubridate` - Date/time handling

**Machine Learning:**
- `xgboost` - Gradient boosting (state-of-the-art)
- `randomForest` - Random forest ensemble
- `caret` - Unified ML interface
- `recipes` - Feature engineering pipeline
- `pROC` - ROC curve analysis

**Dashboard:**
- `shiny` - Interactive web applications
- `shinydashboard` - Dashboard layouts
- `plotly` - Interactive plots
- `DT` - Interactive tables

**NLP Support:**
- `reticulate` - R-Python interface
- `text` - Text mining
- `stringdist` - Fuzzy string matching

### Python Packages (NLP Module)

- `transformers` - Hugging Face models (BioBERT, ClinicalBERT)
- `torch` - Deep learning framework
- `pandas` - Data manipulation
- `scikit-learn` - ML utilities

### Development Tools

- `devtools` - Package development
- `testthat` - Unit testing
- `roxygen2` - Documentation

---

## Project 1: Progression Prediction

### Objective

Predict probability of disease progression within 90 days using baseline characteristics and early tumor dynamics.

### Clinical Use Case

**Problem:** Traditional RECIST criteria are reactive - progression detected only after tumors grow ≥20%+5mm.

**Solution:** ML model analyzes early trends to predict progression risk before formal PD criteria met.

**Benefit:** 
- Early identification of high-risk patients
- Proactive intervention planning
- Adaptive trial design support

### Feature Engineering

#### Input Data (SDTM RS Domain)

```r
# SDTM Structure
USUBJID  RSTESTCD  RSORRES  RSDTC       VISIT      
S001     LDIAM     100      2024-01-15  BASELINE
S001     LDIAM     85       2024-03-15  WEEK8
S001     LDIAM     120      2024-05-15  WEEK16
```

#### Derived Features

**Baseline Features:**
- `baseline_sld` - Sum of Longest Diameters at baseline
- `baseline_lesion_count` - Number of target lesions
- `baseline_tumor_burden` - Categorical (low/medium/high)

**Early Response Features (First Follow-up):**
- `first_fu_sld` - SLD at first assessment
- `first_fu_pct_change` - Percent change from baseline
- `first_fu_absolute_change` - Absolute change (mm)
- `early_responder` - Binary flag (change < -30%)

**Temporal Features:**
- `days_to_first_assessment` - Time to first imaging
- `assessment_frequency` - Assessments per month

**Kinetic Features:**
- `sld_velocity` - Rate of change (mm/day)
- `sld_acceleration` - Change in velocity
- `nadir_sld` - Minimum SLD observed
- `nadir_pct_change` - Percent change to nadir

**Variability Features:**
- `sld_coefficient_variation` - SD/mean of measurements
- `consecutive_increases` - Longest streak of increases

**Response Pattern Features:**
- `ever_achieved_pr` - Ever met PR criteria
- `ever_achieved_cr` - Ever met CR criteria
- `response_duration` - Days maintaining response

**Outcome Variable:**
- `progressed` - Binary (0/1)
- `days_to_progression` - Time to PD event

### Model Training

#### XGBoost Implementation

```r
library(xgboost)
library(caret)

# Prepare data
set.seed(42)
train_idx <- createDataPartition(features$progressed, p = 0.8, list = FALSE)
train_data <- features[train_idx, ]
test_data <- features[-train_idx, ]

# Feature matrix
feature_cols <- c(
  "baseline_sld", "first_fu_pct_change", "sld_velocity",
  "nadir_pct_change", "consecutive_increases"
)

dtrain <- xgb.DMatrix(
  data = as.matrix(train_data[, feature_cols]),
  label = train_data$progressed
)

# Hyperparameters (tuned via cross-validation)
params <- list(
  objective = "binary:logistic",
  eval_metric = "auc",
  max_depth = 6,           # Tree depth
  eta = 0.1,              # Learning rate
  subsample = 0.8,        # Row sampling
  colsample_bytree = 0.8, # Column sampling
  min_child_weight = 3,   # Minimum leaf weight
  gamma = 1               # Regularization
)

# Cross-validation
cv_results <- xgb.cv(
  params = params,
  data = dtrain,
  nrounds = 200,
  nfold = 5,
  early_stopping_rounds = 20,
  verbose = 1
)

# Train final model
model <- xgb.train(
  params = params,
  data = dtrain,
  nrounds = cv_results$best_iteration
)
```

#### Random Forest (Comparison)

```r
library(randomForest)

rf_model <- randomForest(
  as.factor(progressed) ~ .,
  data = train_data[, c("progressed", feature_cols)],
  ntree = 500,
  mtry = sqrt(length(feature_cols)),
  importance = TRUE
)
```

### Model Evaluation

#### Metrics

**Classification Performance:**
- **AUC-ROC**: Area under receiver operating characteristic curve (target: >0.80)
- **Accuracy**: Overall correct predictions
- **Sensitivity**: True positive rate (detect actual progressors)
- **Specificity**: True negative rate (avoid false alarms)
- **Precision**: Positive predictive value
- **F1 Score**: Harmonic mean of precision and recall

**Calibration:**
- **Brier Score**: Mean squared error of probabilities
- **Calibration Plot**: Predicted vs. observed probabilities

#### ROC Curve Analysis

```r
library(pROC)

# Predictions
test_preds <- predict(model, dtest)

# ROC curve
roc_obj <- roc(test_data$progressed, test_preds)

# AUC with confidence interval
auc_value <- auc(roc_obj)
ci_auc <- ci.auc(roc_obj)

cat(sprintf("AUC: %.3f (95%% CI: %.3f - %.3f)\n",
            auc_value, ci_auc[1], ci_auc[3]))

# Optimal threshold (Youden's index)
coords <- coords(roc_obj, "best", ret = c("threshold", "sensitivity", "specificity"))
```

#### Confusion Matrix

```r
library(caret)

# Binary predictions at optimal threshold
binary_preds <- ifelse(test_preds > coords$threshold, 1, 0)

# Confusion matrix
conf_matrix <- confusionMatrix(
  factor(binary_preds, levels = c(0, 1)),
  factor(test_data$progressed, levels = c(0, 1))
)

print(conf_matrix)
```

#### Feature Importance

```r
# XGBoost importance
importance <- xgb.importance(
  feature_names = feature_cols,
  model = model
)

# Plot
xgb.plot.importance(importance, top_n = 10)
```

### Expected Results

Based on published literature:
- **AUC**: 0.82-0.88
- **Sensitivity**: 75-85% at 70% specificity
- **Top Features**: Early percent change, baseline SLD, velocity

**Clinical Interpretation:**
- Model identifies ~80% of progressors before formal RECIST PD
- Median lead time: 28-42 days earlier detection
- False positive rate: 15-25% (acceptable for clinical use)

---

## Project 2: Quality Monitoring Dashboard

### Objective

Implement Risk-Based Quality Management (RBQM) dashboard with real-time Key Risk Indicators (KRIs) and anomaly detection.

### Clinical Context

**Traditional Monitoring:**
- 100% source data verification (SDV)
- Expensive, time-consuming
- Often misses systematic issues

**RBQM Approach:**
- Focus on Critical to Quality (CtQ) factors
- Central statistical monitoring
- Data-driven site oversight

**Regulatory Support:**
- FDA: Risk-Based Monitoring guidance
- EMA: Reflection paper on RBQM
- ICH E6(R2): Risk-proportionate approaches

### Key Risk Indicators (KRIs)

#### Data Quality KRIs

**1. Missing Data Rate**
```r
kri_missing_sld <- study_data %>%
  group_by(SITEID) %>%
  summarise(
    missing_rate = 100 * mean(is.na(RSSTRESC)),
    qtl_threshold = 10,  # Quality Tolerance Limit: 10%
    exceeds_qtl = missing_rate > qtl_threshold
  )
```

**2. Outlier Detection**
```r
kri_outliers <- study_data %>%
  group_by(SITEID) %>%
  mutate(
    z_score = (RSSTRESC - mean(RSSTRESC, na.rm=TRUE)) / sd(RSSTRESC, na.rm=TRUE),
    is_outlier = abs(z_score) > 3
  ) %>%
  summarise(
    outlier_rate = 100 * mean(is_outlier, na.rm = TRUE),
    qtl_threshold = 5
  )
```

**3. Protocol Deviation Rate**
```r
kri_deviations <- study_data %>%
  group_by(SITEID) %>%
  summarise(
    deviation_rate = 100 * mean(!is.na(DVREAS)),
    qtl_threshold = 15
  )
```

**4. Query Resolution Time**
```r
kri_query_time <- query_data %>%
  group_by(SITEID) %>%
  summarise(
    median_days = median(difftime(QRYDTC_RESOLVED, QRYDTC_OPENED, units="days")),
    qtl_threshold = 14  # 2 weeks
  )
```

**5. Assessment Window Violations**
```r
kri_window_violations <- study_data %>%
  group_by(SITEID) %>%
  summarise(
    violation_rate = 100 * mean(abs(ACTUAL_DAY - PLANNED_DAY) > 7),
    qtl_threshold = 20
  )
```

#### Enrollment KRIs

**6. Screening Failure Rate**
**7. Screen to Randomization Time**
**8. Dropout Rate**

#### Safety KRIs

**9. Serious Adverse Event (SAE) Reporting Timeliness**
**10. Grade 3+ AE Rate by Site**

### Dashboard Implementation

#### Shiny App Structure

```
app/
├── app.R              # Main app file
├── global.R           # Setup, data loading
├── ui.R               # User interface
├── server.R           # Server logic
└── modules/
    ├── kri_calculations.R
    ├── anomaly_detection.R
    └── visualizations.R
```

#### Key Features

**1. KRI Summary View**
- Traffic light system (red/yellow/green)
- Trend lines over time
- Alert count badges

**2. Site Performance Profile**
- Radar chart with all KRIs
- Drill-down to site-level details
- Historical trends

**3. Anomaly Detection**
- Multivariate outlier detection (Isolation Forest)
- Subject-level anomaly scores
- Investigation queue

**4. Missing Data Heatmap**
- Variables × Sites matrix
- Color-coded by missingness rate
- Identify patterns

**5. Alert Management**
- Automated alert generation when QTL exceeded
- Email notifications
- Action tracking

### Anomaly Detection Algorithm

#### Isolation Forest

```r
library(isotree)

detect_anomalies <- function(study_data) {
  # Select numeric features
  features <- study_data %>%
    select(AVAL, CHG, PCHG, AGE, BSTRAT1) %>%
    na.omit()
  
  # Train Isolation Forest
  iso_model <- isolation.forest(
    data = features,
    ntrees = 100,
    sample_size = 256
  )
  
  # Anomaly scores (higher = more anomalous)
  anomaly_scores <- predict(iso_model, features)
  
  # Flag top 5% as anomalies
  threshold <- quantile(anomaly_scores, 0.95)
  
  study_data$is_anomaly <- anomaly_scores > threshold
  study_data$anomaly_score <- anomaly_scores
  
  return(study_data)
}
```

---

## Project 3: NLP Adverse Events

### Objective

Automated extraction of adverse event terms from clinical narratives and suggestion of MedDRA codes.

### Clinical Workflow

**Current State (Manual):**
1. Investigator writes narrative: "Pt exp severe N/V after cycle 2 chemo"
2. Medical coder reads narrative
3. Coder searches MedDRA dictionary
4. Assigns codes: Nausea (10028813), Vomiting (10047700)
5. Time: 3-5 minutes per event

**AI-Assisted State:**
1. NLP model reads narrative
2. Extracts terms: "nausea", "vomiting"
3. Suggests MedDRA codes with confidence scores
4. Coder reviews and approves (or corrects)
5. Time: 30 seconds per event

**Time Savings:** 69+ hours per 1,000 coded terms

### Architecture

```
Clinical Narrative
       ↓
[Preprocessing]
       ↓
[BioBERT/ClinicalBERT]
       ↓
[Named Entity Recognition]
       ↓
[MedDRA Mapping]
       ↓
Coded Terms + Confidence
```

### BioBERT vs ClinicalBERT

**BioBERT:**
- Pre-trained on PubMed abstracts + PMC full-text articles
- Strong on biomedical terminology
- Best for: Drug names, diseases, procedures

**ClinicalBERT:**
- Pre-trained on MIMIC-III clinical notes
- Optimized for clinical narratives
- Best for: Symptoms, adverse events, clinical descriptions

**Recommendation:** Start with ClinicalBERT for AE extraction

### Implementation

#### Step 1: Download Pre-trained Model

```python
from transformers import AutoTokenizer, AutoModel

# Download ClinicalBERT
model_name = "emilyalsentzer/Bio_ClinicalBERT"

tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModel.from_pretrained(model_name)

# Save locally
tokenizer.save_pretrained("models/clinicalbert_tokenizer")
model.save_pretrained("models/clinicalbert_model")
```

#### Step 2: Named Entity Recognition

```python
from transformers import pipeline

# Load NER pipeline
ner_pipeline = pipeline(
    "ner",
    model="models/clinicalbert_model",
    tokenizer="models/clinicalbert_tokenizer",
    aggregation_strategy="simple"
)

# Extract entities
narrative = "Patient experienced severe nausea and vomiting after chemotherapy"

entities = ner_pipeline(narrative)

# Output:
# [
#   {'entity_group': 'ADVERSE_EVENT', 'word': 'nausea', 'score': 0.96},
#   {'entity_group': 'ADVERSE_EVENT', 'word': 'vomiting', 'score': 0.98}
# ]
```

#### Step 3: MedDRA Mapping (R)

```r
library(stringdist)
library(fuzzyjoin)

meddra_autocoder <- function(extracted_terms, meddra_dict, threshold = 0.95) {
  # Exact matches
  exact <- extracted_terms %>%
    inner_join(meddra_dict, by = c("term" = "llt_name")) %>%
    mutate(match_type = "exact", confidence = 1.0)
  
  # Fuzzy matches for remaining
  remaining <- anti_join(extracted_terms, exact, by = "term")
  
  fuzzy <- remaining %>%
    stringdist_left_join(
      meddra_dict,
      by = c("term" = "llt_name"),
      method = "jw",  # Jaro-Winkler
      max_dist = 0.15,
      distance_col = "distance"
    ) %>%
    mutate(
      match_type = "fuzzy",
      confidence = 1 - distance,
      auto_coded = confidence >= threshold
    )
  
  # Combine
  results <- bind_rows(exact, fuzzy)
  
  return(results)
}
```

### Expected Performance

**Extraction Accuracy:**
- Precision: 85-92% (correctly identified AEs)
- Recall: 78-88% (captured all AEs)
- F1 Score: 82-90%

**Coding Accuracy:**
- Exact matches: ~40% of terms
- Fuzzy matches >95% confidence: ~35% of terms
- Requiring manual review: ~25% of terms
- Overall auto-coding rate: 75%

**Time Savings:**
- Manual coding: 3-5 min/event
- AI-assisted: 0.5-1 min/event
- Reduction: 70-85%

---

## Integration with RECIST Pipeline

### Connecting ML Predictions to ADaM

```r
# Load RECIST BOR results
source("etl/adam_program_library/oncology_response/recist_11_core/derive_best_overall_response.sas")

adrs_bor <- read_sas("outputs/adrs_bor.sas7bdat")

# Add ML predictions
source("ai_ml_study/02_progression_prediction/scripts/step3_make_predictions.R")

adrs_ml <- adrs_bor %>%
  left_join(
    predict_progression_risk(adrs_bor),
    by = "USUBJID"
  ) %>%
  mutate(
    PDRISKFL = if_else(PDRISK_PROB > 0.70, "Y", "N"),
    PDRISKCL = case_when(
      PDRISK_PROB < 0.33 ~ "LOW",
      PDRISK_PROB < 0.67 ~ "MEDIUM",
      TRUE ~ "HIGH"
    )
  )
```

### Dashboard Integration

```r
# Launch dashboard with live RECIST data
shiny::runApp(
  "ai_ml_study/03_quality_dashboard/app",
  launch.browser = TRUE
)
```

---

## Testing & Validation

### Unit Tests (testthat)

```r
library(testthat)

test_that("Feature engineering creates expected columns", {
  test_data <- create_test_recist_data()
  features <- engineer_features(test_data)
  
  expect_true("baseline_sld" %in% names(features))
  expect_true("first_fu_pct_change" %in% names(features))
  expect_equal(nrow(features), n_distinct(test_data$USUBJID))
})

test_that("XGBoost predictions are valid probabilities", {
  model <- readRDS("models/xgboost_progression.rds")
  test_features <- create_test_features()
  
  preds <- predict(model, test_features)
  
  expect_true(all(preds >= 0 & preds <= 1))
  expect_equal(length(preds), nrow(test_features))
})
```

### Model Validation

**Internal Validation:**
- 5-fold cross-validation
- Bootstrap resampling (1000 iterations)
- Temporal validation (train on early, test on late data)

**External Validation:**
- Test on independent dataset (different study)
- Performance metrics on external cohort
- Subgroup analysis (by histology, line of therapy)

---

## Deployment Considerations

### Production Readiness

**Requirements:**
- [ ] Model versioning (MLflow, DVC)
- [ ] Monitoring/logging (model drift detection)
- [ ] API endpoints (Plumber for R, FastAPI for Python)
- [ ] Docker containers for reproducibility
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Documentation (roxygen2, Sphinx)

### Regulatory Compliance

**FDA 21 CFR Part 11:**
- Audit trails for model predictions
- Electronic signatures for model approvals
- Change control for model updates

**GAMP 5 / CSV:**
- Software validation documentation
- Installation/Operational/Performance Qualification (IQ/OQ/PQ)
- Traceability matrix

### Ethical Considerations

**Algorithmic Bias:**
- Subgroup performance analysis (age, race, sex)
- Fairness metrics (demographic parity, equalized odds)
- Mitigation strategies (resampling, fairness constraints)

**Transparency:**
- Explainable AI (SHAP values, LIME)
- Model cards documenting intended use, limitations
- Clear communication of confidence intervals

---

## Additional Resources

### Papers
- Eisenhauer et al. "RECIST 1.1" (2009)
- Rajkomar et al. "Ensuring Fairness in ML for Healthcare" (2018)
- Beam et al. "Big Data and ML in Healthcare" (2018)

### Tutorials
- XGBoost R Tutorial: https://xgboost.readthedocs.io
- Shiny Dashboard Guide: https://rstudio.github.io/shinydashboard/
- BioBERT Paper: https://arxiv.org/abs/1901.08746
- ClinicalBERT Repo: https://github.com/EmilyAlsentzer/clinicalBERT

### Communities
- Pharmaverse: https://pharmaverse.org
- R4DS Learning Community
- Hugging Face Forums (NLP)

---

**Last Updated:** December 20, 2024  
**Author:** Christian Baghai  
**Repository:** [sas-r-hybrid-clinical-pipeline](https://github.com/stiigg/sas-r-hybrid-clinical-pipeline)
