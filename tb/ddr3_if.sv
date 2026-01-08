//ddr3_if.sv
`inlcude "ddr3_defs.svh"

interface ddr3_if(
        input logic clk,
        input logic rst_n
        );


//=========================================================================
// User Request Interface (TB → Controller)
//=========================================================================
    logic user_req_valid; // TB -> controller (I have a request)
    logic user_req_ready; // Controller -> TB (I can accept)
    logic user_req_rnw; // 1 = read ,0 = write
    logic [1:0] user_req_bank;
    logic [ROW_BITS-1:0] user_req_row;
    logic [COL_BITS-1:0] user_req_col;
    logic [DATA_WIDTH-1:0] user_req_wdata;

//=========================================================================
// User Response (Controller → TB)
//=========================================================================
    logic user_resp_valid; // controller -> tb (i have a response)
    logic [DATA_WIDTH-1:0] user_resp_rdata;
//=========================================================================
// DDR3 Physical Interface
//=========================================================================
    logic ddr3_ras_n;
    logic ddr3_cas_n;
    logic ddr3_we_n;
    logic [1:0] ddr3_ba;
    logic [DDR3_ADDR_WIDTH-1:0] ddr3_addr;
    logic [DATA_WIDTH-1:0] ddr3_dq;
    logic ddr3_dqs;
//=========================================================================
// Modports
//=========================================================================

modport dut (
    input clk,
    input rst_n,

    //request interface
    input  user_req_valid,  //high when tb has a request for the dut
    output  user_req_ready, //high when dut is ready for tb request

    input  user_req_rnw,    //1 = read, 0 = write

    input  user_req_bank,
    input  user_req_row,
    input  user_req_col,

    input  user_req_wdata,  //write data requested by the user (TB)

    //response interface
    output user_resp_valid,
    output user_resp_rdata, //read data from dut

    //ddr3 pins
    output ddr3_ras_n,
    output ddr3_cas_n,
    output ddr3_we_n,
    output ddr3_ba,
    output ddr3_addr,
    inout  ddr3_dq
);
modport tb(
    output clk,
    output rst_n,

    //request interface
    output  user_req_valid,  //high when tb has a request for the dut
    input  user_req_ready, //high when dut is ready for tb request

    output  user_req_rnw,    //1 = read, 0 = write

    output  user_req_bank,
    output  user_req_row,
    output  user_req_col,

    output  user_req_wdata,  //write data requested by the user (TB)

    //response interface
    input user_resp_valid,
    input user_resp_rdata, //read data from dut

);
endinterface : ddr3_if