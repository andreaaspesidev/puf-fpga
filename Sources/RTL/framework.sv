`timescale 1ns / 1ps

//! TARGET: BASYS3 board --> The module is fed with the 100 Mhz system clock from the Basys3 board. No clock wizard is instantiated.


//! This is the top module of the project. It instantiates:
//! * The main state machine
//! * The PUF module, including the PUF FSM and the TERO loops
//! * The UART modules to communicate with PC
//! * The data controller module, handling the challenge and the ID transmission
//! * The FIFO module to store responses. (Only some of the counter bits are exposed to the FIFO, in order to perform the last shift of the averege)


module framework#(
    //PUF parameters
    parameter NUM_LOOPS = 1280,
    parameter RESPONSE_BITS = 32,
    parameter REPETITIONS_BITS = 13,
    parameter TOT_CNT_BITS = RESPONSE_BITS + REPETITIONS_BITS -1,
    parameter FIRST_CNT_BITS = 2,
    parameter EVAL_TIME_BITS = 6,
    parameter CHALLENGE_BITS = 8,

    //UART parameters
    parameter DATA_BITS = 8,

    //data controller parameters
    parameter REQUEST_ID = 8'b10101010,
    parameter RESPONSE_ID = 8'b10101011
)
(
    input clk,
    input reset,

    input rx_pin,
    output tx_pin

);

    localparam REPETITIONS_EXPONENT = REPETITIONS_BITS-1;

    //puf signals

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
      .EVAL_TIME_BITS(EVAL_TIME_BITS ),
      .CHALLENGE_BITS (CHALLENGE_BITS )
    ) PUF_inst (
      .clk (clk ),
      .reset (PUF_reset),
      .start_puf (PUF_start),
      .challenge (challenge ),
      .loop_response (loop_response ),
      .loop_number (loop_number ), // at the moment not used
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

    assign FIFO_in = loop_response[$high(loop_response):REPETITIONS_EXPONENT]; // In order to average the TERO responses, a last shift is needed. So we take only the first TOT_CNT_BITS - REPETITION_EXPONENT bits


endmodule
