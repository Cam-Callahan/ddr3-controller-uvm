Architecture · MD
Copy

# DDR3 Memory Controller - Architecture Specification

## 1. System Overview

The DDR3 memory controller acts as an interface between a simple user request/response protocol and the DDR3 SDRAM command protocol. It manages bank states, enforces timing constraints, and handles refresh operations.

### 1.1 Design Goals

- **Simplicity:** Focus on core DDR3 concepts without unnecessary complexity
- **Demonstrable Skills:** Showcase RTL design and verification capabilities
- **Timeline:** Complete in 2-4 weeks for interview preparation
- **Verification-Friendly:** Easy to verify with UVM methodology

### 1.2 Simplifications from Real DDR3

| Feature | Real DDR3 | This Design | Rationale |
|---------|-----------|-------------|-----------|
| Banks | 8 | 4 | Reduces FSM complexity |
| Data Width | 4-bit (x4) | 8-bit | Easier testbench development |
| Burst Length | BL8/BC4 | Fixed BL8 | Simplifies data handling |
| Speed Grades | Multiple | DDR3-800 only | Most forgiving timing |
| ODT | Dynamic | Not implemented | Focus on core functionality |
| DLL | Present | Not implemented | Simplified clocking |

---

## 2. Interface Specifications

### 2.1 User Interface (Request/Response)

The controller presents a simple memory interface to the user (CPU/system).

#### User Request Interface
```systemverilog
// User → Controller
input  logic        user_req_valid      // Request valid
input  logic        user_req_rnw        // 1=Read, 0=Write
input  logic [1:0]  user_req_bank       // Bank select (0-3)
input  logic [12:0] user_req_row        // Row address
input  logic [9:0]  user_req_col        // Column address
input  logic [7:0]  user_req_wdata      // Write data
output logic        user_req_ready      // Controller ready

// Controller → User (Read Response)
output logic        user_resp_valid     // Read data valid
output logic [7:0]  user_resp_rdata     // Read data
```

#### Protocol
1. User asserts `user_req_valid` with request parameters
2. Controller accepts when `user_req_ready` is HIGH
3. For reads: Controller returns data via `user_resp_valid`/`user_resp_rdata`
4. Controller manages all DDR3 timing internally

### 2.2 DDR3 DRAM Interface

Standard DDR3 command/address/data interface.

```systemverilog
// Clock
output logic        ddr3_ck
output logic        ddr3_ck_n

// Command Interface
output logic        ddr3_ras_n
output logic        ddr3_cas_n
output logic        ddr3_we_n
output logic        ddr3_cs_n          // Chip select (tied LOW for single rank)
output logic        ddr3_cke           // Clock enable (tied HIGH)

// Address
output logic [1:0]  ddr3_ba            // Bank address
output logic [12:0] ddr3_addr          // Multiplexed row/column address

// Data
inout  logic [7:0]  ddr3_dq            // Bidirectional data
output logic        ddr3_dqs           // Data strobe (simplified - not differential)
output logic        ddr3_dm            // Data mask (tied LOW - no masking)

// Misc
output logic        ddr3_odt           // On-die termination (not used)
output logic        ddr3_reset_n       // Reset (tied HIGH after init)
```

#### DDR3 Command Encoding

| Command | RAS# | CAS# | WE# | BA | ADDR | Notes |
|---------|------|------|-----|----|----|-------|
| NOP | 1 | 1 | 1 | X | X | No operation |
| ACTIVATE | 0 | 1 | 1 | Bank | Row | Open row in bank |
| READ | 1 | 0 | 1 | Bank | Col | Read from active row |
| WRITE | 1 | 0 | 0 | Bank | Col | Write to active row |
| PRECHARGE | 0 | 1 | 0 | Bank | A10=0/1 | Close row (A10: 0=single, 1=all) |
| REFRESH | 0 | 0 | 1 | X | X | Refresh all banks |

---

## 3. RTL Module Hierarchy

### 3.1 Top-Level Controller (`ddr3_controller.sv`)

**Responsibilities:**
- User request arbitration
- Bank availability checking
- Refresh scheduling
- Top-level command coordination

**Inputs/Outputs:** As specified in Section 2

**Key State:**
```systemverilog
logic refresh_pending;
logic [3:0] bank_busy;      // One bit per bank
```

**Operation:**
1. Check if refresh is due → prioritize refresh
2. If user request valid:
   - Check if target bank is available
   - Route request to appropriate bank FSM
3. Monitor bank FSMs for completion
4. Return read data to user

### 3.2 Bank FSM (`ddr3_bank_fsm.sv`)

**One instance per bank** - manages row state and timing.

**State Machine:**
```
IDLE ─ACTIVATE→ ACTIVATING ─(tRCD)→ ACTIVE ─READ/WRITE→ ACTIVE
                                       │
                                       └─PRECHARGE→ PRECHARGING ─(tRP)→ IDLE
```

