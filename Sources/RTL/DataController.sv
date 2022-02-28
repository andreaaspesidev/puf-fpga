`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/28/2022 05:50:03 PM
// Design Name: 
// Module Name: DataController
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


module DataController#(
    parameter UART_BITS = 8,
    parameter REQUEST_ID = 8'b10101010,
    parameter RESPONSE_ID = 8'b10101010
)( 
    input clk, //global clock
    input reset, //global reset

    input [UART_BITS-1:0] rx_data_in,
    output [UART_BITS-1:0] tx_data_out,

    input data_sel,
    input [UART_BITS-1:0] fifo_out,

    output id_requested,

    input store_challenge,
    output reg [UART_BITS-1:0] challenge
);
    always@(posedge(clk)) //this block implements a flip flop for storing the current input challenge
    begin : challenge_reg_handle
        if (reset == 0'b1) //sync.reset
            challenge <= '0;
        else if (store_challenge == 1'b1)
            challenge <= rx_data_in;
    end : challenge_reg_handle

    // ID requested
    assign id_requested = (rx_data_in == REQUEST_ID);

    // Output mux
    assign tx_data_out = data_sel ? fifo_out : RESPONSE_ID; 

endmodule
