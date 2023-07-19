`default_nettype none

`ifndef DEFINITIONS_SVH_
`define DEFINITIONS_SVH_

`ifdef DIFFTEST_EN
parameter TLBNUM = 32;
`else
parameter TLBNUM = 16;
`endif

parameter TLBIDLEN = $clog2(TLBNUM);
parameter PALEN  = 32;

`define CACHE_LINE_32B

`ifdef CACHE_LINE_16B
`define LINE_WIDTH 128
`define LINE_WORD_NUM 4
`elsif CACHE_LINE_32B
`define LINE_WIDTH 256
`define LINE_WORD_NUM 8
`endif

typedef enum logic [4:0] {
    // alu operation
    OP_OUT1 = 5'h00,  // ALU output A
    OP_OUT2,  // ALU output B
    OP_ADD,   // add operation
    OP_SUB,   // sub operation
    OP_EQU,   // equal compare
    OP_SLT,   // signed compared and set less than
    OP_SLTU,  // unsigned compared and set less than
    OP_AND,   // bitwise and
    OP_NOR,   // bitwise nor
    OP_OR,    // bitwise or
    OP_XOR,   // bitwise xor
    OP_SLL,   // logic left shift
    OP_SRL,   // logic right shift
    OP_SRA,   // arithmetic right shift

    // mul operation
    OP_MUL = 5'h10,
    OP_MULH,
    OP_MULHU,
    
    // div operation
    OP_DIV = 5'h18 ,
    OP_DIVU,
    OP_MOD,
    OP_MODU
} opcode_t;

typedef enum logic [14:0] {
    INT  = {6'h0,  9'h0},
    PIL  = {6'h1,  9'h0},
    PIS  = {6'h2,  9'h0},
    PIF  = {6'h3,  9'h0},
    PME  = {6'h4,  9'h0},
    PPI  = {6'h7,  9'h0},
    ADEF = {6'h8,  9'h0},
    ADEM = {6'h8,  9'h1},
    ALE  = {6'h9,  9'h0},
    SYS  = {6'hb,  9'h0},
    BRK  = {6'hc,  9'h0},
    INE  = {6'hd,  9'h0},
    IPE  = {6'he,  9'h0},
    FPD  = {6'hf,  9'h0},
    FPE  = {6'h12, 9'h0},
    TLBR = {6'h3f, 9'h0},

    ERTN = {6'h3c, 9'h3c}
} exception_t;

typedef enum logic [1:0] {
    MEM_NOP,
    MEM_LOAD_S,
    MEM_LOAD_U,
    MEM_STORE
} mem_type_t;

typedef enum logic [1:0] {
    MEM_BYTE,
    MEM_HALF,
    MEM_WORD
} mem_size_t;

typedef enum logic [2:0] {
    SPEC_CSR,
    SPEC_TLBSRCH,
    SPEC_TLBRD,
    SPEC_TLBWR,
    SPEC_TLBFILL,
    SPEC_INVTLB
} spec_opcode_t;

typedef struct packed {
    spec_opcode_t opcode;
    logic [13:0]  csr_addr;
    logic [31:0]  csr_mask;
    logic [ 4:0]  invtlb_op;
    logic [ 9:0]  invtlb_asid;
    logic [31:0]  invtlb_va;
} spec_op_t;

typedef struct packed {
    logic       plv0;
    logic       plv3;
    logic [1:0] mat;
    logic [2:0] pseg;
    logic [2:0] vseg;
} dmw_t;

typedef struct packed {
    logic [18: 0] vppn;
    logic [ 5: 0] ps;
    logic         g;
    logic [ 9: 0] asid;
    logic         e;
    logic [19: 0] ppn0;
    logic [ 1: 0] plv0;
    logic [ 1: 0] mat0;
    logic         d0;
    logic         v0;
    logic [19: 0] ppn1;
    logic [ 1: 0] plv1;
    logic [ 1: 0] mat1;
    logic         d1;
    logic         v1;
} tlb_entry_t;

typedef struct packed {
    logic                found;
    logic [TLBIDLEN-1:0] index;
    logic [19:0]         ppn;
    logic [ 5:0]         ps;
    logic [ 1:0]         plv;
    logic [ 1:0]         mat;
    logic                d;
    logic                v;
} tlb_result_t;

typedef struct packed {
    logic        valid;
    logic [31:0] instr;
    logic        is_TLBFILL;
    logic [TLBIDLEN-1:0] TLBFILL_index;
    logic        is_CNTinst;
    logic [63:0] timer_64_value;
    logic        csr_rstat;
    logic [31:0] csr_data;
    logic [ 7:0] store_valid;
    logic [31:0] storePAddr;
    logic [31:0] storeVAddr;
    logic [31:0] storeData;
    logic [ 7:0] load_valid;
    logic [31:0] loadPAddr;
    logic [31:0] loadVAddr;
} difftest_t;

typedef struct packed {
    logic        excp_valid;
    logic        eret;
    logic [10:0] intrNo;
    logic [ 5:0] cause;
    logic [31:0] exceptionPC;
    logic [31:0] exceptionInst;
} difftest_excp_t;

typedef struct packed {
    logic [31:0] CRMD     ;
    logic [31:0] PRMD     ;
    logic [31:0] ECFG     ;
    logic [31:0] ESTAT    ;
    logic [31:0] ERA      ;
    logic [31:0] BADV     ;
    logic [31:0] EENTRY   ;
    logic [31:0] TLBIDX   ;
    logic [31:0] TLBEHI   ;
    logic [31:0] TLBELO0  ;
    logic [31:0] TLBELO1  ;
    logic [31:0] ASID     ;
    logic [31:0] SAVE0    ;
    logic [31:0] SAVE1    ;
    logic [31:0] SAVE2    ;
    logic [31:0] SAVE3    ;
    logic [31:0] TID      ;
    logic [31:0] TCFG     ;
    logic [31:0] TVAL     ;
    logic [31:0] TLBRENTRY;
    logic [31:0] DMW0     ;
    logic [31:0] DMW1     ;
} difftest_csr_t;


`endif