# TERO PUF Implementation on Xilinx Artix-7 FPGA
### Authors: Andrea Aspesi, Alessandro Putortì

Physical Unclonable Functions (PUFs) are becoming important in recent years for various purposes such as Device Identification, True Random Number Generators, Cryptographic Key Generators, IP Protection.  
Different ways of realizing PUFs have been proposed in literature, exploiting process variations occurring inside chips.  
Among them, some can be efficiently implemented in FPGAs: in our project, after analyzing the state of the art, we chose to implement a Transient Effect Ring Oscillator (TERO) PUF.
TERO PUF offers high resistance to surrounding logic influence and temperature changes, providing at the same time high uniqueness and reliability.  
As target, we chose Basys3 boards from Digilent, shipped with Xilinx Artix-7 XC7-A35T.

The implementation is based on the one of the paper:
>A Fair and Comprehensive Large-Scale Analysis of
Oscillation-Based PUFs for FPGAs
> -- <cite>Alexander Wild, Georg T. Becker, Tim Guneysu</cite>
Published in 2017, available at https://ieeexplore.ieee.org/document/8056795