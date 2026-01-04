/*
 * ddr3_bank_fsm.sv
 * DDR3 Bank FSM
 *
 * Author: Cameron Callahan
 * Date: Jan 3, 2026
 *
 * Description:
     One instance of Bank fsm per bank (2 total)
     Tracks row state
     Enforce timing contraints (tRCD, tRP,tRAS)
     Issues Commands( ACTIVATE, READ,WRITE ,PRECHARGE)
 */

 `include "ddr3_defs.svh"

module ddr3_bank_fsm #(
    parameter int BANK_ID = 0;
)(
    input logic clk,
    input logic rst_n,

    // interface to top-level controller

    input logic         req_valid,                  //top has a request for the bank_fsm
    input logic         req_rnw,                    // 1 = read, 0 = write
    input logic         [ROW_BITS-1:0] req_row,     // row address
    input logic         [COL_BITS-1:0] req_col,     //column address
    output logic        req_ready,                  // bank fsm can accept req from top-level

    //interface to cmd_gen

    output logic        [ADDR_WIDTH-1:0] cmd_addr,  // address for the command
    output logic        cmd_valid,                  // bank_fsm has a cmd for the cmd_gen
    output ddr3_cmd_t   cmd_type,                        //command type (ACTIVATE, ACTIVATING, READ, WRITE, PRECHARGE)

    // status outputs
    output bank_state_t state,                      //current state (for monitor)
    output logic        busy,                       // Bank is busy (not idle)

);

// internal state registers
bank_state_t    state,next_state;

// Timing counters
// Count down counters load when command is issued and counts to 0 before releasing fsm to next_state

//tRCD counter (after setting RAS low to activate a row, we need to wait 6 cycles to read/write to that row, CAS = 0)
logic           [3:0] trcd_counter;
logic           trcd_met;

//tRAS Counter (Row must be active for tRAS cycles before moving on to precharge )
logic           [4:0] tRAS_counter;
logic           tras_met;

//tRP Counter (time after issuing precharge cmd before returning to idle)
logic           [3:0] tRP_counter;
logic           trp_met;
