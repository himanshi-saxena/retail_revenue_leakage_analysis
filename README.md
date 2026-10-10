# Retail Revenue Leakage & Retention Analysis

End-to-end analysis of about 1 million UK online retail transactions (Dec 2009 to Dec 2011) to find where revenue is lost and which customers are leaving.

## Problem
Where does the shop lose money, and which valuable customers should it try to win back first?

## Dataset
Online Retail II, UCI Machine Learning Repository: https://archive.ics.uci.edu/dataset/502/online+retail+ii

## What I did
- **Excel:** cleaned the raw data in Power Query, flagged cancelled orders instead of deleting them, and validated results with pivot tables.
- **SQL Server:** loaded raw data into a staging table, built a cleaned table and a star schema (1,061,146 fact rows), and wrote queries for RFM segmentation, cohort retention, monthly revenue leakage, and running totals, using CTEs and window functions.
- **Power BI:** built a 4-page dashboard on top of SQL views: Executive Summary, Customer Segments, Cohort Retention and Risk Watchlist.

## Key findings
- Net revenue was £19.45M, and £1.53M (7.28%) was lost to cancellations.
- November is the peak month in both years. December 2011 is a partial month, because the data ends on 9 December.
- Only about 21% of new customers buy again in month 1, and about 18% are still buying at month 12.
- 1,274 Champions (22% of customers) bring about 72% of identified customer spend.
- 3,228 customers (55%) are At Risk or Lost, but they hold only about 10% of spend (£1.76M). 200 of them are high-priority win-back targets.
- Highest leakage month (excluding partial December 2011): [your month from the SQL query]

## Dashboard
![Executive Summary](Retail-Executive_summary.png)
![Customer Segments](Retail-Customer_segments.png)
![Cohort Retention](Retail-Cohort_retension_.png)
![Risk Watchlist](Retail-Risk_watchlist.png)

## Files
- `retail_analytics_full.sql`: all SQL queries
- `Retail_Dashboard.pdf`: dashboard export
- Screenshots of each dashboard page

## Notes and limits
- Guest orders (no customer ID) are kept in revenue totals but excluded from customer-level analysis.
- Segment limits (Champion, Loyal, At Risk, Lost) are my own assumptions.
- "Revenue at risk" means past spend of lapsed customers, not a forecast.

## Tools
Excel, Power Query, SQL Server, Power BI

## Status
✅ Excel
✅ SQL Server
✅ Power BI
🔲 Python extension, planned after I learn Python
