module pred
#(
    parameter RASNUM = 16,
    parameter RASIDLEN = $clog2(RASNUM),
    parameter RASCNTLEN = 8,
    parameter RASCNTMAX = (2**RASCNTLEN)-1,
    parameter BHTNUM = 64,
    parameter BHTIDLEN = $clog2(BHTNUM),
    parameter BHRLEN = 8,
    parameter PHTNUM = 2**BHRLEN,
    parameter TCNUM = 2**BHRLEN
)
(
    input             clk           ,
    input             reset         ,
    //from/to if
    input  [31:0]     fetch_pc_0    ,
    input  [31:0]     fetch_pc_1    ,

    input             dual_issue    ,
    

    output [31:0]     ret_pc_0        ,
    output [31:0]     ret_pc_1        ,

    output            taken_0         ,
    output            taken_1         ,

    //update
    input             branch_mistaken  ,
    input  [31:0]     wrong_pc         ,
    input  [31:0]     right_target     ,
    input  [2:0]      ins_type_w        ,
    
    input             update_orien_en  ,
    input  [31:0]     retire_pc        ,
    input             right_orien   

);

//not jump instruction  -> 000  while both not jmp, pc_1+0x4
//direct jmp            -> 001, predicted in btb
//call                  -> 010, predicted in btb, push pc+0x4 into RAS
//ret:  jirl r0, r1, 0  -> 011, using RAS
//indirect jmp          -> 100, using Target Cache
logic  [2:0]      ins_type_0    ;
logic  [2:0]      ins_type_1    ;

  

//BHT
reg [BHRLEN - 1:0]  bht [BHTNUM - 1:0] ;//8bit bhr
//search BHT
logic   [BHTIDLEN - 1:0]    bht_index_0 ;
logic   [BHTIDLEN - 1:0]    bht_index_1 ;
logic   [BHTIDLEN - 1:0]    bht_index_o ;
logic   [BHTIDLEN - 1:0]    bht_index_w ;
logic   [BHRLEN - 1:0]      bht_val_0   ;
logic   [BHRLEN - 1:0]      bht_val_1   ;
logic   [BHRLEN - 1:0]      bht_val_o   ;
logic   [BHRLEN - 1:0]      bht_val_w   ;
logic   [BHRLEN - 1:0]      pc_frag_0     ;
logic   [BHRLEN - 1:0]      pc_frag_1     ;
logic   [BHRLEN - 1:0]      pc_frag_o   ;
logic   [BHRLEN - 1:0]      pc_frag_w   ;
logic   [BHRLEN - 1:0]      hashed_index_0;
logic   [BHRLEN - 1:0]      hashed_index_1;
logic   [BHRLEN - 1:0]      hashed_index_o ;
logic   [BHRLEN - 1:0]      hashed_index_w ;


//adjust this hash while change BHTNUM/IDLEN
assign bht_index_0 = fetch_pc_0[31:26]^fetch_pc_0[25:20]^fetch_pc_0[19:14]^fetch_pc_0[13:8]^fetch_pc_0[7:2];
assign bht_index_1 = fetch_pc_1[31:26]^fetch_pc_1[25:20]^fetch_pc_1[19:14]^fetch_pc_1[13:8]^fetch_pc_1[7:2];
assign bht_index_o = retire_pc[31:26]^retire_pc[25:20]^retire_pc[19:14]^retire_pc[13:8]^retire_pc[7:2];
assign bht_index_w = wrong_pc[31:26]^wrong_pc[25:20]^wrong_pc[19:14]^wrong_pc[13:8]^wrong_pc[7:2];

assign bht_val_0 = bht[bht_index_0];
assign bht_val_1 = bht[bht_index_1];
assign bht_val_o = bht[bht_index_o];
assign bht_val_w = bht[bht_index_w];

assign pc_frag_0 = fetch_pc_0[BHRLEN + 1 :2];
assign pc_frag_1 = fetch_pc_1[BHRLEN + 1 :2];
assign pc_frag_o = retire_pc[BHRLEN + 1 :2];
assign pc_frag_w = wrong_pc[BHRLEN + 1 :2];

assign hashed_index_0 = bht_val_0 ^ pc_frag_0;
assign hashed_index_1 = bht_val_1 ^ pc_frag_1;
assign hashed_index_o = bht_val_o ^ pc_frag_o;
assign hashed_index_w = bht_val_w ^ pc_frag_w;
//reset & update BHT
integer i;
always @(posedge clk) begin
    if(reset) begin
        for(i = 0; i < BHTNUM; i = i + 1) begin
            bht[i] <= 0;
        end
    end
    else if(update_orien_en) begin
        for(i = BHRLEN - 1; i >= 0; i = i - 1) begin
            bht[bht_index_o] <= bht[bht_index_o] << 1;
            bht[bht_index_o][0] <= right_orien;
        end
    end
end



//PHT
// 00 01 10 11
//untaken -> taken
reg     [1:0]   pht   [PHTNUM - 1:0];
//search PHT
logic   [1:0]   pht_res_0           ;
logic   [1:0]   pht_res_1           ;

