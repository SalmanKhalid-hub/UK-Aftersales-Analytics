-- 02_load.sql
-- Purpose: load every CSV into its staging table, then check row counts.
-- The files were copied into the container at /var/opt/mssql/import/ (Step 4.1).
-- Note: SQL Server here runs on Linux (inside Docker), which doesn't support
-- the CODEPAGE option, so it isn't used.
USE AftersalesDB;


GO
-- SIMPLE recovery = SQL Server keeps only a minimal transaction log.
-- On a local learning database this stops the log file ballooning
-- while loading millions of rows. (Live company databases usually use FULL.)
ALTER DATABASE AftersalesDB
    SET RECOVERY SIMPLE;


GO
-- ---------------------------------------------------------------
-- 1. MOT DATA (comma-separated, header row)
-- TRUNCATE empties the table first, so rerunning never doubles the data.
-- ---------------------------------------------------------------
TRUNCATE TABLE staging.mot_results;

BULK INSERT staging.mot_results FROM '/var/opt/mssql/import/mot_results_filtered.csv'
    WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK); -- understands standard CSV rules (e.g. quoted values)
 -- skip row 1: the header with column names
 -- columns are separated by commas
 -- each row ends with a newline (hex code 0a)
 -- lock the whole table while loading: much faster

TRUNCATE TABLE staging.mot_failures;

BULK INSERT staging.mot_failures FROM '/var/opt/mssql/import/mot_failures_filtered.csv'
    WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);

-- ---------------------------------------------------------------
-- 2. SYNTHETIC DEALER DATA (comma-separated, header row)
-- ---------------------------------------------------------------
TRUNCATE TABLE staging.dealers;

BULK INSERT staging.dealers FROM '/var/opt/mssql/import/dealers.csv'
    WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);

TRUNCATE TABLE staging.service_jobs;

BULK INSERT staging.service_jobs FROM '/var/opt/mssql/import/service_jobs.csv'
    WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', TABLOCK);

-- ---------------------------------------------------------------
-- 3. LOOKUP TABLES (PIPE-separated: | not ,)
-- ---------------------------------------------------------------
TRUNCATE TABLE staging.item_detail;

BULK INSERT staging.item_detail FROM '/var/opt/mssql/import/item_detail.csv'
    WITH (FIRSTROW = 2, FIELDTERMINATOR = '|', ROWTERMINATOR = '0x0a', TABLOCK);

TRUNCATE TABLE staging.item_group;

BULK INSERT staging.item_group FROM '/var/opt/mssql/import/item_group.csv'
    WITH (FIRSTROW = 2, FIELDTERMINATOR = '|', ROWTERMINATOR = '0x0a', TABLOCK);


GO
-- ---------------------------------------------------------------
-- 4. CHECK: count the rows in every staging table
-- UNION ALL stacks several results into one table.
-- ---------------------------------------------------------------
SELECT 'mot_results' AS table_name,
       COUNT(*) AS row_count
FROM   staging.mot_results
UNION ALL
SELECT 'mot_failures',
       COUNT(*)
FROM   staging.mot_failures
UNION ALL
SELECT 'dealers',
       COUNT(*)
FROM   staging.dealers
UNION ALL
SELECT 'service_jobs',
       COUNT(*)
FROM   staging.service_jobs
UNION ALL
SELECT 'item_detail',
       COUNT(*)
FROM   staging.item_detail
UNION ALL
SELECT 'item_group',
       COUNT(*)
FROM   staging.item_group;