`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/22/2022 03:28:23 PM
// Design Name: 
// Module Name: counter
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

// Ripple counter with async reset
module counter#(
    parameter NUM_BITS = 32
) (
    input arst,                     // Asynchronous reset of the counter

    input signal_in,                // Oscillating signal to be counted (counts the rising endge)
    input enable,                   // When asserted, counting is enabled

    output [NUM_BITS-1 : 0] count   // Output of the counter (binary encoding)
);

    wire [NUM_BITS-1 : 0] q;
    wire [NUM_BITS-1 : 0] d;
    wire [NUM_BITS : 0] t;

    assign t[0] = signal_in;    // the first block is linked to the signal

    genvar i;
    generate // Generate ripple counter with FFD
       for (i=NUM_BITS-1; i >= 0; i=i-1)
       begin: gen_ripple_block
            assign d[i] = ~q[i];  // self-loop for this block
            assign t[i+1] = d[i]; // link the block with the next
            // Generate the block
            FDCE #(
                .INIT(1'b0)
            ) FDCE_inst (
                .Q(q[i]),
                .C(t[i]),
                .CE(enable),
                .CLR(arst),
                .D(d[i])
            );
       end : gen_ripple_block
    endgenerate

    // Link output
    assign count = q;

endmodule
