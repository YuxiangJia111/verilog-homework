module mac_array #(
    parameter int unsigned P_ICH = 4,
    parameter int unsigned A_BIT = 8,
    parameter int unsigned W_BIT = 8,
    parameter int unsigned B_BIT = 32
) (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    en,     
    input  logic                    dat_vld, 
    input  logic                    clr,    
    input  logic        [A_BIT-1:0] x_vec  [P_ICH],
    input  logic signed [W_BIT-1:0] w_vec  [P_ICH],
    output logic signed [B_BIT-1:0] acc
);

    logic signed [A_BIT+W_BIT:0] products [P_ICH];
    logic signed [B_BIT-1:0]     tree_sum;

    always_comb begin
        for (int i = 0; i < P_ICH; i++) begin
            products[i] = $signed({1'b0, x_vec[i]}) * w_vec[i];
        end
    end

    always_comb begin
        logic signed [B_BIT-1:0] temp_sum;
        temp_sum = 0;
        for (int i = 0; i < P_ICH; i++) begin
            temp_sum = temp_sum + products[i];
        end
        tree_sum = temp_sum;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc <= '0;
        end else if (en) begin
            case ({
                clr, dat_vld
            })
                2'b00: acc <= acc;
                2'b01: acc <= acc + tree_sum;
                2'b10: acc <= '0;
                2'b11: acc <= tree_sum;
            endcase
        end
    end

endmodule