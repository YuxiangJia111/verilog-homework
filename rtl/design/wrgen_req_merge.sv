module wrgen_req_merge #(
    parameter int MERGE_NUM  = 2,
    parameter int DATA_WIDTH = 512,
    parameter int MASK_WIDTH = 64,
    parameter int ADDR_WIDTH = 34,
    parameter int ADDR_STEP  = 64
) (
    input  logic                                    clk,
    input  logic                                    rst_n,

    // Input Interface
    input  logic                                    in_vld,
    input  logic [ADDR_WIDTH-1:0]                   in_addr,
    input  logic [DATA_WIDTH-1:0]                   in_dat,
    input  logic [MASK_WIDTH-1:0]                   in_msk,
    input  logic                                    in_lst,
    output logic                                    in_rdy,

    // Output Interface
    output logic                                    out_vld,
    output logic [ADDR_WIDTH-1:0]                   out_addr,
    output logic [MERGE_NUM*DATA_WIDTH-1:0]         out_dat,
    output logic [MERGE_NUM*MASK_WIDTH-1:0]         out_msk,
    output logic                                    out_lst,
    input  logic                                    out_rdy
);


endmodule
