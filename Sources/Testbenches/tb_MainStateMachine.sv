`timescale 1ns / 1ps

module tb_MainStateMachine;

    // Parameters
    localparam RESET_CYCLES = 20;
    localparam DEL_CYCLES = 10;

    // Ports
    reg clk = 0;
    reg reset = 0;
    reg tx_busy;
    reg valid_data_in = 0;
    reg id_requested = 0;
    wire store_challenge;
    wire data_sel;
    wire PUF_enable;
    wire PUF_reset;
    reg PUF_done = 0;
    wire tx_enable;
    wire rx_enable;
    wire UART_reset;
    reg empty_FIFO = 0;
    wire FIFO_re;
    wire FIFO_reset;


    MainStateMachine  MainStateMachine_dut (
                          .clk (clk ),
                          .reset (reset ),
                          .tx_busy (tx_busy ),
                          .valid_data_in (valid_data_in ),
                          .id_requested (id_requested ),
                          .store_challenge (store_challenge ),
                          .data_sel (data_sel ),
                          .PUF_enable (PUF_enable ),
                          .PUF_reset (PUF_reset ),
                          .PUF_done (PUF_done ),
                          .tx_enable (tx_enable ),
                          .rx_enable (rx_enable ),
                          .UART_reset (UART_reset ),
                          .empty_FIFO (empty_FIFO ),
                          .FIFO_re (FIFO_re ),
                          .FIFO_reset  ( FIFO_reset)
                      );

    initial
    begin
        begin
            clk <= 0;
            reset = 1'b1;

            id_requested = 1'b0;

            tx_busy = 0;
            valid_data_in = 0;

            PUF_done = 0;
            empty_FIFO = 0;

            repeat(RESET_CYCLES) @(posedge(clk)); //wait for RESET_CYCLES cycles

            reset <= 1'b0; //end reset window

            repeat(2) @(posedge(clk));
            valid_data_in <= 1'b1;
            id_requested <= 1'b1;

            @(posedge(clk));

            valid_data_in <= 1'b0;
            id_requested <= 1'b0;

            @(posedge(rx_enable));
            valid_data_in <= 1'b1;
            @(posedge(clk));
            valid_data_in <= 1'b0;

            repeat(5) @(posedge(clk));
            PUF_done <= 1'b1;
            @(posedge(clk));
            PUF_done <= 1'b0;

            repeat(4) @(negedge(FIFO_re));
            empty_FIFO <= 1'b1;

            repeat(50)@(posedge(clk));
            $finish;
        end
    end

    always
        #5  clk = ~ clk ;

    always
    begin //block used to simulate busy UART transmission pin

        @(posedge(tx_enable));
        @(posedge(clk));
        tx_busy <= 1'b1;
        repeat(10) @(posedge(clk));
        tx_busy <= 1'b0;
    end

endmodule
