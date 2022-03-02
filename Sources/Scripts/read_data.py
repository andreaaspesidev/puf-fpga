import binascii
import serial

# Define and open port
serial_port = serial.Serial(port='/dev/ttyUSB1', 
                            baudrate=9600, 
                            bytesize=serial.EIGHTBITS, 
                            parity=serial.PARITY_NONE, 
                            stopbits=serial.STOPBITS_ONE,
                            timeout=10)
# Params
AUTH_ID = 0b10101010
AUTH_RESPONSE = 0b10101011
CHALLENGE = 0b00000000

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
    while i < 1280:
        # Read 4 bytes
        bytes = serial_port.read(4)
        # Convert to 32bit int
        frequency = int.from_bytes(bytes=bytes, byteorder="little",signed=False)
        frequencies.append(frequency)
        # Print
        print(f"[{i}]{binascii.hexlify(bytearray(bytes)).decode('ascii')}: {frequency}")
        i = i + 1
    print("---------------")
    print("End")
else:
    print("Auth failed!")