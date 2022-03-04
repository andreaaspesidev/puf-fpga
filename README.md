# TERO PUF Implementation on Xilinx Artix7 FPGA
### Authors: Andrea Aspesi, Alessandro Putortì

Physical Unclonable Functions (PUFs) are becoming important in recent years for various purposes such as Device Identification, True Random Number Generators, Cryptographic Key Generators, IP Protection.  
Different ways of realizing PUFs have been proposed in literature, exploiting process variations occurring inside chips.  
Among them, some can be efficiently implemented in FPGAs: in our project, after analyzing the state of the art, we chose to implement a Transient Effect Ring Oscillator (TERO) PUF.
TERO PUF offers high resistance to surrounding logic influence and temperature changes, providing at the same time high uniqueness and reliability.  
As target, we chose Basys3 boards from Digilent, shipped with Xilinx Artix7 XC7-A35T.