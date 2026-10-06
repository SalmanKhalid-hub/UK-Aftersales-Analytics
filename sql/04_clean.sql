-- 04_clean.sql
-- Purpose: build the CLEAN tables from staging, fixing data quality problems,
-- and record every fix in clean.data_quality_log.
-- Staging is never changed, so this script can be rerun at any time.
USE AftersalesDB;


GO
-- =====================================================================
-- 0. DATA QUALITY LOG: one row per fix (what, where, how many, what we did)
-- IDENTITY(1,1) = SQL Server numbers each row automatically: 1, 2, 3...
-- DEFAULT SYSDATETIME() = fills in the current date and time automatically.
-- =====================================================================
DROP TABLE IF EXISTS clean.data_quality_log;

CREATE TABLE clean.data_quality_log (
    log_id        INT           IDENTITY (1, 1) PRIMARY KEY,
    table_name    VARCHAR (50) ,
    issue         VARCHAR (200),
    rows_affected INT          ,
    action_taken  VARCHAR (200),
    logged_at     DATETIME2     DEFAULT SYSDATETIME()
);


GO
-- =====================================================================
-- 1. MOT RESULTS
--    Fix 1: duplicates  -> keep ONE row per test_id
--    Fix 2: fuel_type   -> codes AND text mapped into 5 fuel groups
--    Also: proper data types (numbers, dates) and vehicle age at test
-- =====================================================================
DROP TABLE IF EXISTS clean.mot_results;

-- ROW_NUMBER() numbers the rows 1, 2, 3... separately for each test_id
-- (PARTITION BY = "restart the numbering for every test_id").
-- Keeping only rn = 1 keeps exactly one row per test.
WITH   ranked
AS     (SELECT *,
               ROW_NUMBER() OVER (PARTITION BY test_id ORDER BY test_id) AS rn
        FROM   staging.mot_results)
SELECT TRY_CAST (test_id AS BIGINT) AS test_id, -- TRY_CAST: text -> number (NULL if impossible)
       TRY_CAST (vehicle_id AS BIGINT) AS vehicle_id,
       TRY_CAST (test_date AS DATE) AS test_date, -- text -> real date
       test_result,
       make,
       model,
       CASE -- like a nested IF in Excel
       WHEN fuel_type = 'PE' THEN 'Petrol' WHEN fuel_type = 'DI' THEN 'Diesel' WHEN fuel_type IN ('EL', 'Electric') THEN 'Electric' WHEN fuel_type IN ('HY', 'ED', 'Hybrid Electric (Clean)') THEN 'Hybrid' ELSE 'Other' END AS fuel_group,
       TRY_CAST (first_use_date AS DATE) AS first_use_date,
       -- Age in whole years: months between first use and the test, divided by 12
       DATEDIFF(MONTH, TRY_CAST (first_use_date AS DATE), TRY_CAST (test_date AS DATE)) / 12 AS age_years
INTO   clean.mot_results -- SELECT ... INTO creates the new table and fills it in one step
FROM   ranked
WHERE  rn = 1;

-- An index is like a book's index: it makes lookups and JOINs on test_id much faster.
CREATE CLUSTERED INDEX ix_mot_results_test_id
    ON clean.mot_results(test_id);

-- Log both fixes
INSERT INTO clean.data_quality_log (
    table_name,
    issue,
    rows_affected,
    action_taken
)
SELECT 'mot_results',
       'Duplicate rows (same test_id appears more than once)',
       (SELECT COUNT(*)
        FROM   staging.mot_results) - (SELECT COUNT(*)
                                       FROM   clean.mot_results),
       'Kept one row per test_id';

INSERT INTO clean.data_quality_log (
    table_name,
    issue,
    rows_affected,
    action_taken
)
SELECT 'mot_results',
       'Fuel type stored as text instead of a code',
       COUNT(*),
       'Mapped text and codes into one fuel group'
FROM   staging.mot_results
WHERE  fuel_type IN ('Electric', 'Hybrid Electric (Clean)');


GO
-- =====================================================================
-- 2. MOT FAILURES
--    Adds a readable failure CATEGORY (e.g. "Brakes") using the lookups:
--    rfr_id -> item_detail (cars) -> section id -> item_group (cars) -> name
--    The name is then mapped to one standard list, because DVSA has
--    old (pre-2018) and new names for the same category.
--    Fix: exact duplicate rows removed with DISTINCT.
-- =====================================================================
DROP TABLE IF EXISTS clean.mot_failures;

SELECT DISTINCT -- DISTINCT removes exact duplicate rows
                TRY_CAST (f.test_id AS BIGINT) AS test_id,
                TRY_CAST (f.rfr_id AS INT) AS rfr_id,
                f.rfr_type_code,
                CASE WHEN g.item_name LIKE 'Brakes%' THEN 'Brakes' WHEN g.item_name LIKE 'Tyres%' THEN 'Tyres' WHEN g.item_name LIKE 'Road Wheels%' THEN 'Road wheels' WHEN g.item_name LIKE 'Lamps%' THEN 'Lighting and electrical' WHEN g.item_name LIKE 'Steering%' THEN 'Steering' WHEN g.item_name LIKE 'Suspension%' THEN 'Suspension' WHEN g.item_name LIKE 'Body%' THEN 'Body and structure' WHEN g.item_name LIKE 'Exhaust%'
                                                                                                                                                                                                                                                                                                                                                                                                          OR g.item_name LIKE 'Noise%' THEN 'Exhaust and emissions' WHEN g.item_name LIKE 'Driver''s View%'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                         OR g.item_name LIKE 'Visibility%' THEN 'Visibility' WHEN g.item_name LIKE 'Seat belt%' THEN 'Seat belts' ELSE 'Other' END AS failure_category
