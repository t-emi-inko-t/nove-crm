-- Create NovaCRM database
CREATE DATABASE NovaCRM;
GO

USE NovaCRM;
GO

-- Customers table
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    company_name NVARCHAR(100) NOT NULL,
    industry NVARCHAR(50) NOT NULL,
    signup_date DATE NOT NULL,
    plan_tier NVARCHAR(20) NOT NULL,
    is_churned BIT NOT NULL DEFAULT 0,
    churn_date DATE NULL
);

-- Subscriptions table
CREATE TABLE subscriptions (
    subscription_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    event_type NVARCHAR(20) NOT NULL,
    event_date DATE NOT NULL,
    mrr_amount DECIMAL(10,2) NOT NULL,
    plan_tier NVARCHAR(20) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Marketing touchpoints table
CREATE TABLE marketing_touchpoints (
    touchpoint_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    channel NVARCHAR(50) NOT NULL,
    touchpoint_date DATE NOT NULL,
    cost DECIMAL(10,2) NOT NULL,
    is_conversion BIT NOT NULL DEFAULT 0,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Revenue events table
CREATE TABLE revenue_events (
    event_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    event_date DATE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    event_type NVARCHAR(20) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);
GO