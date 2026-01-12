//tb_bank_fsm.sv
//Tests only the bank_fsm module

`timescale 1ns/1ps
import ddr3_pkg::*;

module test_bank_fsm;

//=========================================================================
// Clock and Reset
//=========================================================================

logic clk = 0;
logic rst_n;

always #5 clk = !clk;// 10ns period 100MHz

//=========================================================================
// Signals (TB <-> FSM)
//=========================================================================

//request interface tb -> FSM
logic user_req_valid;
logic req_rnw;
logic [COL_BITS-1:0] req_col;
logic [ROW_BITS-1:0] req_row;
//response FSM -> tb
logic user_req_ready;

//command interface FSM -> cmd_gen
logic cmd_valid;
ddr3_cmd_t cmd_type;
logic [ADDR_WIDTH-1:0] cmd_addr;

//status flags
logic busy;
bank_state_t state;

//=========================================================================
// FSM Interface Connections
//=========================================================================

ddr3_bank_fsm #(.BANK_ID(0)) dut(
    .clk(clk),
    .rst_n(rst_n),
    .user_req_valid(user_req_valid),
    .user_req_ready(user_req_ready),
    .req_rnw(req_rnw),
    .req_row(req_row),
    .req_col(req_col),
    .cmd_valid(cmd_valid),
    .cmd_type(cmd_type),
    .cmd_addr(cmd_addr),
    .state(state),
    .busy(busy)
);
//=========================================================================
// Monitor
//=========================================================================
int cycle = 0;
always @(posedge clk) begin
    $display("[%0t][CYCLE:%0d][REQUEST LOGIC] req_valid:%0b, req_ready:%0b,rnw:%0b, req_row:0x%0h,req_col:0x%0h",
                $time,cycle,user_req_valid,user_req_ready,req_rnw,req_row,req_col);

    $display("[%0t][CYCLE:%0d][COMMAND LOGIC] CMD: %s, ADDR=0x%0h, STATE=%s",
                    $time,cycle,cmd_type.name(), cmd_addr,state.name());

    $display("[%0t][CYCLE:%0d][FSM STATUS] STATE: %s, NEXT_STATE: %s, OPEN_ROW: 0x%0h",
                    $time,cycle,state.name(), dut.next_state.name(),dut.open_row);

    $display("[%0t][CYCLE:%0d][COUNTER TRACKING] tRCD: %0d, tRAS: %0d, tRP=%0d",
                    $time,cycle,dut.trcd_counter,dut.tRAS_counter,dut.tRP_counter);

    $display("[%0t][CYCLE:%0d][COUNTER FLAGS] tRCD: %0d, tRAS: %0d, tRP=%0d",
                    $time,cycle,dut.trcd_met,dut.tras_met,dut.trp_met);
cycle++;

end
//=========================================================================
// Test Stimulus
//=========================================================================
initial begin
    $dumpfile("bank_fsm.vcd");
    $dumpvars(0,test_bank_fsm);

    //initialize
    user_req_valid = 0;
    req_rnw = 0;
    req_col = 0;
    req_row = 0;

    //reset
    rst_n = 0;
    repeat(5) @(posedge clk);
    rst_n = 1;
    $display("\n[%0t] === Reset Complete ===\n",$time);

    repeat(2) @(posedge clk);

//=====================================================================
// Test 1: Simple READ
//=====================================================================
$display("\n[%0t]===TEST 1: SIMPLE READ===\n",$time);

    @(posedge clk);
    user_req_valid <= 1;
    req_rnw <= 1;
    req_row <= 13'h100;
    req_col <= 10'h060;

    @(posedge clk);
    user_req_valid <= 0;

    do begin
    @(posedge clk);
    end while(!user_req_ready);
///Expected Behavior
/*
    @75ns
*/

//=====================================================================
// Test 2: Row Hit
//=====================================================================
$display("\n[%0t]===TEST 2: ROW HIT===\n",$time);

    @(posedge clk);
    user_req_valid <= 1;
    req_rnw <= 1;
    req_row <= 13'h100; //same row as test 1
    req_col <= 10'h050;

    @(posedge clk);
    user_req_valid <= 0;

    do begin
    @(posedge clk);
    end while(!user_req_ready);
//=====================================================================
// Test 3: Row Miss
//=====================================================================
$display("\n[%0t]===TEST 3: ROW MISS===\n",$time);

    @(posedge clk);
    user_req_valid <= 1;
    req_rnw <= 1;
    req_row <= 13'h200; //different row as test 1
    req_col <= 10'h070;

    @(posedge clk);
    user_req_valid <= 0;

    do begin
    @(posedge clk);
    end while(!user_req_ready);
//=====================================================================
$display("\n[%0t]===TEST COMPLETE===\n",$time);
$finish;
end
 initial begin
        #5000;
        $display("TIMEOUT!");
        $finish;
    end
endmodule