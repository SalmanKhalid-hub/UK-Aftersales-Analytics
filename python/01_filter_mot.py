"""
01_filter_mot.py

Purpose:
    Filter the 2024 DVSA MOT data down to what this project needs:
    cars only, normal completed tests, and 10 makes (MG + 9 competitors).

Why a script and not Excel:
    The raw data is 12.8 GB unzipped (tens of millions of rows).
    Excel stops at about 1 million rows, so we process it with Python,
    reading straight from the zip files, one chunk at a time.

Inputs  (in data/raw/):
    mot_results_2024.zip        one row per MOT test
    mot_failure_items_2024.zip  one row per defect found

Outputs (in data/processed/):
    mot_results_filtered.csv    the tests we keep
    mot_failures_filtered.csv   the real failures for those tests

How to run (from the project folder):
    python python/01_filter_mot.py
"""

# ---------------------------------------------------------------------------
# 1. IMPORTS: tools this script borrows from Python libraries
# ---------------------------------------------------------------------------
import zipfile                   # built into Python: opens zip files without extracting them
from collections import Counter  # built into Python: a dictionary that counts things
from pathlib import Path         # built into Python: handles file paths (works on Mac and Windows)

import pandas as pd              # the main data library: tables are called "DataFrames"


# ---------------------------------------------------------------------------
# 2. SETTINGS: the rules list, all in one place so they're easy to change
# ---------------------------------------------------------------------------
RAW = Path("data/raw")           # where the downloaded zips live
OUT = Path("data/processed")     # where the filtered CSVs will be saved
OUT.mkdir(parents=True, exist_ok=True)  # create data/processed if missing; no error if it exists

# The 10 makes in scope. Written in CAPITALS because that's how the MOT data stores them.
MAKES = ["MG", "KIA", "HYUNDAI", "DACIA", "SKODA",
         "VAUXHALL", "FORD", "TOYOTA", "NISSAN", "TESLA"]

# Only the columns we need (rule 6). Leaving out colour, postcode etc. saves time and memory.
RESULT_COLS = ["test_id", "vehicle_id", "test_date", "test_class_id", "test_type",
               "test_result", "make", "model", "fuel_type", "first_use_date"]
FAILURE_COLS = ["test_id", "rfr_id", "rfr_type_code"]

# How many rows to read at a time. 1 million rows fits comfortably in memory.
# The underscores in 1_000_000 are just for readability; Python ignores them.
CHUNK = 1_000_000


# ---------------------------------------------------------------------------
# 3. HELPER FUNCTION: find the real data files inside a zip
# ---------------------------------------------------------------------------
# A function is a reusable block of code. We define it once with "def"
# and call it twice: once for the results zip and once for the failures zip.
def data_files(zip_path, prefix):
    """Return the names of the real monthly CSVs in a zip, skipping junk (rule 1)."""
    # "with" opens the zip and automatically closes it when the block ends
    with zipfile.ZipFile(zip_path) as z:
        # This is a "list comprehension": build a list by looping and filtering in one line.
        # z.namelist()  = every file name inside the zip
        # Path(n).name  = just the file name, without the folder part
        # Keep a name only if it starts with the prefix (e.g. "test_result_")
        # AND it isn't inside the __MACOSX junk folder.
        return [n for n in z.namelist()
                if Path(n).name.startswith(prefix) and "__MACOSX" not in n]


