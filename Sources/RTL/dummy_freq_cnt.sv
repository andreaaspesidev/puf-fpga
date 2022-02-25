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


module dummy_freq_cnt #(
    parameter N_TERO_BITS = 32,
    parameter CHALLENGE_BITS = 4) (

    //input [N_TERO_BITS-1:0] curr_TERO, // number of current TERO selected
    input clk,
    input [CHALLENGE_BITS-1:0] challenge_in,

    input increment,
    input reset,
    
    output reg [N_TERO_BITS-1:0] next_TERO = 0 // number of next TERO to select

);

    //assign next_TERO = curr_TERO + 1; //in this dummy implementation the next TERO is the current one + 1

    always@(posedge(clk))

    begin
        if (reset == 1'b1)
            next_TERO <= '0;
        else if (increment == 1'b1)

        begin
            next_TERO <= next_TERO + 1;
        end

    end


endmodule
