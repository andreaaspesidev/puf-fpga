`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/22/2022 03:28:23 PM
// Design Name: 
// Module Name: TERO_instance
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

//! This module implements 2 TERO loops that will be placed inside a single Slice.

module TERO_instance(
        input clk,      //! System clock

        input enable_1, //! If asseted, starts the oscillation of the first TERO loop
        input enable_2, //! If asseted, starts the oscillation of the second TERO loop

        output dout_1,  //! Oscillating output of the first TERO loop
        output dout_2   //! Oscillating output of the second TERO loop
    );

    wire loop1_enable1; // 1 of 2 enable signals of for the first loop
    wire loop1_enable2; // 2 of 2 enable signals of for the first loop
    wire loop1_inv1;    // Output of the interter 1 for the first loop
    wire loop1_inv2;    // Output of the interter 2 for the first loop
    wire loop1_and1;    // Output of the and 1 for the first loop
    wire loop1_and2;    // Output of the and 2 for the first loop


    wire loop2_enable1; // 1 of 2 enable signals of for the second loop
    wire loop2_enable2; // 2 of 2 enable signals of for the second loop
    wire loop2_inv1;    // Output of the interter 1 for the second loop
    wire loop2_inv2;    // Output of the interter 2 for the second loop
    wire loop2_and1;    // Output of the and 1 for the second loop
    wire loop2_and2;    // Output of the and 2 for the second loop


    // ---------------------------
    //      First TERO Loop
    // ---------------------------

    // Enable buffers of loop1
    FDRE #(
        .INIT(1'b0)         // start at 0
    ) loop1_enable1_buff (
        .Q(loop1_enable1), // output
        .C(clk),
        .CE(1'b1),          // always enabled
        .R(1'b0),           // never reset
        .D(enable_1)        // input
    );
    FDRE #(
        .INIT(1'b0)         // start at 0
    ) loop1_enable2_buff (
        .Q(loop1_enable2), // output
        .C(clk),
        .CE(1'b1),          // always enabled
        .R(1'b0),           // never reset
        .D(enable_1)        // input
    );

    // Blocks of loop1 (AND + NOT)
    LUT6_2 #(
        .INIT(64'hcccc000000ff00ff)   // block configuration
    ) loop1_block1 (    
        .O6(loop1_and1),              // the upper LUT5 is I4 AND I1, assigned to O6                
        .O5(loop1_inv1),              // the lower LUT5 is NOT I3, assigned to O5            
        .I0(1'b0),
        .I1(loop1_enable1),
        .I2(1'b0),
        .I3(loop1_and1),              // self loop on the and (as now must enter in the inverter in the lower LUT5)
        .I4(loop1_inv2),              // inverter of the second block of this loop
        .I5(1'b1)                     // select upper LUT5 as O6 (in order to use both LUT5)
    );
    LUT6_2 #(
        .INIT(64'hcccc000000ff00ff)   // block configuration
    ) loop1_block2 (    
        .O6(loop1_and2),              // the upper LUT5 is I4 AND I1, assigned to O6                
        .O5(loop1_inv2),              // the lower LUT5 is NOT I3, assigned to O5            
        .I0(1'b0),
        .I1(loop1_enable2),
        .I2(1'b0),
        .I3(loop1_and2),              // self loop on the and (as now must enter in the inverter in the lower LUT5)
        .I4(loop1_inv1),              // inverter of the first block of this loop
        .I5(1'b1)                     // select upper LUT5 as O6 (in order to use both LUT5)
    );

    // Link output
    assign dout_1 = loop1_and1;

    // ---------------------------
    //      Second TERO Loop
    // ---------------------------

    // Enable buffers of loop2
    FDRE #(
        .INIT(1'b0)         // start at 0
    ) loop2_enable1_buff (
        .Q(loop2_enable1), // output
        .C(clk),
        .CE(1'b1),          // always enabled
        .R(1'b0),           // never reset
        .D(enable_2)        // input
    );
    FDRE #(
        .INIT(1'b0)         // start at 0
    ) loop2_enable2_buff (
        .Q(loop2_enable2), // output
        .C(clk),
        .CE(1'b1),          // always enabled
        .R(1'b0),           // never reset
        .D(enable_2)        // input
    );

    // Blocks of loop2 (AND + NOT)
    LUT6_2 #(
        .INIT(64'hf000f0000000ffff)   // block configuration
    ) loop2_block1 (    
        .O6(loop2_and1),              // the upper LUT5 is I4 AND I1, assigned to O6                
        .O5(loop2_inv1),              // the lower LUT5 is NOT I3, assigned to O5            
        .I0(1'b0),
        .I1(1'b0),
        .I2(loop2_enable1),
        .I3(loop2_inv2),              // inverter of the second block of this loop
        .I4(loop2_and1),              // self loop on the and (as now must enter in the inverter in the lower LUT5)
        .I5(1'b1)                     // select upper LUT5 as O6 (in order to use both LUT5)
    );
    LUT6_2 #(
        .INIT(64'hf000f0000000ffff)   // block configuration
    ) loop2_block2 (    
        .O6(loop2_and2),              // the upper LUT5 is I4 AND I1, assigned to O6                
        .O5(loop2_inv2),              // the lower LUT5 is NOT I3, assigned to O5            
        .I0(1'b0),
        .I1(1'b0),
        .I2(loop2_enable2),
        .I3(loop2_inv1),              // inverter of the first block of this loop 
        .I4(loop2_and2),              // self loop on the and (as now must enter in the inverter in the lower LUT5)
        .I5(1'b1)                     // select upper LUT5 as O6 (in order to use both LUT5)
    );

    // Link output
    assign dout_2 = loop2_and1;

endmodule
