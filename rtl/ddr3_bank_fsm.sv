/*
 * ddr3_bank_fsm.sv
 * DDR3 Bank FSM
 *
 * Author: Cameron Callahan
 * Date: Jan 3, 2026
 *
 * Description:
     One instance of Bank fsm per bank (4 total)
     Tracks row state
     Enforce timing contraints (tRCD, tRP,tRAS)
     Issues Commands( ACTIVATE, READ,WRITE ,PRECHARGE)
 */

import ddr3_pkg::*;

module ddr3_bank_fsm #(
    parameter bank_t BANK_ID = BANK_0
)(
    input logic clk,
    input logic rst_n,

    // interface to top-level controller

    input logic         user_req_valid,                  //top has a request for the bank_fsm
    input logic         req_rnw,                    // 1 = read, 0 = write
    input logic         [ROW_BITS-1:0] req_row,     // row address
    input logic         [COL_BITS-1:0] req_col,     //column address
    output logic        user_req_ready,                  // bank fsm can accept req from top-level

    //interface to cmd_gen
    input bank_t        next_prio_bank,             //next priority bank for cmd_generator
    output logic        [ADDR_WIDTH-1:0] cmd_addr,  // address for the command
    output logic        cmd_valid,                  // bank_fsm has a cmd for the cmd_gen
    output ddr3_cmd_t   cmd_type,                        //command type (ACTIVATE, ACTIVATING, READ, WRITE, PRECHARGE)
    input logic [3:0] bank_cmd_ready,
    // status outputs
    output bank_state_t state,                      //current state (for monitor)
    output logic        busy,                       // Bank is busy (not idle)
    //interface with refresh_fsm
    input logic refresh_imminent

);

// internal registers
bank_state_t    next_state;
//open row reg
logic [ROW_BITS-1:0] open_row;//stores currently open row
//captured req data currently be processed
logic [ROW_BITS-1:0] my_req_row;
logic [COL_BITS-1:0] my_req_col;
logic my_rnw; //
logic pending_req; // are we currently working on a req (flag)

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
// additional state transition logic
logic skip_cycle;
logic advance;
logic force_idle;

//continuous assigns for flags
assign trcd_met = (trcd_counter == 0);
assign tras_met = (tRAS_counter >= tRAS_CYCLES);
assign trp_met = (tRP_counter == 0);

always_ff @(posedge clk or negedge rst_n) begin //async reset
    if(!rst_n)begin
        //init state register
        state <= IDLE;
        //init counter registers
        trcd_counter <= 4'h0;
        tRAS_counter <= 5'd0;
        tRP_counter <= 4'h0;
        //init request tracking registers
        open_row <= '0;
        my_req_row <= '0;
        my_req_col <= '0;
        pending_req <= 1'b0;
        my_rnw <= 1'b0;
    end else begin
        state <= next_state;
    //=========================================================================
    // Request Capture & Tracking
    // Latches should save values input by the dut the same clk cycle the dut
    // sends them
    //=========================================================================
        if (state == IDLE && user_req_valid) begin
            my_req_row <= req_row;
            my_req_col <= req_col;
            my_rnw <= req_rnw;
            pending_req <= 1'b1;
        end
        //latch when accepting input in active (row_hit)
        else if (state == ACTIVE && !pending_req && user_req_valid)begin
            pending_req <= 1'b1;
            my_req_row <= req_row;
            my_req_col <= req_col;
            my_rnw <= req_rnw;
        end
        //clear pending flag after req is finsished
        if(state == ACTIVE && cmd_valid && (cmd_type == CMD_READ || cmd_type == CMD_WRITE) && advance)begin
            pending_req <= 1'b0;
        end
        //update open row
        if (cmd_valid && cmd_type == CMD_ACTIVATE && advance) begin
            open_row <= my_req_row;
        end
        if (cmd_valid && cmd_type == CMD_PRECHARGE && advance) begin
            open_row <= '0;
        end
    //=========================================================================
    // Timing counters Register logic
    //
    //=========================================================================
        //tRCD logic
        //start count down as soon as state == ACTIVE
        if (state == ACTIVATING && trcd_counter > 0)begin
            trcd_counter <= trcd_counter - 1;
        end
        //load tRCD_CYCLES(6) into counter register as soon as CMD_ACTIVATE is issued
        else if (next_state == ACTIVATING && cmd_valid && cmd_type == CMD_ACTIVATE)begin
            trcd_counter <= skip_cycle ? (tRCD_CYCLES - 1) : tRCD_CYCLES;
        end
        //tRAS logic
        // start count up as soon as state is ACTIVATING and continue count up into ACTIVE state
        if (state == ACTIVATING || state == ACTIVE) begin
            tRAS_counter <= tRAS_counter + 1;
        end else if (next_state == ACTIVATING && skip_cycle) begin
            tRAS_counter <= 5'h1;
        end
        //load tRAS_CYCLES(15) into counter register
        else begin
            tRAS_counter <= '0;
        end
        //start count down as soon as state is PRECHARGING and tRP_counter has been loaded
        if (state == PRECHARGING && tRP_counter > 0) begin
            tRP_counter <= tRP_counter - 1;
        end
        //load tRP_CYCLES(6) into counter register as soon as CMD_PRECHARGE has been issued
        else if (cmd_valid && cmd_type == CMD_PRECHARGE && advance)begin
            tRP_counter <= skip_cycle ? (tRP_CYCLES-1) : tRP_CYCLES;
        end

    end
