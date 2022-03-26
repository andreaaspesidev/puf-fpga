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
EXPERIMENT_SUFFIX = "_CHALLENGE"
OUT_DIR = "Analysis/Data/TERO_AA"

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

def calc_response(frequencies):
    half = int(len(frequencies)/2)
    start = frequencies[0:half]
    end = frequencies[half:]
    return [start[i] > end[i] for i in range(0, half)]

def bit_array_to_string(arr):
    response_char = ''
    for i in range(0, len(arr)):
        response_char = response_char + ('1' if arr[i] else '0')
    return response_char 

# -------------
#   Code 
# -------------
challenge_num = 0
responses = []
def evaluation():
    # Define and open port
    serial_port = serial.Serial(port='/dev/ttyUSB1', 
                                baudrate=115200, 
                                bytesize=serial.EIGHTBITS, 
                                parity=serial.PARITY_NONE, 
                                stopbits=serial.STOPBITS_ONE)
    # Params
    NUM_LOOPS = 160
    AUTH_ID = i2b(0b10101010)
    AUTH_RESPONSE = i2b(0b10101011)
    CHALLENGE = i2b(challenge_num) # 14

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
        #save_csv(frequencies, 'frequencies.csv')
        # Compute statistics
        max = np.max(frequencies)
        max_bits = np.math.ceil(np.math.log2(max))
        print(f"Maximum frequency: {max}")
        print(f"Maximum number of bits used: {max_bits}")
        print("-----------------------------")
        print("------ IDENTIFICATION -------")
        print("-----------------------------")
        # Generate ID
        unique_id = calc_response(frequencies)
        unique_id_str = bit_array_to_string(unique_id)
        responses.append(unique_id_str)
    else:
        print("Auth failed!")



# Run evaluation
while READ_NUMBER > 0:
    responses = []
    for i in range(0, 120):
        challenge_num = i
        evaluation()
    READ_NUMBER = READ_NUMBER - 1
    save_csv(responses, f'responses.csv')
    print(f"Missing {READ_NUMBER} repetitions!!")