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


module Core #(
parameter NUM_LOOPS = 8, //!number of TERO loops to generate
parameter TOT_CNT_BITS = 32, //!Total number of bits of the response (counter bits considering first and second stage merged)
parameter FIRST_CNT_BITS = 2 //!Number of bits of the first stage counters​
)
    
(
    input clk,
    input reset, //!asserted by FSM

    input enable, //!when 1 the selected loop oscillate, when 0 the oscillation stops​
    input [$clog2(NUM_LOOPS-1):0] loop_select, //!specify the number of the tero loop to activate and count​

    output [TOT_CNT_BITS-1:0] response //!response of the selected loop
    );

    wire enable_reg; //! output of enable  buffer

    reg [NUM_LOOPS-1:0] mask ;
    //reg [NUM_LOOPS-1:0] mask = {NUM_LOOPS-1 {1'b0}}; //should be the same of previous one

    wire [NUM_LOOPS-1:0] TEROS_out;  // signal to store the outputs of each TERO loop
    wire [NUM_LOOPS/4-1:0] ored_out; // signal to store the output of the OR LUTS
    wire [FIRST_CNT_BITS * NUM_LOOPS /4 -1 : 0] first_cnt_res;  // signal to store the outputs of the first stage counters
    wire [TOT_CNT_BITS-FIRST_CNT_BITS-1:0] second_cnt_res;      // signal to store the outputs of the second stage counter
    wire [$left(loop_select):$right(loop_select)] loop_sel_shift; // signal to select the desired group of 4 TEROS
    wire [FIRST_CNT_BITS-1:0] muxed_res; // FIRST_CNT_BITS bits to bring to the second stage counter



    FDRE #(
        .INIT(1'b0) // Initial value of register (1'b0 or 1'b1)
    ) enable_buffer (
        .Q(enable_reg), // 1-bit Data output
        .C(clk), // 1-bit Clock input
        .CE(1'b1), // 1-bit Clock enable input
        .R(reset), // 1-bit Synchronous reset input
        .D(enable) // 1-bit Data input
    );

    always @(*) //! this always block decodes the select_core signal, giving a one-hot encoded signal to enable one loop at a time

    begin : decode_select
        mask = '0;
        mask[loop_select] = enable_reg; //wires the selected loop to the enable signal
    end : decode_select

    genvar currInst;
    generate // generate TERO loops
       for (currInst=0; currInst < NUM_LOOPS/2; currInst=currInst+1)
       begin: gen_TEROS
          

        TERO_instance TEROS (
                    .clk(clk),
                    .enable_1(mask[2 * currInst]),
                    .enable_2(mask[1 + 2 * currInst]),
                    .dout_1(TEROS_out[2 * currInst]),
                    .dout_2(TEROS_out[1 + 2 * currInst])
        );

       end : gen_TEROS
    endgenerate

    genvar currOR;
    generate // generate OR LUTS
       for (currOR=0; currOR < NUM_LOOPS/4; currOR=currOR+1)
       begin: gen_OR
          

        LUT4 #(
            .INIT(16'hFFFE) // Specify LUT Contents
        ) LUT4_inst (
            .O(ored_out[currOR]), // LUT general output
            .I0(TEROS_out[currOR * 4 + 3]), // LUT input
            .I1(TEROS_out[currOR * 4 + 1]), // LUT input
            .I2(TEROS_out[currOR * 4 + 2]), // LUT input
            .I3(TEROS_out[currOR * 4]) // LUT input
);

       end : gen_OR
    endgenerate

    genvar currCnt;
    generate //Generate first stage counters
       for (currCnt=0; currCnt < NUM_LOOPS/4; currCnt=currCnt+1)
       begin: gen_cnt_fst_stage
          

        counter #(
            .NUM_BITS(FIRST_CNT_BITS)
        ) cnt (
            .arst(reset),
            .signal_in(ored_out[currCnt]),
            .enable(1'b1),
            .count(first_cnt_res[FIRST_CNT_BITS * (currCnt+1)-1  : FIRST_CNT_BITS*currCnt])
        );

       end : gen_cnt_fst_stage
    endgenerate

    //this signal contains the number of the selected banch of 4-TERO loops
    assign loop_sel_shift = {2'b00,loop_select[$high(loop_select):2]};

    // this signal contains the FIRST_CNT_BITS bits to bring to the input of the second stage
    assign muxed_res = first_cnt_res[loop_sel_shift*FIRST_CNT_BITS +: FIRST_CNT_BITS]; 

    counter #( // second stage counter
            .NUM_BITS(TOT_CNT_BITS-FIRST_CNT_BITS)
    ) cnt_second (
            .arst(reset),
            .signal_in(muxed_res[FIRST_CNT_BITS-1]),
            .enable(1'b1),
            .count(second_cnt_res)
    );


    assign response = {second_cnt_res,muxed_res}; //output result of the selected TERO (first + second stage counters' out)



endmodule

