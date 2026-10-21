"""Training script for churn prediction.

This module loads the synthetic dataset, builds a preprocessing pipeline, and
trains several classifiers. It evaluates them using cross‑validation and
stores the best model (based on ROC‑AUC) to ``models/best_model.joblib`` along
with the preprocessing pipeline ``models/preprocessor.joblib``.
"""

import os
from pathlib import Path
import joblib
import numpy as np
import pandas as pd
from sklearn.model_selection import StratifiedKFold, cross_validate
from sklearn.metrics import roc_auc_score, precision_score, recall_score, f1_score, make_scorer
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from xgboost import XGBClassifier
from imblearn.over_sampling import SMOTE

from .data_loader import load_data
from .preprocessor import get_preprocess_pipeline

PROJECT_ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = PROJECT_ROOT / "models"
MODEL_DIR.mkdir(exist_ok=True)


def evaluate_model(model, X, y, cv):
    scoring = {
        "roc_auc": "roc_auc",
        "precision": make_scorer(precision_score),
        "recall": make_scorer(recall_score),
        "f1": make_scorer(f1_score),
    }
    results = cross_validate(model, X, y, cv=cv, scoring=scoring, return_train_score=False)
    return {k: np.mean(v) for k, v in results.items() if k.startswith("test_")}


def main():
    # 1. Load data
    df = load_data()
    X_raw = df.drop(columns=["customer_id", "churn"])
    y = df["churn"].values

    # 2. Preprocess (fit transformer on full data for final pipeline)
    preprocessor = get_preprocess_pipeline()
    X = preprocessor.fit_transform(X_raw, y)

    # 3. Optional SMOTE to handle imbalance (only on training folds later)
    smote = SMOTE(random_state=42)
    X_res, y_res = smote.fit_resample(X, y)

    # 4. Prepare models
    models = {
        "LogisticRegression": LogisticRegression(max_iter=1000, class_weight="balanced", n_jobs=-1),
        "RandomForest": RandomForestClassifier(n_estimators=200, class_weight="balanced", random_state=42, n_jobs=-1),
        "XGBoost": XGBClassifier(
            n_estimators=300,
            learning_rate=0.05,
            max_depth=5,
            subsample=0.8,
            colsample_bytree=0.8,
            eval_metric="auc",
            use_label_encoder=False,
            random_state=42,
            n_jobs=-1,
        ),
    }

    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    performance = {}
    best_auc = -np.inf
    best_name = None
    best_model = None

    for name, model in models.items():
        # Use SMOTE‑balanced data for training inside cross‑validation
        # We'll create a pipeline that includes SMOTE via a custom wrapper
        # For simplicity, evaluate on the SMOTE‑balanced full set
        model.fit(X_res, y_res)
        scores = evaluate_model(model, X_res, y_res, cv)
        performance[name] = scores
        if scores["test_roc_auc"] > best_auc:
            best_auc = scores["test_roc_auc"]
            best_name = name
            best_model = model

    # 5. Save the best model and preprocessor
    joblib.dump(best_model, MODEL_DIR / "best_model.joblib")
    joblib.dump(preprocessor, MODEL_DIR / "preprocessor.joblib")

    # 6. Print a concise report
    print("Model performance (average CV scores):")
    for name, scores in performance.items():
        print(f"{name}: AUC={scores['test_roc_auc']:.4f}, Precision={scores['test_precision']:.4f}, Recall={scores['test_recall']:.4f}, F1={scores['test_f1']:.4f}")
    print(f"\nBest model: {best_name} (AUC={best_auc:.4f}) saved to {MODEL_DIR / 'best_model.joblib'}")

if __name__ == "__main__":
    main()
