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


    logic [DATA_WIDTH-1:0]                      data_buf [MERGE_NUM];
    logic [MASK_WIDTH-1:0]                      mask_buf [MERGE_NUM];

    logic [ADDR_WIDTH-1:0]                      base_addr;
    logic [$clog2(MERGE_NUM+1)-1:0]             count;

    logic                                       continuous;
    logic                                       is_full;
    logic                                       is_last;
    logic                                       is_discont;
    logic                                       is_flush;

    logic [ADDR_WIDTH-1:0]                      out_addr_r;
    logic [MERGE_NUM*DATA_WIDTH-1:0]            out_dat_r;
    logic [MERGE_NUM*MASK_WIDTH-1:0]            out_msk_r;

    assign in_rdy           = !out_vld || out_rdy;
    assign continuous       = (count == 0) || (in_addr == base_addr + count*ADDR_STEP);
    assign is_full          = (count == MERGE_NUM-1);
    assign is_last          = in_lst;
    assign is_discont       = (count != 0) && !continuous;
    assign is_flush         = in_vld && (is_full || is_last || is_discont);

    always_ff @( posedge clk or negedge rst_n ) begin 
        if(!rst_n) begin
            out_lst <= 0;
        end
        if(in_vld && in_rdy) begin
            if(is_discont) begin
                out_lst <= 0;
            end
            if(is_full || is_last) begin
                out_lst <= in_lst;
            end
        end
    end
    always_ff @( posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            base_addr  <= 0;
            out_addr_r <= 0;
        end
        if(in_vld && in_rdy) begin
            if(is_discont) begin
                out_addr_r <= base_addr;
                base_addr  <= in_addr;
            end 
            else begin
                if(count == 0)begin
                    base_addr <= in_addr;
                end
                if(is_full || is_last) begin
                    out_addr_r <= (count == 0) ? in_addr : base_addr;
                end
            end
        end
    end
    always_ff @( posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            out_vld <= 0;
        end
        if(out_vld && out_rdy)begin
            out_vld <= 0;
        end
        if(in_vld && in_rdy) begin
            if(is_discont) begin
                out_vld <= 1;
            end
            else begin
            if(is_full || is_last) begin
                out_vld <= 1;
            end
            end
        end
    end
    always_ff @(  posedge clk or negedge rst_n ) begin 
        if(!rst_n) begin
            count <= 0;
        end
        if(in_vld && in_rdy) begin
            if(is_discont) begin
                count <= 1;
            end
            else begin
                if(is_full || is_last) begin
                    count <= 0;
                end
                else begin
                    count <= count + 1;
                end
            end
        end

    end
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            out_dat_r  <= 0;
            out_msk_r  <= 0;
        end
        else begin
            if(in_vld && in_rdy) begin
                if(is_discont) begin
                    for(int i=0;i<MERGE_NUM;i++) begin
                        if(i < count) begin
                            out_dat_r[i*DATA_WIDTH +: DATA_WIDTH] <= data_buf[i];
                            out_msk_r[i*MASK_WIDTH +: MASK_WIDTH] <= mask_buf[i];
                        end
                        else begin
                            out_dat_r[i*DATA_WIDTH +: DATA_WIDTH] <= '0;
                            out_msk_r[i*MASK_WIDTH +: MASK_WIDTH] <= '0;
                        end
                    end
                    data_buf[0] <= in_dat;
                    mask_buf[0] <= in_msk;
                end

                else begin
                        data_buf[count] <= in_dat;
                        mask_buf[count] <= in_msk;
                        if(is_full || is_last) begin
                            for(int i=0;i<MERGE_NUM;i++) begin
                                if(i < count) begin
                                    out_dat_r[i*DATA_WIDTH +: DATA_WIDTH] <= data_buf[i];
                                    out_msk_r[i*MASK_WIDTH +: MASK_WIDTH] <= mask_buf[i];
                                end
                                else if(i == count) begin
                                    out_dat_r[i*DATA_WIDTH +: DATA_WIDTH] <= in_dat;
                                    out_msk_r[i*MASK_WIDTH +: MASK_WIDTH] <= in_msk;
                                end
                                else begin
                                    out_dat_r[i*DATA_WIDTH +: DATA_WIDTH] <= '0;
                                    out_msk_r[i*MASK_WIDTH +: MASK_WIDTH] <= '0;
                                end
                            end
                        end
                end
            end
        end
    end


    assign out_addr = out_addr_r;
    assign out_dat  = out_dat_r;
    assign out_msk  = out_msk_r;
    endmodule