// Code your testbench here
// or browse Examples
`timescale 1ns/1ps

module clk_mux_tb;

    //---------------------------------------------------------
    // Signals
    //---------------------------------------------------------
    logic arst_ni;
    logic sel_i;
    logic clk0_i;
    logic clk1_i;
    logic clk_o;

    logic clk0_delayed, clk1_delayed; // Delayed reference for functional check
    int error_count = 0;
    time last_edge;
    time pulse_width;

    //---------------------------------------------------------
    // DUT
    //---------------------------------------------------------
    clk_mux dut (
        .arst_ni (arst_ni),
        .sel_i   (sel_i),
        .clk0_i  (clk0_i),
        .clk1_i  (clk1_i),
        .clk_o   (clk_o)
    );

    //---------------------------------------------------------
    // Clock Generation (Asynchronous)
    //---------------------------------------------------------
    initial clk0_i = 0;
    always #5 clk0_i = ~clk0_i;   // 10ns period

    initial clk1_i = 0;
    always #5 clk1_i = ~clk1_i;   // 14ns period

    //---------------------------------------------------------
    // Create delayed references for functional check
    //---------------------------------------------------------
    always @(posedge clk0_i) clk0_delayed <= clk0_i;
    always @(posedge clk1_i) clk1_delayed <= clk1_i;

    //---------------------------------------------------------
    // Reset Task
    //---------------------------------------------------------
    task automatic apply_reset();
        begin
            arst_ni = 0;
            sel_i   = 0;
            #20;
            arst_ni = 1;
            #20;
        end
    endtask

    //---------------------------------------------------------
    // Test Sequence
    //---------------------------------------------------------
    initial begin
        $display("==== START TEST ====");
        apply_reset();

        // TC1: Steady clk0
        sel_i = 0;
        #200;

        // TC2: Switch to clk1
        sel_i = 1;
        #200;

        // TC3: Switch back
        sel_i = 0;
        #200;

        // TC4: Fast toggle stress
        repeat (10) begin
            #15 sel_i = ~sel_i;
        end

        // TC5: Random switching
        repeat (20) begin
            #($urandom_range(10,50));
            sel_i = $urandom_range(0,1);
        end

        // TC6: Reset during operation
        #100;
        arst_ni = 0;
        #15;
        arst_ni = 1;

        #300;

        //-----------------------------------------------------
        // Final Result
        //-----------------------------------------------------
        if (error_count == 0)
            $display("==== TEST PASSED ====");
        else
            $display("==== TEST FAILED. Errors = %0d ====", error_count);

        $finish;
    end

    //---------------------------------------------------------
    // 1️⃣ Mutual Exclusion Check
    //---------------------------------------------------------
  
    always @(posedge clk0_i or posedge clk1_i) begin
        if (dut.en0 && dut.en1) begin
            $display("ERROR: Both enables HIGH at %0t", $time);
            error_count++;
        end
    end
    

    //---------------------------------------------------------
    // 2️⃣ Functional Output Check with delayed reference
    //---------------------------------------------------------
    always @(posedge clk_o) begin
        if (dut.en0) begin
            if (clk_o !== clk0_delayed) begin
                $display("ERROR: clk_o mismatch with delayed clk0 at %0t", $time);
                error_count++;
            end
        end
        else if (dut.en1) begin
            if (clk_o !== clk1_delayed) begin
                $display("ERROR: clk_o mismatch with delayed clk1 at %0t", $time);
                error_count++;
            end
        end
    end

    //---------------------------------------------------------
    // 3️⃣ X / Z Detection
    //---------------------------------------------------------
    always @(clk_o) begin
        if (^clk_o === 1'bx) begin
            $display("ERROR: clk_o has X/Z at %0t", $time);
            error_count++;
        end
    end

    //---------------------------------------------------------
    // 4️⃣ Glitch Detection (Pulse Width Check)
    //---------------------------------------------------------
    always @(posedge clk_o) begin
        if (last_edge != 0) begin
            pulse_width = $time - last_edge;

            // Minimum allowed half-period ~5ns, glitch < 4ns
            if (pulse_width < 4) begin
                $display("ERROR: Glitch detected! Pulse width=%0t", pulse_width);
                error_count++;
            end
        end
        last_edge = $time;
    end

endmodule