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

