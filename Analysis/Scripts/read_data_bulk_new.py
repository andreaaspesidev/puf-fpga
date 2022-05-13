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
# During the original evaluation:
# 0000 0001 0    119       15  117       30  114       45  110       60  105       75  99        90  92        105
# 0000 0010 1    0001 0010 16  118       31  115       46  111       61  106       76  100       91  93        106
# 0000 0011 2    0001 0011 17  0010 0011 32  116       47  112       62  107       77  101       92  94        107
# 0000 0100 3    0001 0100 18  0010 0100 33  0011 0100 48  113       63  108       78  102       93  95        108
# 0000 0101 4    0001 0101 19  0010 0101 34  0011 0101 49  0100 0101 64  109       79  103       94  96        109
# 0000 0110 5    0001 0110 20  0010 0110 35  0011 0110 50  0100 0110 65  0101 0110 80  104       95  97        110
# 0000 0111 6    0001 0111 21  0010 0111 36  0011 0111 51  0100 0111 66  0101 0111 81  0110 0111 96  98        111
# 0000 1000 7    0001 1000 22  0010 1000 37  0011 1000 52  0100 1000 67  0101 1000 82  0110 1000 97  0111 1000 112  
# 0000 1001 8    0001 1001 23  0010 1001 38  0011 1001 53  0100 1001 68  0101 1001 83  0110 1001 98  0111 1001 113 1000 1001   
# 0000 1010 9    0001 1010 24  0010 1010 39  0011 1010 54  0100 1010 69  0101 1010 84  0110 1010 99  0111 1010 114 1000 1010   1001 1010
# 0000 1011 10   0001 1011 25  0010 1011 40  0011 1011 55  0100 1011 70  0101 1011 85  0110 1011 100 0111 1011 115 1000 1011   1001 1011   1010 1011
# 0000 1100 11   0001 1100 26  0010 1100 41  0011 1100 56  0100 1100 71  0101 1100 86  0110 1100 101 0111 1100 116 1000 1100   1001 1100   1010 1100   1011 1100
# 0000 1101 12   0001 1101 27  0010 1101 42  0011 1101 57  0100 1101 72  0101 1101 87  0110 1101 102 0111 1101 117 1000 1101   1001 1101   1010 1101   1011 1101   1100 1101
# 0000 1110 13   0001 1110 28  0010 1110 43  0011 1110 58  0100 1110 73  0101 1110 88  0110 1110 103 0111 1110 118 1000 1110   1001 1110   1010 1110   1011 1110   1100 1110   1101 1110
# 0000 1111 14   0001 1111 29  0010 1111 44  0011 1111 59  0100 1111 74  0101 1111 89  0110 1111 104 0111 1111 119 1000 1111   1001 1111   1010 1111   1011 1111   1100 1111   1101 1111   1110 1111 
# --- 14         ---- 28       ---- 41       ---- 53       ---- 64       ---- 74       ---- 83       ---- 91       ---- 98     ---- 104    ---- 109    ---- 113    ---- 116    ---- 118    ---- 119
challenge_sequence = [
    0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,  # skip 0
   16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29,  # skip 1
   32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, # skip 2
   48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, # skip 3
   64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, # skip 4
   80, 81, 82, 83, 84, 85, 86, 87, 88, 89, # skip 5
   96, 97, 98, 99,100,101,102,103,104,  # skip 6
   112,113,114,115,116,117,118,119, # skip 7
   105,106,107,108,109,110,111,
    90, 91, 92, 93, 94, 95,
    75, 76, 77, 78, 79,
    60, 61, 62, 63,
    45, 46, 47,
    30, 31,
    15
]

while READ_NUMBER > 0:
    responses = []
    for i in range(0, 120):
        challenge_num = challenge_sequence[i]
        evaluation()
    READ_NUMBER = READ_NUMBER - 1
    save_csv(responses, f'responses.csv')
    print(f"Missing {READ_NUMBER} repetitions!!")