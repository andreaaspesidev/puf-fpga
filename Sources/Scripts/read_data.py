import binascii
import serial
import numpy as np


def i2b (i):
    """"""
    return i.to_bytes(length = 1, byteorder="little",signed=False)



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

# Auth ID
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
    print("---------------")
    while i < NUM_LOOPS:
        # Read 4 bytes
        bytes = serial_port.read(4)
        # Convert to 32bit int
        frequency = int.from_bytes(bytes=bytes, byteorder="big",signed=False)
        frequencies.append(frequency)
        # Print
        print(f"[{i}]{binascii.hexlify(bytearray(bytes)).decode('ascii')}: {frequency}")
        i = i + 1
    print("---------------")
    print("End")

    max = np.max(frequencies)
    max_bits = np.math.ceil(np.math.log2(max))
    print(f"max = {max}, max_bits = {max_bits}")
    

else:
    print("Auth failed!")

