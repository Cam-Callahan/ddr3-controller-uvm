// ddr3_defs.svh
// DDR3 Memory Controller - Parameter Definitions
//
// This file contains all configurable parameters and type definitions
// for the DDR3 memory controller project.

`ifndef DDR3_DEFS_SVH
`define DDR3_DEFS_SVH

package ddr3_pkg;

//=============================================================================
// Memory Geometry Parameters
//=============================================================================

parameter int NUM_BANKS     = 4;      // Number of banks (simplified from 8)
parameter int ROW_BITS      = 13;     // Row address width (8K rows)
parameter int COL_BITS      = 10;     // Column address width (1K columns)
parameter int BANK_BITS     = 2;      // Bank select bits (log2(NUM_BANKS))
parameter int DATA_WIDTH    = 8;      // Data bus width (bits)
parameter int ADDR_WIDTH    = 13;     // Address bus width (max of row/col)

//=============================================================================
// Timing Parameters (DDR3-800, tCK = 2.5ns)
//=============================================================================

// Clock Period
parameter real tCK_NS       = 2.5;    // Clock period (ns)
parameter int  FREQ_MHZ     = 400;    // Clock frequency (MHz)

// Command Timing (in clock cycles)
parameter int tRCD_CYCLES   = 6;      // RAS to CAS delay (15ns)
parameter int tRP_CYCLES    = 6;      // Precharge time (15ns)
parameter int tRAS_CYCLES   = 15;     // Row active time (37.5ns)
parameter int tRC_CYCLES    = 21;     // Row cycle time (52.5ns)
parameter int tRFC_CYCLES   = 44;     // Refresh cycle time (110ns)
parameter int tWR_CYCLES    = 6;      // Write recovery time (15ns)

// CAS Latency
parameter int CL_CYCLES     = 6;      // CAS latency for reads (15ns)
parameter int CWL_CYCLES    = 5;      // CAS write latency (12.5ns)

// Refresh Timing
parameter int tREFI_CYCLES  = 3120;   // Refresh interval (7.8μs)
parameter int REFRESH_COUNT = 8192;   // Number of rows to refresh

// Initialization Timing
parameter int INIT_WAIT_CYCLES = 80000; // Power-up wait (200μs @ 2.5ns)

// Burst Parameters
parameter int BURST_LENGTH  = 8;      // Fixed burst length (BL8)

//=============================================================================
// Command Type Encoding
//=============================================================================

typedef enum logic [2:0] {
    CMD_NOP       = 3'b111,  // No operation / IDLE
    CMD_ACTIVATE  = 3'b011,  // Activate (open row)
    CMD_READ      = 3'b101,  // Read
    CMD_WRITE     = 3'b100,  // Write
    CMD_PRECHARGE = 3'b010,  // Precharge (close row)
    CMD_REFRESH   = 3'b001   // Refresh
} ddr3_cmd_t;

//=============================================================================
// Bank State Machine States
//=============================================================================

typedef enum logic [2:0] {
    IDLE        = 3'b000,  // No row open, ready for ACTIVATE
    ACTIVATING  = 3'b001,  // ACTIVATE issued, waiting tRCD
    ACTIVE      = 3'b010,  // Row open, can READ/WRITE
    READING     = 3'b011,  // READ in progress
    WRITING     = 3'b100,  // WRITE in progress
    PRECHARGING = 3'b101   // PRECHARGE issued, waiting tRP
} bank_state_t;
//=============================================================================
// Refresh State Machine States
//=============================================================================
typedef enum logic [1:0] {
    COUNTING = 2'b00,
    WAITING = 2'b01,
    REFRESHING = 2'b10
} refresh_state_t;
//=============================================================================
// Current Bank Types
//=============================================================================

typedef enum logic [1:0] {
    BANK_0  = 2'b00,
    BANK_1 = 2'b01,
    BANK_2 = 2'b10,
    BANK_3  = 2'b11
} bank_t;
//=============================================================================
// Internal Request Types
//=============================================================================

typedef enum logic [1:0] {
    REQ_READ  = 2'b00,
    REQ_WRITE = 2'b01,
    REQ_IDLE  = 2'b11
} request_type_t;

//=============================================================================
// Utility Functions
//=============================================================================

// Convert nanoseconds to clock cycles (ceiling)
function automatic int ns_to_cycles(real ns);
    return int'($ceil(ns / tCK_NS));
endfunction

// Check if timing parameter is met
function automatic bit timing_met(int counter, int requirement);
    return (counter >= requirement);
endfunction

//=============================================================================
// Debug/Simulation Parameters
//=============================================================================

`ifdef SIMULATION
    parameter bit ENABLE_ASSERTIONS   = 1;
    parameter bit ENABLE_COVERAGE     = 1;
    parameter int SIM_TIMEOUT_CYCLES  = 100000;
`else
    parameter bit ENABLE_ASSERTIONS   = 0;
    parameter bit ENABLE_COVERAGE     = 0;
`endif

//=============================================================================
// Derived Parameters (Do Not Modify)
//=============================================================================

parameter int TOTAL_ROWS     = 2**ROW_BITS;
parameter int TOTAL_COLS     = 2**COL_BITS;
parameter int TOTAL_CAPACITY = NUM_BANKS * TOTAL_ROWS * TOTAL_COLS * DATA_WIDTH; // bits

endpackage : ddr3_pkg

`endif // DDR3_DEFS_SVH

