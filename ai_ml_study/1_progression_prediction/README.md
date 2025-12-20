# Project 1: Tumor Progression Prediction

Machine learning model to predict disease progression using RECIST 1.1 tumor measurements.

## Quick Start

```bash
cd ai_ml_study/1_progression_prediction

# Run complete pipeline (5-10 minutes)
Rscript scripts/run_all.R

# Or step by step
Rscript scripts/step1_create_features.R
Rscript scripts/step2_train_model.R  
Rscript scripts/step3_make_predictions.R
```

## What This Does

Predicts which patients will experience tumor progression **before it happens** using:
- Baseline tumor characteristics
- Early treatment response patterns  
- Tumor growth velocity and acceleration
- Temporal trends

**Typical Performance**:
- AUC: 0.80-0.90 (excellent)
- Sensitivity: 75-85%
- Specificity: 80-90%

## Outputs Created

```
1_progression_prediction/
├── data/
│   └── engineered_features.csv          # 25+ ML features per patient
├── models/
│   ├── xgboost_progression.model       # Trained model
│   └── xgboost_complete.rds            # Full results object
└── outputs/
    ├── progression_predictions.csv     # Risk scores for all patients
    ├── prediction_report.txt           # Detailed text report
    └── plots/
        ├── roc_curve.png
        ├── feature_importance.png
        └── prediction_distribution.png
```

## How It Works

### Step 1: Feature Engineering

Transforms raw SDTM RS data into ML-ready features:

**Input (3 assessments)**:
```
Subject    Date        SLD(mm)
001-001    Day 0       100
001-001    Day 56      65  
001-001    Day 112     75
```

**Output (25+ features)**:
```
baseline_sld:          100mm
first_fu_change_pct:   -35%
nadir_change_pct:      -35%
overall_velocity:      -0.22 mm/day
acceleration:          +0.18 mm/day²  (tumor growing again!)
```

**Feature Categories**:
1. **Baseline** (2 features): Initial tumor size, lesion count
2. **Early Response** (6 features): First follow-up changes
3. **Nadir** (5 features): Best response achieved
4. **Velocity** (4 features): Rate of tumor change
5. **Acceleration** (2 features): Is growth speeding up?
6. **Patterns** (4 features): Consecutive changes, direction switches
7. **Temporal** (4 features): Time on study, assessment frequency

### Step 2: Model Training

XGBoost learns patterns from historical data:

1. **80/20 split**: Training vs. test sets
2. **5-fold cross-validation**: Find optimal parameters
3. **Early stopping**: Prevent overfitting
4. **Feature importance**: Identify key predictors

**Top Predictive Features** (typical):
1. First follow-up change % (most important!)
2. Tumor growth velocity
3. Baseline tumor size
4. Days to best response
5. Growth acceleration

### Step 3: Predictions

For each patient, generates:
- **Probability**: 0-100% risk of progression
- **Category**: Low (<30%), Medium (30-60%), High (>60%)
- **Binary**: Predicted Progression or Stable

**Example Output**:
```
Patient 001-001:
  Risk Score:        73%
  Category:          High Risk
  Baseline:          120mm
  Early Change:      -8% (poor response)
  Velocity:          +0.15 mm/day (growing)
  Recommendation:    Increase monitoring frequency
```

## Using Your Own Data

### Input Requirements

SDTM RS domain with columns:
- `USUBJID`: Subject ID
- `RSDTC`: Assessment date
- `RSSTRESC`: Sum of Longest Diameters (mm)
- `LESIONID`: Lesion identifier (optional)

### Customization

1. **Add features**: Edit `step1_create_features.R`
2. **Tune model**: Modify parameters in `step2_train_model.R`  
3. **Change threshold**: Adjust risk categories in `step3_make_predictions.R`

## Interpreting Results

### Model Performance

- **AUC > 0.80**: Excellent discrimination
- **AUC 0.70-0.80**: Good performance
- **AUC < 0.70**: May need more features or data

### Feature Importance

Tells you which variables matter most:
- High gain = strong predictor
- Helps validate clinical intuition
- Guides future data collection

### Risk Categories

**High Risk (>60%)**:
- Consider more frequent imaging
- Discuss treatment modifications
- Flag for close monitoring

**Low Risk (<30%)**:
- Standard monitoring schedule
- Likely good prognosis

## Troubleshooting

**Error: "Model not found"**
- Run `step2_train_model.R` first

**Low accuracy (<70%)**
- Need more training data (>50 patients ideal)
- Check data quality (missing values?)
- Try adding more features

**All predictions same class**
- Unbalanced data (too few progressions)
- Adjust decision threshold

## Next Steps

1. ✅ Run on demo data to verify it works
2. ✅ Review feature importance - does it make clinical sense?
3. ✅ Try with your own RECIST data
4. ✅ Tune parameters for your specific population
5. ✅ Integrate with main pipeline
6. ✅ Create presentation slides

## References

- XGBoost Algorithm: Chen & Guestrin, 2016
- RECIST 1.1: Eisenhauer et al., 2009
- Feature Engineering: Practical ML best practices

---

**Time Investment**: ~20 hours to fully understand and customize
**Difficulty**: Medium (R programming + basic ML concepts)
**Portfolio Value**: High (demonstrates modern clinical data science)
