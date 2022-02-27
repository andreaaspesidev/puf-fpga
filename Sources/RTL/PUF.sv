`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2022 11:40:40 AM
// Design Name: 
// Module Name: PUF
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module PUF #(
    parameter NUM_LOOPS = 1280,

    parameter TOT_CNT_BITS = 32,
    parameter FIRST_CNT_BITS = 2,

    parameter REPETITIONS_BITS = 13,
    parameter REPETITIONS = (2**(REPETITIONS_BITS-1)),

    parameter EVAL_TIME_BITS = 16,
    parameter EVAL_TIME = (2**(EVAL_TIME_BITS-1)),

    parameter CHALLENGE_BITS = 4
) 

(
    //common inputs
    input clk,
    input reset,
    
    //inputs to StateMachine
    input start_puf, //linked to FSM start signal
    input [CHALLENGE_BITS-1:0] challenge,

    //output from core
    output [TOT_CNT_BITS-1:0] loop_response,
    output [$clog2(NUM_LOOPS-1):0] loop_number,

    //output from StateMachine
    output store_response_puf,
    output done

);

wire enable_core; 
//wire [$clog2(NUM_LOOPS-1):0] loop_select;
wire reset_puf;

Core #(
  .NUM_LOOPS(NUM_LOOPS),
  .TOT_CNT_BITS(TOT_CNT_BITS),
  .FIRST_CNT_BITS (FIRST_CNT_BITS)
)
Core_inst (
  .clk (clk),
  .reset (reset_puf),
  .enable (enable_core),
  .loop_select (loop_number),
  .response  (loop_response)
);

StateMachine #(
  .NUM_LOOPS(NUM_LOOPS),
  .REPETITIONS_BITS(REPETITIONS_BITS),
  .REPETITIONS(REPETITIONS),
  .EVAL_TIME_BITS(EVAL_TIME_BITS),
  .EVAL_TIME(EVAL_TIME),
  .CHALLENGE_BITS (CHALLENGE_BITS)
)
StateMachine_inst (
  .clk (clk),
  .reset (reset),

  .start (start_puf),
  .challenge (challenge),

  .done (done),
  .reset_puf (reset_puf),
  .select_puf (loop_number),
  .enable_puf (enable_core),
  .store_response_puf  (store_response_puf)
);


endmodule
