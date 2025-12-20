# Quick Demo: ML Prediction in 5 Minutes

## What This Does

Creates a simple machine learning model that predicts tumor progression risk from baseline and early follow-up data.

**You'll see:**
- Model training in real-time
- Risk predictions for sample patients
- Feature importance (what matters most)

## Run It

```bash
# From repository root
Rscript ai_ml_study/01_quick_demo/quick_demo.R
```

## Expected Output

```
=== Training Progression Prediction Model ===

Training data: 100 patients
Progression rate: 30.0%

[Training XGBoost model...]
✓ Model trained in 2.3 seconds
Training AUC: 0.85

=== Sample Predictions ===

Patient A (Baseline: 110mm, Change: -15%)
  → Progression Risk: 28.3% [LOW]
  
Patient B (Baseline: 130mm, Change: +5%)
  → Progression Risk: 72.1% [HIGH] ⚠️
  
Patient C (Baseline: 95mm, Change: -35%)
  → Progression Risk: 12.7% [LOW]

=== Feature Importance ===
1. first_followup_change_pct: 0.67 (most important)
2. baseline_tumor_mm: 0.33

✓ Demo complete!
```

## What's Happening Behind the Scenes

1. **Generate Training Data**: Creates 100 synthetic patients with tumor measurements
2. **Train Model**: Uses XGBoost (gradient boosting) to learn patterns
3. **Make Predictions**: Applies model to 3 new patients
4. **Show Importance**: Reveals which features matter most

## Next Steps

### Understand the Code
Open `quick_demo.R` and read the comments - it's heavily annotated.

### Use Real RECIST Data
Modify line 10 to use your actual demo data:
```r
# Instead of synthetic data:
training_data <- read_csv("../../demo/data/test_sdtm_rs.csv")
```

### Expand to Full Implementation
Move to `02_progression_prediction/` for the complete pipeline with:
- Feature engineering from RECIST data
- Cross-validation
- Model evaluation metrics (ROC curves, confusion matrix)
- Hyperparameter tuning
- Integration with your ADRS datasets

## Troubleshooting

**Error: Package 'xgboost' not found**
```r
install.packages("xgboost")
install.packages("tidyverse")
```

**Want more patients/features?**
Edit the parameters in `quick_demo.R`:
```r
n_patients <- 500  # Increase from 100
```

## Why This Matters

This 40-line script demonstrates:
- ✅ Machine learning fundamentals
- ✅ Clinical prediction use case
- ✅ Real-world application (progression risk assessment)
- ✅ Industry-relevant technology (XGBoost used by pharma)

Perfect for explaining ML concepts in interviews or client calls.
