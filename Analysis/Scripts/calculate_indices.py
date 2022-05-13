import sys

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
        print(str(grouped_frequencies[i,currBatch]) + " > " + str(grouped_frequencies[j,currBatch]))
        response[currBatch] = grouped_frequencies[i,currBatch] > grouped_frequencies[j,currBatch]
    return response # 80 bit

# i,   j    (extended)
# 0000 0001     
# 0000 0010     0001 0010
# 0000 0011     0001 0011   0010 0011
# 0000 0100     0001 0100   0010 0100   0011 0100
# 0000 0101     0001 0101   0010 0101   0011 0101   0100 0101
# 0000 0110     0001 0110   0010 0110   0011 0110   0100 0110   0101 0110   
# 0000 0111     0001 0111   0010 0111   0011 0111   0100 0111   0101 0111   0110 0111
# 0000 1000     0001 1000   0010 1000   0011 1000   0100 1000   0101 1000   0110 1000   0111 1000   
# 0000 1001     0001 1001   0010 1001   0011 1001   0100 1001   0101 1001   0110 1001   0111 1001   1000 1001   
# 0000 1010     0001 1010   0010 1010   0011 1010   0100 1010   0101 1010   0110 1010   0111 1010   1000 1010   1001 1010
# 0000 1011     0001 1011   0010 1011   0011 1011   0100 1011   0101 1011   0110 1011   0111 1011   1000 1011   1001 1011   1010 1011
# 0000 1100     0001 1100   0010 1100   0011 1100   0100 1100   0101 1100   0110 1100   0111 1100   1000 1100   1001 1100   1010 1100   1011 1100
# 0000 1101     0001 1101   0010 1101   0011 1101   0100 1101   0101 1101   0110 1101   0111 1101   1000 1101   1001 1101   1010 1101   1011 1101   1100 1101
# 0000 1110     0001 1110   0010 1110   0011 1110   0100 1110   0101 1110   0110 1110   0111 1110   1000 1110   1001 1110   1010 1110   1011 1110   1100 1110   1101 1110
# 0000 1111     0001 1111   0010 1111   0011 1111   0100 1111   0101 1111   0110 1111   0111 1111   1000 1111   1001 1111   1010 1111   1011 1111   1100 1111   1101 1111   1110 1111

# i,   j    (compact)
# 0000 0001     1110 1111   1101 1110   1100 1101   1011 1100   1010 1011   1001 1010   1000 1001
# 0000 0010     0001 0010   1101 1111   1100 1110   1011 1101   1010 1100   1001 1011   1000 1010
# 0000 0011     0001 0011   0010 0011   1100 1111   1011 1110   1010 1101   1001 1100   1000 1011
# 0000 0100     0001 0100   0010 0100   0011 0100   1011 1111   1010 1110   1001 1101   1000 1100
# 0000 0101     0001 0101   0010 0101   0011 0101   0100 0101   1010 1111   1001 1110   1000 1101
# 0000 0110     0001 0110   0010 0110   0011 0110   0100 0110   0101 0110   1001 1111   1000 1110
# 0000 0111     0001 0111   0010 0111   0011 0111   0100 0111   0101 0111   0110 0111   1000 1111
# 0000 1000     0001 1000   0010 1000   0011 1000   0100 1000   0101 1000   0110 1000   0111 1000   
# 0000 1001     0001 1001   0010 1001   0011 1001   0100 1001   0101 1001   0110 1001   0111 1001      
# 0000 1010     0001 1010   0010 1010   0011 1010   0100 1010   0101 1010   0110 1010   0111 1010      
# 0000 1011     0001 1011   0010 1011   0011 1011   0100 1011   0101 1011   0110 1011   0111 1011         
# 0000 1100     0001 1100   0010 1100   0011 1100   0100 1100   0101 1100   0110 1100   0111 1100            
# 0000 1101     0001 1101   0010 1101   0011 1101   0100 1101   0101 1101   0110 1101   0111 1101               
# 0000 1110     0001 1110   0010 1110   0011 1110   0100 1110   0101 1110   0110 1110   0111 1110                  
# 0000 1111     0001 1111   0010 1111   0011 1111   0100 1111   0101 1111   0110 1111   0111 1111                    
CORRECT_INDICES_PER_CHALLENGE = [
    0b00000001,
    0b00000010,     
    0b00000011,     
    0b00000100,     
    0b00000101,     
    0b00000110,     
    0b00000111,     
    0b00001000,     
    0b00001001,          
    0b00001010,         
    0b00001011,          
    0b00001100,                
    0b00001101,                   
    0b00001110,                       
    0b00001111,

    0b11101111,   
    0b00010010,   
    0b00010011,   
    0b00010100,   
    0b00010101,   
    0b00010110,   
    0b00010111,   
    0b00011000,   
    0b00011001,   
    0b00011010,   
    0b00011011,   
    0b00011100,   
    0b00011101,  
    0b00011110,   
    0b00011111, 

    0b11011110,   
    0b11011111,   
    0b00100011,   
    0b00100100,   
    0b00100101,   
    0b00100110,   
    0b00100111,   
    0b00101000,    
    0b00101001,    
    0b00101010,     
    0b00101011,       
    0b00101100,   
    0b00101101,     
    0b00101110,   
    0b00101111, 

    0b11001101,   
    0b11001110,   
    0b11001111,   
    0b00110100,   
    0b00110101,   
    0b00110110,   
    0b00110111,   
    0b00111000,   
    0b00111001,  
    0b00111010,   
    0b00111011,   
    0b00111100,   
    0b00111101,   
    0b00111110,   
    0b00111111,   

    0b10111100,   
    0b10111101,   
    0b10111110,   
    0b10111111,   
    0b01000101,   
    0b01000110,   
    0b01000111,   
    0b01001000,    
    0b01001001,   
    0b01001010,   
    0b01001011,   
    0b01001100,   
    0b01001101,   
    0b01001110,   
    0b01001111,   

    0b10101011,   
    0b10101100,   
    0b10101101,   
    0b10101110,   
    0b10101111,   
    0b01010110,   
    0b01010111,   
    0b01011000,   
    0b01011001,   
    0b01011010,   
    0b01011011,   
    0b01011100,   
    0b01011101,   
    0b01011110,  
    0b01011111,   

    0b10011010,  
    0b10011011,   
    0b10011100,   
    0b10011101,   
    0b10011110,   
    0b10011111,   
    0b01100111,   
    0b01101000,   
    0b01101001,   
    0b01101010,   
    0b01101011,   
    0b01101100,   
    0b01101101,   
    0b01101110,   
    0b01101111,  

    0b10001001,
    0b10001010,
    0b10001011,
    0b10001100,
    0b10001101,
    0b10001110,
    0b10001111,
    0b01111000,
    0b01111001,
    0b01111010,
    0b01111011,
    0b01111100,
    0b01111101,
    0b01111110,
    0b01111111
]

