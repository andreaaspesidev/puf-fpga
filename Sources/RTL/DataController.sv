`timescale 1ns / 1ps

//! This module handles the exchange of data with the UART module. It implements:
//! * A MUX to select whether to send ID or responses to UART_tx
//! * A register to store challenge coming from UART_rx
//! * A comparator to determine whether the received ID is correct

module DataController#(
    parameter UART_BITS = 8, //! number of bits for UART communication
    parameter REQUEST_ID = 8'b10101010, //! ID to be received from UART for identification
    parameter RESPONSE_ID = 8'b10101010 //! ID to be sent as a response for identification
)( 
    input clk, //!global clock
    input reset, //!global reset

    input [UART_BITS-1:0] rx_data_in, //!data coming from UART_rx
    output [UART_BITS-1:0] tx_data_out, //! data going to UART_tx

    input data_sel, //!signal to select whether to send ID or PUF responses to UART
    input [UART_BITS-1:0] fifo_out, //!output of responses' FIFO

    output id_requested, //!signal asserted when ID received on UART matches

    input store_challenge, //!control signal to store challenge inside the register
    output reg [UART_BITS-1:0] challenge //!challenge to send to PUF
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
