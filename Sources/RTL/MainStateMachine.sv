`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/27/2022 08:10:42 PM
// Design Name: 
// Module Name: MainStateMachine
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


module MainStateMachine#(
    //n. of bits received from UART
    parameter DATA_IN_BITS = 8, //at the moment it must be kept to 8 to ensure correct functioning.
    parameter ID = 8'b10101010 //ID to check
)

(
    input clk, //global clock
    input reset, //global reset

    input puf_done, //done signal from puf

    input tx_busy, //busy signal from UART, asserted when UART_tx is transmitting data

    input valid_data_in, //valid signal from UART
    input [DATA_IN_BITS-1:0]rx_data_in, //at the moment this block reads data from UART for ID verification

    input empty_FIFO,


    output reg PUF_enable, //signal to enable PUF FSM
    output reg PUF_reset, // signal to reset PUF_FSM

    output reg tx_enable,  //signal to start UART_tx transmission
    output reg rx_enable,  //signal to enable reception of data from UART_rx
    output reg UART_reset, //signal to reset UART
    output reg UART_mux_sel, // 0-> send ID, 1 -> send FIFO output (PUF responses)

    output reg FIFO_re, //read enable of response FIFO
    output reg FIFO_reset //signal to reset response FIFO

);

enum reg [2:0] {     RESET = 3'b000,
                     WAIT_ID  = 3'b001,
                     SEND_ID  = 3'b010,
                     CHALLENGE_RCV = 3'b011,
                     EVALUATION = 3'b100,
                     SEND_RESP = 3'b101} state, next_state; //state regs

reg [DATA_IN_BITS-1:0] challenge_reg;
reg store_challenge;

always @ (posedge(clk)) // FSM state handle 
begin : FSM_state_handle
    if (reset == 1'b1)
        state <= RESET;
    else
        state <= next_state;
end : FSM_state_handle 

always@(posedge(clk)) //this block implements a flip flop for storing the current input challenge
begin : challenge_reg_handle

    if (reset == 0'b1) //sync.reset
        challenge_reg <= 1'b0;
    else if (store_challenge == 1'b1)
        challenge_reg <= rx_data_in;

end : challenge_reg_handle

always @ (*)
begin
    
    //output default values
    PUF_enable = 1'b0;
    tx_enable = 1'b0;
    rx_enable = 1'b0;
    UART_mux_sel = 1'b1;
    FIFO_re = 1'b0;

    PUF_reset = 1'b0;
    UART_reset = 1'b0;
    FIFO_reset = 1'b0;

    store_challenge = 1'b0;

    next_state = state;

    case(state)

        RESET: begin

            PUF_reset = 1'b1;
            UART_reset = 1'b1;
            FIFO_reset = 1'b1;

            next_state = WAIT_ID;

        end

        WAIT_ID: begin
            rx_enable = 1'b1;
            if (valid_data_in == 1'b1 && rx_data_in == ID)
            begin
                next_state = SEND_ID;
            end
        end

        SEND_ID: begin
            if (tx_busy == 0) begin

                UART_mux_sel = 1'b0; //select ID on UART_mux
                tx_enable = 1'b1; //enable UART_tx to send ID
                next_state = CHALLENGE_RCV; //ready to receive challenge
            end
        end

        CHALLENGE_RCV: begin

            rx_enable = 1'b1;

            if(valid_data_in == 1'b1) begin
                
                store_challenge = 1'b1;
                next_state = EVALUATION;

            end

        end

        EVALUATION: begin
            
            PUF_enable = 1'b1;

            if(puf_done == 1'b1) begin

                FIFO_re = 1'b1; //expose first word from FIFO (in next clk cycle)
                next_state = SEND_RESP;

            end

        end

        SEND_RESP: begin
            
            tx_enable = 1'b1;

            if (tx_busy == 1'b0 && empty_FIFO == 1'b0) begin //if the tx is idle and the response on the FIFO is not the last one

                FIFO_re = 1'b1; //expose next data on the FIFO output


            end

            else if (tx_busy == 1'b0 && empty_FIFO == 1'b1) begin //else if tx is still idle but it's last data to send
                
                //PUF_reset = 1'b1; it should not be necessary, since the PUF fsm auto resets after every cycle
                next_state = WAIT_ID;

            end

        end

    endcase






end


endmodule