`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/22/2022 03:28:23 PM
// Design Name: 
// Module Name: Core
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


module Core #(
parameter NUM_LOOPS = 4, //number of TERO loops to generate
parameter REPETITIONS = 1, //number of times a TERO loop must be evaluated to compute average
parameter EVAL_TIME = 16, //number of clk cycles to evaluate a tero loop
parameter CHALLENGE_BITS = 4 //bits for the input challenge
)
    
(
    input clk,
    input reset,

    input start, // Start the evaluation of all the tero loops, based on the value of the challenge
    input [CHALLENGE_BITS-1:0] challenge, // Challenge number used to select the way tero loops are selected​

    input next_enable, //Waited to be 1, before passing to evaluate the next tero loop (from AVG module)​
    
    output done, // Asserted when the whole computation is finished (all the tero loops that had to be evaluated were evaluated)
    output reset_puf, // Signal used to reset all tero instances
    output [$clog2(NUM_LOOPS-1):0] select_puf, // Signal containing the number of the loop to evaluate
    output enable_puf, // Signals used to start the selected loop evaluation
    output add_response_puf // When asserted, the response of the puf must be saved (in the AVG module)​
    );


    




endmodule

