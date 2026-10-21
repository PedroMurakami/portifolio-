"""Prediction utilities for the churn model.

Provides a simple :func:`predict_churn` function that takes a pandas DataFrame
with the same features as the training data (excluding ``customer_id`` and
``churn``) and returns the predicted probability of churn.
"""

import joblib
import pandas as pd
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = PROJECT_ROOT / "models"

# Load artifacts once (lazy loading could be added for performance)
_preprocessor = joblib.load(MODEL_DIR / "preprocessor.joblib")
_model = joblib.load(MODEL_DIR / "best_model.joblib")


def predict_churn(df: pd.DataFrame) -> pd.Series:
    """Return churn probability for each row in ``df``.

    Parameters
    ----------
    df: pd.DataFrame
        Input features (must contain all columns used during training except the
        target ``churn`` and the identifier ``customer_id``).

    Returns
    -------
    pd.Series
        Probabilities in the range ``[0, 1]``.
    """
    # Ensure column order matches training (preprocessor will select needed cols)
    X = _preprocessor.transform(df)
    # XGBoost, RandomForest and LogisticRegression implement ``predict_proba``
    prob = _model.predict_proba(X)[:, 1]
    return pd.Series(prob, index=df.index, name="churn_probability")
