import pyodbc
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random

# Connect to LocalDB
conn_str = (
    r'DRIVER={ODBC Driver 17 for SQL Server};'
    r'SERVER=(localdb)\MSSQLLocalDB;'
    r'DATABASE=NovaCRM;'
    r'Trusted_Connection=yes;'
)

# --- Generate Customers ---
np.random.seed(42)
random.seed(42)

n_customers = 500
start_date = datetime(2023, 1, 1)
end_date = datetime(2024, 6, 30)

industries = ['Technology', 'Healthcare', 'Finance', 'Retail', 'Manufacturing', 'Education']
plans = ['Starter', 'Growth', 'Enterprise']
plan_weights = [0.4, 0.35, 0.25]
channels = ['Google Ads', 'LinkedIn', 'Content Marketing', 'Referral', 'Cold Outreach', 'Webinar']

customers = []
for i in range(1, n_customers + 1):
    signup_date = start_date + timedelta(days=random.randint(0, (end_date - start_date).days))
    plan = np.random.choice(plans, p=plan_weights)
    industry = random.choice(industries)
    
    # Churn probability varies by plan
    churn_probs = {'Starter': 0.35, 'Growth': 0.20, 'Enterprise': 0.10}
    is_churned = random.random() < churn_probs[plan]
    
    if is_churned:
        min_tenure = 30
        max_tenure = (end_date - signup_date).days
        if max_tenure > min_tenure:
            churn_date = signup_date + timedelta(days=random.randint(min_tenure, max_tenure))
        else:
            churn_date = None
            is_churned = False
    else:
        churn_date = None
    
    customers.append({
        'customer_id': i,
        'company_name': f'Company_{i:04d}',
        'industry': industry,
        'signup_date': signup_date,
        'plan_tier': plan,
        'is_churned': 1 if is_churned else 0,
        'churn_date': churn_date
    })

df_customers = pd.DataFrame(customers)

# --- Generate Subscriptions ---
subscriptions = []
sub_id = 1
for _, cust in df_customers.iterrows():
    mrr_base = {'Starter': 49, 'Growth': 149, 'Enterprise': 499}
    current_mrr = mrr_base[cust['plan_tier']] + random.randint(-10, 30)
    current_date = cust['signup_date']
    end = cust['churn_date'] if cust['is_churned'] else end_date
    
    subscriptions.append({
        'subscription_id': sub_id,
        'customer_id': cust['customer_id'],
        'event_type': 'new',
        'event_date': current_date,
        'mrr_amount': current_mrr,
        'plan_tier': cust['plan_tier']
    })
    sub_id += 1
    
    # Random plan changes
    months_active = max(1, (end - current_date).days // 30)
    for m in range(1, months_active):
        if random.random() < 0.05:  # 5% chance of change per month
            event_date = current_date + timedelta(days=m * 30 + random.randint(-5, 5))
            if event_date < end:
                change = random.choice(['upgrade', 'downgrade'])
                if change == 'upgrade':
                    current_mrr = int(current_mrr * 1.3)
                else:
                    current_mrr = int(current_mrr * 0.7)
                subscriptions.append({
                    'subscription_id': sub_id,
                    'customer_id': cust['customer_id'],
                    'event_type': change,
                    'event_date': event_date,
                    'mrr_amount': current_mrr,
                    'plan_tier': cust['plan_tier']
                })
                sub_id += 1
    
    if cust['is_churned'] and cust['churn_date']:
        subscriptions.append({
            'subscription_id': sub_id,
            'customer_id': cust['customer_id'],
            'event_type': 'cancellation',
            'event_date': cust['churn_date'],
            'mrr_amount': 0,
            'plan_tier': cust['plan_tier']
        })
        sub_id += 1

df_subscriptions = pd.DataFrame(subscriptions)

# --- Generate Marketing Touchpoints ---
touchpoints = []
tp_id = 1
channel_costs = {
    'Google Ads': (50, 200),
    'LinkedIn': (80, 300),
    'Content Marketing': (10, 50),
    'Referral': (0, 20),
    'Cold Outreach': (30, 100),
    'Webinar': (20, 80)
}

for _, cust in df_customers.iterrows():
    n_touches = random.randint(2, 7)
    days_before = sorted(random.sample(range(1, 90), min(n_touches, 89)), reverse=True)
    
    for days in days_before:
        tp_date = cust['signup_date'] - timedelta(days=days)
        channel = random.choice(channels)
        cost_range = channel_costs[channel]
        cost = round(random.uniform(cost_range[0], cost_range[1]), 2)
        
        touchpoints.append({
            'touchpoint_id': tp_id,
            'customer_id': cust['customer_id'],
            'channel': channel,
            'touchpoint_date': tp_date,
            'cost': cost,
            'is_conversion': 1 if days == min(days_before) else 0
        })
        tp_id += 1

df_touchpoints = pd.DataFrame(touchpoints)

# --- Generate Revenue Events ---
revenue_events = []
rev_id = 1
for _, cust in df_customers.iterrows():
    current_date = cust['signup_date']
    end = cust['churn_date'] if cust['is_churned'] else end_date
    mrr = mrr_base = {'Starter': 49, 'Growth': 149, 'Enterprise': 499}[cust['plan_tier']]
    
    while current_date < end:
        revenue_events.append({
            'event_id': rev_id,
            'customer_id': cust['customer_id'],
            'event_date': current_date,
            'amount': mrr + random.randint(-5, 15),
            'event_type': 'payment'
        })
        rev_id += 1
        current_date += timedelta(days=30)

df_revenue = pd.DataFrame(revenue_events)

# --- Load into SQL Server ---
conn = pyodbc.connect(conn_str)
cursor = conn.cursor()

# Insert customers
for _, row in df_customers.iterrows():
    cursor.execute("""
        INSERT INTO customers (customer_id, company_name, industry, signup_date, plan_tier, is_churned, churn_date)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, row['customer_id'], row['company_name'], row['industry'],
       row['signup_date'], row['plan_tier'], row['is_churned'],
       row['churn_date'] if pd.notna(row['churn_date']) else None)

# Insert subscriptions
for _, row in df_subscriptions.iterrows():
    cursor.execute("""
        INSERT INTO subscriptions (subscription_id, customer_id, event_type, event_date, mrr_amount, plan_tier)
        VALUES (?, ?, ?, ?, ?, ?)
    """, row['subscription_id'], row['customer_id'], row['event_type'],
       row['event_date'], row['mrr_amount'], row['plan_tier'])

# Insert touchpoints
for _, row in df_touchpoints.iterrows():
    cursor.execute("""
        INSERT INTO marketing_touchpoints (touchpoint_id, customer_id, channel, touchpoint_date, cost, is_conversion)
        VALUES (?, ?, ?, ?, ?, ?)
    """, row['touchpoint_id'], row['customer_id'], row['channel'],
       row['touchpoint_date'], row['cost'], row['is_conversion'])

# Insert revenue events
for _, row in df_revenue.iterrows():
    cursor.execute("""
        INSERT INTO revenue_events (event_id, customer_id, event_date, amount, event_type)
        VALUES (?, ?, ?, ?, ?)
    """, row['event_id'], row['customer_id'], row['event_date'],
       row['amount'], row['event_type'])

conn.commit()
conn.close()
print(f"Data loaded: {len(df_customers)} customers, {len(df_subscriptions)} subscriptions, {len(df_touchpoints)} touchpoints, {len(df_revenue)} revenue events")