`include "definitions.svh"

module ibuf(
    input wire             clk,
    input wire             reset,
    input wire             flush,

    input wire   [ 1:0]    input_size,
    output logic           input_ready,
    input wire   [31:0]    input_pc1,
    input wire   [31:0]    input_inst1,
    input wire             input_pred_branch_taken1,
    input wire   [31:0]    input_pred_branch_target1,
    input wire   [31:0]    input_pc2,
    input wire   [31:0]    input_inst2,
    input wire             input_pred_branch_taken2,
    input wire   [31:0]    input_pred_branch_target2,

    input wire logic       have_exception,
    input wire exception_t exception_type,

    output logic           output_valid1,
    output logic [31:0]    output_pc1,
    output logic [31:0]    output_inst1,
    output logic           output_pred_branch_taken1,
    output logic [31:0]    output_pred_branch_target1,
    output logic           output_have_exception1,
    output exception_t     output_exception_type1,


    output logic           output_valid2,
    output logic [31:0]    output_pc2,
    output logic [31:0]    output_inst2,
    output logic           output_pred_branch_taken2,
    output logic [31:0]    output_pred_branch_target2,

    input wire [1:0]       consume_inst
);

logic [31:0] pc                [7:0];
logic [31:0] inst              [7:0];
logic        pred_branch_taken [7:0];
logic [31:0] pred_branch_target[7:0];

logic [2:0] head;
logic [2:0] tail;
logic [3:0] length;
logic       full;

assign input_ready = length <= 4'd4;
assign full = length == 4'd8;

assign output_valid1 = length >= 4'd1;
assign output_pc1 = pc[head];
assign output_inst1 = have_exception ? 32'h03400000 /* NOP */ : inst[head] ;
assign output_pred_branch_taken1 = pred_branch_taken[head];
assign output_pred_branch_target1 = pred_branch_target[head];
assign output_have_exception1 = have_exception;
assign output_exception_type1 = exception_type;

assign output_valid2 = length >= 4'd2;
assign output_pc2 = pc[head + 3'b1];
assign output_inst2 = inst[head + 3'b1];
assign output_pred_branch_taken2 = pred_branch_taken[head + 3'b1];
assign output_pred_branch_target2 = pred_branch_target[head + 3'b1];

always_ff @(posedge clk) begin
    if (reset || flush) begin
        head <= 3'd0;
        tail <= 3'd0;
        length <= 4'd0;
    end
    else begin
        tail <= tail + input_size;
        head <= head + consume_inst;
        length <= length + {1'b0, input_size} - {1'b0, consume_inst};
        if (input_size >= 2'd1) begin
            pc[tail] <= input_pc1;
            inst[tail] <= input_inst1;
            pred_branch_taken[tail] <= input_pred_branch_taken1;
            pred_branch_target[tail] <= input_pred_branch_target1;
        end
        if (input_size >= 2'd2) begin
            pc[tail + 3'd1] <= input_pc2;
            inst[tail + 3'd1] <= input_inst2;
            pred_branch_taken[tail + 3'd1] <= input_pred_branch_taken2;
            pred_branch_target[tail + 3'd1] <= input_pred_branch_target2;
        end
    end
end

endmodule