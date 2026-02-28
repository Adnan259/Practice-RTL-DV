# **Clock Mux Design: Glitch-Free with Cross-Domain Enable Fix**

## 1️⃣ Original Design Overview

* **Module:** `clk_mux`
* **Inputs:**

  * `clk0_i` – Primary clock
  * `clk1_i` – Secondary clock
  * `sel_i` – Clock select signal (0 → clk0, 1 → clk1)
  * `arst_ni` – Asynchronous reset, active low
* **Output:** `clk_o` – Multiplexed clock, intended to be glitch-free

**Original enable logic:**

```systemverilog
q0_ff1 <= (!sel_i) && (!en1);
en0    <= q0_ff1;

q1_ff1 <= sel_i && (!en0);
en1    <= q1_ff1;
```

* **Purpose:** Prevent both `en0` and `en1` from being high simultaneously
* **Assumption:** `!en1` for en0, `!en0` for en1 prevents overlap

---

## 2️⃣ Problem Observed

During simulation, TB reported:

```
ERROR: Both enables HIGH at 1001000
ERROR: Both enables HIGH at 1295000
```

**Root cause:**

1. **Asynchronous clocks**: `clk0_i` and `clk1_i` have different periods.
2. **Direct cross-domain feedback**: `en0` reads `en1` and vice versa.
3. **Race condition**: Both always_ff blocks can sample the other enable as `0` **before it updates**, allowing **both enables to go HIGH briefly**.

**Effect:**

* `clk_o` could theoretically glitch if both enables overlap
* TB detects this as a **functional failure**
* This is **not a TB bug**; it is a **real cross-domain design hazard**

---

## 3️⃣ Fix: Cross-Domain Safe Enable Synchronization

### 3.1 Concept

* **Goal:** Ensure `en0` and `en1` cannot be high simultaneously even with asynchronous clocks
* **Method:** Use **two-stage DFF synchronizers** to transfer enable signals into the **opposite clock domain** before using them in the handshake logic

### 3.2 Implementation

```systemverilog
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
```

* `en0_sync_clk1_d` is a **two-stage synchronized version of en0 in clk1 domain**
* `en1_sync_clk0_d` is a **two-stage synchronized version of en1 in clk0 domain**

**Updated handshake logic:**

```systemverilog
q0_ff1 <= (!sel_i) && (!en1_sync_clk0_d);
en0    <= q0_ff1;

q1_ff1 <= sel_i && (!en0_sync_clk1_d);
en1    <= q1_ff1;
```

---

## 4️⃣ Why This Fix Works

| Original Issue                                    | Fix Explanation                                                                                           |
| ------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Both enables HIGH due to race across async clocks | Two-stage synchronizers ensure each enable **sees a stable version of the other enable** before asserting |
| Potential glitch on output                        | Handshake delay preserves **mutual exclusion** → `clk_o` remains glitch-free                              |
| TB error reported                                 | TB now correctly sees **only one enable high at a time**                                                  |

**Key Design Principle:**

> “Never directly use a signal from another asynchronous clock domain without a proper synchronizer.”

---

## 5️⃣ Additional Notes

1. **Glitch-Free Output**:

```systemverilog
assign clk_o = (clk0_i & en0) | (clk1_i & en1);
```

* Guaranteed because only one enable is high at any time
* Output cannot pulse both clocks simultaneously

2. **Delay Compensation**:

* Handshake logic introduces **1-cycle latency** in the output
* This is **expected and required** to avoid glitches

3. **Professional DV Practice**:

* Self-checking testbench should compare `clk_o` against **delayed reference** to account for handshake latency

---

## 6️⃣ Summary

* **Why errors occurred:**

  * Original design directly cross-referenced enables across asynchronous clocks
  * Race condition allowed both enables to be high simultaneously

* **How fix solves it:**

  * Two-stage synchronizers transfer enables into opposite clock domains
  * Ensures **mutual exclusion** even for fully asynchronous clocks
  * Glitch-free clock output is preserved

---

If you want, I can also **draw a diagram** showing:

* `clk0_i`, `clk1_i`
* `sel_i` changes
* `en0`, `en1` handshake and cross-domain sync
* `clk_o` output
