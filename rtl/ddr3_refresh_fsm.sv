
/*
 * ddr3_refresh_fsm.sv
 * DDR3 Refresh
 *
 * Author: Cameron Callahan
 * Date: Jan 12, 2026
 *
 * Description:
    track the refresh timing of the ddr3 controller
    issue CMD_REFRESH to cmd_gen when refresh is needed
    issue refresh flag to bank_fsm when refresh is imminent
 */
`import ddr3_pkg::*;

module refresh_fsm(
//input logic from TB
    input logic clk,
    input logic rst_n,

//interface to top-level controller
    input logic all_IDLE,
    output logic ddr_refresh,

//interface to bank_fsm
    output logic refresh_imminent,


//interface to cmd_gen
    output ddr3_cmd_t refresh_req,
    output logic refresh_cmd_valid
);

//=============================================================================
// Internal Registers
//=============================================================================
//state logic
    refresh_state_t ref_state, ref_next_state;
//counter logic
    logic [11:0] tREFI_counter;
    logic refresh_due;
    logic [5:0] tRFC_counter;
    logic tRFC_met;
//continuos assign
assign tRFC_met = (tRFC_counter == tRFC_CYCLES);
assign refresh_due = (tREFI_counter >= tREFI_CYCLES);
//=============================================================================
// sequential logic
//=============================================================================
always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        tRFC_counter <= '0;
        tREFI_counter <= '0;
        ref_state <= COUNTING;
    end else begin
        ref_state <= ref_next_state;

        case(ref_state)
            COUNTING: tREFI_counter <= tREFI_counter + 1;
            WAITING: ;//HOLD COUNTERS
            REFRESHING: begin
                if (tRFC_met) begin //reset counters
                    tRFC_counter <= '0;
                    tREFI_counter <= '0;
                end else  begin
                    tRFC_counter <= tRFC_counter + 1;
                end
            end
        endcase
    end
end
//=============================================================================
// comb logic
//=============================================================================
always_comb begin
    //defaults
    refresh_cmd_valid = 1'b0;
    refresh_req = CMD_NOP;
    refresh_imminent = 1'b0;
    ddr_refresh = 1'b0;
    ref_next_state = ref_state;
    case(ref_state)
        COUNTING: begin
            if (refresh_due) begin
                ref_next_state = WAITING;
            end else begin
                if (tREFI_counter == (tREFI_CYCLES - 10)) begin //ISSUE WARNING TO FSM/TOPLEVEL TO SET IDLE
                     refresh_imminent = 1'b1;
                end
                ref_next_state = COUNTING;
            end
        end
        WAITING: begin
            refresh_imminent = 1'b1;
            if(all_IDLE)begin
                refresh_cmd_valid = 1'b1;
                refresh_req = CMD_REFRESH;
                ddr_refresh = 1'b1; // tell the top-level all banks are refreshing
                ref_next_state = REFRESHING;
            end else begin
                ref_next_state = WAITING;
            end

        end
        REFRESHING: begin
            ddr_refresh = 1'b1; // tell the top-level all banks are refreshing
            if(tRFC_met)begin
                ref_next_state = COUNTING;
            end else begin
                ref_next_state = REFRESHING;
            end

        end
        default: begin
            ref_next_state = COUNTING;
        end
    endcase
end
endmodule : refresh_fsm