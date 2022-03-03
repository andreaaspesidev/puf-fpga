import binascii
import serial
import numpy as np
import csv


def i2b (i):
    return i.to_bytes(length = 1, byteorder="little",signed=False)

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


def write_csv (freqs, board_n, eval_bits, rep_bits):
    """This function takes as input an array of PUF frequencies and exports them to a csv file"""

    with open(f'frequencies_{board_n}_{eval_bits}_{rep_bits}_try.csv', 'w') as f:
        csv_fields = ["NUM_LOOP", "FREQ","EVAL_BITS","REP_BITS","BOARD_NUM"]
        writer = csv.writer(f)
        writer.writerow(csv_fields)
        csv_rows = [[currFreq,freqs[currFreq],eval_bits,rep_bits,board_n] for currFreq in range(len(freqs))]
        writer.writerows(csv_rows)

# -------------
#   Code 
# -------------

# Generate challenges mapping
generate_challenge_to_params()

# Define and open port
serial_port = serial.Serial(port='/dev/ttyUSB1', 
                            baudrate=9600, 
                            bytesize=serial.EIGHTBITS, 
                            parity=serial.PARITY_NONE, 
                            stopbits=serial.STOPBITS_ONE,
                            timeout=10*60)
# Params
NUM_LOOPS = 1280
AUTH_ID = i2b(0b10101010)
AUTH_RESPONSE = i2b(0b10101011)
CHALLENGE = i2b(0b00000000)

#
BOARD_NUM = 0
EVAL_BITS = 6
REPETITION_BITS = 2

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
    """ with open('frequencies.csv', 'w') as f:
        # create the csv writer
        writer = csv.writer(f)
        for freq in frequencies:
            # write a row to the csv file
            writer.writerow([freq]) """
    write_csv(frequencies,BOARD_NUM,EVAL_BITS,REPETITION_BITS)

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
    # Ask for challenge
    print(f"Available challenges: {len(CHALLENGE_TO_PARAMS)}")
    while True:
        challenge_num = -1
        while challenge_num < 1 or challenge_num > len(CHALLENGE_TO_PARAMS):
            challenge_num = int(input("Insert challenge number: "))
        # Map challenge to parameters
        unique_id = generate_unique_id(CHALLENGE_TO_PARAMS[challenge_num][0],CHALLENGE_TO_PARAMS[challenge_num][1],gfreqs)
        unique_id_str = bit_array_to_string(unique_id)
        print(f"Unique ID: {unique_id_str}")
else:
    print("Auth failed!")

