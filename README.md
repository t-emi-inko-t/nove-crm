# Revenue Operations (RevOps) Analytics & Churn Prediction Pipeline

Every subscription business lives and dies by three questions: *Why are customers leaving? How much does it cost to acquire new ones? Which marketing channels bring in the most profitable customers?* 

This project implements a complete end-to-end Revenue Operations (RevOps) data pipeline for **NovaCRM**, a B2B SaaS company. It loads synthetic customer lifecycle data into a SQL database, runs advanced analytical SQL queries, trains a machine learning model to predict individual churn risk, and visualizes all insights in an interactive Power BI dashboard.

## 🚀 Tech Stack & Architecture
* **Database:** SQL Server LocalDB
* **Data Engineering & Analysis:** T-SQL (CTEs, Window Functions, Views)
* **Data Generation & Machine Learning:** Python 3 (pandas, numpy, pyodbc, scikit-learn)
* **Business Intelligence:** Power BI Desktop

---

## 📊 Database Schema
The database uses a normalized star-like schema mapping 18 months (Jan 2023–June 2024) of SaaS customer behavior across 500 accounts and 2,000+ interactions:
* `customers`: Core account metadata (industry, signup date, plan tier, churn status).
* `subscriptions`: MRR lifecycle events (signups, upgrades, downgrades, cancellations).
* `marketing_touchpoints`: Multi-touch pre-conversion marketing touchpoint logs and channel cost.
* `revenue_events`: Granular monthly transaction logs.
* `churn_risk_scores` *(Engineered via ML)*: Individual customer churn probabilities and risk bands.

---

## 🔍 Analytical SQL Highlights (T-SQL)
I built three modular SQL views to power my Power BI visuals on the fly:

1. **Cohort Retention Analysis (`vw_cohort_retention`)**
   Tracks monthly signup cohorts over an 18-month decay curve. It leverages cross-joins with sequential series to produce continuous matrices without gap gaps in inactive months.
2. **Unit Economics & Health Scorecard (`vw_unit_economics`)**
   Aggregates Lifetime Value (LTV) and Customer Acquisition Cost (CAC) by channel and tier. It assigns a status flag (`Healthy` if LTV:CAC ≥ 3, `Warning`, or `Unhealthy`) to alert stakeholders of inefficient ad spend.
3. **Attribution Model Comparison (`vw_attribution_comparison`)**
   Unions **First-Touch**, **Last-Touch**, **Linear**, and **Time-Decay** attribution models. The time-decay model utilizes an exponential half-life decay formula `POWER(0.5, days_before_conversion / 7.0)` to assign heavier credit to touchpoints occurring closer to the purchase decision. It handles zero-touchpoint anomalies gracefully using `NULLIF` to prevent division-by-zero database crashes.

---

## 🧠 Machine Learning: Churn Risk Scoring
To move from descriptive to predictive analytics, I built a Python-based machine learning module (`churn_model.py`):
* **Feature Engineering:** Extracted six behavior-based predictors per account: tenure, plan value, upgrade/downgrade count, average MRR, total spend, and days since last payment.
* **Model:** Trained a scaled **Logistic Regression** model using `scikit-learn` with an 80/20 train-test split.
* **Scoring Pipeline:** Generated a 0-100 risk score and mapped customers into Low, Medium, and High risk bands. The script automatically drops and rebuilds `churn_risk_scores` in SQL Server using batch execution (`executemany`) for maximum load efficiency.

---

## 🖥️ Power BI Executive Dashboard
The Power BI dashboard brings the pipeline together into a single, interactive control center.

### Core Visuals:
* **Cohort Retention Heatmap:** A conditional-formatted matrix showing exact retention percentages over 18 months, highlighting that **Enterprise** tier retains customers significantly longer than Starter tiers.
* **CAC vs LTV Profitability Chart:** A clustered bar chart indicating that while LinkedIn is the highest-volume channel, **Referral** and **Content Marketing** boast the highest ROI (up to 113x).
* **Attribution Revenue Comparison:** A grouped column chart displaying how marketing channels perform under different conversion credit rules (e.g., showing Google Ads as a top-funnel awareness builder, and webinars/content as bottom-funnel closers).
* **Customer Lifetime Value vs Churn Risk Plot:** A scatter plot plotting LTV against Churn Risk to instantly isolate and flag high-paying, high-risk accounts for immediate customer success outreach.

### Interactive Controls:
* **Plan Tier Slicer:** Toggles the entire dashboard (including SQL views and machine learning results) between Starter, Growth, and Enterprise views using custom single-directional many-to-many relationships.

---

## 🛠️ Installation & Setup
To run the full pipeline locally:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
   cd YOUR_REPOSITORY
   ```

2. **Initialize Database Schema:**
   Open `01_create_database.sql` in VS Code and execute against your SQL Server LocalDB connection (`(localdb)\MSSQLLocalDB`).

3. **Install Dependencies:**
   ```bash
   pip install pyodbc pandas numpy scikit-learn
   ```

4. **Run Predictive Modeling Pipeline:**
   ```bash
   python churn_model.py
   ```

5. **Open Dashboard:**
   Open `NovaCRM_RevOps_Dashboard.pbix` in Power BI Desktop and click **Refresh** to populate the visuals with live data!
