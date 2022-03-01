`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/24/2022 11:50:17 AM
// Design Name: 
// Module Name: dummy_freq_cnt
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

//! This module computes, given the challenge, the next TERO to evaluate

module dummy_freq_cnt #(
    parameter NUM_LOOPS = 32, //! number of total TERO loops
    parameter CHALLENGE_BITS = 8) ( //!number of bits to represent challenge

    //input [N_TERO_BITS-1:0] curr_TERO, // number of current TERO selected
    input clk,
    input [CHALLENGE_BITS-1:0] challenge_in, //! input challenge

    input increment, //! when this signal is asserted, the next TERO number is exposed (syncronous with clk)
    input reset, //! when this signal is asserted, the first TERO is exposed again
    
    output reg [$clog2(NUM_LOOPS-1):0] next_TERO, //! number of next TERO to evaluate
    output done //! Asserted when the last tero is supplied (combinatorial)
);
    localparam last_TERO = NUM_LOOPS - 1; // local parameter to define last TERO to be evaluated
    
    assign done = (next_TERO == last_TERO); //done output is combinatorial and asserted when the last TERO is supplied

    //assign next_TERO = curr_TERO + 1; //in this dummy implementation the next TERO is the current one + 1
    always@(posedge(clk))
    begin
        if (reset == 1'b1)
        begin
            next_TERO <= '0;
        end
        else if (increment == 1'b1)
        begin
            next_TERO <= next_TERO + 1;
        end
    end


endmodule