**States:**
- **IDLE:** No row open, ready for ACTIVATE
- **ACTIVATING:** ACTIVATE command issued, waiting tRCD
- **ACTIVE:** Row open, ready for READ/WRITE
- **PRECHARGING:** PRECHARGE command issued, waiting tRP

**Inputs:**
```systemverilog
input  logic        req_valid          // Request from top-level
input  logic        req_rnw            // Read/Write
input  logic [12:0] req_row
input  logic [9:0]  req_col
```

**Outputs:**
```systemverilog
output logic        busy               // Bank is busy
output logic        cmd_valid          // Command to issue
output logic [2:0]  cmd_type           // ACTIVATE/READ/WRITE/PRECHARGE
output logic [12:0] cmd_addr           // Row or column address
```

**Timing Counters:**
```systemverilog
logic [4:0] tRCD_counter;   // Counts down from tRCD after ACTIVATE
logic [4:0] tRP_counter;    // Counts down from tRP after PRECHARGE
logic [4:0] tRAS_counter;   // Tracks minimum row active time
```

**Key Logic:**
- Track currently open row
- Enforce tRCD before READ/WRITE
- Enforce tRAS before PRECHARGE
- Auto-precharge if different row requested

### 3.3 Command Generator (`ddr3_cmd_gen.sv`)

**Responsibilities:**
- Mux commands from 4 bank FSMs
- Translate internal command types to RAS#/CAS#/WE#
- Drive DDR3 command pins

**Inputs:**
```systemverilog
input logic [3:0] bank_cmd_valid;
input logic [2:0] bank_cmd_type[4];
input logic [1:0] bank_id[4];
input logic [12:0] bank_addr[4];
input logic       refresh_req;
```

**Outputs:**
```systemverilog
output logic       ddr3_ras_n;
output logic       ddr3_cas_n;
output logic       ddr3_we_n;
output logic [1:0] ddr3_ba;
output logic [12:0] ddr3_addr;
```

**Arbitration:**
1. Refresh has highest priority
2. Round-robin among banks
3. Issue NOP if no commands pending

### 3.4 Refresh Controller (`ddr3_refresh.sv`)

**Responsibilities:**
- Track refresh timing (tREFI = 7.8μs)
- Request refresh when due
- Ensure all banks idle before refresh

**Parameters:**
```systemverilog
parameter tREFI_CYCLES = 3120;  // 7.8μs / 2.5ns = 3120 cycles
parameter tRFC_CYCLES  = 44;    // 110ns / 2.5ns = 44 cycles (1Gb density)
```

**State Machine:**
```
IDLE ─(counter == tREFI)→ REFRESH_REQ ─(all banks idle)→ REFRESHING ─(tRFC)→ IDLE
```

**Outputs:**
```systemverilog
output logic refresh_req;       // Request refresh
output logic refreshing;        // Currently refreshing
```

---

## 4. Timing Parameters (DDR3-800)

Based on Micron datasheet Table 49 (DDR3-800 speed bin).

| Parameter | Symbol | Time (ns) | Cycles @ 2.5ns | Description |
|-----------|--------|-----------|----------------|-------------|
| Clock Period | tCK | 2.5 | 1 | 400 MHz |
| RAS to CAS Delay | tRCD | 15 | 6 | ACTIVATE to READ/WRITE |
| Precharge Time | tRP | 15 | 6 | PRECHARGE to ACTIVATE |
| Row Active Time | tRAS | 37.5 | 15 | Min time row must be open |
| Row Cycle Time | tRC | 52.5 | 21 | ACTIVATE to ACTIVATE same bank |
| Refresh Interval | tREFI | 7,800,000 | 3,120,000 | Max time between refreshes |
| Refresh Cycle Time | tRFC | 110 | 44 | Refresh command duration |
| CAS Latency | CL | 15 | 6 | READ command to data valid |
| Write Recovery | tWR | 15 | 6 | WRITE to PRECHARGE |

### 4.1 Timing Enforcement Strategy

**In Bank FSM:**
- tRCD: Counter after ACTIVATE before allowing READ/WRITE
- tRAS: Counter after ACTIVATE before allowing PRECHARGE
- tRP: Counter after PRECHARGE before returning to IDLE
- tRC: Derived from tRAS + tRP

**In Refresh Controller:**
- tREFI: Free-running counter, request refresh when expires
- tRFC: Counter during refresh, hold banks idle

---

## 5. Data Path Design

### 5.1 Write Data Path

```
User → Write FIFO → DDR3 DQ (when WRITE command issued)
```

**Simplification:** No data strobe generation in first iteration
- DQS toggling aligned with write data
- DM tied LOW (no masking)

### 5.2 Read Data Path

```
DDR3 DQ → Read FIFO → User Response
```

**CAS Latency Handling:**
- Pipeline read data by CL cycles (6 cycles for DDR3-800)
- Tag with bank ID for matching to original request

---

## 6. Initialization Sequence

DDR3 requires specific power-up and initialization sequence.

**Simplified Init (after stable power/clock):**
1. Wait 200μs (80,000 cycles @ 2.5ns)
2. Issue PRECHARGE ALL command
3. Issue 2 REFRESH commands
4. Wait for tRFC after each
5. Controller ready for user requests

