import csv
import os
from pathlib import Path
import numpy as np
import pandas as pd

def save_csv(array, path):
    # Write changes
    with open(path, 'w') as f:
        # create the csv writer
        writer = csv.writer(f)
        for row in array:
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

# -------------
#   2 Comp 
# -------------
CHALLENGE_TO_PARAMS = []
def generate_challenge_to_params():
    # 0,1
    # ...
    # 0,15
    # 1,2
    # ...
    # 1,15
    # ...
    # 14,15
    for i in range(0, 16):
        for j in range(i+1, 16):
            CHALLENGE_TO_PARAMS.append([i,j])

def group_frequencies(freqs):
    # Based on the assumption we have 8 different cell types, we group each type in the right column
    NUM_INSTANCES = freqs.shape[0]  # 1280
    NUM_TYPES = 8
    BATCH_SIZE = 16
    batchArray = np.zeros((int(NUM_INSTANCES/NUM_TYPES),NUM_TYPES))
    for instance_type in range(0, NUM_TYPES):
        batchArray[:,instance_type] = freqs[instance_type::NUM_TYPES] # from the starting index, we sample every 8 elements
    # batcharray: 160x8
    BATCH_COLUMNS = int(NUM_INSTANCES/BATCH_SIZE)   # 80
    fpgaBatch = np.zeros((BATCH_SIZE, BATCH_COLUMNS))
    col = 0
    for instance_type in range(0,NUM_TYPES):
        # get old column
        current_col = batchArray[:,instance_type]
        # create 10 new columns
        for index in range(0, len(current_col), BATCH_SIZE):
            fpgaBatch[:,col] = current_col[index:index+BATCH_SIZE]
            col += 1
        # continue for each of the 8 columns (8x10 = 80 columns)
    # set the new batch
    return fpgaBatch

def generate_unique_id(i,j, grouped_frequencies):
    assert i!=j
    NUM_BATCHES = grouped_frequencies.shape[1]
    response = np.zeros((NUM_BATCHES), dtype=np.int)
    for currBatch in range (0,NUM_BATCHES): #num of batches
            response[currBatch] = grouped_frequencies[i,currBatch] > grouped_frequencies[j,currBatch]
    return response # 80 bit

def bit_array_to_string(arr):
    response_char = ''
    for i in range(0, len(arr)):
        response_char = response_char + ('1' if arr[i] else '0')
    return response_char 

# Uniqueness
def hamming_distance(arr1, arr2): 
    distance = 0
    L = len(arr1)
    for i in range(L):
        if arr1[i] != arr2[i]:
            distance += 1
    return distance

# uniqueness = 1 (tutti flip)
# uniqueness = 0 (nessun flip)
# uniqueness = 0.5 (50% prob. flip)
# 1111
# 0000
# 2/(2*1) * sum(4/4) = 1
# 2/(2*1) * sum(0/4) = 0 

def calc_uniqueness(data):
    num_bits = len(data[0])
    num_devices = len(data)
    return 2/(num_devices*(num_devices-1)) * np.sum([
        np.sum([
            hamming_distance(data[i], data[j])/num_bits
            for j in range(i+1, num_devices)])  
        for i in range(0, num_devices-1)])

# Read csv
REPORT_PATH = Path('Analysis/Data/Freq_vs_params/Report_freq_vs_params.csv')
report = pd.read_csv(REPORT_PATH, sep=',')

generate_challenge_to_params()
# Extract data, calculate responses
boards = np.unique(report['BOARD_NUM'])
board_responses = []
for board_num in boards:
    board_data = report[report['BOARD_NUM'] == board_num]
    for eval_bits in np.unique(board_data['EVAL_BITS']):
        eval_data = board_data[board_data['EVAL_BITS'] == eval_bits]
        for rep_bits in np.unique(eval_data['REP_BITS']):
            # Extract frequencies
            frequencies = np.array(eval_data[eval_data['REP_BITS'] == rep_bits]['FREQ'], dtype=np.int)
            # Group frequencies
            gfreqs = group_frequencies(frequencies)
            # Calculate challenge
            for challenge_num in range(0,len(CHALLENGE_TO_PARAMS)):
                response = generate_unique_id(CHALLENGE_TO_PARAMS[challenge_num][0],
                                              CHALLENGE_TO_PARAMS[challenge_num][1], 
                                              gfreqs)    
                response_str = bit_array_to_string(response)
                board_responses.append([challenge_num, response_str, eval_bits, rep_bits, board_num])

# Calculate uniqueness fixing the challenge number
board_responses = pd.DataFrame(board_responses, columns=['CHALLENGE_NUM','CHALLENGE','EVAL_BITS','REP_BITS','BOARD_NUM'])
board_responses.to_csv(str(Path('Analysis/Data/responses.csv')), index=False)
index = 0
final_response = [['CHALLENGE_NUM','UNIQUENESS','EVAL_BITS','REP_BITS']]
uniq_values = []
uniq_worst = 0.5 # ideal
uniq_worst_settings = []
for challenge_num in range(0,len(CHALLENGE_TO_PARAMS)):
    challenge_data = board_responses[board_responses['CHALLENGE_NUM'] == challenge_num]
    for eval_bits in np.unique(challenge_data['EVAL_BITS']):
        eval_data = challenge_data[challenge_data['EVAL_BITS'] == eval_bits]
        for rep_bits in np.unique(eval_data['REP_BITS']):
            responses = np.array(eval_data['CHALLENGE'],dtype=np.object)
            if len(responses) > 1: # only if we have something to compare
                uniqueness = calc_uniqueness(responses) 
                uniq_values.append(uniqueness)
                if abs(uniqueness - 0.5) > abs(uniq_worst - 0.5):
                   uniq_worst = uniqueness
                   uniq_worst_settings = [challenge_num, eval_bits, rep_bits]
                final_response.append([challenge_num, uniqueness, eval_bits, rep_bits])
               
# Add column to the dataset
save_csv(final_response, str(Path('Analysis/Data/uniqueness.csv')))

# Print general average
print(f"Mean uniqueness: {np.mean(uniq_values)}")
print(f"Worst uniqueness: {uniq_worst} -> (challenge_num,eval_bits,rep_bits) {uniq_worst_settings}")