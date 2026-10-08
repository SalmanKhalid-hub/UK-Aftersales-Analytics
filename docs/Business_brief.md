# Business Brief: UK Aftersales Reliability & Dealer Performance

## Purpose
Give an aftersales team a clear view of 
(1) how reliable a brand's vehicles are
compared with the market. 

(2) how well its dealer network performs, so they
can act on parts planning, service campaigns and dealer support.

## Audience
Aftersales managers and the dealer network team (non-technical readers).

## Business questions
1. How does the focus brand's first-MOT pass rate compare with competitors?
2. How do failure rates change as vehicles age?
3. Which failure categories are most common?
4. Do EVs fail more or less often than petrol and diesel cars?
5. Which dealers have the highest costs and slowest repairs?

## Scope
- Vehicles: cars only (MOT class 4); focus brand MG, compared with Kia, Hyundai, Dacia, Skoda, Vauxhall, Ford, Toyota, Nissan and Tesla
- Geography: Great Britain
- Period: MOT tests in 2024


## Data sources and why they were chosen
| Source | Tables | Type | Why |
|---|---|---|---|
| DVSA anonymised MOT data | MOT test results; MOT failure items (linked by test ID) | Real, open government data | Independent inspection of every GB car aged 3+, with failure reasons; covers all makes including MG |
| Dealer data | Dealers; service jobs (linked by dealer ID) | Synthetic | Real dealer data is confidential; generated with realistic structure and planted data quality problems |

## KPI definitions
| # | KPI | Definition | Notes |
|---|---|---|---|
| 1 | First-MOT pass rate | Tests passed first time ÷ all first MOT tests, by make and model | First MOT = vehicle aged 3 to 4 years at test. "Pass after rectification" counts as a fail, because a defect was found |
| 2 | Failure rate by age band | Tests with at least one failure ÷ all tests, by age band | Age at test = test date minus first-use date; bands 3-4, 5-6, 7-9, 10+ years |
| 3 | Top failure categories | Failures in a category ÷ all failures | e.g. brakes, tyres, lighting, suspension |
| 4 | EV vs petrol/diesel failure rate | Failure rate (as KPI 2) split by fuel type | |
| 5 | Cost per job | Total job cost ÷ number of jobs, per dealer | Mean, because finance needs totals. Synthetic data |
| 6 | Turnaround time | Days from job opened to job closed (closed date minus opened date), median per dealer | Median because a few long parts delays skew the mean. Jobs closed before they were opened are excluded and logged as a data quality issue. Jobs with no closed date are still open and are excluded |

## Assumptions and open questions
- MOT column names and codes confirmed during profiling; see docs/data_dictionary.md

## Stretch goals (if time allows)
- DVSA recalls data; % of jobs over 7 days; mileage bands
