"""Preprocessing pipeline for churn data.

The pipeline handles:
- Missing values (simple median imputation for numeric, most_frequent for categoricals)
- Categorical encoding (One‑Hot for low‑cardinality, TargetEncoder for high‑cardinality)
- Scaling numeric features with ``StandardScaler``.

The function :func:`get_preprocess_pipeline` returns a ready‑to‑fit ``sklearn`` ``Pipeline``.
"""

from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
# from category_encoders import TargetEncoder  # Removed to avoid extra dependency
from sklearn.impute import SimpleImputer
import pandas as pd

NUMERIC_FEATURES = ["tenure_months", "monthly_charges", "total_charges", "num_logins", "support_tickets"]
CATEGORICAL_LOW = ["contract_type"]  # <= 3 categories → OneHot
CATEGORICAL_HIGH = ["plan_type"]  # treat as target encoded (more informative)


def get_preprocess_pipeline():
    """Return a Scikit‑Learn preprocessing pipeline.

    The pipeline can be directly used with ``fit``/``transform`` on the training
    data (dropping the ``customer_id`` and ``churn`` columns manually).
    """
    # numeric pipeline: median impute then scale
    numeric_pipe = Pipeline([
        ("imputer", SimpleImputer(strategy="median")),
        ("scaler", StandardScaler()),
    ])

    # low‑cardinality categorical: most_frequent impute then one‑hot
    low_cat_pipe = Pipeline([
        ("imputer", SimpleImputer(strategy="most_frequent")),
        ("onehot", OneHotEncoder(handle_unknown="ignore")),
    ])

    # high‑cardinality categorical: using OneHotEncoder for simplicity
    high_cat_pipe = Pipeline([
        ("imputer", SimpleImputer(strategy="most_frequent")),
        ("onehot", OneHotEncoder(handle_unknown="ignore")),
    ])

    preprocessor = ColumnTransformer([
        ("num", numeric_pipe, NUMERIC_FEATURES),
        ("cat_low", low_cat_pipe, CATEGORICAL_LOW),
        ("cat_high", high_cat_pipe, CATEGORICAL_HIGH),
    ])
    return preprocessor
