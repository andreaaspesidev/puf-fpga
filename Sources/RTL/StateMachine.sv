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


module StateMachine #(
    parameter NUM_LOOPS = 4, //number of TERO loops to generate
    parameter REPETITIONS_BITS = 16, //bits to store number of times a TERO loop must be evaluated to compute average
    parameter REPETITIONS = 2**(REPETITIONS_BITS-1),
    parameter EVAL_TIME_BITS = 16, //number of bits to store clk cycles to evaluate a tero loop
    parameter EVAL_TIME = 2**(EVAL_TIME_BITS-1),
    parameter CHALLENGE_BITS = 4 //bits for the input challenge
)
    
(
    input clk,
    input reset,

    input start, // Start the evaluation of all the tero loops, based on the value of the challenge
    input [CHALLENGE_BITS-1:0] challenge, // Challenge number used to select the way tero loops are selected​

    input next_enable, //Waited to be 1, before passing to evaluate the next tero loop (from AVG module)​
    
    output reg done, // Asserted when the whole computation is finished (all the tero loops that had to be evaluated were evaluated)
    output reg reset_puf, // Signal used to reset all tero instances
    output [$clog2(NUM_LOOPS-1):0] select_puf, // Signal containing the number of the loop to evaluate
    output reg enable_puf, // Signals used to start the selected loop evaluation
    output reg store_response_puf // When asserted, the response of the puf must be saved (in the AVG module)​,
    );


    reg en_del_cnt; //enable increment of delay counter
    reg reset_del_cnt; //reset value of delay counter
    reg [EVAL_TIME_BITS-1:0] del_cnt; //delay conter : used to wait for evaluation time

    reg inc_TERO_cnt; //enable increment of TERO counter 
    reg reset_TERO_cnt; //reset value of TERO counter
    reg [$clog2(NUM_LOOPS-1):0] TERO_cnt; //TERO counter: used to select TEROS to evaluate

    reg en_rep_cnt; //enable increment of repetitions counter
    reg reset_rep_cnt; //reset value of repetition counter
    reg [REPETITIONS_BITS-1:0] rep_cnt; //repetition counter: used to count the repetition of the evaluations

    localparam last_TERO = NUM_LOOPS-1; // number of the last TERO to evaluate



    enum reg [2:0] {RESET = 3'b000,
                     IDLE = 3'b001,
                     INIT = 3'b010,
                     EVAL = 3'b011,
                     STORE_RES = 3'b100,
                     TERO_SELECT = 3'b101,
                     DONE = 3'b110} state, next_state; //state regs



    always @ (posedge(clk)) // Sequential block to handle delay counter
    begin : del_cnt_handle
        if (reset_del_cnt == 1'b1)
            del_cnt <= '0;
        else if (en_del_cnt == 1'b1)
            del_cnt <= del_cnt + 1;
    end : del_cnt_handle

    always @ (posedge(clk)) // Sequential block to handle repetition counter
    begin : rep_cnt_handle
        if (reset_rep_cnt == 1'b1)
            rep_cnt <= '0;
        else if (en_rep_cnt == 1'b1)
            rep_cnt <= rep_cnt + 1;
    end : rep_cnt_handle


    // TERO counter handling
    
    dummy_freq_cnt #( //Block to handle loop select counter
        .N_TERO_BITS($clog2(NUM_LOOPS-1)+1),
        .CHALLENGE_BITS (CHALLENGE_BITS)
    )
    freq_cnt_inst (
        .clk (clk),
        .challenge_in (challenge),
        .increment(inc_TERO_cnt),
        .reset(reset_TERO_cnt),
        .next_TERO  (TERO_cnt)
    );

    assign select_puf = TERO_cnt; //TERO cnt is hard wired to output select_puf port


    always @ (posedge(clk)) // FSM state handle 
    begin : FSM_state_handle

        if (reset == 3'd1)
            state <= RESET;
        else
            state <= next_state;

    end : FSM_state_handle 

    always @ (*) //combinatorial FSM block
    begin : FSM_comb
        
        reset_puf = '0;
        enable_puf = '0;

        reset_del_cnt ='0;
        en_del_cnt = '0;

        reset_rep_cnt = '0;
        en_rep_cnt = '0;

        reset_TERO_cnt = '0;
        inc_TERO_cnt = '0;


        done = '0;

        next_state = state;

        case (state)

            RESET: begin //reset state to reset all counters
                
                reset_puf = '1;
                enable_puf = '0;

                reset_del_cnt  = '1;
                reset_rep_cnt  = '1;
                reset_TERO_cnt = '1;

                next_state = IDLE;
            end

            IDLE: begin //wait for start signal

                if (start == 1'b1)
                    next_state = INIT;

            end

            INIT: begin //reset the PUF module and go to evaluation state
                reset_puf = 1'b1;
                next_state = EVAL;
            end

            EVAL: begin //evaluate current puf
                enable_puf = 1'b1;
                en_del_cnt = 1'b1;

                if (del_cnt == EVAL_TIME) begin //if evaluation time passed, reset delay counter and schedule an increase of repetition counter

                    reset_del_cnt = 1'b1;
                    en_rep_cnt = 1'b1;
                    next_state = STORE_RES;
                end

            end

            STORE_RES: begin //if repetition counter reaches max go to tero_select state and reset repetition counter
                if(rep_cnt == REPETITIONS)
                begin
                    store_response_puf = 1'b1;
                    reset_rep_cnt = 1'b1;
                    next_state = TERO_SELECT;
                end
                else begin //else reset delay counter and make another evaluation
                    reset_del_cnt = 1'b1;
                    next_state = EVAL;
                end
            end

            TERO_SELECT: begin //if last TERO, go to DONE,
                if(TERO_cnt == last_TERO) begin
                    reset_TERO_cnt = 1'b1;
                    next_state = DONE;
                end
                else begin //else reset delay counter and go to init (start evaluation of next TERO)
                    reset_del_cnt = 1'b1;
                    inc_TERO_cnt = 1'b1;
                    next_state = INIT;
                end
            end

            DONE: begin
                done = 1; //set 'done' output to 1
                if(start == 1'b0)
                next_state = IDLE; //return to idle if start signal is '0'
            end

 
        endcase


    end : FSM_comb

endmodule

