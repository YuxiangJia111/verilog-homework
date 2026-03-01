
module mac #(
    parameter int unsigned A_BIT = 8,
    parameter int unsigned W_BIT = 8,
    parameter int unsigned B_BIT = 32
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    en,
    input  logic        [A_BIT-1:0] x,
    input  logic signed [W_BIT-1:0] w,
    input  logic signed [B_BIT-1:0] num_in,
    output logic signed [B_BIT-1:0] num_out
);

    logic signed [B_BIT-1:0] mult;

    assign mult = $signed({1'b0, x}) * w;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            num_out <= '0;
        else if (en)
            num_out <= num_in + mult;
    end

endmodule
module mac_acc #(
    parameter int unsigned A_BIT = 8,
    parameter int unsigned W_BIT = 8,
    parameter int unsigned B_BIT = 32
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    en,
    input  logic                    clr,
    input  logic                    valid,
    input  logic        [A_BIT-1:0] x,
    input  logic signed [W_BIT-1:0] w,
    input  logic signed [B_BIT-1:0] num_in,
    output logic signed [B_BIT-1:0] result
);

    logic signed [B_BIT-1:0] acc_q;
    logic signed [B_BIT-1:0] mult;

    assign mult = $signed({1'b0, x}) * w;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_q <= '0;
        end
        else if (en) begin

            if (!clr && !valid)
                acc_q <= acc_q;

            else if (!clr && valid)
                acc_q <= acc_q + num_in + mult;

            else if (clr && !valid)
                acc_q <= num_in;

            else
                acc_q <= num_in + mult;
        end
    end

    assign result = acc_q;

endmodule
module conv_mac_array #(
    parameter int unsigned P_ICH = 4,
    parameter int unsigned A_BIT = 8,
    parameter int unsigned W_BIT = 8,
    parameter int unsigned B_BIT = 32
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    en,
    input  logic                    dat_vld,
    input  logic                    clr,
    input  logic        [A_BIT-1:0] x_vec [P_ICH],
    input  logic signed [W_BIT-1:0] w_vec [P_ICH],
    output logic signed [B_BIT-1:0] acc
);

    logic [A_BIT-1:0]        x_pipe [P_ICH];
    logic signed [W_BIT-1:0] w_pipe [P_ICH];
    logic                    dat_vld_pipe [P_ICH];
    logic                    clr_pipe [P_ICH];
    logic signed [B_BIT-1:0] num   [P_ICH+1];

    assign num[0] = '0;

    generate
        for (genvar i = 0; i < P_ICH; i++) begin : ALIGN
            delayline #(
                .WIDTH(A_BIT),
                .DEPTH(i+1)
            ) dx (
                .clk(clk),
                .rst_n(rst_n),
                .en(en),
                .data_in(x_vec[i]),
                .data_out(x_pipe[i])
            );

            delayline #(
                .WIDTH(W_BIT),
                .DEPTH(i+1)
            ) dw (
                .clk(clk),
                .rst_n(rst_n),
                .en(en),
                .data_in(w_vec[i]),
                .data_out(w_pipe[i])
            );
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < P_ICH; i++) begin
                dat_vld_pipe[i] <= 1'b0;
                clr_pipe[i] <= 1'b0;
            end
        end
        else if (en) begin
            dat_vld_pipe[0] <= dat_vld;
            clr_pipe[0] <= clr;

            for (int i = 1; i < P_ICH; i++) begin
                dat_vld_pipe[i] <= dat_vld_pipe[i-1];
                clr_pipe[i] <= clr_pipe[i-1];
            end
        end
    end

    generate
        for (genvar i = 0; i < P_ICH-1; i++) begin
            mac #(
                .A_BIT(A_BIT),
                .W_BIT(W_BIT),
                .B_BIT(B_BIT)
            ) m (
                .clk(clk),
                .rst_n(rst_n),
                .en(en && dat_vld_pipe[i]),
                .x(x_pipe[i]),
                .w(w_pipe[i]),
                .num_in(num[i]),
                .num_out(num[i+1])
            );
        end
    endgenerate

    mac_acc #(
        .A_BIT(A_BIT),
        .W_BIT(W_BIT),
        .B_BIT(B_BIT)
    )(
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .clr(clr_pipe[P_ICH-1]),
        .valid(dat_vld_pipe[P_ICH-1]),
        .x(x_pipe[P_ICH-1]),
        .w(w_pipe[P_ICH-1]),
        .num_in(num[P_ICH-1]),
        .result(num[P_ICH])
    );

    assign acc = num[P_ICH];

endmodule