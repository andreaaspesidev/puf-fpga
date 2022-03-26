import csv
import os
import numpy as np
from pathlib import Path
import re

# Usage
# 1. From the root folder of the project, launch: python3 Analysis/Scripts/read_data_bulk.py

def natural_sort(l): 
    convert = lambda text: int(text) if text.isdigit() else text.lower()
    alphanum_key = lambda key: [convert(c) for c in re.split('([0-9]+)', key)]
    return sorted(l, key=alphanum_key)

def save_csv(array, name):
    existing_data = []
    # Check if another csv exists
    if os.path.exists(name):
        # Read csv
        with open(name, 'r') as f:
            reader = csv.reader(f)
            for row in reader:
                existing_data.append(row)
    # Add another column
    for i in range(0, len(array)):
        if i < len(existing_data):
            existing_data[i].append(array[i])
        else:
            existing_data.append([array[i]])
    # Write changes
    with open(name, 'w') as f:
        # create the csv writer
        writer = csv.writer(f)
        for row in existing_data:
            # write a row to the csv file
            writer.writerow(row)

def read_csv(name):
    data = []
    if os.path.exists(name):
        # Read csv
        with open(name, 'r') as f:
            reader = csv.reader(f)
            for row in reader:
                data.append(row)
    return data

def hamming_distance(arr1, arr2): 
    distance = 0
    L = len(arr1)
    for i in range(L):
        if arr1[i] != arr2[i]:
            distance += 1
    return distance

def hd_intra(challenge_row):
    return np.sum([
        hamming_distance(challenge_row[0], challenge_row[exp_num]) / len(challenge_row[0])
        for exp_num in range(1, len(challenge_row))]) / len(challenge_row)
    
def reliability(challenge_row):
    return 1 - hd_intra(challenge_row)

def compute_reliability(data, name, output_file):
    # On each row, we have a challenge response id. We want ideally to have the same response
    reliabilities = []
    i = 1
    reliabilities.append(name)
    for challenge_row in data:
        row_reliability = reliability(challenge_row)
        reliabilities.append(row_reliability)
        print(f"[CHALLENGE #{i}] Reliability: {row_reliability}")
        i = i + 1
    save_csv(reliabilities, output_file)

# Read data
RESPONSE_PATH = Path("Analysis/Data/TERO_AA/responses")
OUTPUT_FILE = Path("Analysis/reliabilities_TERO_AA.csv")
for csv_name in natural_sort(os.listdir(RESPONSE_PATH)):
    experiment_name = re.search(r'responses_([\w_]+)\.csv', csv_name)[1]
    data = read_csv(str(RESPONSE_PATH / csv_name))
    compute_reliability(data, experiment_name, OUTPUT_FILE)