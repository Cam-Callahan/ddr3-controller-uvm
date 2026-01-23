/*
 * ddr3_cmd_gen.sv
 * DDR3 Command Generator
 *
 * Author: Cameron Callahan
 * Date: Jan 13, 2026
 *
 * Description:
    receive commands from each of the 4 banks
    arbitrate between which banks have priority
    Execute the commands given by priority bank
    recieve commands from refresh_fsm
    send refresh commands (refresh has highest prio)
 */
import ddr3_pkg::*;

module cmd_gen(
//input from TB
    input logic clk,
    input logic rst_n,
//input from bank_fsm
    input logic [3:0] bank_cmd_valid,
    input ddr3_cmd_t bank_cmd_type[4],
    input logic [12:0] bank_addr[4],
//output to Bank_fsm
    output logic [3:0] bank_cmd_ready,
    output bank_t next_prio_bank,
//input from refresh_fsm
    input logic     refresh_cmd_valid,
//output to ddr3 PHY (model in TB)
    output logic ddr3_ras_n,
    output logic ddr3_cas_n,
    output logic ddr3_we_n,
    output logic [1:0] ddr3_ba,
    output logic [12:0] ddr3_addr
);
//internal registers
bank_t prio_bank,next_bank,sel_bank;
logic bank_selected;
//=============================================================================
//  Assigns
//=============================================================================
assign next_prio_bank = next_bank;
//=============================================================================
//
//=============================================================================
always_ff@(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        prio_bank <= BANK_0;
    end else begin
        prio_bank <= next_bank;
    end
end
//=============================================================================
// selected Bank Arbitration
//=============================================================================
always_comb begin
    sel_bank = BANK_0;
    bank_selected = 1'b0;

    for(int i = 0; i < NUM_BANKS; i++) begin
        bank_t bank_check = bank_t'((prio_bank + i)%NUM_BANKS); //define which bank is begin checked starting with the prio_bank
        if(bank_cmd_valid[bank_check] && !bank_selected) begin  //if checked bank has a valid cmd and we havent selected a bank
            sel_bank = bank_check;
            bank_selected = 1'b1;
        end
    end
end

//=============================================================================
//  Command
//=============================================================================
always_comb begin
    //Defaults
    bank_cmd_ready = 4'b0000;
    ddr3_ras_n = 1'b1;
    ddr3_cas_n = 1'b1;
    ddr3_we_n = 1'b1;
    ddr3_ba = 2'b00;
    ddr3_addr = 13'b0;
    next_bank = prio_bank;


    if(refresh_cmd_valid) begin
        ddr3_ras_n = 1'b0;
        ddr3_cas_n = 1'b0;
        ddr3_we_n = 1'b1;
        ddr3_ba = 2'b00;  // dont care for refresh
        ddr3_addr = 13'b0; //dont care for refresh
        next_bank = prio_bank;
    end else if (bank_selected) begin
                    ddr3_ba = 2'(sel_bank);
                    ddr3_addr = bank_addr[2'(sel_bank)];
                    bank_cmd_ready[2'(sel_bank)] = 1'b1;
                   case (bank_cmd_type[2'(sel_bank)])
                    CMD_NOP: begin
                        ddr3_ras_n = 1'b1;
                        ddr3_cas_n = 1'b1;
                        ddr3_we_n = 1'b1;
                    end
                    CMD_ACTIVATE: begin
                        ddr3_ras_n = 1'b0;
                        ddr3_cas_n = 1'b1;
                        ddr3_we_n = 1'b1;
                    end
                    CMD_READ: begin
                        ddr3_ras_n = 1'b1;
                        ddr3_cas_n = 1'b0;
                        ddr3_we_n = 1'b1;
                    end
                    CMD_WRITE: begin
                        ddr3_ras_n = 1'b1;
                        ddr3_cas_n = 1'b0;
                        ddr3_we_n = 1'b0;
                    end
                    CMD_PRECHARGE: begin
                        ddr3_ras_n = 1'b0;
                        ddr3_cas_n = 1'b1;
                        ddr3_we_n = 1'b0;
                    end
                    default: begin
                        ddr3_ras_n = 1'b1;
                        ddr3_cas_n = 1'b1;
                        ddr3_we_n = 1'b1;
                    end
                   endcase

                next_bank = sel_bank + 1;
        end else begin
                next_bank = prio_bank;
            end
end
endmodule : cmd_gen