// Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2020.2 (lin64) Build 3064766 Wed Nov 18 09:12:47 MST 2020
// Date        : Sun Feb 27 23:45:20 2022
// Host        : pop-os running 64-bit Pop!_OS 21.10
// Command     : write_verilog -force -mode synth_stub -rename_top fifo_generator_0 -prefix
//               fifo_generator_0_ fifo_generator_0_stub.v
// Design      : fifo_generator_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a35tcpg236-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "fifo_generator_v13_2_5,Vivado 2020.2" *)
module fifo_generator_0(clk, srst, din, wr_en, rd_en, dout, full, empty)
/* synthesis syn_black_box black_box_pad_pin="clk,srst,din[31:0],wr_en,rd_en,dout[7:0],full,empty" */;
  input clk;
  input srst;
  input [31:0]din;
  input wr_en;
  input rd_en;
  output [7:0]dout;
  output full;
  output empty;
endmodule
