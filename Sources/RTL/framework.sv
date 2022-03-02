`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/28/2022 10:44:06 PM
// Design Name: 
// Module Name: framework
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


module framework#(
    //PUF parameters
    parameter NUM_LOOPS = 1280,
    parameter RESPONSE_BITS = 32,
    parameter REPETITIONS_BITS = 13, //rep will be 2^12
    parameter TOT_CNT_BITS = RESPONSE_BITS + REPETITIONS_BITS -1,
    parameter FIRST_CNT_BITS = 2,
    //parameter REPETITIONS = (2**(REPETITIONS_BITS-1)),
    parameter EVAL_TIME_BITS = 16,
    //parameter EVAL_TIME = (2**(EVAL_TIME_BITS-1)),
    parameter CHALLENGE_BITS = 8,

    //UART parameters
    parameter DATA_BITS = 8,

    //data controller parameters
    parameter REQUEST_ID = 8'b10101010,
    parameter RESPONSE_ID = 8'b10101010
)
(
    input clk_pin,
    input reset,

    input rx_pin,
    output tx_pin

    //output done_LED

);

    localparam REPETITIONS_EXPONENT = REPETITIONS_BITS-1; //12

    //puf signals

    wire clk;

    wire PUF_start;
    wire PUF_reset;
    wire [CHALLENGE_BITS-1:0] challenge;
    wire [TOT_CNT_BITS-1:0] loop_response;
    wire [$clog2(NUM_LOOPS-1):0] loop_number;

    wire store_response_puf;
    wire PUF_done;

    //UART signals
    wire UART_reset;                  // reset signal (async)
    // ------- TX signals --------
    wire [DATA_BITS-1 : 0] UART_out;   // outgoing data
    wire tx_enable;                    // when asserted, enable sending the outgoing data
    wire tx_busy;                     // when sending, is asserted
    // ------- RX signals --------
    wire [DATA_BITS-1 : 0] UART_in;   // incoming data
    wire rx_valid;                    // when asserted, incoming data is valid
    wire rx_enable;                    // when asserted, enable the reception of data

    //DataController signals

    wire data_sel;
    wire [DATA_BITS-1:0] fifo_out;
    wire id_requested;
    wire store_challenge;

    //FIFO signals
    wire FIFO_empty;
    wire FIFO_reset;
    wire [RESPONSE_BITS-1:0] FIFO_in;
    wire FIFO_re;


    clk_wiz_0 clk_wizard_inst (
        .clk_out1(clk),
        .reset(reset),
        .clk_in1(clk_pin)
    );

    MainStateMachine MainStateMachine_inst (
      .clk (clk ),
      .reset (reset ),
      .tx_busy (tx_busy),
      .valid_data_in (rx_valid),
      .id_requested (id_requested),
      .store_challenge (store_challenge),
      .data_sel (data_sel),
      .PUF_enable (PUF_start),
      .PUF_reset (PUF_reset ),
      .PUF_done (PUF_done ),
      .tx_enable (tx_enable),
      .rx_enable (rx_enable),
      .UART_reset (UART_reset),
      .empty_FIFO (FIFO_empty),
      .FIFO_re (FIFO_re),
      .FIFO_reset  (FIFO_reset)
    );
  
    uart #(
      .DATA_BITS (DATA_BITS)
    ) uart_inst (
      .clk (clk),
      .areset (UART_reset),
      .data_out (UART_out),
      .tx_enable (tx_enable),
      .tx_busy (tx_busy),
      .tx_pin (tx_pin),
      .data_in (UART_in),
      .rx_valid (rx_valid),
      .rx_enable (rx_enable),
      .rx_pin  (rx_pin)
    );


    PUF #(
      .NUM_LOOPS(NUM_LOOPS),
      .TOT_CNT_BITS(TOT_CNT_BITS ),
      .FIRST_CNT_BITS(FIRST_CNT_BITS ),
      .REPETITIONS_BITS(REPETITIONS_BITS ),
      //.REPETITIONS(REPETITIONS ),
      .EVAL_TIME_BITS(EVAL_TIME_BITS ),
      //.EVAL_TIME(EVAL_TIME ),
      .CHALLENGE_BITS (CHALLENGE_BITS )
    ) PUF_inst (
      .clk (clk ),
      .reset (PUF_reset),
      .start_puf (PUF_start),
      .challenge (challenge ),
      .loop_response (loop_response ),
      .loop_number (loop_number ),
      .store_response_puf (store_response_puf ),
      .done  (PUF_done)
    );


    DataController #(
      .UART_BITS(DATA_BITS),
      .REQUEST_ID(REQUEST_ID ),
      .RESPONSE_ID (RESPONSE_ID )
    ) DataController_inst (
      .clk (clk),
      .reset (reset),
      .rx_data_in (UART_in),
      .tx_data_out (UART_out),
      .data_sel (data_sel),
      .fifo_out (fifo_out),
      .id_requested (id_requested),
      .store_challenge (store_challenge),
      .challenge  (challenge)
    );
  
    fifo_generator_0 res_fifo_inst (
      .clk (clk),
      .srst (FIFO_reset),
      .din (FIFO_in),
      .wr_en (store_response_puf),
      .rd_en (FIFO_re),
      .dout (fifo_out),
      .full (open),
      .empty (FIFO_empty)
    );

    assign FIFO_in = loop_response[$high(loop_response):REPETITIONS_EXPONENT];


endmodule
