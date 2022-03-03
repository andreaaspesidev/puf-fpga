import binascii
import serial
import numpy as np
import csv
import os
from pathlib import Path

# Usage
# 1. Adjust EXPERIMENT_SUFFIX
# 2. From the root folder of the project, launch: python3 Analysis/Scripts/read_data_bulk.py
# 3. Move frequencies and responses to their folder manually

# General configuration
READ_NUMBER = 100
EXPERIMENT_SUFFIX = "_EVAL6_REP13"
OUT_DIR = "Analysis/Data/TERO_AP"

def i2b (i):
    return i.to_bytes(length = 1, byteorder="little",signed=False)

def save_csv(array, name):
    name = str(Path(OUT_DIR) / Path(os.path.splitext(name)[0] + EXPERIMENT_SUFFIX + ".csv"))
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
    freqs = np.array(freqs, dtype=np.int)
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
    response = np.zeros((NUM_BATCHES))
    for currBatch in range (0,NUM_BATCHES): #num of batches
            response[currBatch] = grouped_frequencies[i,currBatch] > grouped_frequencies[j,currBatch]
    return response # 80 bit

def bit_array_to_string(arr):
    response_char = ''
    for i in range(0, len(arr)):
        response_char = response_char + ('1' if arr[i] else '0')
    return response_char 

# -------------
#   Code 
# -------------
def evaluation():
    # Define and open port
    serial_port = serial.Serial(port='/dev/ttyUSB1', 
                                baudrate=9600, 
                                bytesize=serial.EIGHTBITS, 
                                parity=serial.PARITY_NONE, 
                                stopbits=serial.STOPBITS_ONE)
    # Params
    NUM_LOOPS = 1280
    AUTH_ID = i2b(0b10101010)
    AUTH_RESPONSE = i2b(0b10101011)
    CHALLENGE = i2b(0b00000000)

    # Send Auth request
    print("-----------------------------")
    print("------ AUTHENTICATION -------")
    print("-----------------------------")
    print(f"Sending Auth request")
    serial_port.write(AUTH_ID)
    response = serial_port.read()

    print(f"Auth response: {response}")
    if response == AUTH_RESPONSE:
        print("Response OK!")
        # Send challenge
        serial_port.write(CHALLENGE)
        # Read data
        frequencies = []
        i = 0
        print("-----------------------------")
        print("--- RAW LOOPS FREQUENCIES ---")
        print("-----------------------------")
        while i < NUM_LOOPS:
            # Read 4 bytes
            bytes = serial_port.read(4)
            # Convert to 32bit int
            frequency = int.from_bytes(bytes=bytes, byteorder="big",signed=False)
            frequencies.append(frequency)
            # Print
            print(f"[LOOP #{i}] {binascii.hexlify(bytearray(bytes)).decode('ascii')} (hex) -> {frequency} (dec)")
            i = i + 1
        print("-----------------------------")
        print("-------- STATISTICS ---------")
        print("-----------------------------")
        # Save frequencies to a file
        save_csv(frequencies, 'frequencies.csv')
        # Compute statistics
        max = np.max(frequencies)
        max_bits = np.math.ceil(np.math.log2(max))
        print(f"Maximum frequency: {max}")
        print(f"Maximum number of bits used: {max_bits}")
        print("-----------------------------")
        print("------ IDENTIFICATION -------")
        print("-----------------------------")
        # Split frequencies
        gfreqs = group_frequencies(frequencies)
        print(f"Available challenges: {len(CHALLENGE_TO_PARAMS)}")
        responses = []
        for challenge_num in range(0,len(CHALLENGE_TO_PARAMS)):
            # Generate id
            unique_id = generate_unique_id(CHALLENGE_TO_PARAMS[challenge_num][0],
                                           CHALLENGE_TO_PARAMS[challenge_num][1],
                                           gfreqs)
            unique_id_str = bit_array_to_string(unique_id)
            responses.append(unique_id_str)
            print(f"[CHALLENGE #{challenge_num}] Unique ID: {unique_id_str}")
        save_csv(responses, 'responses.csv')
    else:
        print("Auth failed!")



# Generate challenges mapping
generate_challenge_to_params()

# Run evaluation
while READ_NUMBER > 0:
    evaluation()
    READ_NUMBER = READ_NUMBER - 1