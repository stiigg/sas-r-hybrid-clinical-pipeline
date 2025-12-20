#!/usr/bin/env Rscript
# Train XGBoost model for progression prediction
# Includes cross-validation, hyperparameter tuning, and evaluation

library(tidyverse)
library(xgboost)
library(caret)
library(pROC)

set.seed(42)

train_xgboost_model <- function(features, n_folds = 5, save_model = TRUE) {
  
  cat("\n╔═══════════════════════════════════════════════════════\n")
  cat("║  XGBoost Model Training                                \n")
  cat("╚═══════════════════════════════════════════════════════\n\n")
  
  cat("→ Preparing data...\n")
  
  feature_cols <- features %>%
    select(-USUBJID, -progressed, -days_to_progression) %>%
    select(where(is.numeric)) %>%
    names()
  
  cat(sprintf("  Features: %d\n", length(feature_cols)))
  cat(sprintf("  Samples: %d\n", nrow(features)))
  
  features_clean <- features %>%
    mutate(across(all_of(feature_cols), 
                  ~if_else(is.na(.), median(., na.rm = TRUE), .)))
  
  train_idx <- createDataPartition(features_clean$progressed, p = 0.8, list = FALSE)
  train_data <- features_clean[train_idx, ]
  test_data <- features_clean[-train_idx, ]
  
  cat(sprintf("  Training set: %d subjects (%.1f%% progressed)\n", 
              nrow(train_data), 100 * mean(train_data$progressed)))
  cat(sprintf("  Test set: %d subjects (%.1f%% progressed)\n\n",
              nrow(test_data), 100 * mean(test_data$progressed)))
  
  dtrain <- xgb.DMatrix(
    data = as.matrix(train_data[, feature_cols]),
    label = as.numeric(train_data$progressed)
  )
  
  dtest <- xgb.DMatrix(
    data = as.matrix(test_data[, feature_cols]),
    label = as.numeric(test_data$progressed)
  )
  
  cat("→ Running cross-validation...\n")
  
  params <- list(
    objective = "binary:logistic",
    eval_metric = "auc",
    max_depth = 6,
    eta = 0.1,
    subsample = 0.8,
    colsample_bytree = 0.8,
    min_child_weight = 3,
    gamma = 0.1
  )
  
  cv_results <- xgb.cv(
    params = params,
    data = dtrain,
    nrounds = 200,
    nfold = n_folds,
    early_stopping_rounds = 20,
    verbose = 0
  )
  
  best_iteration <- cv_results$best_iteration
  best_cv_auc <- cv_results$evaluation_log$test_auc_mean[best_iteration]
  
  cat(sprintf("  Best iteration: %d\n", best_iteration))
  cat(sprintf("  CV AUC: %.4f\n\n", best_cv_auc))
  
  cat("→ Training final model...\n")
  
  model <- xgb.train(
    params = params,
    data = dtrain,
    nrounds = best_iteration,
    watchlist = list(train = dtrain, test = dtest),
    verbose = 0
  )
  
  cat("  ✓ Training complete\n\n")
  
  cat("→ Evaluating on test set...\n\n")
  
  test_preds <- predict(model, dtest)
  train_preds <- predict(model, dtrain)
  
  test_roc <- roc(test_data$progressed, test_preds, quiet = TRUE)
  train_roc <- roc(train_data$progressed, train_preds, quiet = TRUE)
  
  test_auc <- auc(test_roc)
  train_auc <- auc(train_roc)
  
  coords_optimal <- coords(test_roc, "best", ret = "all")
  optimal_threshold <- coords_optimal$threshold
  
  test_pred_class <- if_else(test_preds >= optimal_threshold, 1, 0)
  
  confusion <- table(Predicted = test_pred_class, Actual = test_data$progressed)
  
  tp <- confusion[2, 2]
  tn <- confusion[1, 1]
  fp <- confusion[2, 1]
  fn <- confusion[1, 2]
  
  sensitivity <- tp / (tp + fn)
  specificity <- tn / (tn + fp)
  accuracy <- (tp + tn) / sum(confusion)
  
  cat("╔═══════════════════════════════════════════════════════\n")
  cat("║  Model Performance Summary                             \n")
  cat("╚═══════════════════════════════════════════════════════\n\n")
  
  cat("AUC:\n")
  cat(sprintf("  Training:   %.4f\n", train_auc))
  cat(sprintf("  Test:       %.4f\n\n", test_auc))
  
  cat(sprintf("Metrics (threshold = %.3f):\n", optimal_threshold))
  cat(sprintf("  Accuracy:    %.1f%%\n", 100 * accuracy))
  cat(sprintf("  Sensitivity: %.1f%%\n", 100 * sensitivity))
  cat(sprintf("  Specificity: %.1f%%\n\n", 100 * specificity))
  
  importance <- xgb.importance(feature_names = feature_cols, model = model)
  
  cat("Top 10 Features:\n")
  print(head(importance, 10), row.names = FALSE)
  cat("\n")
  
  if (save_model) {
    dir.create("../models", showWarnings = FALSE, recursive = TRUE)
    dir.create("../outputs", showWarnings = FALSE, recursive = TRUE)
    
    xgb.save(model, "../models/xgboost_progression.model")
    
    model_results <- list(
      model = model,
      feature_names = feature_cols,
      params = params,
      test_auc = test_auc,
      optimal_threshold = optimal_threshold,
      sensitivity = sensitivity,
      specificity = specificity,
      accuracy = accuracy,
      confusion_matrix = confusion,
      test_roc = test_roc,
      importance = importance
    )
    
    saveRDS(model_results, "../models/xgboost_complete.rds")
    
    cat("✓ Model saved\n\n")
  }
  
  return(model_results)
}

create_evaluation_plots <- function(model_results) {
  cat("→ Creating plots...\n")
  dir.create("../outputs/plots", showWarnings = FALSE, recursive = TRUE)
  
  # ROC Curve
  png("../outputs/plots/roc_curve.png", width = 800, height = 600, res = 120)
  plot(model_results$test_roc, main = sprintf("ROC Curve (AUC = %.3f)", model_results$test_auc),
       col = "#2E86AB", lwd = 3)
  abline(a = 0, b = 1, lty = 2, col = "gray")
  dev.off()
  
  # Feature Importance
  top_features <- head(model_results$importance, 15)
  png("../outputs/plots/feature_importance.png", width = 1000, height = 700, res = 120)
  par(mar = c(5, 15, 4, 2))
  barplot(rev(top_features$Gain), names.arg = rev(top_features$Feature),
          horiz = TRUE, las = 1, col = "#06A77D",
          main = "Top 15 Feature Importance", xlab = "Gain")
  dev.off()
  
  cat("  ✓ Plots saved\n\n")
}

if (sys.nframe() == 0) {
  cat("\n╔═══════════════════════════════════════════════════════\n")
  cat("║   RECIST Progression - Model Training                 \n")
  cat("╚═══════════════════════════════════════════════════════\n")
  
  if (!file.exists("../data/engineered_features.csv")) {
    stop("❌ Features not found. Run step1_create_features.R first!")
  }
  
  cat("\n→ Loading features...\n")
  features <- read_csv("../data/engineered_features.csv", show_col_types = FALSE)
  cat(sprintf("  ✓ Loaded %d subjects\n", nrow(features)))
  
  model_results <- train_xgboost_model(features)
  create_evaluation_plots(model_results)
  
  cat("\n╔═══════════════════════════════════════════════════════\n")
  cat("║   Training Complete!                                    \n")
  cat("╚═══════════════════════════════════════════════════════\n")
  cat("\nNext: Rscript step3_make_predictions.R\n\n")
}
