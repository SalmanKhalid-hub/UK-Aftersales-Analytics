-- 05_kpi_views.sql
-- Purpose: calculate the 6 KPIs from the CLEAN tables and save them as VIEWS
-- in the reporting schema. A view is a saved query that acts like a table:
-- it stores no data and recalculates from the clean tables each time it's queried.
-- Excel (Phase 6) and Power BI (Phase 7) read from these views.
USE AftersalesDB;


GO
-- =====================================================================
-- KPI 1: FIRST-MOT PASS RATE, by make
-- First MOT = car aged 3 at the test (cars need their first MOT at 3 years old).
-- Pass first time = 'P' only (PRS counts as a fail: a defect was found).
-- CASE inside SUM = "count only the rows that match": 1 if passed, else 0.
-- 100.0 (not 100) forces decimal maths, so 87/100 gives 87.0 not 0.
-- CREATE OR ALTER = create the view, or replace it if it already exists.
-- Each CREATE VIEW must be alone in its batch, hence the GO after each one.
-- =====================================================================
CREATE OR ALTER VIEW reporting.vw_first_mot_pass_rate
AS
SELECT   make,
         COUNT(*) AS first_mot_tests,
         SUM(CASE WHEN test_result = 'P' THEN 1 ELSE 0 END) AS passed_first_time,
         ROUND(100.0 * SUM(CASE WHEN test_result = 'P' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pass_rate_pct
FROM     clean.mot_results
WHERE    age_years = 3
GROUP BY make;


GO
-- =====================================================================
-- KPI 2: FAILURE RATE BY AGE BAND, by make
-- Failure = the car had at least one defect (F or PRS).
-- The inner query works out each test's age band first; the outer query
-- then groups by it (you can't GROUP BY a name created in the same SELECT).
-- =====================================================================
CREATE OR ALTER VIEW reporting.vw_failure_rate_by_age
AS
SELECT   make,
         age_band,
         COUNT(*) AS tests,
         ROUND(100.0 * SUM(CASE WHEN test_result IN ('F', 'PRS') THEN 1 ELSE 0 END) / COUNT(*), 1) AS failure_rate_pct
FROM     (SELECT make,
                 test_result,
                 CASE WHEN age_years < 3 THEN 'Under 3' WHEN age_years <= 4 THEN '3-4' WHEN age_years <= 6 THEN '5-6' WHEN age_years <= 9 THEN '7-9' ELSE '10+' END AS age_band
          FROM   clean.mot_results
          WHERE  age_years IS NOT NULL) AS t
GROUP BY make, age_band;


GO
-- =====================================================================
-- KPI 3: TOP FAILURE CATEGORIES, by make
-- JOIN: failures don't contain the make, so we join each failure to its test
-- (one test -> many failures, linked by test_id) to find out which make it was.
-- SUM(COUNT(*)) OVER (PARTITION BY make) is a WINDOW FUNCTION: it adds up the
-- counts of all categories for the same make, without collapsing the rows.
-- That total is used to turn each category's count into a % share.
-- =====================================================================
CREATE OR ALTER VIEW reporting.vw_failure_categories
AS
SELECT   r.make,
         f.failure_category,
         COUNT(*) AS failure_items,
         ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY r.make), 1) AS share_of_make_failures_pct
FROM     clean.mot_failures AS f
         INNER JOIN
         clean.mot_results AS r
         ON r.test_id = f.test_id
GROUP BY r.make, f.failure_category;


GO
-- =====================================================================
-- KPI 4: FAILURE RATE BY FUEL GROUP, by make (EV vs petrol/diesel/hybrid)
-- =====================================================================
CREATE OR ALTER VIEW reporting.vw_fuel_failure_rate
AS
SELECT   make,
         fuel_group,
         COUNT(*) AS tests,
         ROUND(100.0 * SUM(CASE WHEN test_result IN ('F', 'PRS') THEN 1 ELSE 0 END) / COUNT(*), 1) AS failure_rate_pct
FROM     clean.mot_results
GROUP BY make, fuel_group;


GO
-- =====================================================================
-- KPIs 5 and 6: DEALER SCORECARD
-- KPI 5 cost per job = MEAN (AVG), because finance needs totals.
-- KPI 6 turnaround = MEDIAN of closed jobs only (open and invalid-date jobs excluded).
-- SQL Server has no MEDIAN(), so PERCENTILE_CONT(0.5) (the 50th percentile) is used.
-- It's a window function, so DISTINCT collapses it to one row per dealer.
-- Two CTEs (named mini-results) are built first, then joined to the dealers.
-- =====================================================================
CREATE OR ALTER VIEW reporting.vw_dealer_scorecard
AS
WITH   job_stats
AS     (SELECT   dealer_id,
                 COUNT(*) AS total_jobs,
                 SUM(CASE WHEN job_status = 'Closed' THEN 1 ELSE 0 END) AS closed_jobs,
                 SUM(CASE WHEN job_status = 'Open' THEN 1 ELSE 0 END) AS open_jobs,
                 SUM(CASE WHEN job_status = 'Invalid dates' THEN 1 ELSE 0 END) AS invalid_date_jobs,
                 ROUND(AVG(cost_gbp), 2) AS avg_cost_per_job_gbp
        FROM     clean.service_jobs
        GROUP BY dealer_id),
       medians
AS     (SELECT DISTINCT dealer_id,
                        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY turnaround_days) OVER (PARTITION BY dealer_id) AS median_turnaround_days
        FROM   clean.service_jobs
        WHERE  job_status = 'Closed')
SELECT d.dealer_id,
       d.dealer_name,
       d.region,
       s.total_jobs,
       s.closed_jobs,
       s.open_jobs,
       s.invalid_date_jobs,
       s.avg_cost_per_job_gbp,
       m.median_turnaround_days
FROM   clean.dealers AS d
       LEFT OUTER JOIN
       job_stats AS s
       ON s.dealer_id = d.dealer_id -- LEFT JOIN: keep every dealer
       LEFT OUTER JOIN
       medians AS m
       ON m.dealer_id = d.dealer_id;


GO
-- =====================================================================
-- CHECKS: look at two of the views
-- (Views can't contain ORDER BY themselves, so we sort when we query them.)
-- =====================================================================
SELECT   *
FROM     reporting.vw_first_mot_pass_rate
ORDER BY pass_rate_pct DESC;

SELECT   TOP 10 *
FROM     reporting.vw_dealer_scorecard
ORDER BY median_turnaround_days DESC;