-- 01_create_tables.sql
-- Purpose: create the schemas and the empty STAGING tables.
-- Staging holds the data exactly as it arrives in the CSV files.
USE AftersalesDB;


GO
-- ---------------------------------------------------------------
-- 1. SCHEMAS (folders inside the database)
-- SCHEMA_ID('x') returns NULL if schema x doesn't exist yet,
-- so each one is only created once. That makes this script safe to rerun.
-- ---------------------------------------------------------------
IF SCHEMA_ID('staging') IS NULL
    EXECUTE ('CREATE SCHEMA staging');

IF SCHEMA_ID('clean') IS NULL
    EXECUTE ('CREATE SCHEMA clean');

IF SCHEMA_ID('reporting') IS NULL
    EXECUTE ('CREATE SCHEMA reporting');


GO
-- ---------------------------------------------------------------
-- 2. STAGING TABLES
-- Every column is VARCHAR (text) on purpose: staging must accept the
-- data exactly as it is, even if a value is bad. Proper types
-- (dates, numbers) are applied later, in the clean layer.
-- DROP TABLE IF EXISTS deletes an old version first, so reruns start fresh.
-- ---------------------------------------------------------------
-- One row per MOT test (from mot_results_filtered.csv)
DROP TABLE IF EXISTS staging.mot_results;

CREATE TABLE staging.mot_results (
    test_id        VARCHAR (20) ,
    vehicle_id     VARCHAR (20) ,
    test_date      VARCHAR (20) ,
    test_class_id  VARCHAR (5)  ,
    test_type      VARCHAR (5)  ,
    test_result    VARCHAR (10) ,
    make           VARCHAR (50) ,
    model          VARCHAR (200),
    fuel_type      VARCHAR (50) ,
    first_use_date VARCHAR (20) 
);

-- One row per failure item (from mot_failures_filtered.csv)
DROP TABLE IF EXISTS staging.mot_failures;

CREATE TABLE staging.mot_failures (
    test_id       VARCHAR (20),
    rfr_id        VARCHAR (20),
    rfr_type_code VARCHAR (5) 
);

-- One row per dealer (from dealers.csv)
DROP TABLE IF EXISTS staging.dealers;

CREATE TABLE staging.dealers (
    dealer_id   VARCHAR (10) ,
    dealer_name VARCHAR (100),
    region      VARCHAR (50) 
);

-- One row per service job (from service_jobs.csv)
DROP TABLE IF EXISTS staging.service_jobs;

CREATE TABLE staging.service_jobs (
    job_id         VARCHAR (10),
    dealer_id      VARCHAR (10),
    model          VARCHAR (20),
    fault_category VARCHAR (50),
    opened_date    VARCHAR (20),
    closed_date    VARCHAR (20),
    cost_gbp       VARCHAR (20)
);


GO
-- One row per defect type per vehicle class (from item_detail.csv, pipe-delimited)
-- All 10 columns must be here because BULK INSERT loads every column in the file.
DROP TABLE IF EXISTS staging.item_detail;

CREATE TABLE staging.item_detail (
    rfr_id                   VARCHAR (20)  ,
    test_class_id            VARCHAR (5)   ,
    test_item_id             VARCHAR (20)  ,
    minor_item               VARCHAR (5)   ,
    rfr_deficiency_category  VARCHAR (50)  ,
    rfr_desc                 VARCHAR (500) ,
    rfr_loc_marker           VARCHAR (5)   ,
    rfr_insp_manual_desc     VARCHAR (1000),
    rfr_advisory_text        VARCHAR (1000),
    test_item_set_section_id VARCHAR (20)  
);

-- One row per item or category per vehicle class (from item_group.csv, pipe-delimited)
DROP TABLE IF EXISTS staging.item_group;

CREATE TABLE staging.item_group (
    test_item_id             VARCHAR (20) ,
    test_class_id            VARCHAR (5)  ,
    parent_id                VARCHAR (20) ,
    test_item_set_section_id VARCHAR (20) ,
    item_name                VARCHAR (200)
);


GO
-- ---------------------------------------------------------------
-- 3. CHECK: list every table we've created
-- INFORMATION_SCHEMA.TABLES is SQL Server's built-in list of all tables.
-- ---------------------------------------------------------------
SELECT   TABLE_SCHEMA,
         TABLE_NAME
FROM     INFORMATION_SCHEMA.TABLES
WHERE    TABLE_SCHEMA = 'staging'
ORDER BY TABLE_NAME;