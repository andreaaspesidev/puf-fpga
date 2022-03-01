`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/27/2022 23:04:13 PM
// Design Name: 
// Module Name: uart
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

//! This module implements UART communication. UART_tx and UART_rx modules taken from https://github.com/ben-marshall/uart

module uart#(
    parameter DATA_BITS = 8        //!number of data bits
) (
    input clk,                     //!clock signal
    input areset,                  //!reset signal (async)
    // ------- TX signals --------
    input [DATA_BITS-1 : 0] data_out,   //! outgoing data
    input tx_enable,                    //! when asserted, enable sending the outgoing data
    output tx_busy,                     //! when sending, is asserted
    output tx_pin,                      //! TX board pin
    // ------- RX signals --------
    output [DATA_BITS-1 : 0] data_in,   //! incoming data
    output rx_valid,                    //! when asserted, incoming data is valid
    input rx_enable,                    //! when asserted, enable the reception of data
    input rx_pin                        //! RX board pin
);
    wire reset_n;

    // Local parameters
    localparam BIT_RATE = 9600;
    localparam STOP_BITS = 1;
    localparam CLOCK_HZ = 100_000_000;

    assign reset_n = ~areset;   // Negate reset

    // Serial Receive
    uart_rx #(
        .BIT_RATE(BIT_RATE),        // Input bit rate of the UART line (bits / sec).
        .CLK_HZ(CLOCK_HZ),          // Clock frequency in hertz.
        .PAYLOAD_BITS(DATA_BITS),   // Number of data bits received per UART packet.
        .STOP_BITS(STOP_BITS)       // Number of stop bits indicating the end of a packet.
    ) serial_receiver (
        .clk(clk),                      // Top level system clock input.
        .resetn(reset_n),               // Asynchronous active low reset.
        .uart_rxd(rx_pin),              // UART Recieve pin.
        .uart_rx_en(rx_enable),         // Recieve enable
        .uart_rx_break(open),           // Did we get a BREAK message? (unconnected)
        .uart_rx_valid(rx_valid),       // Valid data recieved and available.
        .uart_rx_data(data_in)          // The recieved data.
    );

    // Serial Send
    uart_tx #(
        .BIT_RATE(BIT_RATE),        // Input bit rate of the UART line (bits / sec).
        .CLK_HZ(CLOCK_HZ),          // Clock frequency in hertz.
        .PAYLOAD_BITS(DATA_BITS),   // Number of data bits received per UART packet.
        .STOP_BITS(STOP_BITS)       // Number of stop bits indicating the end of a packet.
    ) serial_sender (
        .clk(clk),                  // Top level system clock input.
        .resetn(reset_n),           // Asynchronous active low reset.
        .uart_txd(tx_pin),          // UART transmit pin.
        .uart_tx_busy(tx_busy),     // Module busy sending previous item.
        .uart_tx_en(tx_enable),     // Send the data on uart_tx_data
        .uart_tx_data(data_out)     // The data to be sent
    );

endmodule
