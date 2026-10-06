"""
02_generate_dealersdata.py

Purpose:
    Create a realistic SYNTHETIC (made-up) dealer network for the focus brand:
    a list of dealers and a year (2024) of service/repair jobs at those dealers.

Why synthetic:
    Real dealer data is confidential and never published, but KPIs 5 and 6
    (cost per job, turnaround time) need it. So we generate data with the same
    structure a real aftersales system would have, and say openly that it's synthetic.

Planted data problems (to clean in SQL in Phase 4):
    1. Duplicate jobs           (some job rows appear twice)
    2. Messy dealer names       (wrong capitals, extra spaces)
    3. Impossible dates         (closed date before opened date)
    The exact counts are saved in an "answer key", so the SQL cleaning can be checked.

Outputs (in data/synthetic/, small enough to commit to GitHub):
    dealers.csv        one row per dealer
    service_jobs.csv   one row per repair job
    answer_key.txt     how many of each problem were planted

How to run (from the project folder):
    python python/02_generate_dealers.py
"""

# ---------------------------------------------------------------------------
# 1. IMPORTS
# ---------------------------------------------------------------------------
from pathlib import Path

import numpy as np    # NumPy: fast maths and random numbers
import pandas as pd   # pandas: tables (DataFrames)


# ---------------------------------------------------------------------------
# 2. SETTINGS
# ---------------------------------------------------------------------------
OUT = Path("data/synthetic")
OUT.mkdir(parents=True, exist_ok=True)

# A random "seed" makes the random numbers come out the SAME every run.
# Anyone who runs this script gets identical data, so the project is reproducible.
rng = np.random.default_rng(seed=42)

N_JOBS = 20_000          # jobs to create (before duplicates are added)
N_DUPLICATES = 300       # planted problem 1
N_BAD_DATES = 120        # planted problem 2 (closed before opened)
N_MESSY_NAMES = 6        # planted problem 3 (dealers with badly typed names)
YEAR_START = pd.Timestamp("2024-01-01")
YEAR_END = pd.Timestamp("2024-12-31")

# 50 towns and their regions. Dealer names are built from these.
TOWNS = {
    "Reading": "South East", "Oxford": "South East", "Guildford": "South East",
    "Brighton": "South East", "Maidstone": "South East", "Southampton": "South East",
    "Portsmouth": "South East", "Milton Keynes": "South East",
    "Croydon": "London", "Ealing": "London", "Enfield": "London", "Romford": "London",
    "Bristol": "South West", "Exeter": "South West", "Plymouth": "South West",
    "Swindon": "South West", "Bath": "South West",
    "Birmingham": "Midlands", "Coventry": "Midlands", "Leicester": "Midlands",
    "Nottingham": "Midlands", "Derby": "Midlands", "Wolverhampton": "Midlands",
    "Stoke": "Midlands", "Northampton": "Midlands",
    "Cambridge": "East", "Norwich": "East", "Ipswich": "East", "Peterborough": "East",
    "Manchester": "North West", "Liverpool": "North West", "Preston": "North West",
    "Bolton": "North West", "Chester": "North West", "Stockport": "North West",
    "Leeds": "North East", "Sheffield": "North East", "York": "North East",
    "Newcastle": "North East", "Hull": "North East", "Bradford": "North East",
    "Sunderland": "North East",
    "Cardiff": "Wales", "Swansea": "Wales", "Newport": "Wales",
    "Glasgow": "Scotland", "Edinburgh": "Scotland", "Aberdeen": "Scotland",
    "Dundee": "Scotland", "Inverness": "Scotland",
}

MODELS = ["MG3", "MG4", "MG5", "ZS", "ZS EV", "HS"]
MODEL_WEIGHTS = [0.15, 0.20, 0.08, 0.30, 0.12, 0.15]   # how common each model is (adds to 1)
EV_MODELS = {"MG4", "MG5", "ZS EV"}

# Fault categories, how common each is, and a typical repair cost in GBP.
# Names match the standard MOT categories, so dealer and MOT data line up.
FAULTS = {
    #  category                 share  typical cost
    "Brakes":                  (0.22, 280),
    "Tyres":                   (0.20, 170),
    "Lighting and electrical": (0.15, 120),
    "Suspension":              (0.12, 340),
    "Steering":                (0.06, 310),
    "Exhaust and emissions":   (0.08, 260),
    "Body and structure":      (0.07, 420),
    "Visibility":              (0.05, 90),
    "Battery and charging":    (0.05, 650),   # EVs only (see below)
}


# ---------------------------------------------------------------------------
# 3. DEALERS TABLE
# ---------------------------------------------------------------------------
dealers = pd.DataFrame({
    # f"D{i:03d}" formats a number with 3 digits: 1 -> "D001"
    "dealer_id": [f"D{i:03d}" for i in range(1, len(TOWNS) + 1)],
    "dealer_name": [f"{town} Branch" for town in TOWNS],
    "region": list(TOWNS.values()),
})

# Hidden "performance profile" for each dealer, so the dashboard has a real story:
#   size  : how many jobs it gets (some dealers are much busier)
#   speed : multiplies repair time (1.0 = average; 1.6 = 60% slower)
#   cost  : multiplies repair cost (1.0 = average; 1.2 = 20% dearer)
# These are NOT saved to the CSV: in real life you'd have to discover them from the data.
size = rng.choice([0.5, 1.0, 2.0], size=len(dealers), p=[0.3, 0.5, 0.2])
speed = rng.normal(1.0, 0.15, size=len(dealers)).clip(0.7, 1.5)
cost = rng.normal(1.0, 0.10, size=len(dealers)).clip(0.8, 1.3)
speed[[7, 33]] = [1.6, 1.7]   # make two dealers clearly slow, as a finding to discover
cost[[12]] = [1.35]           # and one clearly expensive


