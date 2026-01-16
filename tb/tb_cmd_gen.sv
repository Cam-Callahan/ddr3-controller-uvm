//tb_cmd_gen.sv
//Tests only the cmd_gen module

`timescale 1ns/1ps
import ddr3_pkg::*;

module test_cmd_gen;

//=========================================================================
// Clock and Reset
//=========================================================================

logic clk = 0;
logic rst_n;

always #5 clk = !clk;// 10ns period 100MHz

//=========================================================================
// Signals (TB <-> cmd_gen)
//=========================================================================

//cmd interface FMS/ref_fsm -> cmd_gen (TB in this case)
logic [3:0] bank_cmd_valid;
ddr3_cmd_t bank_cmd_type[4];
logic [12:0] bank_addr[4];
//refrresh commands refreshe_fsm -> cmd_gen
logic refresh_cmd_valid;

//=========================================================================
// FSM Interface Connections
//=========================================================================

ddr3_cmd_gen dut(.*);
//=========================================================================
// Monitor
//=========================================================================
int cycle = 0;
always @(posedge clk) begin
     $display("[%0t][CYCLE:%0d][REFRESH LOGIC] Refresh Requested: %0b",$time,cycle,refresh_cmd_valid);
     if(refresh_cmd_valid) begin
        $display("[%0t][CYCLE:%0d][OUTPUTS] RAS_n: %0b, CAS_n: %0b, WE_n: %0b,BA: %00b, ADDR:%0h",
                    $time,cycle,ddr3_ras_n,ddr3_cas_n,ddr3_we_n,ddr3_ba,ddr3_addr);
     end

    for (int i = 0;i < 4; i++) begin
        if(bank_cmd_valid[i]) begin
            $display("[%0t][CYCLE:%0d][COMMAND LOGIC] bank:%0d, bank_addr:%0b, cmd_valid:%0b, cmd_type:%s,",
                        $time,cycle,i,bank_addr[i],bank_cmd_valid[i],bank_cmd_type[i].name());
        end
    end
    $display("[%0t][CYCLE:%0d][BANK ARBITRATION] Priority bank: %s, Selected Bank: %s, Bank_selected %0b",
                    $time,cycle,prio_bank.name(),sel_bank.name(),bank_selected);

    if(!refresh_cmd_valid) begin
    $display("[%0t][CYCLE:%0d][OUTPUTS] RAS_n: %0b, CAS_n: %0b, WE_n: %0b,BA: %00b, ADDR:%0h",
                    $time,cycle,ddr3_ras_n,ddr3_cas_n,ddr3_we_n,ddr3_ba,ddr3_addr);

    end

cycle++;

end
//=========================================================================
// Test Stimulus
//=========================================================================
initial begin
    $dumpfile("cmd_gen.vcd");
    $dumpvars(0,tb_cmd_gen);

    //initialize
    bank_cmd_valid = 4'b0000;
    for (int i = 0; i < 4; i++) begin
            bank_cmd_type[i] = CMD_NOP;
            bank_addr[i] = 13'h0;
        end
    refresh_req = 1'b0;

    //reset
    rst_n = 0;
    repeat(5) @(posedge clk);
    rst_n = 1;
    $display("\n[%0t] === Reset Complete ===\n",$time);

    repeat(2) @(posedge clk);

//=====================================================================
// Test 1: Single Bank Active
//=====================================================================
$display("\n[%0t]===TEST 1: SINGLE BANK ACTIVATE===\n",$time);

    @(posedge clk);
    refresh_req <= 1'b0;
    bank_cmd_valid[0] <= 1'b1;
    bank_cmd_type <= ACTIVATE;
    bank_addr <= 13'h100;

    @(posedge clk);
    bank_cmd_valid <= 1'b0;
    repeat(2) @(posedge clk);

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