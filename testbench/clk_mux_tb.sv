module clk_div_tb;

    // Parameters
    parameter int DIV_WIDTH = 4;
    parameter realtime T_IN = 10.0; // 10ns input clock (100MHz)

    // Signals
    logic                 clk_i;
    logic                 arst_ni;
    logic [DIV_WIDTH-1:0] div_i;
    logic                 clk_o;

    // Measurement Variables
    realtime t_start, t_fall, t_end;
    realtime actual_period, actual_high;
    realtime expected_period;
    int pass_test = 0;
    int fail_test = 0;
	bit error_inject = 0;  // Use to inject error 

    // 1. Instantiate the DUT
    clk_div #(.DIV_WIDTH(4)) dut (
      .arst_ni(arst_ni),
      .clk_i(clk_i),
      .div_i(div_i),
      .clk_o(clk_o)
    );

    // 2. Input Clock Generation
    initial clk_i = 0;
    always #(T_IN/2) clk_i = ~clk_i;

    // 3. Test Sequence (The Stimulus)
    initial begin
        // Setup Waveform Dump
        $dumpfile("waveform.vcd");
        $dumpvars(0, clk_div_tb);

        // Initialization
        arst_ni = 0;
        div_i   = 0;
        #25 arst_ni = 1; // Release Reset

        $display("\n--- Starting Self-Checking Tests ---");

        // Test Case 1: Bypass (N=1)
        run_test(4'd1);

        // Test Case 2: Even Division (N=4)
        run_test(4'd4);

        // Test Case 3: Odd Division (N=5)
        run_test(4'd5);

        // Test Case 4: Small Odd (N=3)
        run_test(4'd3);
        // Test Case 5: Apply asynchronius Reset
        test_async_reset();

        // Test Case 6: Large Even (N=10)
        run_test(4'd10);
        // Test Case 7:
        for (int i= 0; i < 16; i++) begin
          run_test(i);
        end
        // Test Summary ////
        test_summary();
    end
    
    task test_summary;
      begin
      $display("--------------------Test Summary-------------------------");
        if(fail_test == 0) begin
          $display("\n--- ALL TESTS PASSED SUCCESSFULLY ---\n");
          $display("Total pass cases: %d", pass_test);
          $finish;
        end
        else begin
          $display("\n--- TESTS Failed ---\n");
          $display("Total fail cases: %d", fail_test);
          $finish;
        end
      end
    endtask
        
        
    
    task test_async_reset();
       begin
        $display("\n[TEST] Starting Asynchronous Reset Test...");
        
        // 1. Set a divisor and let it run
        div_i = 4'd5;
        repeat(3) @(posedge clk_o);
        
        // 2. Trigger reset at an "awkward" time (not aligned with clk_i)
        #3.7; 
        $display("       Triggering Reset at time %0t", $realtime);
        arst_ni = 0;
        
        // 3. Immediate check (zero-delay or very small delay)
        #0.1; 
        if (clk_o !== 0) begin
            $error("FAIL: clk_o did not drop to 0 immediately upon reset!");
            //$finish;
            fail_test += 1;
          
        end else begin
            $display("       [PASS] clk_o dropped to 0 asynchronously.");
            pass_test += 1;
        end

        // 4. Recover from reset
        #20;
        arst_ni = 1;
        $display("       Reset released. Waiting for recovery...");
        repeat(2) @(posedge clk_o);
       end
    endtask

    // 4. Task: Run Test Case
    // Sets the divisor and calls the checker
    task run_test(input [DIV_WIDTH-1:0] n);
        begin
            $display("[TEST] Setting Divisor N = %0d", n);
            @(posedge clk_i);
            div_i = n;
            
            // Calculate Reference Model Expectations
            if (n <= 1) expected_period = T_IN;
            else        expected_period = n * T_IN;

            // Wait for logic to stabilize
            repeat(2) @(posedge clk_o);
            
            // Perform Self-Check
            check_measurement();
        end
    endtask

    // 5. Task: Measure and Compare (The Checker)
    task check_measurement();
        begin
            @(posedge clk_o);
            t_start = $realtime;
            
            @(negedge clk_o);
            t_fall = $realtime;
            
            @(posedge clk_o);
            t_end = $realtime;
            if (error_inject && div_i == 8) begin ///Error inject for div_i = 8 with error injection flag
                actual_period = t_end - t_start+1;
                actual_high   = t_fall - t_start +1;
          end else begin
                actual_period = t_end - t_start;
                actual_high   = t_fall - t_start;
          end
          
            // Self-Check Comparison with 1ps tolerance
            if (abs_diff(actual_period, expected_period) > 0.001) begin
                $error("FREQ FAIL: N=%0d | Expected Period: %0t, Got: %0t", div_i, expected_period, actual_period);
                
                //$finish;
                fail_test += 1;
            end 
            
            if (abs_diff(actual_high, expected_period/2.0) > 0.001) begin
                $error("DUTY FAIL: N=%0d | Expected High: %0t, Got: %0t", div_i, expected_period/2.0, actual_high);
              fail_test += 1;
                //$finish;
            end

            $display("       [PASS] Period: %0t | High Time: %0t", actual_period, actual_high);
           pass_test += 1;
        end
    endtask

    // Helper Function for Absolute Difference (to handle precision)
    function realtime abs_diff(realtime a, realtime b);
        return (a > b) ? (a - b) : (b - a);
    endfunction

endmodule