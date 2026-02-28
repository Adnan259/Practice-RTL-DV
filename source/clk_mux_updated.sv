//==============================================================================
// Author:      Adnan Sami Anirban
// Date:        2026-03-01
// Module:      clk_mux
// Description: Robust, Glitch-Free Clock Multiplexer
//              Handles asynchronous input clocks safely using
//              2-stage DFF synchronizers for enable signals.
//==============================================================================

module clk_mux (
    input  logic arst_ni, // Active-low asynchronous reset
    input  logic sel_i,   // Select: 0->clk0, 1->clk1
    input  logic clk0_i,  // Clock 0
    input  logic clk1_i,  // Clock 1
    output logic clk_o    // Glitch-free mux output
);

    // Internal enable signals
    logic en0;                // clk0 enable
    logic en1;                // clk1 enable

    // Synchronizers for cross-domain enable signals
    logic en0_sync_clk1, en0_sync_clk1_d;
    logic en1_sync_clk0, en1_sync_clk0_d;

    //---------------------------------------------------------
    // clk0 enable generation
    //---------------------------------------------------------
    logic q0_ff1;
    always_ff @(posedge clk0_i or negedge arst_ni) begin
        if (!arst_ni) begin
            q0_ff1 <= 1'b0;
            en0    <= 1'b0;
        end else begin
            q0_ff1 <= (!sel_i) && (!en1_sync_clk0_d); // Check synced en1
            en0    <= q0_ff1;
        end
    end

    //---------------------------------------------------------
    // clk1 enable generation
    //---------------------------------------------------------
    logic q1_ff1;
    always_ff @(posedge clk1_i or negedge arst_ni) begin
        if (!arst_ni) begin
            q1_ff1 <= 1'b0;
            en1    <= 1'b0;
        end else begin
            q1_ff1 <= sel_i && (!en0_sync_clk1_d); // Check synced en0
            en1    <= q1_ff1;
        end
    end

    //---------------------------------------------------------
    // Cross-domain synchronizers
    //---------------------------------------------------------
    // Sync en0 into clk1 domain
    always_ff @(posedge clk1_i or negedge arst_ni) begin
        if (!arst_ni) begin
            en0_sync_clk1   <= 1'b0;
            en0_sync_clk1_d <= 1'b0;
        end else begin
            en0_sync_clk1   <= en0;
            en0_sync_clk1_d <= en0_sync_clk1;
        end
    end

    // Sync en1 into clk0 domain
    always_ff @(posedge clk0_i or negedge arst_ni) begin
        if (!arst_ni) begin
            en1_sync_clk0   <= 1'b0;
            en1_sync_clk0_d <= 1'b0;
        end else begin
            en1_sync_clk0   <= en1;
            en1_sync_clk0_d <= en1_sync_clk0;
        end
    end

    //---------------------------------------------------------
    // Glitch-free output
    //---------------------------------------------------------
    assign clk_o = (clk0_i & en0) | (clk1_i & en1);

endmodule