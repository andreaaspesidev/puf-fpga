`timescale 1ns / 1ps

//! This module computes, given the challenge, the next TERO to evaluate. At the moment it ignores the Challenge and outputs the very next TERO loop number. 
//! It's possible to implement a variant of this block exposing the next TERO number basing on the challenge given in input. It would be necessary to set the local parameter "last_TERO", in order to
//! correctly assert the "done" signal at the end. 

module dummy_freq_cnt #(
    parameter NUM_LOOPS = 32, //! number of total TERO loops
    parameter CHALLENGE_BITS = 8) ( //!number of bits to represent challenge

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
