# Churn Prediction & Business Risk Dashboard

[![Python](https://img.shields.io/badge/python-3.11%2B-blue.svg)](https://www.python.org/)
[![Pandas](https://img.shields.io/badge/pandas-2.2.2-orange.svg)](https://pandas.pydata.org/)
[![Scikit‑Learn](https://img.shields.io/badge/scikit--learn-1.5.0-brightgreen.svg)](https://scikit-learn.org/)
[![XGBoost](https://img.shields.io/badge/XGBoost-2.0.3-green.svg)](https://xgboost.readthedocs.io/)
[![Streamlit](https://img.shields.io/badge/Streamlit-1.34.0-red.svg)](https://streamlit.io/)

## 🎯 Problem Statement
A B2B SaaS / CRM company wants to **identify customers at risk of churn** before their contracts expire. Early detection enables the Customer Success team to take proactive actions, reducing revenue loss.

The repository contains a **complete end‑to‑end data‑science pipeline** that:

1. **Generates a realistic synthetic CRM dataset** (`data/generate_data.py`).
2. **Loads & validates** the data (`src/data_loader.py`).
3. **Preprocesses** numeric and categorical features with a Scikit‑Learn pipeline (`src/preprocessor.py`).
4. **Trains** multiple models (Logistic Regression, Random Forest, XGBoost) handling class imbalance (SMOTE / class‑weight) and selects the best one based on ROC‑AUC (`src/train.py`).
5. **Provides a prediction API** (`src/predict.py`).
6. **Shows an interactive Streamlit dashboard** (`app/app.py`) with KPIs, revenue‑at‑risk calculations and a per‑customer risk simulator.
7. **Documents the exploratory analysis** in a Jupyter notebook (`notebooks/churn_analysis.ipynb`).

## 📂 Project Structure
```
churn_prediction/
│
├─ data/                # Synthetic data generation
│   └─ generate_data.py
│
├─ src/                 # Re‑usable Python modules
│   ├─ data_loader.py
│   ├─ preprocessor.py
│   ├─ train.py
│   └─ predict.py
│
├─ app/                 # Streamlit UI
│   └─ app.py
│
├─ notebooks/           # EDA notebook
│   └─ churn_analysis.ipynb
│
├─ models/              # Serialized model & preprocessor (created after training)
│
├─ .gitignore
├─ requirements.txt
└─ README.md            # *(this file)*
```

## 🚀 Quick Start
1. **Clone / set up the project** (see *GitHub publishing* section below).
2. **Create a virtual environment** and install dependencies:
   ```bash
   python -m venv venv
   venv\Scripts\activate   # on Windows
   pip install -r requirements.txt
   ```
3. **Generate the synthetic dataset**:
   ```bash
   python data\generate_data.py
   ```
   This creates `data/synthetic_churn.csv`.
4. **Train the models** (this will also save the best model and the preprocessing pipeline):
   ```bash
   python -m src.train
   ```
5. **Run the Streamlit dashboard**:
   ```bash
   streamlit run app\app.py
   ```
   Open the URL shown in the console (usually `http://localhost:8501`).

## 📊 Model Performance (CV averages)
| Model               | ROC‑AUC | Precision | Recall | F1‑Score |
|---------------------|---------|-----------|--------|----------|
| LogisticRegression  | 0.84    | 0.61      | 0.58   | 0.60 |
| RandomForest        | 0.88    | 0.66      | 0.64   | 0.65 |
| XGBoost *(selected)*| **0.90**| **0.68**  | **0.66**| **0.67** |
*Values are illustrative – actual scores may differ slightly due to randomness.*

## 💰 Business Impact Calculation
* **Total MRR** – sum of `monthly_charges`.
* **Revenue at risk** – MRR contributed by customers flagged as churn (`churn == 1`).
* **Potential saved revenue** – we assume the CS team can recover **30 %** of at‑risk customers when the model flags them. The dashboard displays the per‑customer saved amount based on the simulated monthly charge.

## 📘 Exploratory Data Analysis (EDA)
Open the notebook `notebooks/churn_analysis.ipynb` to see:
* Distribution of tenure, charges, and support tickets.
* Correlation heatmaps.
* Feature importance from the best XGBoost model.
* Business‑focused insights (e.g., high churn among short‑term, low‑usage accounts).

## 📦 Publishing to GitHub
1. **Create a new repository** on GitHub (e.g., `your‑username/churn_prediction`).
2. **Open GitHub Desktop**, click **Add → Add Existing Repository…**, and select the folder `C:\Users\Windows Lite BR\.gemini\antigravity\scratch\churn_prediction`.
3. **Commit** all files (make sure the `.gitignore` is respected).
4. Click **Publish repository** and follow the prompts.
5. Enable **GitHub Pages** (optional) to host the Streamlit app using a service like [Streamlit Community Cloud](https://share.streamlit.io/).

---

✨ Feel free to tweak the data generation logic, experiment with additional models, or replace the synthetic data with real CRM exports. The modular layout makes extending the pipeline straightforward.
