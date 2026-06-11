import pyodbc
import pandas as pd
import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

# Connect to NovaCRM LocalDB
conn_str = (
    r'DRIVER={ODBC Driver 17 for SQL Server};'
    r'SERVER=(localdb)\MSSQLLocalDB;'
    r'DATABASE=NovaCRM;'
    r'Trusted_Connection=yes;'
)
conn = pyodbc.connect(conn_str)

# Pull raw database tables
df_customers = pd.read_sql("SELECT customer_id, signup_date, plan_tier, is_churned, churn_date FROM customers", conn)
df_subs = pd.read_sql("SELECT customer_id, event_type, mrr_amount FROM subscriptions", conn)
df_revenue = pd.read_sql("SELECT customer_id, event_date, amount FROM revenue_events", conn)

# Feature engineering
today = pd.Timestamp('2024-06-30')

# 1. Tenure
df_customers['signup_date'] = pd.to_datetime(df_customers['signup_date'])
df_customers['tenure_months'] = ((today - df_customers['signup_date']).dt.days / 30).astype(int)

# 2. Plan Tier numeric mapping
plan_map = {'Starter': 1, 'Growth': 2, 'Enterprise': 3}
df_customers['plan_numeric'] = df_customers['plan_tier'].map(plan_map)

# 3. Plan changes (upgrades/downgrades)
plan_changes = df_subs[df_subs['event_type'].isin(['upgrade', 'downgrade'])].groupby('customer_id').size().reset_index(name='plan_change_count')

# 4. Avg MRR
avg_mrr = df_subs.groupby('customer_id')['mrr_amount'].mean().reset_index(name='avg_mrr')

# 5. Total revenue and days since last payment
df_revenue['event_date'] = pd.to_datetime(df_revenue['event_date'])
rev_features = df_revenue.groupby('customer_id').agg(
    total_revenue=('amount', 'sum'),
    last_payment_date=('event_date', 'max')
).reset_index()
rev_features['days_since_last_payment'] = (today - rev_features['last_payment_date']).dt.days

# Combine everything
df_features = df_customers[['customer_id', 'tenure_months', 'plan_numeric', 'is_churned']].copy()
df_features = df_features.merge(plan_changes, on='customer_id', how='left')
df_features = df_features.merge(avg_mrr, on='customer_id', how='left')
df_features = df_features.merge(rev_features[['customer_id', 'total_revenue', 'days_since_last_payment']], on='customer_id', how='left')

df_features = df_features.fillna(0)
print(f"Features created for {len(df_features)} customers.")


# Define features (X) and target (y)
feature_cols = ['tenure_months', 'plan_numeric', 'plan_change_count', 'avg_mrr', 'total_revenue', 'days_since_last_payment']
X = df_features[feature_cols]
y = df_features['is_churned']

# Train/test split (80/20)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Scale features so large numbers don't drown out smaller values
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# Fit Logistic Regression
model = LogisticRegression(random_state=42, max_iter=1000)
model.fit(X_train_scaled, y_train)

# Output evaluation metrics
accuracy = model.score(X_test_scaled, y_test)
print(f"Model accuracy: {accuracy:.2%}")

# Generate risk scores (0-100) across ALL customers
X_all_scaled = scaler.transform(X)
churn_probabilities = model.predict_proba(X_all_scaled)[:, 1]
df_features['churn_risk_score'] = (churn_probabilities * 100).astype(int)

# Bin into actionable bands
df_features['risk_band'] = pd.cut(
    df_features['churn_risk_score'],
    bins=[0, 30, 60, 100],
    labels=['Low', 'Medium', 'High']
)
print(df_features['risk_band'].value_counts())


# Create the churn_risk_scores table in local database
cursor = conn.cursor()
cursor.execute("IF OBJECT_ID('churn_risk_scores', 'U') IS NOT NULL DROP TABLE churn_risk_scores;")
cursor.execute("""
    CREATE TABLE churn_risk_scores (
        customer_id INT PRIMARY KEY,
        churn_risk_score INT NOT NULL,
        risk_band NVARCHAR(10) NOT NULL,
        scored_date DATE NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    );
""")

# Insert rows
insert_sql = "INSERT INTO churn_risk_scores (customer_id, churn_risk_score, risk_band, scored_date) VALUES (?, ?, ?, ?)"
scored_date = '2024-06-30'
rows = [
    (int(row['customer_id']), int(row['churn_risk_score']), str(row['risk_band']), scored_date)
    for _, row in df_features.iterrows()
]

cursor.executemany(insert_sql, rows)
conn.commit()
print(f"Inserted {len(rows)} risk scores into SQL Server successfully!")
conn.close()


