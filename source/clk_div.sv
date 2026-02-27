module clk_div #(
    parameter int DIV_WIDTH = 4
) (
    input  logic                 arst_ni, // Active-low asynchronous reset
    input  logic                 clk_i,   // Input source clock
    input  logic [DIV_WIDTH-1:0] div_i,   // Divisor value (0/1 = Bypass)
    output logic                 clk_o    // Output divided clock
);

    logic [DIV_WIDTH-1:0] count;
    logic q_p, q_n;

    // 1. Counter Logic
    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni)
            count <= 0;
        else if (count >= div_i - 1 || div_i <= 1)
            count <= 0;
        else
            count <= count + 1;
    end

    // 2. Posedge Signal (Generates base pulse)
    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni)
            q_p <= 0;
        else
            // For N=5, q_p is high for 2 cycles
            q_p <= (count < (div_i >> 1));
    end

    // 3. Negedge Signal (Shifts signal by 0.5 cycles)
  always_ff @(posedge ~clk_i or negedge arst_ni) begin
        if (!arst_ni)
            q_n <= 0;
        else
            q_n <= q_p;
    end

    // 4. Final Output Multiplexer
    // Logic: 
    // - If div_i is 0 or 1: Pass through clk_i
    // - If div_i is odd (LSB=1): OR(q_p, q_n) for 50% duty cycle
    // - If div_i is even: Use q_p directly
    always_comb begin
      clk_o = (div_i <= 1) ? clk_i : 
                   (div_i[0]    ? (q_p | q_n) : q_p);
    end

endmodule