# Retail Revenue Leakage & Retention Analysis

## Problem
Analyzing UK online retail transaction data to identify where revenue is 
being lost and which customers are at risk of churning.

## Dataset
Online Retail II (UCI Machine Learning Repository) — ~540,000 transaction 
records, Dec 2009 to Dec 2011.

## What I did (Excel phase)
- Cleaned raw data using Power Query: removed duplicates, separated orders 
  with missing Customer IDs, flagged cancelled orders instead of deleting 
  them (preserved for leakage analysis)
- Built calculated fields: Revenue, InvoiceMonth, IsCancelled
- Validated the cleaned data using pivot tables across Country, Month, 
  and Top Products
- Built a Gross vs Net revenue comparison to quantify monthly leakage 
  from cancellations

## Key Findings
- UK accounts for ~85% of total revenue (16.1M out of 19M total)
- Clear seasonal spike in November, consistent across both years in 
  the dataset (holiday ordering pattern)
- Total revenue leakage from cancellations: *£[your real total here]*
- Highest-leakage month: *[your worst month here]*

## Files
- Retail_Revenue_Analysis.xlsx — full workbook with Power Query 
  cleaning steps, pivot tables, and leakage comparison
- data/cleaned_online_retail.csv — final cleaned dataset
- screenshots/ — pivot table, chart, and leakage comparison outputs

## Tools used so far
Excel, Power Query

## Status
✅ Excel — data cleaning, validation, leakage analysis
🔲 SQL Server (star schema, RFM, cohort, leakage queries) — next
🔲 Power BI dashboard
🔲 Python (EDA, churn model)
