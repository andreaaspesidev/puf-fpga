`timescale 1ns / 1ps

//! This module implements the main Finite State Machine, which handles the control signals for:
//! * The PUF module
//! * The Data Controller
//! * The UART blocks
//! * The responses' FIFO

module MainStateMachine (

        input clk, //!global clock
        input reset, //!global reset

        input tx_busy, //!busy signal from UART, asserted when UART_tx is transmitting data
        input valid_data_in, //!valid signal from UART

        input id_requested, //!signal asserted when the received id is correct
        output reg store_challenge, //!control signal to store challenge read from UART into a register
        output reg data_sel, //!sel input of multiplexer to choose whether to send ID or responses to UART tx (0=ID, 1=responses)

        output reg PUF_enable, //!signal to enable PUF FSM
        output reg PUF_reset, //! signal to reset PUF_FSM
        input PUF_done, //!done signal from puf

        output reg tx_enable,  //!signal to start UART_tx transmission
        output reg rx_enable,  //!signal to enable reception of data from UART_rx
        output reg UART_reset, //!signal to reset UART

        input empty_FIFO,
        output reg FIFO_re, //!read enable of response FIFO
        output reg FIFO_reset //!signal to reset response FIFO

    );

    enum reg [2:0] {     RESET = 3'b000,
                         WAIT_ID  = 3'b001,
                         SEND_ID  = 3'b010,
                         CHALLENGE_RCV = 3'b011,
                         EVALUATION = 3'b100,
                         SEND_RESP = 3'b101,
                         SEND_LAST_RESP= 3'b110} state, next_state; //FSM state regs


    always @ (posedge(clk)) // FSM state handle (sequential)
    begin : FSM_state_handle
        if (reset == 1'b1)
            state <= RESET;
        else
            state <= next_state;
    end : FSM_state_handle

    always @ (*)
    begin

        //output default values
        PUF_enable = 1'b0;
        tx_enable = 1'b0;
        rx_enable = 1'b0;
        FIFO_re = 1'b0;

        data_sel = 1'b1;

        PUF_reset = 1'b0;
        UART_reset = 1'b0;
        FIFO_reset = 1'b0;

        store_challenge = 1'b0;

        next_state = state;

        case(state)

            RESET:
            begin
                PUF_reset = 1'b1;
                UART_reset = 1'b1;
                FIFO_reset = 1'b1;

                next_state = WAIT_ID;
            end

            WAIT_ID:
            begin // Wait for id and respond
                rx_enable = 1'b1;   // Enable reception
                if (valid_data_in == 1'b1 && id_requested == 1'b1) // Request
                begin
                    next_state = SEND_ID;
                end
            end

            SEND_ID:
            begin
                if (tx_busy == 0)
                begin // Wait for available tx channel
                    data_sel = 1'b0;    //place ID response into UART TX buffer
                    tx_enable = 1'b1;   //enable UART to send ID
                    next_state = CHALLENGE_RCV; //ready to receive challenge
                end
            end

            CHALLENGE_RCV:
            begin    // Ready to receive challenge
                rx_enable = 1'b1;   // Enable reception

                if(valid_data_in == 1'b1)
                begin // Wait for data of challenge
                    store_challenge = 1'b1;     // Save challenge in buffer
                    next_state = EVALUATION;
                end
            end

            EVALUATION:
            begin
                PUF_enable = 1'b1;  // Start PUF Evaluation FSM

                if(PUF_done == 1'b1)
                begin  // PUF Evaluation FSM Completed. Here FIFO is full with responses
                    next_state = SEND_RESP;
                end
            end

            SEND_RESP:
            begin
                //tx_enable = 1'b1;   // Save and trasmit the FIFO word

                /* if (tx_busy == 1'b0) begin
                    if (empty_FIFO == 1'b0) begin //if the tx is idle and the response on the FIFO is not the last one
                        FIFO_re = 1'b1; //expose next data on the FIFO output
                        tx_enable = 1'b1;   // Save and trasmit the FIFO word
                    end 
                    
                    else begin//else if tx is still idle but it's last data to send
                        //PUF_reset = 1'b1; it should not be necessary, since the PUF fsm auto resets after every cycle
                        tx_enable = 1'b1; // raise tx_enable to send last response
                        next_state = SEND_LAST_RESP;
                    end
                end */

                if (empty_FIFO == 1'b0 && tx_busy == 1'b0)
                begin
                    FIFO_re = 1'b1;     //expose next data on the FIFO output
                    tx_enable = 1'b1;   // Trasmit the current FIFO word
                end
                else if (empty_FIFO == 1'b1)
                begin
                    next_state = SEND_LAST_RESP;
                end
            end

            SEND_LAST_RESP:
            begin

                if (tx_busy == 1'b0) //wait for the last data to be sent before waiting for another ID
                begin
                    next_state = WAIT_ID;
                end
            end

        endcase
    end


endmodule