# Challenge Number
# 0000 0000     0000 1111   0001 1110   0010 1101   0011 1100   0100 1011   0101 1010   0110 1001
# 0000 0001     0001 0000   0001 1111   0010 1110   0011 1101   0100 1100   0101 1011   0110 1010
# 0000 0010     0001 0001   0010 0000   0010 1111   0011 1110   0100 1101   0101 1100   0110 1011
# 0000 0011     0001 0010   0010 0001   0011 0000   0011 1111   0100 1110   0101 1101   0110 1100
# 0000 0100     0001 0011   0010 0010   0011 0001   0100 0000   0100 1111   0101 1110   0110 1101
# 0000 0101     0001 0100   0010 0011   0011 0010   0100 0001   0101 0000   0101 1111   0110 1110
# 0000 0110     0001 0101   0010 0100   0011 0011   0100 0010   0101 0001   0110 0000   0110 1111
# 0000 0111     0001 0110   0010 0101   0011 0100   0100 0011   0101 0010   0110 0001   0111 0000   
# 0000 1000     0001 0111   0010 0110   0011 0101   0100 0100   0101 0011   0110 0010   0111 0001      
# 0000 1001     0001 1000   0010 0111   0011 0110   0100 0101   0101 0100   0110 0011   0111 0010      
# 0000 1010     0001 1001   0010 1000   0011 0111   0100 0110   0101 0101   0110 0100   0111 0011         
# 0000 1011     0001 1010   0010 1001   0011 1000   0100 0111   0101 0110   0110 0101   0111 0100            
# 0000 1100     0001 1011   0010 1010   0011 1001   0100 1000   0101 0111   0110 0110   0111 0101               
# 0000 1101     0001 1100   0010 1011   0011 1010   0100 1001   0101 1000   0110 0111   0111 0110                  
# 0000 1110     0001 1101   0010 1100   0011 1011   0100 1010   0101 1001   0110 1000   0111 0111  


# Returns i,j given challenge number
import numpy as np


def calc_indices(challenge_num):
    a = int(challenge_num) >> 4
    b = int(challenge_num) & 0xF
    c = a + 1
    d = b + c
    if d & 0x10:   # carry, new column
        i = (~c) & 0xF
        j = b
    else:
        i = a
        j = d & 0xF

    return i,j

# Test Indices
for challenge_num in range(0, 120):
    i,j = calc_indices(challenge_num)
    res = i << 4 | j
    if CORRECT_INDICES_PER_CHALLENGE[challenge_num] != res:
        print("Indices Generation Failed!")
        exit(-1)
print("Indices Generation Okay!")

# After the indices, the needed frequencies are found with:
# start:    i*8 + 128*k + l =  i + (k<<7) + l   with 0<=k<=9, 0<=l<=7
# end:      j*8 + 128*k + l =  (j<<3) + (k<<7) + l   with 0<=k<=9, 0<=l<=7
k = 0
l = 0
i_active = True
ended = False
def next_frequency(challenge_num):
    global k, l, i_active, ended

    i,j = calc_indices(challenge_num)
    
    if i_active:
        index = (i<<3) + (k << 7) + l
    else:
        index = (j<<3) + (k << 7) + l
    
    k += 1
    if l == 7:
        if k == 10:
            if not i_active:
                ended = True
            else:
                i_active = 0
                k = 0
                l = 0
    elif k == 10:
        k = 0
        l += 1

    return index


def calc_response(frequencies):
    half = int(len(frequencies)/2)
    start = frequencies[0:half]
    end = frequencies[half:]
    res = []
    for i in range(0, half):
        print(str(start[i]) + " > " + str(end[i]))
        res.append(start[i] > end[i])
    
    return res

string = ""
for num in range(0,120):
    i,j = calc_indices(num)
    #print(f"[{num}] i: {i}, j: {j}")
    string = string + "8'd" + str(i << 4 | j) + ", "
print(string)
print()
print()

test = [i for i in range(0, 1280)]
gfr = group_frequencies(test)
np.set_printoptions(suppress=True)

print(gfr)

print(generate_unique_id(0,1, gfr))

string = ""
count = 0
g1_freqs = []
while(True):
    n = next_frequency(61)
    g1_freqs.append(test[n])
    string = string + "11'd" + str(n) + ", "
    if ended:
        break
    count += 1
print(string)
print(count)

print(calc_response(g1_freqs))