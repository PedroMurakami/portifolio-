import numpy as np
import pandas as pd


def generate_synthetic_data(n_samples: int = 5000, random_state: int = 42) -> pd.DataFrame:
    """Generate a realistic synthetic B2B SaaS churn dataset.

    Parameters
    ----------
    n_samples: int
        Number of customers to simulate.
    random_state: int
        Seed for reproducibility.

    Returns
    -------
    pd.DataFrame
        DataFrame with synthetic features and a binary ``churn`` target.
    """
    rng = np.random.default_rng(random_state)

    # Customer ID
    customer_id = [f"CUST{100000 + i}" for i in range(n_samples)]

    # Tenure (months) – longer tenure reduces churn probability
    tenure = rng.integers(1, 61, size=n_samples)  # up to 5 years

    # Monthly charges – depends on plan type, add some noise
    plan_type = rng.choice(["Basic", "Standard", "Premium"], size=n_samples, p=[0.5, 0.35, 0.15])
    base_price = {"Basic": 100, "Standard": 300, "Premium": 700}
    monthly_charges = np.array([base_price[t] for t in plan_type])
    monthly_charges = monthly_charges * rng.uniform(0.9, 1.1, size=n_samples)

    # Total charges – cumulative revenue
    total_charges = monthly_charges * tenure + rng.normal(0, 200, size=n_samples)

    # Engagement metrics
    num_logins = rng.poisson(lam=30 - tenure * 0.2)  # more senior customers login less often
    num_logins = np.clip(num_logins, 0, None)

    # Support tickets – higher churn risk if many tickets
    support_tickets = rng.poisson(lam=0.5 + (tenure < 12) * 1.0)

    # Contract type (categorical)
    contract_type = rng.choice(["Monthly", "Annual", "Biennial"], size=n_samples, p=[0.4, 0.5, 0.1])

    # Churn probability – logistic model using some key features
    # Coefficients chosen to reflect business intuition
    logit = (
        -0.03 * tenure
        + 0.001 * monthly_charges / 100
        + 0.5 * (support_tickets > 2).astype(int)
        - 0.2 * (contract_type == "Annual").astype(int)
        - 0.3 * (plan_type == "Premium").astype(int)
        + 0.2 * (plan_type == "Basic").astype(int)
        + rng.normal(0, 0.5, size=n_samples)  # noise
    )
    churn_prob = 1 / (1 + np.exp(-logit))
    churn = rng.binomial(1, churn_prob)

    df = pd.DataFrame({
        "customer_id": customer_id,
        "tenure_months": tenure,
        "monthly_charges": monthly_charges.round(2),
        "total_charges": total_charges.round(2),
        "num_logins": num_logins,
        "support_tickets": support_tickets,
        "contract_type": contract_type,
        "plan_type": plan_type,
        "churn": churn,
    })
    return df


if __name__ == "__main__":
    df = generate_synthetic_data()
    df.to_csv(Path(__file__).resolve().parent / "synthetic_churn.csv", index=False)
    print("Synthetic dataset saved to synthetic_churn.csv (rows:", len(df), ")")