# ---------------------------------------------------------------------------
# 4. FILTER THE RESULTS FILE (one row per MOT test)
# ---------------------------------------------------------------------------
def filter_results():
    zip_path = RAW / "mot_results_2024.zip"          # "/" joins path parts with Path objects
    out_file = OUT / "mot_results_filtered.csv"
    out_file.unlink(missing_ok=True)                 # delete an old output so a re-run starts fresh

    kept_ids = set()       # a set = collection of unique values; remembers every test_id we keep
    make_counts = Counter()  # counts how many rows we keep per make (our sanity check)
    rows_in = 0            # running total of rows read

    with zipfile.ZipFile(zip_path) as z:
        # Loop over the 12 monthly files
        for name in data_files(zip_path, "test_result_"):
            print(f"Reading {name}")   # f"..." is an f-string: {name} is replaced by the value

            # z.open() reads one CSV *inside* the zip, without extracting it to disk
            with z.open(name) as f:
                # pd.read_csv with chunksize gives us the file 1 million rows at a time.
                #   usecols=          only load the columns we listed above
                #   dtype=str         read everything as text (SQL Server sets proper types later)
                #   keep_default_na=False  keep blank cells as "" instead of NaN (makes comparisons simpler)
                for chunk in pd.read_csv(f, usecols=RESULT_COLS, dtype=str,
                                         keep_default_na=False, chunksize=CHUNK):
                    rows_in += len(chunk)   # len() = number of rows in this chunk

                    # Apply filter rules 2 to 5.
                    # Each condition gives a True/False column; "&" means AND,
                    # so a row is kept only if every condition is True.
                    # The brackets around each condition are required in pandas.
                    keep = chunk[
                        (chunk["test_class_id"] == "4")                      # rule 2: cars only
                        & (chunk["test_type"] == "NT")                       # rule 3: normal tests, not retests
                        & (chunk["test_result"].isin(["P", "F", "PRS"]))     # rule 4: completed tests only
                        & (chunk["make"].isin(MAKES))                        # rule 5: our 10 makes
                    ]

                    # MGs first used before 2011 are old MG Rovers, a different company.
                    # Dates are text like "2006-03-01", and text in YYYY-MM-DD format
                    # sorts in date order, so "<" works. A blank date ("") also counts
                    # as before 2011, so MGs with no date are dropped too.
                    old_mg = (keep["make"] == "MG") & (keep["first_use_date"] < "2011-01-01")
                    keep = keep[~old_mg]   # "~" means NOT: keep every row that is not an old MG

                    # Save this chunk by appending it to the output file.
                    #   mode="a"      append (add to the end) instead of overwriting
                    #   header=...    write column names only if the file doesn't exist yet
                    #   index=False   don't write pandas' row numbers as an extra column
                    keep.to_csv(out_file, mode="a", header=not out_file.exists(), index=False)

                    kept_ids.update(keep["test_id"])   # remember these test_ids for the failures step
                    make_counts.update(keep["make"])   # add this chunk's rows to the per-make count

    # Print a summary so we can sanity-check the result.
    # {rows_in:,} formats a number with thousands commas, e.g. 12,345,678
    print(f"\nResults: read {rows_in:,} rows, kept {sum(make_counts.values()):,}")
    for make, n in make_counts.most_common():          # most_common() = sorted, largest first
        print(f"  {make:<10} {n:>12,}")                # <10 = left-align in 10 spaces, >12 = right-align
    return kept_ids   # hand the set of kept test_ids back to whoever called this function


# ---------------------------------------------------------------------------
# 5. FILTER THE FAILURE ITEMS FILE (one row per defect)
# ---------------------------------------------------------------------------
def filter_failures(kept_ids):
    zip_path = RAW / "mot_failure_items_2024.zip"
    out_file = OUT / "mot_failures_filtered.csv"
    out_file.unlink(missing_ok=True)
    rows_in = rows_out = 0   # set both counters to 0 in one line

    with zipfile.ZipFile(zip_path) as z:
        for name in data_files(zip_path, "test_item_"):
            print(f"Reading {name}")
            with z.open(name) as f:
                for chunk in pd.read_csv(f, usecols=FAILURE_COLS, dtype=str,
                                         keep_default_na=False, chunksize=CHUNK):
                    rows_in += len(chunk)

                    keep = chunk[
                        chunk["test_id"].isin(kept_ids)              # rule 7: only defects from tests we kept
                        & chunk["rfr_type_code"].isin(["F", "P"])    # rule 8: real failures, not advisories
                    ]
                    keep.to_csv(out_file, mode="a", header=not out_file.exists(), index=False)
                    rows_out += len(keep)

    print(f"\nFailures: read {rows_in:,} rows, kept {rows_out:,}")


# ---------------------------------------------------------------------------
# 6. RUN EVERYTHING
# ---------------------------------------------------------------------------
# This line means: only run the code below when this file is run directly
# (python python/01_filter_mot.py), not when another script imports it.
if __name__ == "__main__":
    ids = filter_results()   # step 1: filter tests, get back the kept test_ids
    filter_failures(ids)     # step 2: filter defects using those test_ids
    print("\nDone.")

# Note: duplicates are NOT removed here on purpose. That is cleaning,
# and it happens in SQL (Phase 4), where every fix is counted and logged.