INTO   clean.mot_failures
FROM   staging.mot_failures AS f
       -- LEFT JOIN = keep every failure even if no matching lookup row is found
       LEFT OUTER JOIN
       staging.item_detail AS d
       ON d.rfr_id = f.rfr_id
          AND d.test_class_id = '4' -- cars only (codes repeat per vehicle class)
       LEFT OUTER JOIN
       staging.item_group AS g
       ON -- REPLACE removes a hidden carriage-return character (CHAR(13)) that
       -- Windows-made files can leave at the end of the last column.
       g.test_item_id = REPLACE(d.test_item_set_section_id, CHAR(13), '')
       AND g.test_class_id = '4';

CREATE CLUSTERED INDEX ix_mot_failures_test_id
    ON clean.mot_failures(test_id);

INSERT INTO clean.data_quality_log (
    table_name,
    issue,
    rows_affected,
    action_taken
)
SELECT 'mot_failures',
       'Exact duplicate rows',
       (SELECT COUNT(*)
        FROM   staging.mot_failures) - (SELECT COUNT(*)
                                        FROM   clean.mot_failures),
       'Removed with DISTINCT';


GO
-- =====================================================================
-- 3. DEALERS
--    Fix: messy names (extra spaces, wrong capitals)
--    TRIM removes spaces at the start/end; REPLACE turns double spaces into one;
--    UPPER makes every name the same case, so "reading branch" = "READING BRANCH".
-- =====================================================================
DROP TABLE IF EXISTS clean.dealers;

SELECT dealer_id,
       UPPER(REPLACE(TRIM(dealer_name), '  ', ' ')) AS dealer_name,
       region
INTO   clean.dealers
FROM   staging.dealers;

-- Count the messy names.
-- DATALENGTH counts every character including spaces at the end
-- (a plain "=" in SQL Server ignores trailing spaces, so it would miss them).
-- SQL Server also ignores capitals by default, so COLLATE Latin1_General_CS_AS
-- switches on a Case-Sensitive comparison to spot all-capitals or all-lower-case names.
INSERT INTO clean.data_quality_log (
    table_name,
    issue,
    rows_affected,
    action_taken
)
SELECT 'dealers',
       'Messy dealer names (extra spaces or wrong capitals)',
       COUNT(*),
       'Trimmed spaces and standardised to upper case'
FROM   staging.dealers
WHERE  DATALENGTH(dealer_name) <> DATALENGTH(TRIM(dealer_name))
       OR dealer_name LIKE '%  %'
       OR dealer_name COLLATE Latin1_General_CS_AS = UPPER(dealer_name)
       OR dealer_name COLLATE Latin1_General_CS_AS = LOWER(dealer_name);


GO
-- =====================================================================
-- 4. SERVICE JOBS
--    Fix 1: exact duplicate rows removed with DISTINCT
--    Fix 2: closed-before-opened dates flagged as 'Invalid dates'
--    Also: job_status and turnaround_days, ready for the KPIs
-- =====================================================================
DROP TABLE IF EXISTS clean.service_jobs;

SELECT DISTINCT j.*,
                CASE WHEN j.closed_date IS NULL THEN 'Open' WHEN j.closed_date < j.opened_date THEN 'Invalid dates' ELSE 'Closed' END AS job_status, -- still being repaired
                -- impossible: exclude from KPIs
                CASE WHEN j.closed_date >= j.opened_date THEN DATEDIFF(DAY, j.opened_date, j.closed_date) END AS turnaround_days -- end date minus start date
INTO   clean.service_jobs
FROM   (-- Inner query: convert the text columns to proper types first
        SELECT job_id,
               dealer_id,
               model,
               fault_category,
               TRY_CAST (opened_date AS DATE) AS opened_date,
               TRY_CAST (NULLIF (closed_date, '') AS DATE) AS closed_date, -- NULLIF: blank text -> NULL
               TRY_CAST (cost_gbp AS DECIMAL (10, 2)) AS cost_gbp -- money: 10 digits, 2 decimals
        FROM   staging.service_jobs) AS j;

INSERT INTO clean.data_quality_log (
    table_name,
    issue,
    rows_affected,
    action_taken
)
SELECT 'service_jobs',
       'Exact duplicate rows',
       (SELECT COUNT(*)
        FROM   staging.service_jobs) - (SELECT COUNT(*)
                                        FROM   clean.service_jobs),
       'Removed with DISTINCT';

INSERT INTO clean.data_quality_log (
    table_name,
    issue,
    rows_affected,
    action_taken
)
SELECT 'service_jobs',
       'Closed date before opened date',
       COUNT(*),
       'Flagged as Invalid dates; excluded from turnaround'
FROM   clean.service_jobs
WHERE  job_status = 'Invalid dates';


GO
-- =====================================================================
-- 5. CHECK: the full data quality log
-- Compare with data/synthetic/answer_key.txt:
--   service_jobs duplicates = 300, invalid dates = 120, messy dealer names = 6
-- =====================================================================
SELECT   log_id,
         table_name,
         issue,
         rows_affected,
         action_taken
FROM     clean.data_quality_log
ORDER BY log_id;