assign pht_res_0 = pht[hashed_index_0];
assign pht_res_1 = pht[hashed_index_1];
assign taken_0 = pht_res_0[1];
assign taken_1 = pht_res_1[1];
//reset & update PHT
integer j;
always @(posedge clk) begin
    if(reset) begin
        for(j = 0; j < PHTNUM; j = j + 1) begin
            pht[j] <= 0;
        end
    end
    else if(update_orien_en) begin
        if(right_orien) begin
            if(pht[hashed_index_o] != 2'b11)begin    
                pht[hashed_index_o] <= pht[hashed_index_o] + 1;
            end
        end
        else begin
            if(pht[hashed_index_o] != 2'b00)begin    
                pht[hashed_index_o] <= pht[hashed_index_o] - 1;
            end
        end
    end
end



//RAS
reg     [31:0]              ras_pc      [RASNUM - 1:0];
reg     [RASCNTLEN - 1:0]   ras_counter [RASNUM - 1:0];
reg     [$clog2(RASNUM)-1:0]ras_top                   ;
//search RAS
reg     [31:0]              ras_res;
logic   [31:0]              ras_top_val;
logic   [31:0]              ras_ret_pc;
logic   [31:0]              ras_ret_pc_0;
logic   [31:0]              ras_ret_pc_1;
logic                       ras_push;
logic                       ras_pop;


assign ras_top_val = ras_pc[ras_top];
assign ras_ret_pc = ({32{ins_type_0 == 3'b010}} & ras_ret_pc_0 )|
                    ({32{ins_type_0 == 3'b010 && dual_issue}} & ras_ret_pc_1 )|
                    32'b0;
assign ras_ret_pc_0 = {fetch_pc_0[31:2] + 1'b1,fetch_pc_0[1:0]};
assign ras_ret_pc_1 = {fetch_pc_1[31:2] + 1'b1,fetch_pc_1[1:0]};
assign ras_push = ins_type_0 == 3'b010 || (ins_type_1 == 3'b010 && dual_issue);
assign ras_pop = ins_type_0 == 3'b011 || (ins_type_1 == 3'b011 && dual_issue);
//reset & push & pop RAS

integer k;
always @(posedge clk) begin
    if(reset) begin
        for(k = 0; k < RASNUM; k = k + 1) begin
            ras_pc[k] <= 0;
            ras_counter[k] <=0;
        end
        ras_top <= 0;
    end
    else begin
        //call->push
        if(ras_push) begin
            //recursion counter increase
            if(ras_ret_pc == ras_top_val && ras_counter[ras_top] != RASCNTMAX) begin
                ras_counter[ras_top] <= ras_counter[ras_top] + 1;
            end
            else begin
                ras_top <= ras_top + 1;
                ras_pc[ras_top] <= ras_ret_pc;
                ras_counter[ras_top] <= 1;
            end
        end
        //ret->pop
        else if(ras_pop) begin
            ras_res <= ras_top_val;
            if(ras_counter[ras_top] <= 1) begin
                ras_counter[ras_top] <= 0;
                ras_top <= ras_top - 1;
            end
            else begin
                ras_counter[ras_top] = ras_counter[ras_top] - 1;
            end
        end
    end
end

//Target Cache
reg     [31:0]  tc    [TCNUM - 1:0];
//search Target Cache
logic           tc_res_0           ;
logic           tc_res_1           ;


assign tc_res_0 = tc[hashed_index_0];
assign tc_res_1 = tc[hashed_index_1];
//reset & update Target Cache
integer l;
always @(posedge clk) begin
    if(reset) begin
        for(l = 0; l < TCNUM; l = l + 1) begin
            tc[l] <= 0;
        end
    end
    else if(branch_mistaken && ins_type_w == 3'b100) begin
        tc[hashed_index_w] <= right_target;
    end
end


//BTB
logic   [31:0]  btb_res_0;
logic   [31:0]  btb_res_1;
btb btb(
    .clk(clk),
    .reset(reset),

    .fetch_pc_0(fetch_pc_0),
    .fetch_pc_1(fetch_pc_1),
    .target_pc_0(btb_res_0),
    .target_pc_1(btb_res_1),
    .ins_type_0(ins_type_0),
    .ins_type_1(ins_type_1),

    .branch_mistaken(branch_mistaken),
    .ins_type_w(ins_type_w),
    .wrong_pc(wrong_pc),
    .right_target(right_target)
);

//final select
assign ret_pc_0 = ({32{ins_type_0 == 3'b000}} & {fetch_pc_0[31:3] + 1'b1,3'b0}) |
                ({32{ins_type_0 == 3'b001}} & btb_res_0)|
                ({32{ins_type_0 == 3'b010}} & btb_res_0)|
                ({32{ins_type_0 == 3'b011}} & ras_res)|
                ({32{ins_type_0 == 3'b100}} & tc_res_0)|
                ({32{ins_type_0 == 3'b101}} & btb_res_0)|
                32'b0;
assign ret_pc_1 = ({32{ins_type_1 == 3'b000}} & {fetch_pc_1[31:3] + 1'b1,3'b0}) |
                ({32{ins_type_1 == 3'b001}} & btb_res_1)|
                ({32{ins_type_1 == 3'b010}} & btb_res_1)|
                ({32{ins_type_1 == 3'b011}} & ras_res)|
                ({32{ins_type_1 == 3'b100}} & tc_res_1)|
                ({32{ins_type_1 == 3'b101}} & btb_res_1)|
                32'b0;





endmodule

