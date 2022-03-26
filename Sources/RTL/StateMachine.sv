`timescale 1ns / 1ps

/**
  * State Machine
  * ----------------------------------
  * Implements the FSM for the TERO Loops evaluation
  * 
  * Usage:
  * 1. Reset the block with the reset signal
  * 2. Supply a challenge to be evaluated via challenge input signal, then assert start signal
  * 3. After each rising edge of the signal store_response_puf, read from the shared counter the number of oscillations F_i.
  *    In the counter, there will be REPETITIONS*F_i. In order to extract the average value, perform a right shift of REPETITIONS (if power of 2)
  *    The number i of the TERO loop can be read from the select_puf signal.
  *    N.B.: Only one clock cycle is available to save the counter and select_puf, before overwritten
  * 4. Wait for the done signal to be asserted. Then eventually repeat.
  *
  * Notes:
  * - the TERO loops are numbered from 0 to NUM_LOOPS-1 (in order to have a total of NUM_LOOPS). 
  *   For this reason $clog2(NUM_LOOPS) bits are enough to store the TERO loop number
  * - REPETITIONS and EVAL_TIME can be arbitrary, but power of 2 are recommended (leave as default if not needed explicitely)
  * - EVAL_TIME +1 cycles are actually executed due to a delay of one clock cycle in the TERO loops (buffers)
  */

//! This block implements the FSM for the evaluation of the TERO loops.

module StateMachine #(
        parameter NUM_LOOPS = 4, //!number of TERO loops to generate
        parameter REPETITIONS_BITS = 13, //!bits to store number of times a TERO loop must be evaluated to compute average
        parameter REPETITIONS = (2**(REPETITIONS_BITS-1)), //!number of repetitions, must be less than 2^REPETITIONS_BITS - 1
        parameter EVAL_TIME_BITS = 16, //!number of bits to store clk cycles to evaluate a tero loop
        parameter EVAL_TIME = (2**(EVAL_TIME_BITS-1)), //!number of clock cycles of evaluation, must be less than 2^EVAL_TIME_BITS - 1
        parameter CHALLENGE_BITS = 4 //!bits for the input challenge
    )
    (
        input clk,   //! global clock
        input reset, //! reset from main FSM

        input start, //! Start the evaluation of all the tero loops, based on the value of the challenge
        input [CHALLENGE_BITS-1:0] challenge, //!challenge number used to select the way tero loops are selected​

        output reg done, //!asserted when the whole computation is finished (all the tero loops that had to be evaluated were evaluated)
        output reg reset_puf, //!signal used to reset all tero instances
        output [$clog2(NUM_LOOPS-1):0] select_puf, //!signal containing the number of the loop to evaluate
        output reg enable_puf, //!signals used to start the selected loop evaluation
        output reg store_response_puf //!when asserted, the response of the puf must be saved (in the AVG module)​,
    );


    reg en_del_cnt; //enable increment of delay counter
    reg reset_del_cnt; //reset value of delay counter
    reg [EVAL_TIME_BITS-1:0] del_cnt; //delay conter : used to wait for evaluation time

    reg inc_TERO_cnt; //enable increment of TERO counter
    reg reset_TERO_cnt; //reset value of TERO counter
    reg TERO_cnt_done; //asserted when the last tero loop number was given
    reg [$clog2(NUM_LOOPS-1):0] TERO_cnt; //TERO counter: used to select TEROS to evaluate

    reg en_rep_cnt; //enable increment of repetitions counter
    reg reset_rep_cnt; //reset value of repetition counter
    reg [REPETITIONS_BITS-1:0] rep_cnt; //repetition counter: used to count the repetition of the evaluations


    enum reg [2:0] {RESET = 3'b000,
                    IDLE = 3'b001,
                    INIT = 3'b010,
                    EVAL = 3'b011,
                    STORE_RES = 3'b100,
                    TERO_SELECT = 3'b101,
                    DONE = 3'b110} state, next_state; //state regs

    // ---------------------------
    //      Auxiliary Logic
    // ---------------------------
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


    // ---------------------------
    //   Select Tero Loop Number
    // ---------------------------
    //dummy_freq_cnt #( //Block to handle loop select counter
    //                   .NUM_LOOPS(NUM_LOOPS),
    //                   .CHALLENGE_BITS(CHALLENGE_BITS)
    //               )
    //               freq_cnt_inst (
    //                   .clk(clk),
    //                   .challenge_in(challenge),   // challenge number used to compute the tero loop sequence
    //                   .increment(inc_TERO_cnt),   // command to be used to get the next tero loop number
    //                   .reset(reset_TERO_cnt),     // reset signal, sets next_TERO at its initial value
    //                   .next_TERO(TERO_cnt),       // calculated next tero loop number
    //                   .done(TERO_cnt_done)        // asserted when last tero loop number for this challenge has been given
    //               );
    comp_freq_cnt freq_cnt_inst (
        .clk(clk),
        .challenge_in(challenge),   // challenge number used to compute the tero loop sequence
        .increment(inc_TERO_cnt),   // command to be used to get the next tero loop number
        .reset(reset_TERO_cnt),     // reset signal, sets next_TERO at its initial value
        .next_TERO(TERO_cnt),       // calculated next tero loop number
        .done(TERO_cnt_done)        // asserted when last tero loop number for this challenge has been given
    );

    assign select_puf = TERO_cnt; //TERO cnt is hard wired to output select_puf port

    // ---------------------------
    //        FSM Logic
    // ---------------------------
    always @ (posedge(clk)) // FSM state handle
    begin : FSM_state_handle
        if (reset == 1'd1)
            state <= RESET;
        else
            state <= next_state;
    end : FSM_state_handle

    always @ (*) //combinatorial FSM block
    begin : FSM_comb

        // Initial state of signals
        reset_puf = '0;
        enable_puf = '0;

        reset_del_cnt ='0;
        en_del_cnt = '0;

        reset_rep_cnt = '0;
        en_rep_cnt = '0;

        reset_TERO_cnt = '0;
        inc_TERO_cnt = '0;

        store_response_puf = 0;

        done = 0;

        next_state = state; // if not explicited, stay in current state

        case (state)

            RESET:
            begin //reset state to reset all counters
                reset_puf = '1;  //reset puf oscillations and puf counters

                reset_del_cnt  = '1;
                reset_rep_cnt  = '1;
                reset_TERO_cnt = '1;

                next_state = IDLE;
            end

            IDLE:
            begin //wait for start signal
                if (start == 1'b1)
                    next_state = INIT;
            end

            // ------------- start loop ----------------
            INIT:
            begin //reset the PUF module and go to evaluation state
                reset_puf = 1'b1;  //reset puf oscillations and puf counters
                next_state = EVAL;
            end

            // ------------- begin loop for each single tero loop ----------------
            EVAL:
            begin //evaluate current puf
                enable_puf = 1'b1; //start puf oscillation and counting from the next clock cycle
                en_del_cnt = 1'b1; //start delay counting from the next clock cycle

                if (del_cnt == EVAL_TIME)
                begin //if evaluation time passed, reset delay counter and schedule an increase of repetition counter
                    reset_del_cnt = 1'b1;   //del_cnt = 0 in the next clock cycle
                    en_rep_cnt = 1'b1;      //rep_cnt = rep_cnt + 1 in the next clock cycle
                    next_state = STORE_RES;
                end
            end

            STORE_RES:
            begin //if repetition counter reaches max go to tero_select state and reset repetition counter
                if(rep_cnt == REPETITIONS)
                begin
                    store_response_puf = 1'b1;  //signal to save the oscillations to an external block
                    reset_rep_cnt = 1'b1;       //rep_cnt = 0 in the next clock cycle
                    next_state = TERO_SELECT;
                end
                else
                begin //else reset delay counter and make another evaluation
                    next_state = EVAL;
                end
            end

            // ------------- end loop for each single tero loop ----------------

            TERO_SELECT:
            begin //if last TERO, go to DONE
                if(TERO_cnt_done == 1'b1)
                begin  //when we have N tero loops, we have TERO_cnt_done = 1 when N-1 is the next tero selected
                    reset_TERO_cnt = 1'b1;
                    next_state = DONE;
                end
                else
                begin //else reset delay counter and go to init (start evaluation of next TERO)
                    inc_TERO_cnt = 1'b1; //at the next clock rise, the next value will be computed.
                    next_state = INIT;
                end
            end
            // ------------- end loop ----------------

            DONE:
            begin
                done = 1'b1; //set 'done' output to 1

                if(start == 1'b0)
                    next_state = IDLE; //return to idle if start signal is '0'
            end


        endcase


    end : FSM_comb

endmodule

