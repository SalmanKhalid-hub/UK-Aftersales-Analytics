-- 03_profile_staging.sql
-- Purpose: measure the data quality problems in staging BEFORE cleaning.
USE AftersalesDB;


GO
-- 1. Every distinct fuel_type value and how often it appears.
--    GROUP BY = "one row per distinct value"; COUNT(*) counts each group.
SELECT   fuel_type,
         COUNT(*) AS tests
FROM     staging.mot_results
GROUP BY fuel_type
ORDER BY tests DESC;

-- 2. MOT duplicates: total rows vs unique test IDs.
--    COUNT(DISTINCT x) counts each different value once.
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT test_id) AS unique_tests,
       COUNT(*) - COUNT(DISTINCT test_id) AS duplicate_rows
FROM   staging.mot_results;

-- 3. Service job duplicates (the answer key says 300).
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT job_id) AS unique_jobs,
       COUNT(*) - COUNT(DISTINCT job_id) AS duplicate_rows
FROM   staging.service_jobs;

-- 4. Are the MOT duplicates EXACT copies (every column identical)?
--    SELECT DISTINCT * keeps one of each fully identical row.
--    If this equals unique_tests (11,951,361), every duplicate is an exact copy,
--    so it's safe to keep just one row per test_id.
SELECT COUNT(*) AS distinct_full_rows
FROM   (SELECT DISTINCT *
        FROM   staging.mot_results) AS d;

-- 5. Service jobs closed before they were opened (answer key says 120).
--    TRY_CONVERT turns text into a real date; if the text isn't a valid date
--    it returns NULL instead of crashing.
SELECT COUNT(*) AS closed_before_opened
FROM   staging.service_jobs
WHERE  TRY_CONVERT (DATE, closed_date) < TRY_CONVERT (DATE, opened_date);