# ---------------------------------------------------------------------------
# 4. SERVICE JOBS TABLE
# ---------------------------------------------------------------------------
# Which dealer each job goes to: busier dealers (bigger size) get more jobs.
dealer_idx = rng.choice(len(dealers), size=N_JOBS, p=size / size.sum())

model = rng.choice(MODELS, size=N_JOBS, p=MODEL_WEIGHTS)

# Fault category: EVs can have battery faults but no exhaust; petrol cars the opposite.
fault_names = list(FAULTS)
base_share = np.array([FAULTS[f][0] for f in fault_names])
fault = []
for m in model:
    share = base_share.copy()
    if m in EV_MODELS:
        share[fault_names.index("Exhaust and emissions")] = 0
    else:
        share[fault_names.index("Battery and charging")] = 0
    fault.append(rng.choice(fault_names, p=share / share.sum()))
fault = np.array(fault)

# Opened date: a random day in 2024
opened = YEAR_START + pd.to_timedelta(rng.integers(0, 366, size=N_JOBS), unit="D")

# Turnaround days: usually 1 to 4 days, scaled by the dealer's speed,
# plus about 5% of jobs waiting a long time for parts (10 to 60 extra days).
days = rng.gamma(shape=2.0, scale=1.2, size=N_JOBS) * speed[dealer_idx]
parts_wait = rng.random(N_JOBS) < 0.05
days = days + parts_wait * rng.integers(10, 61, size=N_JOBS)
days = np.round(days).astype(int)
closed = opened + pd.to_timedelta(days, unit="D")

# Jobs that would finish after 31 Dec 2024 are still open: closed date left blank.
# (This is a real state, not a data error.)
closed = closed.where(closed <= YEAR_END)

# Cost: typical cost for the fault x dealer cost factor x random variation
typical = np.array([FAULTS[f][1] for f in fault])
cost_gbp = typical * cost[dealer_idx] * rng.lognormal(0, 0.25, size=N_JOBS)

jobs = pd.DataFrame({
    "job_id": [f"J{i:06d}" for i in range(1, N_JOBS + 1)],
    "dealer_id": dealers["dealer_id"].to_numpy()[dealer_idx],
    "model": model,
    "fault_category": fault,
    "opened_date": opened,
    "closed_date": closed,
    "cost_gbp": cost_gbp.round(2),
})


# ---------------------------------------------------------------------------
# 5. PLANT THE DATA PROBLEMS
# ---------------------------------------------------------------------------
# Problem: impossible dates. Pick closed jobs and swap their dates around,
# so closed_date ends up BEFORE opened_date.
closed_jobs = jobs.index[jobs["closed_date"].notna() & (days > 0)]
bad = rng.choice(closed_jobs, size=N_BAD_DATES, replace=False)
jobs.loc[bad, ["opened_date", "closed_date"]] = jobs.loc[bad, ["closed_date", "opened_date"]].to_numpy()

# Problem: duplicates. Copy some normal rows (not the bad-date ones) and add them again.
clean_rows = jobs.index.difference(bad)
dup = rng.choice(clean_rows, size=N_DUPLICATES, replace=False)
jobs = pd.concat([jobs, jobs.loc[dup]], ignore_index=True)

# Shuffle the rows so the duplicates aren't all at the bottom (like a real export).
jobs = jobs.sample(frac=1, random_state=42).reset_index(drop=True)

# Problem: messy dealer names, the kind of thing typed by hand into a system.
messy = rng.choice(len(dealers), size=N_MESSY_NAMES, replace=False)
for i, style in zip(messy, ["lower", "upper", "trailing", "leading", "lower", "double"]):
    name = dealers.at[i, "dealer_name"]
    dealers.at[i, "dealer_name"] = {
        "lower": name.lower(),                  # "reading branch"
        "upper": name.upper(),                  # "READING BRANCH"
        "trailing": name + "  ",                # "Reading Branch  "
        "leading": "  " + name,                 # "  Reading Branch"
        "double": name.replace(" ", "  "),      # "Reading  Branch"
    }[style]


# ---------------------------------------------------------------------------
# 6. SAVE THE FILES AND THE ANSWER KEY
# ---------------------------------------------------------------------------
dealers.to_csv(OUT / "dealers.csv", index=False)
# date_format writes dates as YYYY-MM-DD (no time), which SQL Server reads easily
jobs.to_csv(OUT / "service_jobs.csv", index=False, date_format="%Y-%m-%d")

n_open = int(jobs["closed_date"].isna().sum())
answer_key = (
    "ANSWER KEY: planted data problems (check the Phase 4 SQL cleaning against these)\n"
    f"Dealers: {len(dealers)}\n"
    f"Job rows in file: {len(jobs)} ({N_JOBS} real jobs + {N_DUPLICATES} duplicates)\n"
    f"1. Duplicate job rows: {N_DUPLICATES}\n"
    f"2. Messy dealer names: {N_MESSY_NAMES} -> {sorted(dealers.loc[messy, 'dealer_id'])}\n"
    f"3. Closed before opened: {N_BAD_DATES}\n"
    f"Not a problem: still-open jobs (blank closed_date): {n_open}\n"
)
(OUT / "answer_key.txt").write_text(answer_key)

print(answer_key)
print(f"Saved to {OUT}/")