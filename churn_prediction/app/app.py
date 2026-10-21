"""Streamlit app for churn prediction demo.

The app shows overall KPIs, a risk revenue calculator and an interactive
simulator for a single customer.
"""

import streamlit as st
import pandas as pd
import numpy as np
from pathlib import Path
import joblib

# Load model and preprocessor (same as in src.predict)
PROJECT_ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = PROJECT_ROOT / "models"
_preprocessor = joblib.load(MODEL_DIR / "preprocessor.joblib")
_model = joblib.load(MODEL_DIR / "best_model.joblib")

# Load the full dataset for KPI calculations
DATA_PATH = PROJECT_ROOT / "data" / "synthetic_churn.csv"
if DATA_PATH.is_file():
    df_full = pd.read_csv(DATA_PATH)
else:
    st.error("Dataset not found. Please run generate_data.py first.")
    st.stop()

st.set_page_config(page_title="Churn Prediction Dashboard", layout="wide")
st.title("📊 Churn Prediction & Business Impact Dashboard")

# --- KPI Section -----------------------------------------------------------
col1, col2, col3 = st.columns(3)

churn_rate = df_full["churn"].mean()
total_mrr = df_full["monthly_charges"].sum()
risk_mrr = (df_full.loc[df_full["churn"] == 1, "monthly_charges"].sum())

col1.metric("Overall Churn Rate", f"{churn_rate:.2%}")
col2.metric("Total Monthly Recurring Revenue (MRR)", f"${total_mrr:,.0f}")
col3.metric("Revenue at Risk (MRR)", f"${risk_mrr:,.0f}")

st.markdown("---")

# --- Individual Customer Simulator ------------------------------------------
st.header("🔎 Individual Customer Risk Simulator")
st.caption("Adjust the sliders to model a hypothetical customer and see the churn probability.")

with st.form(key="simulator_form"):
    tenure = st.slider("Tenure (months)", 0, 60, 12)
    plan_type = st.selectbox("Plan Type", ["Basic", "Standard", "Premium"], index=0)
    contract_type = st.selectbox("Contract Type", ["Monthly", "Annual", "Biennial"], index=1)
    monthly_charges = st.slider("Monthly Charges (USD)", 50, 1500, 300, step=10)
    num_logins = st.slider("Number of Logins (last month)", 0, 200, 30)
    support_tickets = st.slider("Support Tickets (last month)", 0, 20, 0)
    submitted = st.form_submit_button("Predict Churn")

if submitted:
    # Build a single‑row DataFrame matching training features
    input_df = pd.DataFrame({
        "tenure_months": [tenure],
        "monthly_charges": [monthly_charges],
        "total_charges": [monthly_charges * tenure],
        "num_logins": [num_logins],
        "support_tickets": [support_tickets],
        "contract_type": [contract_type],
        "plan_type": [plan_type],
    })
    X = _preprocessor.transform(input_df)
    prob = _model.predict_proba(X)[0, 1]

    # Visual risk indicator
    if prob < 0.3:
        risk_color = "🟢 Low"
    elif prob < 0.6:
        risk_color = "🟡 Medium"
    else:
        risk_color = "🔴 High"

    st.subheader("📈 Prediction Result")
    st.write(f"**Churn probability:** {prob:.2%} ({risk_color})")

    # Simple financial impact: assume 30% of at‑risk customers are saved
    potential_save = monthly_charges * 0.3
    st.write(f"**Potential revenue saved (30% recovery):** ${potential_save:,.0f} per month")

    # Suggested actions (very basic rule‑based)
    actions = []
    if tenure < 6:
        actions.append("✅ Onboard with a success manager")
    if support_tickets > 2:
        actions.append("🛠️ Prioritize support ticket resolution")
    if num_logins < 5:
        actions.append("📧 Send product usage tips email")
    if actions:
        st.markdown("**Recommended actions:**")
        for a in actions:
            st.write(a)
    else:
        st.write("✅ Customer appears engaged – keep current success cadence.")

st.markdown("---")
st.caption("*This demo uses a synthetic dataset and a simple model. In production you would replace the data generation step with real CRM data and potentially a more sophisticated model.*")