end

    //=========================================================================
    // FSM combinational logic
    //  triggered whenever any internal logic changes
    //
    //=========================================================================
always_comb begin : fsm
    //DEFAULTS
    next_state = state;
    cmd_valid = 1'b0;
    cmd_type = CMD_NOP;
    cmd_addr = '0;
    user_req_ready = 1'b0;
    busy = 1'b0;
    skip_cycle = 1'b0;
    advance = 1'b0;

        case(state)
        IDLE: begin
            if (refresh_imminent) begin
                user_req_ready = 1'b0;
                next_state = IDLE;
                busy = 1'b1;
            end else if (user_req_valid || pending_req) begin
                    cmd_valid = 1'b1;               //we have a cmd for cmd_gen
                    cmd_type = CMD_ACTIVATE;        //cmd is to activate
                    busy = 1'b1;
                    user_req_ready = 1'b0;
                    cmd_addr = req_row;
                if(next_prio_bank == BANK_ID) begin //transition state this cycle
                    next_state = ACTIVATING;        //state for fsm should be activating at next clk
                    advance = 1'b1;
                end else if (bank_cmd_ready[BANK_ID]) begin
                    advance = 1'b1;
                    next_state = ACTIVATING;
                    skip_cycle = 1'b1;
                end else begin
                    next_state = IDLE;
                end
            end else begin
                    user_req_ready = 1'b1;
                    busy = 1'b0;
            end
        end
        ACTIVATING:begin
            next_state = trcd_met ? ACTIVE : ACTIVATING;
            busy = 1'b1;
        end
        ACTIVE:begin
            busy = 1'b1;

            if (pending_req) begin
                user_req_ready = 1'b0;
                    if (my_req_row == open_row)begin //row hit
                        cmd_valid = 1'b1;
                        cmd_type = my_rnw ? CMD_READ : CMD_WRITE;
                        cmd_addr = {3'b000,my_req_col};
                        if(next_prio_bank == BANK_ID || bank_cmd_ready[BANK_ID]) begin
                            next_state = ACTIVE;
                            advance = 1'b1;
                        end else begin //if
                            advance = 1'b0;
                            next_state = ACTIVE;
                        end

                    end else begin //row miss, must precharge (close row)
                        if (tras_met) begin
                            cmd_valid = 1'b1;
                            cmd_type = CMD_PRECHARGE;
                            cmd_addr = '0;
                            if(next_prio_bank == BANK_ID ) begin
                                next_state = PRECHARGING;
                                advance = 1'b1;
                            end else if (bank_cmd_ready[BANK_ID])begin
                                next_state = PRECHARGING;
                                advance = 1'b1;
                                skip_cycle = 1'b1;
                            end else begin
                                next_state = ACTIVE;
                                advance = 1'b0;
                            end

                        end
                    end

            end else begin
                if(refresh_warnig) begin
                    user_req_ready = 1'b0;
                end else begin
                user_req_ready = 1'b1;
                end
            end
        end
        PRECHARGING:begin
            next_state = trp_met ? IDLE : PRECHARGING;
            busy = 1'b1;
        end
        default: begin
            user_req_ready = 1'b1;
            cmd_valid = 1'b0;
            cmd_type = CMD_NOP;
            next_state = IDLE;
            cmd_addr = 13'b0;
            busy = 1'b0;
        end
        endcase
end
endmodule

