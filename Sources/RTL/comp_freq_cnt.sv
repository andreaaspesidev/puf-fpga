`timescale 1ns / 1ps

//! This module computes, given the challenge, the next TERO to evaluate. At the moment it ignores the Challenge and outputs the very next TERO loop number. 
//! It's possible to implement a variant of this block exposing the next TERO number basing on the challenge given in input. It would be necessary to set the local parameter "last_TERO", in order to
//! correctly assert the "done" signal at the end. 

module comp_freq_cnt (
    input clk,
    input [7:0] challenge_in, //! input challenge

    input increment, //! when this signal is asserted, the next TERO number is exposed (syncronous with clk)
    input reset, //! when this signal is asserted, the first TERO is exposed again
    
    output reg [11:0] next_TERO, //! number of next TERO to evaluate
    output reg done //! Asserted when the last tero is supplied (combinatorial)
);
    // Generating the next tero loop to evaluate is rather complex.
    // The first step is generating the indexes i,j from the supplied challenge number.
    // This requires some combinatorial logic, to achieve the table right below:

    // i,   j    (compact)
    // 0000 0001     1110 1111   1101 1110   1100 1101   1011 1100   1010 1011   1001 1010   1000 1001
    // 0000 0010     0001 0010   1101 1111   1100 1110   1011 1101   1010 1100   1001 1011   1000 1010
    // 0000 0011     0001 0011   0010 0011   1100 1111   1011 1110   1010 1101   1001 1100   1000 1011
    // 0000 0100     0001 0100   0010 0100   0011 0100   1011 1111   1010 1110   1001 1101   1000 1100
    // 0000 0101     0001 0101   0010 0101   0011 0101   0100 0101   1010 1111   1001 1110   1000 1101
    // 0000 0110     0001 0110   0010 0110   0011 0110   0100 0110   0101 0110   1001 1111   1000 1110
    // 0000 0111     0001 0111   0010 0111   0011 0111   0100 0111   0101 0111   0110 0111   1000 1111
    // 0000 1000     0001 1000   0010 1000   0011 1000   0100 1000   0101 1000   0110 1000   0111 1000   
    // 0000 1001     0001 1001   0010 1001   0011 1001   0100 1001   0101 1001   0110 1001   0111 1001      
    // 0000 1010     0001 1010   0010 1010   0011 1010   0100 1010   0101 1010   0110 1010   0111 1010      
    // 0000 1011     0001 1011   0010 1011   0011 1011   0100 1011   0101 1011   0110 1011   0111 1011         
    // 0000 1100     0001 1100   0010 1100   0011 1100   0100 1100   0101 1100   0110 1100   0111 1100            
    // 0000 1101     0001 1101   0010 1101   0011 1101   0100 1101   0101 1101   0110 1101   0111 1101               
    // 0000 1110     0001 1110   0010 1110   0011 1110   0100 1110   0101 1110   0110 1110   0111 1110                  
    // 0000 1111     0001 1111   0010 1111   0011 1111   0100 1111   0101 1111   0110 1111   0111 1111                    

    // Challenge Number
    // 0000 0000     0000 1111   0001 1110   0010 1101   0011 1100   0100 1011   0101 1010   0110 1001
    // 0000 0001     0001 0000   0001 1111   0010 1110   0011 1101   0100 1100   0101 1011   0110 1010
    // 0000 0010     0001 0001   0010 0000   0010 1111   0011 1110   0100 1101   0101 1100   0110 1011
    // 0000 0011     0001 0010   0010 0001   0011 0000   0011 1111   0100 1110   0101 1101   0110 1100
    // 0000 0100     0001 0011   0010 0010   0011 0001   0100 0000   0100 1111   0101 1110   0110 1101
    // 0000 0101     0001 0100   0010 0011   0011 0010   0100 0001   0101 0000   0101 1111   0110 1110
    // 0000 0110     0001 0101   0010 0100   0011 0011   0100 0010   0101 0001   0110 0000   0110 1111
    // 0000 0111     0001 0110   0010 0101   0011 0100   0100 0011   0101 0010   0110 0001   0111 0000   
    // 0000 1000     0001 0111   0010 0110   0011 0101   0100 0100   0101 0011   0110 0010   0111 0001      
    // 0000 1001     0001 1000   0010 0111   0011 0110   0100 0101   0101 0100   0110 0011   0111 0010      
    // 0000 1010     0001 1001   0010 1000   0011 0111   0100 0110   0101 0101   0110 0100   0111 0011         
    // 0000 1011     0001 1010   0010 1001   0011 1000   0100 0111   0101 0110   0110 0101   0111 0100            
    // 0000 1100     0001 1011   0010 1010   0011 1001   0100 1000   0101 0111   0110 0110   0111 0101               
    // 0000 1101     0001 1100   0010 1011   0011 1010   0100 1001   0101 1000   0110 0111   0111 0110                  
    // 0000 1110     0001 1101   0010 1100   0011 1011   0100 1010   0101 1001   0110 1000   0111 0111 

    reg [3:0] i;
    reg [3:0] j;
    wire [3:0] a,b,c,c_n;
    wire [4:0] d;
    wire challenge_valid;
    
    // Check the challenge is valid
    assign challenge_valid = challenge_in >= 8'd0 && challenge_in <= 8'd119;
    
    // Generate index i,j
    assign a = challenge_in[7:4];
    assign b = challenge_in[3:0];
    assign c = a + 1;
    assign c_n = ~c;
    assign d = b + c;

    assign i = d[4] ? c_n[3:0] : a;
    assign j = d[4] ? b : d[3:0];

    // Now computing next frequency starting from i and j
    //
    // The frequencies are grouped as:
    // F#0  F#8 ... F#120       F#128   F#136   ... F#248       ...     F#1152  F#1160  ... F#1272
    // F#1  F#9 ... F#121       F#129   F#137   ... F#249       ...     F#1153  F#1161  ... F#1273
    // ...
    // F#7 F#15 ... F#127       F#135   F#143   ... F#255       ...     F#1159  F#1167  ... F#1279
    //
    // i,j freq. of each batch are considered to calculate the response.
    // So if i=0, j=15 (challenge 14), the needed frequencies are: F#0, F#120, F#128, F#248, ..., F#1, F#121, ...
    // We can identify two groups (start, end)
    // - "start" values are: F#0, F#128, F#1152, F#1, ...
    //   they can be found at indexes: i*8 + 128*k + l = (i<<3) + (k<<7) + l, with 0<=k<=9, 0<=l<=7
    // - "end" values are: F#120, F#248, F#1272, F#121, ...
    //   they can be found at indexes: j*8 + 128*k + l = (j<<3) + (k<<7) + l, with 0<=k<=9, 0<=l<=7

    // As for the two different equations, first we generate the "start" frequencies, then the "end" ones
    // using the flag i_active

    reg [3:0] k,l;
    reg i_active;
    
    // Control the next tero output
    always @(posedge(clk))
    begin
        if (reset == 1'b1) begin // Load the default
            next_TERO <= i << 3; // The first
        end
        else if (increment == 1'b1 && done == 1'b0 && challenge_valid == 1'b1) begin
            if (i_active == 1'b1) begin
                next_TERO <= (i << 3) + (k << 7) + l;
            end
            else begin
                next_TERO <= (j << 3) + (k << 7) + l;
            end
        end
    end

    always @(posedge(clk)) 
    begin
        if (reset == 1'b1) begin
            k = 4'd1;   // As the first value was already in output
            l = '0;
            i_active = 1;
            done = 0;
        end
        else if (increment == 1'b1 && done == 1'b0 && challenge_valid == 1'b1) begin
            k = k+1;
        end
        if (k == 4'd10) begin
            k = '0;
            l = l + 1;
            if (l == 4'd8) begin
                if (i_active == 1'b0) begin
                    done = 1;
                end
                else begin
                    i_active = 0;
                    k = '0;
                    l = '0;
                end
            end
        end
    end
endmodule
