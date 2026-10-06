# Data Dictionary

Source: DVSA anonymised MOT data, 2024 (Open Government Licence).
Filtered by `python/01_filter_mot.py`: cars (class 4), normal tests, completed results
(P, F, PRS), 10 makes; MGs first used before 2011 removed (old MG Rover).

## mot_results_filtered.csv (17.6m rows, one row per MOT test)
| Column | Meaning | Example / values |
|---|---|---|
| test_id | Unique MOT test ID | 982603987 |
| vehicle_id | Anonymised vehicle ID | 596187188 |
| test_date | Date of test | 2024-08-19 |
| test_class_id | Vehicle class (4 = cars) | 4 |
| test_type | Test type (NT = normal test) | NT |
| test_result | P = pass, F = fail, PRS = pass after rectification at station | P |
| make | Manufacturer (capitals) | MG |
| model | Model | ZS |
| fuel_type | PE petrol, DI diesel, EL electric, HY/ED hybrid, others = other | EL |
| first_use_date | Date first registered | 2020-01-01 |

## mot_failures_filtered.csv (10.1m rows, one row per failure item)
| Column | Meaning | Example / values |
|---|---|---|
| test_id | Links to mot_results_filtered.test_id (one test, many failures) | 1479190053 |
| rfr_id | Defect code (Reason for Rejection); category via lookup tables | 30335 |
| rfr_type_code | F = fail, P = fixed during test (advisories removed) | F |

## Known data quality issues (handled in SQL, Phase 4)
- Exact duplicate rows found in the raw results data
- Failure categories exist in two sets (old and post-2018); mapped to one list