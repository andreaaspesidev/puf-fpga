`timescale 1ns / 1ps

module tb_StateMachine;

  // Parameters
  localparam  NUM_LOOPS = 4;
  localparam  REPETITIONS_BITS = 16;
  localparam  REPETITIONS = 2;
  localparam  EVAL_TIME_BITS = 16;
  localparam  EVAL_TIME = 8;
  localparam  CHALLENGE_BITS = 4;

  localparam RESET_CYCLES = 10;

  // Ports
  reg clk = 0;
  reg reset = 0;
  reg start = 0;
  reg [CHALLENGE_BITS-1:0] challenge = 0;
  //reg next_enable = 0;
  wire done;
  wire reset_puf;
  wire [$clog2(NUM_LOOPS-1):0] select_puf;
  wire enable_puf;
  wire store_response_puf;

  StateMachine #(
    .NUM_LOOPS(NUM_LOOPS ),
    .REPETITIONS_BITS(REPETITIONS_BITS ),
    .REPETITIONS(REPETITIONS ),
    .EVAL_TIME_BITS(EVAL_TIME_BITS ),
    .EVAL_TIME(EVAL_TIME ),
    .CHALLENGE_BITS (
        CHALLENGE_BITS )
  )
  StateMachine_dut (
    .clk (clk ),
    .reset (reset ),
    .start (start ),
    .challenge (challenge ),
    //.next_enable (next_enable ),
    .done (done ),
    .reset_puf (reset_puf ),
    .select_puf (select_puf ),
    .enable_puf (enable_puf ),
    .store_response_puf  ( store_response_puf)
  );

  initial begin
    begin
        //$stop;
        clk <= 0; //initialize clock to 0
        reset = 1; // initialize reset to 1
        start = 0; //initialize start to 0

        repeat(RESET_CYCLES) @(posedge(clk)); //wait for RESET_CYCLES before putting the reset signal to 0

        reset <= 0; //deassert reset

        repeat(10) @(posedge(clk)); //wait for 10 clock cycles
        start <= 1'b1; //set start to 1
        
        @(posedge(clk)); //wait for 1 clock cycle
        start <= 1'b0; // set start to 0 again

        @(posedge(done)); //wait for the done signal to be 1
        repeat(5) @(posedge(clk)); //wait another clock cycle

      $finish; //end the simulation
    end
  end

  always
    #5  clk =~ clk ;

endmodule