**Note:** Mode Register Set (MRS) commands omitted in simplified design

---

## 7. Reset and Error Handling

### 7.1 Reset
- Asynchronous reset (active LOW)
- All FSMs return to IDLE
- Clear all pending requests
- Re-run initialization sequence

### 7.2 Error Conditions (Future)
- **Row hit/miss tracking:** Performance optimization
- **Request timeout:** Detect stuck requests
- **Timing violations:** Assertions catch protocol errors

---

## 8. Verification Considerations

### 8.1 Observability Points

**Internal Signals to Monitor:**
- Bank FSM states
- Timing counters
- Command queue status
- Refresh pending/active

### 8.2 Coverage Points

**Functional Coverage:**
- All bank states reached
- All command types issued
- Bank state transitions
- Simultaneous operations on different banks
- Refresh during idle vs. active banks

**Timing Coverage:**
- tRCD boundary cases (exactly 6 cycles)
- tRAS boundary cases
- Back-to-back commands same bank
- Interleaved commands different banks

### 8.3 Assertions

**Protocol Checks:**
- No READ/WRITE before tRCD expires
- No PRECHARGE before tRAS expires
- REFRESH only when all banks idle

**Timing Checks:**
- Command spacing meets minimums
- No commands during tRFC

---

## 9. Performance Characteristics

### 9.1 Latency

**Read Latency (best case):**
```
Request → Bank IDLE → ACTIVATE (1 cycle) → tRCD (6 cycles) → READ (1 cycle) → CL (6 cycles) → Data
Total: 14 cycles minimum (35ns)
```

**Read Latency (row already open):**
```
Request → Bank ACTIVE (row match) → READ (1 cycle) → CL (6 cycles) → Data
Total: 7 cycles (17.5ns)
```

### 9.2 Throughput

**Theoretical Max (bursts to open row):**
- BL8 = 8 data beats per READ
- Back-to-back READs = 8 beats every 4 cycles (tCCD)
- ~200 MB/s (400 MT/s × 8 bits / 8)

---

## 10. Future Enhancements

**Out of Scope for Initial Implementation:**
1. Write data masking (DM)
2. Differential data strobe (DQS#)
3. On-die termination (ODT)
4. Multiple speed grades
5. Burst chop (BC4)
6. Page management policy (open/closed)
7. Request reordering for performance

---

## 11. Design Parameters

### 11.1 Configurable Parameters (`ddr3_defs.svh`)

```systemverilog
`ifndef DDR3_DEFS_SVH
`define DDR3_DEFS_SVH

// Memory geometry
parameter NUM_BANKS   = 4;
parameter ROW_BITS    = 13;
parameter COL_BITS    = 10;
parameter BANK_BITS   = 2;
parameter DATA_WIDTH  = 8;

// Timing (cycles @ 2.5ns)
parameter tCK         = 2.5;   // ns
parameter tRCD_CYCLES = 6;
parameter tRP_CYCLES  = 6;
parameter tRAS_CYCLES = 15;
parameter tRC_CYCLES  = 21;
parameter tRFC_CYCLES = 44;
parameter tREFI_CYCLES = 3120;
parameter CL_CYCLES   = 6;
parameter tWR_CYCLES  = 6;

// Command encoding
typedef enum logic [2:0] {
  CMD_NOP       = 3'b111,
  CMD_ACTIVATE  = 3'b011,
  CMD_READ      = 3'b101,
  CMD_WRITE     = 3'b100,
  CMD_PRECHARGE = 3'b010,
  CMD_REFRESH   = 3'b001
} cmd_t;

`endif
```

---

## Appendix A: Command Timing Diagrams

### A.1 ACTIVATE → READ → PRECHARGE
```
Cycle:  0    1    2    3    4    5    6    7    8    9   10   11   12 ...
Cmd:    ACT  NOP  NOP  NOP  NOP  NOP  RD   NOP  NOP  NOP  NOP  NOP  NOP  PRE
        |<------- tRCD ------->|     |<------- CL -------->|
        |                           Data Out                |
        |<--------------- tRAS (min) ------------------------>|
```

### A.2 Refresh Sequence
```
Cycle:  0    1    2    3   ...  44   45
Cmd:    REF  NOP  NOP  NOP  ... NOP  (ready)
        |<-------- tRFC -------->|
```

---

## Appendix B: References

1. **Micron MT41J256M4 Datasheet (1Gb x4 DDR3)**
   - Part Number: MT41J256M4-125
   - Key Sections: Page 10 (state diagram), Page 63 (timing), Page 91 (commands)

2. **JEDEC JESD79-3F** - DDR3 SDRAM Standard
   - Official DDR3 specification

3. **"Memory Systems: Cache, DRAM, Disk"** by Bruce Jacob
   - Chapter on DRAM architecture and timing

---

**Last Updated:** [01/02/2026]
**Author:** Cameron - Texas State University EE Graduate

