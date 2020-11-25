module cpu (
    input logic clock, reset,
    input logic [7:0] data_in,
    output logic [7:0] data_out,
    output logic [15:0] mem_addr,
    output logic mem_wren
);

// Current operation register

logic [7:0] OR_new, OR;
logic OR_ld;

register #(.WIDTH(8)) OR_reg (.in(OR_new), .clock(clock), .reset(reset), .load(OR_ld), .out(OR));

logic [7:0] OP8_new, OP8;
logic OP8_ld;

register #(.WIDTH(8)) OP8_reg (.in(OP8_new), .clock(clock), .reset(reset), .load(OP8_ld), .out(OP8));

logic [15:0] OP16_new, OP16;
logic OP16_ld;

register #(.WIDTH(16)) OP16_reg (.in(OP16_new), .clock(clock), .reset(reset), .load(OP16_ld), .out(OP16));


// stack pointer and program counter
logic [15:0] SP_new, SP;
logic [15:0] PC_new, PC;
logic SP_ld, PC_ld;

register #(.WIDTH(16)) PC_reg (.in(PC_new), .clock(clock), .reset(reset), .load(PC_ld), .out(PC));
register #(.WIDTH(16)) SP_reg (.in(SP_new), .clock(clock), .reset(reset), .load(SP_ld), .out(SP));


// internal registers
logic [7:0] A_new, A;
logic [7:0] F;
logic [7:0] B_new, B;
logic [7:0] C_new, C;
logic [7:0] D_new, D;
logic [7:0] E_new, E;
logic [7:0] H_new, H;
logic [7:0] L_new, L;
logic [15:0] BC_new, BC;
logic [15:0] DE_new, DE;
logic [15:0] HL_new, HL;
logic A_ld, F_ld, B_ld, C_ld, D_ld, E_ld, H_ld, L_ld, BC_ld, DE_ld, HL_ld;

logic [7:0] B_final_new; // intermediate signals for 16 bit combo register inputs
logic [7:0] C_final_new;
logic [7:0] D_final_new;
logic [7:0] E_final_new;
logic [7:0] H_final_new;
logic [7:0] L_final_new;

logic Z_flag_new, Z_flag;
logic N_flag_new, N_flag;
logic H_flag_new, H_flag;
logic C_flag_new, C_flag;

// handling 16 bit combo registers
always_comb begin : REGISTER_INPUTS
	Z_flag = F[7];
	N_flag = F[6];
	H_flag = F[5];
	C_flag = F[4];

	BC = {B, C};
	DE = {D, E};
	HL = {H, L};

	if (BC_ld) {B_final_new, C_final_new} = BC_new; // if 16 bit register is to be loaded, make inputs equal to the 16 bit
	else {B_final_new, C_final_new} = {B_new, C_new}; // if 8 bit register, make inputs equal to concat. 8 bit regs

	if (DE_ld) {D_final_new, E_final_new} = DE_new;
	else {D_final_new, E_final_new} = {D_new, E_new};

	if (HL_ld) {H_final_new, L_final_new} = HL_new;
	else {H_final_new, L_final_new} = {H_new, L_new};
end

register A_reg (.in(A_new), .clock(clock), .reset(reset), .load(A_ld), .out(A));
register F_reg (.in({Z_flag_new,N_flag_new,H_flag_new,C_flag_new,4'h0}), .clock(clock), .reset(reset), .load(F_ld), .out(F));
register B_reg (.in(B_final_new), .clock(clock), .reset(reset), .load(B_ld | BC_ld), .out(B));
register C_reg (.in(C_final_new), .clock(clock), .reset(reset), .load(C_ld | BC_ld ), .out(C));
register D_reg (.in(D_final_new), .clock(clock), .reset(reset), .load(D_ld | DE_ld), .out(D));
register E_reg (.in(E_final_new), .clock(clock), .reset(reset), .load(E_ld | DE_ld), .out(E));
register H_reg (.in(H_final_new), .clock(clock), .reset(reset), .load(H_ld | HL_ld), .out(H));
register L_reg (.in(L_final_new), .clock(clock), .reset(reset), .load(L_ld | HL_ld), .out(L));


// instruction macros
`define get_one_byte(dst) \
begin \
	mem_addr = PC; \
	``dst``_new = data_in; \
	``dst``_ld = 1'b1; \
	PC_new = PC + 1'b1; \
	PC_ld = 1'b1; \
end

`define get_high_byte(dst) \
begin \
	mem_addr = PC; \
	``dst``_new = {data_in, ``dst``[7:0]}; \
	``dst``_ld = 1'b1; \
	PC_new = PC + 1'b1; \
	PC_ld = 1'b1; \
end

`define get_low_byte(dst) \
begin \
	mem_addr = PC; \
	``dst``_new = {``dst``[15:8], data_in}; \
	``dst``_ld = 1'b1; \
	PC_new = PC + 1'b1; \
	PC_ld = 1;\
end

`define writeRegFromReg(dst,src) \
begin \
	``dst``_new = ``src; \
	``dst``_ld = 1'b1; \
end

`define writeMemFromReg(addr_src,data_src) \
begin \
	mem_addr = addr_src; \
	data_out = data_src; \
	mem_wren = 1'b1; \
end

`define INC16(src) \
begin \
	``src``_new = src + 1'b1; \
	``src``_ld = 1'b1; \
end

`define DEC16(src) \
begin \
	``src``_new = src - 1'b1; \
	``src``_ld = 1'b1; \
end

`define XOR(src) \
begin \
	A_new = src ^ A; \
	A_ld = 1'b1; \
	if (A_new == 8'h0) begin Z_flag_new = 1'b1; end \
	else Z_flag_new = 1'b0; \
	N_flag_new = 1'b0; \
	H_flag_new = 1'b0; \
	C_flag_new = 1'b0; \
	F_ld = 1'b1; \
end

`define ADD(base,add) \
begin \
	``base``_new = base + add; \
	``base``_ld = 1'b1; \
end

// checks the bit of the source signal at the specified index
`define BIT(bit_index,src) \
begin \
	Z_flag_new = ~``src``[bit_index]; \
	N_flag_new = 1'b0; \
	H_flag_new = 1'b1; \
	C_flag_new = C_flag; \
	F_ld = 1'b1; \
end

`define SEXT16(val) 16'(signed'(val))





enum logic [10:0] 	{   RESET,
						FETCH,
						NOP_00,
						LD_01_0,
						WAIT_LD_01_0,
						LD_01_1,
						WAIT_LD_01_1,
						LD_01_2,
						LD_02_0,
						WAIT_LD_02_0,
						LD_02_1,
						INC_03_0,
						WAIT_INC_03_0,
						INC_03_1,
						INC_04,
						DEC_05,
						LD_06_0,
						WAIT_LD_06_0,
						LD_06_1,
						RLCA_07,
						LD_08_0,
						WAIT_LD_08_0,
						LD_08_1,
						WAIT_LD_08_1,
						LD_08_2,
						WAIT_LD_08_2,
						LD_08_3,
						WAIT_LD_08_3,
						LD_08_4,
						ADD_09_0,
						WAIT_ADD_09_0,
						ADD_09_1,
						LD_0A_0,
						WAIT_LD_0A_0,
						LD_0A_1,
						DEC_0B_0,
						WAIT_DEC_0B_0,
						DEC_0B_1,
						INC_0C,
						DEC_0D,
						LD_0E_0,
						WAIT_LD_0E_0,
						LD_0E_1,
						RRCA_0F,
						STOP_10,
						LD_11_0,
						WAIT_LD_11_0,
						LD_11_1,
						WAIT_LD_11_1,
						LD_11_2,
						LD_12_0,
						WAIT_LD_12_0,
						LD_12_1,
						INC_13_0,
						WAIT_INC_13_0,
						INC_13_1,
						INC_14,
						DEC_15,
						LD_16_0,
						WAIT_LD_16_0,
						LD_16_1,
						RLA_17,
						JR_18_0,
						WAIT_JR_18_0,
						JR_18_1,
						WAIT_JR_18_1,
						JR_18_2,
						ADD_19_0,
						WAIT_ADD_19_0,
						ADD_19_1,
						LD_1A_0,
						WAIT_LD_1A_0,
						LD_1A_1,
						DEC_1B_0,
						WAIT_DEC_1B_0,
						DEC_1B_1,
						INC_1C,
						DEC_1D,
						LD_1E_0,
						WAIT_LD_1E_0,
						LD_1E_1,
						RRA_1F,
						JR_20_0,
						WAIT_JR_20_0,
						JR_20_1,
						WAIT_JR_20_1,
						JR_20_2,
						LD_21_0,
						WAIT_LD_21_0,
						LD_21_1,
						WAIT_LD_21_1,
						LD_21_2,
						LD_22_0,
						WAIT_LD_22_0,
						LD_22_1,
						INC_23_0,
						WAIT_INC_23_0,
						INC_23_1,
						INC_24,
						DEC_25,
						LD_26_0,
						WAIT_LD_26_0,
						LD_26_1,
						DAA_27,
						JR_28_0,
						WAIT_JR_28_0,
						JR_28_1,
						WAIT_JR_28_1,
						JR_28_2,
						ADD_29_0,
						WAIT_ADD_29_0,
						ADD_29_1,
						LD_2A_0,
						WAIT_LD_2A_0,
						LD_2A_1,
						DEC_2B_0,
						WAIT_DEC_2B_0,
						DEC_2B_1,
						INC_2C,
						DEC_2D,
						LD_2E_0,
						WAIT_LD_2E_0,
						LD_2E_1,
						CPL_2F,
						JR_30_0,
						WAIT_JR_30_0,
						JR_30_1,
						WAIT_JR_30_1,
						JR_30_2,
						LD_31_0,
						WAIT_LD_31_0,
						LD_31_1,
						WAIT_LD_31_1,
						LD_31_2,
						LD_32_0,
						WAIT_LD_32_0,
						LD_32_1,
						INC_33_0,
						WAIT_INC_33_0,
						INC_33_1,
						INC_34_0,
						WAIT_INC_34_0,
						INC_34_1,
						WAIT_INC_34_1,
						INC_34_2,
						DEC_35_0,
						WAIT_DEC_35_0,
						DEC_35_1,
						WAIT_DEC_35_1,
						DEC_35_2,
						LD_36_0,
						WAIT_LD_36_0,
						LD_36_1,
						WAIT_LD_36_1,
						LD_36_2,
						SCF_37,
						JR_38_0,
						WAIT_JR_38_0,
						JR_38_1,
						WAIT_JR_38_1,
						JR_38_2,
						ADD_39_0,
						WAIT_ADD_39_0,
						ADD_39_1,
						LD_3A_0,
						WAIT_LD_3A_0,
						LD_3A_1,
						DEC_3B_0,
						WAIT_DEC_3B_0,
						DEC_3B_1,
						INC_3C,
						DEC_3D,
						LD_3E_0,
						WAIT_LD_3E_0,
						LD_3E_1,
						CCF_3F,
						LD_40,
						LD_41,
						LD_42,
						LD_43,
						LD_44,
						LD_45,
						LD_46_0,
						WAIT_LD_46_0,
						LD_46_1,
						LD_47,
						LD_48,
						LD_49,
						LD_4A,
						LD_4B,
						LD_4C,
						LD_4D,
						LD_4E_0,
						WAIT_LD_4E_0,
						LD_4E_1,
						LD_4F,
						LD_50,
						LD_51,
						LD_52,
						LD_53,
						LD_54,
						LD_55,
						LD_56_0,
						WAIT_LD_56_0,
						LD_56_1,
						LD_57,
						LD_58,
						LD_59,
						LD_5A,
						LD_5B,
						LD_5C,
						LD_5D,
						LD_5E_0,
						WAIT_LD_5E_0,
						LD_5E_1,
						LD_5F,
						LD_60,
						LD_61,
						LD_62,
						LD_63,
						LD_64,
						LD_65,
						LD_66_0,
						WAIT_LD_66_0,
						LD_66_1,
						LD_67,
						LD_68,
						LD_69,
						LD_6A,
						LD_6B,
						LD_6C,
						LD_6D,
						LD_6E_0,
						WAIT_LD_6E_0,
						LD_6E_1,
						LD_6F,
						LD_70_0,
						WAIT_LD_70_0,
						LD_70_1,
						LD_71_0,
						WAIT_LD_71_0,
						LD_71_1,
						LD_72_0,
						WAIT_LD_72_0,
						LD_72_1,
						LD_73_0,
						WAIT_LD_73_0,
						LD_73_1,
						LD_74_0,
						WAIT_LD_74_0,
						LD_74_1,
						LD_75_0,
						WAIT_LD_75_0,
						LD_75_1,
						HALT_76,
						LD_77_0,
						WAIT_LD_77_0,
						LD_77_1,
						LD_78,
						LD_79,
						LD_7A,
						LD_7B,
						LD_7C,
						LD_7D,
						LD_7E_0,
						WAIT_LD_7E_0,
						LD_7E_1,
						LD_7F,
						ADD_80,
						ADD_81,
						ADD_82,
						ADD_83,
						ADD_84,
						ADD_85,
						ADD_86_0,
						WAIT_ADD_86_0,
						ADD_86_1,
						ADD_87,
						ADC_88,
						ADC_89,
						ADC_8A,
						ADC_8B,
						ADC_8C,
						ADC_8D,
						ADC_8E_0,
						WAIT_ADC_8E_0,
						ADC_8E_1,
						ADC_8F,
						SUB_90,
						SUB_91,
						SUB_92,
						SUB_93,
						SUB_94,
						SUB_95,
						SUB_96_0,
						WAIT_SUB_96_0,
						SUB_96_1,
						SUB_97,
						SBC_98,
						SBC_99,
						SBC_9A,
						SBC_9B,
						SBC_9C,
						SBC_9D,
						SBC_9E_0,
						WAIT_SBC_9E_0,
						SBC_9E_1,
						SBC_9F,
						AND_A0,
						AND_A1,
						AND_A2,
						AND_A3,
						AND_A4,
						AND_A5,
						AND_A6_0,
						WAIT_AND_A6_0,
						AND_A6_1,
						AND_A7,
						XOR_A8,
						XOR_A9,
						XOR_AA,
						XOR_AB,
						XOR_AC,
						XOR_AD,
						XOR_AE_0,
						WAIT_XOR_AE_0,
						XOR_AE_1,
						XOR_AF,
						OR_B0,
						OR_B1,
						OR_B2,
						OR_B3,
						OR_B4,
						OR_B5,
						OR_B6_0,
						WAIT_OR_B6_0,
						OR_B6_1,
						OR_B7,
						CP_B8,
						CP_B9,
						CP_BA,
						CP_BB,
						CP_BC,
						CP_BD,
						CP_BE_0,
						WAIT_CP_BE_0,
						CP_BE_1,
						CP_BF,
						RET_C0_0,
						WAIT_RET_C0_0,
						RET_C0_1,
						WAIT_RET_C0_1,
						RET_C0_2,
						WAIT_RET_C0_2,
						RET_C0_3,
						WAIT_RET_C0_3,
						RET_C0_4,
						POP_C1_0,
						WAIT_POP_C1_0,
						POP_C1_1,
						WAIT_POP_C1_1,
						POP_C1_2,
						JP_C2_0,
						WAIT_JP_C2_0,
						JP_C2_1,
						WAIT_JP_C2_1,
						JP_C2_2,
						WAIT_JP_C2_2,
						JP_C2_3,
						JP_C3_0,
						WAIT_JP_C3_0,
						JP_C3_1,
						WAIT_JP_C3_1,
						JP_C3_2,
						WAIT_JP_C3_2,
						JP_C3_3,
						CALL_C4_0,
						WAIT_CALL_C4_0,
						CALL_C4_1,
						WAIT_CALL_C4_1,
						CALL_C4_2,
						WAIT_CALL_C4_2,
						CALL_C4_3,
						WAIT_CALL_C4_3,
						CALL_C4_4,
						WAIT_CALL_C4_4,
						CALL_C4_5,
						PUSH_C5_0,
						WAIT_PUSH_C5_0,
						PUSH_C5_1,
						WAIT_PUSH_C5_1,
						PUSH_C5_2,
						WAIT_PUSH_C5_2,
						PUSH_C5_3,
						ADD_C6_0,
						WAIT_ADD_C6_0,
						ADD_C6_1,
						RST_C7_0,
						WAIT_RST_C7_0,
						RST_C7_1,
						WAIT_RST_C7_1,
						RST_C7_2,
						WAIT_RST_C7_2,
						RST_C7_3,
						RET_C8_0,
						WAIT_RET_C8_0,
						RET_C8_1,
						WAIT_RET_C8_1,
						RET_C8_2,
						WAIT_RET_C8_2,
						RET_C8_3,
						WAIT_RET_C8_3,
						RET_C8_4,
						RET_C9_0,
						WAIT_RET_C9_0,
						RET_C9_1,
						WAIT_RET_C9_1,
						RET_C9_2,
						WAIT_RET_C9_2,
						RET_C9_3,
						JP_CA_0,
						WAIT_JP_CA_0,
						JP_CA_1,
						WAIT_JP_CA_1,
						JP_CA_2,
						WAIT_JP_CA_2,
						JP_CA_3,
						WAIT_PREFIX_CB,
						PREFIX_CB,
						CALL_CC_0,
						WAIT_CALL_CC_0,
						CALL_CC_1,
						WAIT_CALL_CC_1,
						CALL_CC_2,
						WAIT_CALL_CC_2,
						CALL_CC_3,
						WAIT_CALL_CC_3,
						CALL_CC_4,
						WAIT_CALL_CC_4,
						CALL_CC_5,
						CALL_CD_0,
						WAIT_CALL_CD_0,
						CALL_CD_1,
						WAIT_CALL_CD_1,
						CALL_CD_2,
						WAIT_CALL_CD_2,
						CALL_CD_3,
						WAIT_CALL_CD_3,
						CALL_CD_4,
						WAIT_CALL_CD_4,
						CALL_CD_5,
						ADC_CE_0,
						WAIT_ADC_CE_0,
						ADC_CE_1,
						RST_CF_0,
						WAIT_RST_CF_0,
						RST_CF_1,
						WAIT_RST_CF_1,
						RST_CF_2,
						WAIT_RST_CF_2,
						RST_CF_3,
						RET_D0_0,
						WAIT_RET_D0_0,
						RET_D0_1,
						WAIT_RET_D0_1,
						RET_D0_2,
						WAIT_RET_D0_2,
						RET_D0_3,
						WAIT_RET_D0_3,
						RET_D0_4,
						POP_D1_0,
						WAIT_POP_D1_0,
						POP_D1_1,
						WAIT_POP_D1_1,
						POP_D1_2,
						JP_D2_0,
						WAIT_JP_D2_0,
						JP_D2_1,
						WAIT_JP_D2_1,
						JP_D2_2,
						WAIT_JP_D2_2,
						JP_D2_3,
						ILLEGAL_D3_D3,
						CALL_D4_0,
						WAIT_CALL_D4_0,
						CALL_D4_1,
						WAIT_CALL_D4_1,
						CALL_D4_2,
						WAIT_CALL_D4_2,
						CALL_D4_3,
						WAIT_CALL_D4_3,
						CALL_D4_4,
						WAIT_CALL_D4_4,
						CALL_D4_5,
						PUSH_D5_0,
						WAIT_PUSH_D5_0,
						PUSH_D5_1,
						WAIT_PUSH_D5_1,
						PUSH_D5_2,
						WAIT_PUSH_D5_2,
						PUSH_D5_3,
						SUB_D6_0,
						WAIT_SUB_D6_0,
						SUB_D6_1,
						RST_D7_0,
						WAIT_RST_D7_0,
						RST_D7_1,
						WAIT_RST_D7_1,
						RST_D7_2,
						WAIT_RST_D7_2,
						RST_D7_3,
						RET_D8_0,
						WAIT_RET_D8_0,
						RET_D8_1,
						WAIT_RET_D8_1,
						RET_D8_2,
						WAIT_RET_D8_2,
						RET_D8_3,
						WAIT_RET_D8_3,
						RET_D8_4,
						RETI_D9_0,
						WAIT_RETI_D9_0,
						RETI_D9_1,
						WAIT_RETI_D9_1,
						RETI_D9_2,
						WAIT_RETI_D9_2,
						RETI_D9_3,
						JP_DA_0,
						WAIT_JP_DA_0,
						JP_DA_1,
						WAIT_JP_DA_1,
						JP_DA_2,
						WAIT_JP_DA_2,
						JP_DA_3,
						ILLEGAL_DB_DB,
						CALL_DC_0,
						WAIT_CALL_DC_0,
						CALL_DC_1,
						WAIT_CALL_DC_1,
						CALL_DC_2,
						WAIT_CALL_DC_2,
						CALL_DC_3,
						WAIT_CALL_DC_3,
						CALL_DC_4,
						WAIT_CALL_DC_4,
						CALL_DC_5,
						ILLEGAL_DD_DD,
						SBC_DE_0,
						WAIT_SBC_DE_0,
						SBC_DE_1,
						RST_DF_0,
						WAIT_RST_DF_0,
						RST_DF_1,
						WAIT_RST_DF_1,
						RST_DF_2,
						WAIT_RST_DF_2,
						RST_DF_3,
						LDH_E0_0,
						WAIT_LDH_E0_0,
						LDH_E0_1,
						WAIT_LDH_E0_1,
						LDH_E0_2,
						POP_E1_0,
						WAIT_POP_E1_0,
						POP_E1_1,
						WAIT_POP_E1_1,
						POP_E1_2,
						LD_E2_0,
						WAIT_LD_E2_0,
						LD_E2_1,
						ILLEGAL_E3_E3,
						ILLEGAL_E4_E4,
						PUSH_E5_0,
						WAIT_PUSH_E5_0,
						PUSH_E5_1,
						WAIT_PUSH_E5_1,
						PUSH_E5_2,
						WAIT_PUSH_E5_2,
						PUSH_E5_3,
						AND_E6_0,
						WAIT_AND_E6_0,
						AND_E6_1,
						RST_E7_0,
						WAIT_RST_E7_0,
						RST_E7_1,
						WAIT_RST_E7_1,
						RST_E7_2,
						WAIT_RST_E7_2,
						RST_E7_3,
						ADD_E8_0,
						WAIT_ADD_E8_0,
						ADD_E8_1,
						WAIT_ADD_E8_1,
						ADD_E8_2,
						WAIT_ADD_E8_2,
						ADD_E8_3,
						JP_E9,
						LD_EA_0,
						WAIT_LD_EA_0,
						LD_EA_1,
						WAIT_LD_EA_1,
						LD_EA_2,
						WAIT_LD_EA_2,
						LD_EA_3,
						ILLEGAL_EB_EB,
						ILLEGAL_EC_EC,
						ILLEGAL_ED_ED,
						XOR_EE_0,
						WAIT_XOR_EE_0,
						XOR_EE_1,
						RST_EF_0,
						WAIT_RST_EF_0,
						RST_EF_1,
						WAIT_RST_EF_1,
						RST_EF_2,
						WAIT_RST_EF_2,
						RST_EF_3,
						LDH_F0_0,
						WAIT_LDH_F0_0,
						LDH_F0_1,
						WAIT_LDH_F0_1,
						LDH_F0_2,
						POP_F1_0,
						WAIT_POP_F1_0,
						POP_F1_1,
						WAIT_POP_F1_1,
						POP_F1_2,
						LD_F2_0,
						WAIT_LD_F2_0,
						LD_F2_1,
						DI_F3,
						ILLEGAL_F4_F4,
						PUSH_F5_0,
						WAIT_PUSH_F5_0,
						PUSH_F5_1,
						WAIT_PUSH_F5_1,
						PUSH_F5_2,
						WAIT_PUSH_F5_2,
						PUSH_F5_3,
						OR_F6_0,
						WAIT_OR_F6_0,
						OR_F6_1,
						RST_F7_0,
						WAIT_RST_F7_0,
						RST_F7_1,
						WAIT_RST_F7_1,
						RST_F7_2,
						WAIT_RST_F7_2,
						RST_F7_3,
						LD_F8_0,
						WAIT_LD_F8_0,
						LD_F8_1,
						WAIT_LD_F8_1,
						LD_F8_2,
						LD_F9_0,
						WAIT_LD_F9_0,
						LD_F9_1,
						LD_FA_0,
						WAIT_LD_FA_0,
						LD_FA_1,
						WAIT_LD_FA_1,
						LD_FA_2,
						WAIT_LD_FA_2,
						LD_FA_3,
						EI_FB,
						ILLEGAL_FC_FC,
						ILLEGAL_FD_FD,
						CP_FE_0,
						WAIT_CP_FE_0,
						CP_FE_1,
						RST_FF_0,
						WAIT_RST_FF_0,
						RST_FF_1,
						WAIT_RST_FF_1,
						RST_FF_2,
						WAIT_RST_FF_2,
						RST_FF_3,
						RLC_00,
						RLC_01,
						RLC_02,
						RLC_03,
						RLC_04,
						RLC_05,
						RLC_06_0,
						WAIT_RLC_06_0,
						RLC_06_1,
						WAIT_RLC_06_1,
						RLC_06_2,
						RLC_07,
						RRC_08,
						RRC_09,
						RRC_0A,
						RRC_0B,
						RRC_0C,
						RRC_0D,
						RRC_0E_0,
						WAIT_RRC_0E_0,
						RRC_0E_1,
						WAIT_RRC_0E_1,
						RRC_0E_2,
						RRC_0F,
						RL_10,
						RL_11,
						RL_12,
						RL_13,
						RL_14,
						RL_15,
						RL_16_0,
						WAIT_RL_16_0,
						RL_16_1,
						WAIT_RL_16_1,
						RL_16_2,
						RL_17,
						RR_18,
						RR_19,
						RR_1A,
						RR_1B,
						RR_1C,
						RR_1D,
						RR_1E_0,
						WAIT_RR_1E_0,
						RR_1E_1,
						WAIT_RR_1E_1,
						RR_1E_2,
						RR_1F,
						SLA_20,
						SLA_21,
						SLA_22,
						SLA_23,
						SLA_24,
						SLA_25,
						SLA_26_0,
						WAIT_SLA_26_0,
						SLA_26_1,
						WAIT_SLA_26_1,
						SLA_26_2,
						SLA_27,
						SRA_28,
						SRA_29,
						SRA_2A,
						SRA_2B,
						SRA_2C,
						SRA_2D,
						SRA_2E_0,
						WAIT_SRA_2E_0,
						SRA_2E_1,
						WAIT_SRA_2E_1,
						SRA_2E_2,
						SRA_2F,
						SWAP_30,
						SWAP_31,
						SWAP_32,
						SWAP_33,
						SWAP_34,
						SWAP_35,
						SWAP_36_0,
						WAIT_SWAP_36_0,
						SWAP_36_1,
						WAIT_SWAP_36_1,
						SWAP_36_2,
						SWAP_37,
						SRL_38,
						SRL_39,
						SRL_3A,
						SRL_3B,
						SRL_3C,
						SRL_3D,
						SRL_3E_0,
						WAIT_SRL_3E_0,
						SRL_3E_1,
						WAIT_SRL_3E_1,
						SRL_3E_2,
						SRL_3F,
						BIT_40,
						BIT_41,
						BIT_42,
						BIT_43,
						BIT_44,
						BIT_45,
						BIT_46_0,
						WAIT_BIT_46_0,
						BIT_46_1,
						BIT_47,
						BIT_48,
						BIT_49,
						BIT_4A,
						BIT_4B,
						BIT_4C,
						BIT_4D,
						BIT_4E_0,
						WAIT_BIT_4E_0,
						BIT_4E_1,
						BIT_4F,
						BIT_50,
						BIT_51,
						BIT_52,
						BIT_53,
						BIT_54,
						BIT_55,
						BIT_56_0,
						WAIT_BIT_56_0,
						BIT_56_1,
						BIT_57,
						BIT_58,
						BIT_59,
						BIT_5A,
						BIT_5B,
						BIT_5C,
						BIT_5D,
						BIT_5E_0,
						WAIT_BIT_5E_0,
						BIT_5E_1,
						BIT_5F,
						BIT_60,
						BIT_61,
						BIT_62,
						BIT_63,
						BIT_64,
						BIT_65,
						BIT_66_0,
						WAIT_BIT_66_0,
						BIT_66_1,
						BIT_67,
						BIT_68,
						BIT_69,
						BIT_6A,
						BIT_6B,
						BIT_6C,
						BIT_6D,
						BIT_6E_0,
						WAIT_BIT_6E_0,
						BIT_6E_1,
						BIT_6F,
						BIT_70,
						BIT_71,
						BIT_72,
						BIT_73,
						BIT_74,
						BIT_75,
						BIT_76_0,
						WAIT_BIT_76_0,
						BIT_76_1,
						BIT_77,
						BIT_78,
						BIT_79,
						BIT_7A,
						BIT_7B,
						BIT_7C,
						BIT_7D,
						BIT_7E_0,
						WAIT_BIT_7E_0,
						BIT_7E_1,
						BIT_7F,
						RES_80,
						RES_81,
						RES_82,
						RES_83,
						RES_84,
						RES_85,
						RES_86_0,
						WAIT_RES_86_0,
						RES_86_1,
						WAIT_RES_86_1,
						RES_86_2,
						RES_87,
						RES_88,
						RES_89,
						RES_8A,
						RES_8B,
						RES_8C,
						RES_8D,
						RES_8E_0,
						WAIT_RES_8E_0,
						RES_8E_1,
						WAIT_RES_8E_1,
						RES_8E_2,
						RES_8F,
						RES_90,
						RES_91,
						RES_92,
						RES_93,
						RES_94,
						RES_95,
						RES_96_0,
						WAIT_RES_96_0,
						RES_96_1,
						WAIT_RES_96_1,
						RES_96_2,
						RES_97,
						RES_98,
						RES_99,
						RES_9A,
						RES_9B,
						RES_9C,
						RES_9D,
						RES_9E_0,
						WAIT_RES_9E_0,
						RES_9E_1,
						WAIT_RES_9E_1,
						RES_9E_2,
						RES_9F,
						RES_A0,
						RES_A1,
						RES_A2,
						RES_A3,
						RES_A4,
						RES_A5,
						RES_A6_0,
						WAIT_RES_A6_0,
						RES_A6_1,
						WAIT_RES_A6_1,
						RES_A6_2,
						RES_A7,
						RES_A8,
						RES_A9,
						RES_AA,
						RES_AB,
						RES_AC,
						RES_AD,
						RES_AE_0,
						WAIT_RES_AE_0,
						RES_AE_1,
						WAIT_RES_AE_1,
						RES_AE_2,
						RES_AF,
						RES_B0,
						RES_B1,
						RES_B2,
						RES_B3,
						RES_B4,
						RES_B5,
						RES_B6_0,
						WAIT_RES_B6_0,
						RES_B6_1,
						WAIT_RES_B6_1,
						RES_B6_2,
						RES_B7,
						RES_B8,
						RES_B9,
						RES_BA,
						RES_BB,
						RES_BC,
						RES_BD,
						RES_BE_0,
						WAIT_RES_BE_0,
						RES_BE_1,
						WAIT_RES_BE_1,
						RES_BE_2,
						RES_BF,
						SET_C0,
						SET_C1,
						SET_C2,
						SET_C3,
						SET_C4,
						SET_C5,
						SET_C6_0,
						WAIT_SET_C6_0,
						SET_C6_1,
						WAIT_SET_C6_1,
						SET_C6_2,
						SET_C7,
						SET_C8,
						SET_C9,
						SET_CA,
						SET_CB,
						SET_CC,
						SET_CD,
						SET_CE_0,
						WAIT_SET_CE_0,
						SET_CE_1,
						WAIT_SET_CE_1,
						SET_CE_2,
						SET_CF,
						SET_D0,
						SET_D1,
						SET_D2,
						SET_D3,
						SET_D4,
						SET_D5,
						SET_D6_0,
						WAIT_SET_D6_0,
						SET_D6_1,
						WAIT_SET_D6_1,
						SET_D6_2,
						SET_D7,
						SET_D8,
						SET_D9,
						SET_DA,
						SET_DB,
						SET_DC,
						SET_DD,
						SET_DE_0,
						WAIT_SET_DE_0,
						SET_DE_1,
						WAIT_SET_DE_1,
						SET_DE_2,
						SET_DF,
						SET_E0,
						SET_E1,
						SET_E2,
						SET_E3,
						SET_E4,
						SET_E5,
						SET_E6_0,
						WAIT_SET_E6_0,
						SET_E6_1,
						WAIT_SET_E6_1,
						SET_E6_2,
						SET_E7,
						SET_E8,
						SET_E9,
						SET_EA,
						SET_EB,
						SET_EC,
						SET_ED,
						SET_EE_0,
						WAIT_SET_EE_0,
						SET_EE_1,
						WAIT_SET_EE_1,
						SET_EE_2,
						SET_EF,
						SET_F0,
						SET_F1,
						SET_F2,
						SET_F3,
						SET_F4,
						SET_F5,
						SET_F6_0,
						WAIT_SET_F6_0,
						SET_F6_1,
						WAIT_SET_F6_1,
						SET_F6_2,
						SET_F7,
						SET_F8,
						SET_F9,
						SET_FA,
						SET_FB,
						SET_FC,
						SET_FD,
						SET_FE_0,
						WAIT_SET_FE_0,
						SET_FE_1,
						WAIT_SET_FE_1,
						SET_FE_2,
						SET_FF
				 	}   State, Next_state;   // Internal state logic


// debug 
reg [24*8-1:0] opcode_str, cb_opcode_str;
opcode_string opcode_to_string (.current_op(OR), .opcode_str(opcode_str), .cb_opcode_str(cb_opcode_str));


always_ff @ (posedge clock)
begin
	if (reset)
		State <= RESET;
	else 
		State <= Next_state;
end


always_comb
begin 
	// Assign next state
	Next_state = State;
	unique case (State)
		FETCH : begin
			case (data_in)
				8'h00 : Next_state = NOP_00;
				8'h01 : Next_state = LD_01_0;
				8'h02 : Next_state = LD_02_0;
				8'h03 : Next_state = INC_03_0;
				8'h04 : Next_state = INC_04;
				8'h05 : Next_state = DEC_05;
				8'h06 : Next_state = LD_06_0;
				8'h07 : Next_state = RLCA_07;
				8'h08 : Next_state = LD_08_0;
				8'h09 : Next_state = ADD_09_0;
				8'h0A : Next_state = LD_0A_0;
				8'h0B : Next_state = DEC_0B_0;
				8'h0C : Next_state = INC_0C;
				8'h0D : Next_state = DEC_0D;
				8'h0E : Next_state = LD_0E_0;
				8'h0F : Next_state = RRCA_0F;
				8'h10 : Next_state = STOP_10;
				8'h11 : Next_state = LD_11_0;
				8'h12 : Next_state = LD_12_0;
				8'h13 : Next_state = INC_13_0;
				8'h14 : Next_state = INC_14;
				8'h15 : Next_state = DEC_15;
				8'h16 : Next_state = LD_16_0;
				8'h17 : Next_state = RLA_17;
				8'h18 : Next_state = JR_18_0;
				8'h19 : Next_state = ADD_19_0;
				8'h1A : Next_state = LD_1A_0;
				8'h1B : Next_state = DEC_1B_0;
				8'h1C : Next_state = INC_1C;
				8'h1D : Next_state = DEC_1D;
				8'h1E : Next_state = LD_1E_0;
				8'h1F : Next_state = RRA_1F;
				8'h20 : Next_state = JR_20_0;
				8'h21 : Next_state = LD_21_0;
				8'h22 : Next_state = LD_22_0;
				8'h23 : Next_state = INC_23_0;
				8'h24 : Next_state = INC_24;
				8'h25 : Next_state = DEC_25;
				8'h26 : Next_state = LD_26_0;
				8'h27 : Next_state = DAA_27;
				8'h28 : Next_state = JR_28_0;
				8'h29 : Next_state = ADD_29_0;
				8'h2A : Next_state = LD_2A_0;
				8'h2B : Next_state = DEC_2B_0;
				8'h2C : Next_state = INC_2C;
				8'h2D : Next_state = DEC_2D;
				8'h2E : Next_state = LD_2E_0;
				8'h2F : Next_state = CPL_2F;
				8'h30 : Next_state = JR_30_0;
				8'h31 : Next_state = LD_31_0;
				8'h32 : Next_state = LD_32_0;
				8'h33 : Next_state = INC_33_0;
				8'h34 : Next_state = INC_34_0;
				8'h35 : Next_state = DEC_35_0;
				8'h36 : Next_state = LD_36_0;
				8'h37 : Next_state = SCF_37;
				8'h38 : Next_state = JR_38_0;
				8'h39 : Next_state = ADD_39_0;
				8'h3A : Next_state = LD_3A_0;
				8'h3B : Next_state = DEC_3B_0;
				8'h3C : Next_state = INC_3C;
				8'h3D : Next_state = DEC_3D;
				8'h3E : Next_state = LD_3E_0;
				8'h3F : Next_state = CCF_3F;
				8'h40 : Next_state = LD_40;
				8'h41 : Next_state = LD_41;
				8'h42 : Next_state = LD_42;
				8'h43 : Next_state = LD_43;
				8'h44 : Next_state = LD_44;
				8'h45 : Next_state = LD_45;
				8'h46 : Next_state = LD_46_0;
				8'h47 : Next_state = LD_47;
				8'h48 : Next_state = LD_48;
				8'h49 : Next_state = LD_49;
				8'h4A : Next_state = LD_4A;
				8'h4B : Next_state = LD_4B;
				8'h4C : Next_state = LD_4C;
				8'h4D : Next_state = LD_4D;
				8'h4E : Next_state = LD_4E_0;
				8'h4F : Next_state = LD_4F;
				8'h50 : Next_state = LD_50;
				8'h51 : Next_state = LD_51;
				8'h52 : Next_state = LD_52;
				8'h53 : Next_state = LD_53;
				8'h54 : Next_state = LD_54;
				8'h55 : Next_state = LD_55;
				8'h56 : Next_state = LD_56_0;
				8'h57 : Next_state = LD_57;
				8'h58 : Next_state = LD_58;
				8'h59 : Next_state = LD_59;
				8'h5A : Next_state = LD_5A;
				8'h5B : Next_state = LD_5B;
				8'h5C : Next_state = LD_5C;
				8'h5D : Next_state = LD_5D;
				8'h5E : Next_state = LD_5E_0;
				8'h5F : Next_state = LD_5F;
				8'h60 : Next_state = LD_60;
				8'h61 : Next_state = LD_61;
				8'h62 : Next_state = LD_62;
				8'h63 : Next_state = LD_63;
				8'h64 : Next_state = LD_64;
				8'h65 : Next_state = LD_65;
				8'h66 : Next_state = LD_66_0;
				8'h67 : Next_state = LD_67;
				8'h68 : Next_state = LD_68;
				8'h69 : Next_state = LD_69;
				8'h6A : Next_state = LD_6A;
				8'h6B : Next_state = LD_6B;
				8'h6C : Next_state = LD_6C;
				8'h6D : Next_state = LD_6D;
				8'h6E : Next_state = LD_6E_0;
				8'h6F : Next_state = LD_6F;
				8'h70 : Next_state = LD_70_0;
				8'h71 : Next_state = LD_71_0;
				8'h72 : Next_state = LD_72_0;
				8'h73 : Next_state = LD_73_0;
				8'h74 : Next_state = LD_74_0;
				8'h75 : Next_state = LD_75_0;
				8'h76 : Next_state = HALT_76;
				8'h77 : Next_state = LD_77_0;
				8'h78 : Next_state = LD_78;
				8'h79 : Next_state = LD_79;
				8'h7A : Next_state = LD_7A;
				8'h7B : Next_state = LD_7B;
				8'h7C : Next_state = LD_7C;
				8'h7D : Next_state = LD_7D;
				8'h7E : Next_state = LD_7E_0;
				8'h7F : Next_state = LD_7F;
				8'h80 : Next_state = ADD_80;
				8'h81 : Next_state = ADD_81;
				8'h82 : Next_state = ADD_82;
				8'h83 : Next_state = ADD_83;
				8'h84 : Next_state = ADD_84;
				8'h85 : Next_state = ADD_85;
				8'h86 : Next_state = ADD_86_0;
				8'h87 : Next_state = ADD_87;
				8'h88 : Next_state = ADC_88;
				8'h89 : Next_state = ADC_89;
				8'h8A : Next_state = ADC_8A;
				8'h8B : Next_state = ADC_8B;
				8'h8C : Next_state = ADC_8C;
				8'h8D : Next_state = ADC_8D;
				8'h8E : Next_state = ADC_8E_0;
				8'h8F : Next_state = ADC_8F;
				8'h90 : Next_state = SUB_90;
				8'h91 : Next_state = SUB_91;
				8'h92 : Next_state = SUB_92;
				8'h93 : Next_state = SUB_93;
				8'h94 : Next_state = SUB_94;
				8'h95 : Next_state = SUB_95;
				8'h96 : Next_state = SUB_96_0;
				8'h97 : Next_state = SUB_97;
				8'h98 : Next_state = SBC_98;
				8'h99 : Next_state = SBC_99;
				8'h9A : Next_state = SBC_9A;
				8'h9B : Next_state = SBC_9B;
				8'h9C : Next_state = SBC_9C;
				8'h9D : Next_state = SBC_9D;
				8'h9E : Next_state = SBC_9E_0;
				8'h9F : Next_state = SBC_9F;
				8'hA0 : Next_state = AND_A0;
				8'hA1 : Next_state = AND_A1;
				8'hA2 : Next_state = AND_A2;
				8'hA3 : Next_state = AND_A3;
				8'hA4 : Next_state = AND_A4;
				8'hA5 : Next_state = AND_A5;
				8'hA6 : Next_state = AND_A6_0;
				8'hA7 : Next_state = AND_A7;
				8'hA8 : Next_state = XOR_A8;
				8'hA9 : Next_state = XOR_A9;
				8'hAA : Next_state = XOR_AA;
				8'hAB : Next_state = XOR_AB;
				8'hAC : Next_state = XOR_AC;
				8'hAD : Next_state = XOR_AD;
				8'hAE : Next_state = XOR_AE_0;
				8'hAF : Next_state = XOR_AF;
				8'hB0 : Next_state = OR_B0;
				8'hB1 : Next_state = OR_B1;
				8'hB2 : Next_state = OR_B2;
				8'hB3 : Next_state = OR_B3;
				8'hB4 : Next_state = OR_B4;
				8'hB5 : Next_state = OR_B5;
				8'hB6 : Next_state = OR_B6_0;
				8'hB7 : Next_state = OR_B7;
				8'hB8 : Next_state = CP_B8;
				8'hB9 : Next_state = CP_B9;
				8'hBA : Next_state = CP_BA;
				8'hBB : Next_state = CP_BB;
				8'hBC : Next_state = CP_BC;
				8'hBD : Next_state = CP_BD;
				8'hBE : Next_state = CP_BE_0;
				8'hBF : Next_state = CP_BF;
				8'hC0 : Next_state = RET_C0_0;
				8'hC1 : Next_state = POP_C1_0;
				8'hC2 : Next_state = JP_C2_0;
				8'hC3 : Next_state = JP_C3_0;
				8'hC4 : Next_state = CALL_C4_0;
				8'hC5 : Next_state = PUSH_C5_0;
				8'hC6 : Next_state = ADD_C6_0;
				8'hC7 : Next_state = RST_C7_0;
				8'hC8 : Next_state = RET_C8_0;
				8'hC9 : Next_state = RET_C9_0;
				8'hCA : Next_state = JP_CA_0;
				8'hCB : Next_state = WAIT_PREFIX_CB;
				8'hCC : Next_state = CALL_CC_0;
				8'hCD : Next_state = CALL_CD_0;
				8'hCE : Next_state = ADC_CE_0;
				8'hCF : Next_state = RST_CF_0;
				8'hD0 : Next_state = RET_D0_0;
				8'hD1 : Next_state = POP_D1_0;
				8'hD2 : Next_state = JP_D2_0;
				8'hD3 : Next_state = ILLEGAL_D3_D3;
				8'hD4 : Next_state = CALL_D4_0;
				8'hD5 : Next_state = PUSH_D5_0;
				8'hD6 : Next_state = SUB_D6_0;
				8'hD7 : Next_state = RST_D7_0;
				8'hD8 : Next_state = RET_D8_0;
				8'hD9 : Next_state = RETI_D9_0;
				8'hDA : Next_state = JP_DA_0;
				8'hDB : Next_state = ILLEGAL_DB_DB;
				8'hDC : Next_state = CALL_DC_0;
				8'hDD : Next_state = ILLEGAL_DD_DD;
				8'hDE : Next_state = SBC_DE_0;
				8'hDF : Next_state = RST_DF_0;
				8'hE0 : Next_state = LDH_E0_0;
				8'hE1 : Next_state = POP_E1_0;
				8'hE2 : Next_state = LD_E2_0;
				8'hE3 : Next_state = ILLEGAL_E3_E3;
				8'hE4 : Next_state = ILLEGAL_E4_E4;
				8'hE5 : Next_state = PUSH_E5_0;
				8'hE6 : Next_state = AND_E6_0;
				8'hE7 : Next_state = RST_E7_0;
				8'hE8 : Next_state = ADD_E8_0;
				8'hE9 : Next_state = JP_E9;
				8'hEA : Next_state = LD_EA_0;
				8'hEB : Next_state = ILLEGAL_EB_EB;
				8'hEC : Next_state = ILLEGAL_EC_EC;
				8'hED : Next_state = ILLEGAL_ED_ED;
				8'hEE : Next_state = XOR_EE_0;
				8'hEF : Next_state = RST_EF_0;
				8'hF0 : Next_state = LDH_F0_0;
				8'hF1 : Next_state = POP_F1_0;
				8'hF2 : Next_state = LD_F2_0;
				8'hF3 : Next_state = DI_F3;
				8'hF4 : Next_state = ILLEGAL_F4_F4;
				8'hF5 : Next_state = PUSH_F5_0;
				8'hF6 : Next_state = OR_F6_0;
				8'hF7 : Next_state = RST_F7_0;
				8'hF8 : Next_state = LD_F8_0;
				8'hF9 : Next_state = LD_F9_0;
				8'hFA : Next_state = LD_FA_0;
				8'hFB : Next_state = EI_FB;
				8'hFC : Next_state = ILLEGAL_FC_FC;
				8'hFD : Next_state = ILLEGAL_FD_FD;
				8'hFE : Next_state = CP_FE_0;
				8'hFF : Next_state = RST_FF_0;
			endcase
		end
		WAIT_PREFIX_CB : Next_state = PREFIX_CB;
		PREFIX_CB : begin
			case (data_in)
				8'h00 : Next_state = RLC_00;
				8'h01 : Next_state = RLC_01;
				8'h02 : Next_state = RLC_02;
				8'h03 : Next_state = RLC_03;
				8'h04 : Next_state = RLC_04;
				8'h05 : Next_state = RLC_05;
				8'h06 : Next_state = RLC_06_0;
				8'h07 : Next_state = RLC_07;
				8'h08 : Next_state = RRC_08;
				8'h09 : Next_state = RRC_09;
				8'h0A : Next_state = RRC_0A;
				8'h0B : Next_state = RRC_0B;
				8'h0C : Next_state = RRC_0C;
				8'h0D : Next_state = RRC_0D;
				8'h0E : Next_state = RRC_0E_0;
				8'h0F : Next_state = RRC_0F;
				8'h10 : Next_state = RL_10;
				8'h11 : Next_state = RL_11;
				8'h12 : Next_state = RL_12;
				8'h13 : Next_state = RL_13;
				8'h14 : Next_state = RL_14;
				8'h15 : Next_state = RL_15;
				8'h16 : Next_state = RL_16_0;
				8'h17 : Next_state = RL_17;
				8'h18 : Next_state = RR_18;
				8'h19 : Next_state = RR_19;
				8'h1A : Next_state = RR_1A;
				8'h1B : Next_state = RR_1B;
				8'h1C : Next_state = RR_1C;
				8'h1D : Next_state = RR_1D;
				8'h1E : Next_state = RR_1E_0;
				8'h1F : Next_state = RR_1F;
				8'h20 : Next_state = SLA_20;
				8'h21 : Next_state = SLA_21;
				8'h22 : Next_state = SLA_22;
				8'h23 : Next_state = SLA_23;
				8'h24 : Next_state = SLA_24;
				8'h25 : Next_state = SLA_25;
				8'h26 : Next_state = SLA_26_0;
				8'h27 : Next_state = SLA_27;
				8'h28 : Next_state = SRA_28;
				8'h29 : Next_state = SRA_29;
				8'h2A : Next_state = SRA_2A;
				8'h2B : Next_state = SRA_2B;
				8'h2C : Next_state = SRA_2C;
				8'h2D : Next_state = SRA_2D;
				8'h2E : Next_state = SRA_2E_0;
				8'h2F : Next_state = SRA_2F;
				8'h30 : Next_state = SWAP_30;
				8'h31 : Next_state = SWAP_31;
				8'h32 : Next_state = SWAP_32;
				8'h33 : Next_state = SWAP_33;
				8'h34 : Next_state = SWAP_34;
				8'h35 : Next_state = SWAP_35;
				8'h36 : Next_state = SWAP_36_0;
				8'h37 : Next_state = SWAP_37;
				8'h38 : Next_state = SRL_38;
				8'h39 : Next_state = SRL_39;
				8'h3A : Next_state = SRL_3A;
				8'h3B : Next_state = SRL_3B;
				8'h3C : Next_state = SRL_3C;
				8'h3D : Next_state = SRL_3D;
				8'h3E : Next_state = SRL_3E_0;
				8'h3F : Next_state = SRL_3F;
				8'h40 : Next_state = BIT_40;
				8'h41 : Next_state = BIT_41;
				8'h42 : Next_state = BIT_42;
				8'h43 : Next_state = BIT_43;
				8'h44 : Next_state = BIT_44;
				8'h45 : Next_state = BIT_45;
				8'h46 : Next_state = BIT_46_0;
				8'h47 : Next_state = BIT_47;
				8'h48 : Next_state = BIT_48;
				8'h49 : Next_state = BIT_49;
				8'h4A : Next_state = BIT_4A;
				8'h4B : Next_state = BIT_4B;
				8'h4C : Next_state = BIT_4C;
				8'h4D : Next_state = BIT_4D;
				8'h4E : Next_state = BIT_4E_0;
				8'h4F : Next_state = BIT_4F;
				8'h50 : Next_state = BIT_50;
				8'h51 : Next_state = BIT_51;
				8'h52 : Next_state = BIT_52;
				8'h53 : Next_state = BIT_53;
				8'h54 : Next_state = BIT_54;
				8'h55 : Next_state = BIT_55;
				8'h56 : Next_state = BIT_56_0;
				8'h57 : Next_state = BIT_57;
				8'h58 : Next_state = BIT_58;
				8'h59 : Next_state = BIT_59;
				8'h5A : Next_state = BIT_5A;
				8'h5B : Next_state = BIT_5B;
				8'h5C : Next_state = BIT_5C;
				8'h5D : Next_state = BIT_5D;
				8'h5E : Next_state = BIT_5E_0;
				8'h5F : Next_state = BIT_5F;
				8'h60 : Next_state = BIT_60;
				8'h61 : Next_state = BIT_61;
				8'h62 : Next_state = BIT_62;
				8'h63 : Next_state = BIT_63;
				8'h64 : Next_state = BIT_64;
				8'h65 : Next_state = BIT_65;
				8'h66 : Next_state = BIT_66_0;
				8'h67 : Next_state = BIT_67;
				8'h68 : Next_state = BIT_68;
				8'h69 : Next_state = BIT_69;
				8'h6A : Next_state = BIT_6A;
				8'h6B : Next_state = BIT_6B;
				8'h6C : Next_state = BIT_6C;
				8'h6D : Next_state = BIT_6D;
				8'h6E : Next_state = BIT_6E_0;
				8'h6F : Next_state = BIT_6F;
				8'h70 : Next_state = BIT_70;
				8'h71 : Next_state = BIT_71;
				8'h72 : Next_state = BIT_72;
				8'h73 : Next_state = BIT_73;
				8'h74 : Next_state = BIT_74;
				8'h75 : Next_state = BIT_75;
				8'h76 : Next_state = BIT_76_0;
				8'h77 : Next_state = BIT_77;
				8'h78 : Next_state = BIT_78;
				8'h79 : Next_state = BIT_79;
				8'h7A : Next_state = BIT_7A;
				8'h7B : Next_state = BIT_7B;
				8'h7C : Next_state = BIT_7C;
				8'h7D : Next_state = BIT_7D;
				8'h7E : Next_state = BIT_7E_0;
				8'h7F : Next_state = BIT_7F;
				8'h80 : Next_state = RES_80;
				8'h81 : Next_state = RES_81;
				8'h82 : Next_state = RES_82;
				8'h83 : Next_state = RES_83;
				8'h84 : Next_state = RES_84;
				8'h85 : Next_state = RES_85;
				8'h86 : Next_state = RES_86_0;
				8'h87 : Next_state = RES_87;
				8'h88 : Next_state = RES_88;
				8'h89 : Next_state = RES_89;
				8'h8A : Next_state = RES_8A;
				8'h8B : Next_state = RES_8B;
				8'h8C : Next_state = RES_8C;
				8'h8D : Next_state = RES_8D;
				8'h8E : Next_state = RES_8E_0;
				8'h8F : Next_state = RES_8F;
				8'h90 : Next_state = RES_90;
				8'h91 : Next_state = RES_91;
				8'h92 : Next_state = RES_92;
				8'h93 : Next_state = RES_93;
				8'h94 : Next_state = RES_94;
				8'h95 : Next_state = RES_95;
				8'h96 : Next_state = RES_96_0;
				8'h97 : Next_state = RES_97;
				8'h98 : Next_state = RES_98;
				8'h99 : Next_state = RES_99;
				8'h9A : Next_state = RES_9A;
				8'h9B : Next_state = RES_9B;
				8'h9C : Next_state = RES_9C;
				8'h9D : Next_state = RES_9D;
				8'h9E : Next_state = RES_9E_0;
				8'h9F : Next_state = RES_9F;
				8'hA0 : Next_state = RES_A0;
				8'hA1 : Next_state = RES_A1;
				8'hA2 : Next_state = RES_A2;
				8'hA3 : Next_state = RES_A3;
				8'hA4 : Next_state = RES_A4;
				8'hA5 : Next_state = RES_A5;
				8'hA6 : Next_state = RES_A6_0;
				8'hA7 : Next_state = RES_A7;
				8'hA8 : Next_state = RES_A8;
				8'hA9 : Next_state = RES_A9;
				8'hAA : Next_state = RES_AA;
				8'hAB : Next_state = RES_AB;
				8'hAC : Next_state = RES_AC;
				8'hAD : Next_state = RES_AD;
				8'hAE : Next_state = RES_AE_0;
				8'hAF : Next_state = RES_AF;
				8'hB0 : Next_state = RES_B0;
				8'hB1 : Next_state = RES_B1;
				8'hB2 : Next_state = RES_B2;
				8'hB3 : Next_state = RES_B3;
				8'hB4 : Next_state = RES_B4;
				8'hB5 : Next_state = RES_B5;
				8'hB6 : Next_state = RES_B6_0;
				8'hB7 : Next_state = RES_B7;
				8'hB8 : Next_state = RES_B8;
				8'hB9 : Next_state = RES_B9;
				8'hBA : Next_state = RES_BA;
				8'hBB : Next_state = RES_BB;
				8'hBC : Next_state = RES_BC;
				8'hBD : Next_state = RES_BD;
				8'hBE : Next_state = RES_BE_0;
				8'hBF : Next_state = RES_BF;
				8'hC0 : Next_state = SET_C0;
				8'hC1 : Next_state = SET_C1;
				8'hC2 : Next_state = SET_C2;
				8'hC3 : Next_state = SET_C3;
				8'hC4 : Next_state = SET_C4;
				8'hC5 : Next_state = SET_C5;
				8'hC6 : Next_state = SET_C6_0;
				8'hC7 : Next_state = SET_C7;
				8'hC8 : Next_state = SET_C8;
				8'hC9 : Next_state = SET_C9;
				8'hCA : Next_state = SET_CA;
				8'hCB : Next_state = SET_CB;
				8'hCC : Next_state = SET_CC;
				8'hCD : Next_state = SET_CD;
				8'hCE : Next_state = SET_CE_0;
				8'hCF : Next_state = SET_CF;
				8'hD0 : Next_state = SET_D0;
				8'hD1 : Next_state = SET_D1;
				8'hD2 : Next_state = SET_D2;
				8'hD3 : Next_state = SET_D3;
				8'hD4 : Next_state = SET_D4;
				8'hD5 : Next_state = SET_D5;
				8'hD6 : Next_state = SET_D6_0;
				8'hD7 : Next_state = SET_D7;
				8'hD8 : Next_state = SET_D8;
				8'hD9 : Next_state = SET_D9;
				8'hDA : Next_state = SET_DA;
				8'hDB : Next_state = SET_DB;
				8'hDC : Next_state = SET_DC;
				8'hDD : Next_state = SET_DD;
				8'hDE : Next_state = SET_DE_0;
				8'hDF : Next_state = SET_DF;
				8'hE0 : Next_state = SET_E0;
				8'hE1 : Next_state = SET_E1;
				8'hE2 : Next_state = SET_E2;
				8'hE3 : Next_state = SET_E3;
				8'hE4 : Next_state = SET_E4;
				8'hE5 : Next_state = SET_E5;
				8'hE6 : Next_state = SET_E6_0;
				8'hE7 : Next_state = SET_E7;
				8'hE8 : Next_state = SET_E8;
				8'hE9 : Next_state = SET_E9;
				8'hEA : Next_state = SET_EA;
				8'hEB : Next_state = SET_EB;
				8'hEC : Next_state = SET_EC;
				8'hED : Next_state = SET_ED;
				8'hEE : Next_state = SET_EE_0;
				8'hEF : Next_state = SET_EF;
				8'hF0 : Next_state = SET_F0;
				8'hF1 : Next_state = SET_F1;
				8'hF2 : Next_state = SET_F2;
				8'hF3 : Next_state = SET_F3;
				8'hF4 : Next_state = SET_F4;
				8'hF5 : Next_state = SET_F5;
				8'hF6 : Next_state = SET_F6_0;
				8'hF7 : Next_state = SET_F7;
				8'hF8 : Next_state = SET_F8;
				8'hF9 : Next_state = SET_F9;
				8'hFA : Next_state = SET_FA;
				8'hFB : Next_state = SET_FB;
				8'hFC : Next_state = SET_FC;
				8'hFD : Next_state = SET_FD;
				8'hFE : Next_state = SET_FE_0;
				8'hFF : Next_state = SET_FF;
			endcase
		end
		LD_01_0          : Next_state = WAIT_LD_01_0;
		WAIT_LD_01_0     : Next_state = LD_01_1;
		LD_01_1          : Next_state = WAIT_LD_01_1;
		WAIT_LD_01_1     : Next_state = LD_01_2;
		LD_02_0          : Next_state = WAIT_LD_02_0;
		WAIT_LD_02_0     : Next_state = LD_02_1;
		INC_03_0         : Next_state = WAIT_INC_03_0;
		WAIT_INC_03_0    : Next_state = INC_03_1;
		LD_06_0          : Next_state = WAIT_LD_06_0;
		WAIT_LD_06_0     : Next_state = LD_06_1;
		LD_08_0          : Next_state = WAIT_LD_08_0;
		WAIT_LD_08_0     : Next_state = LD_08_1;
		LD_08_1          : Next_state = WAIT_LD_08_1;
		WAIT_LD_08_1     : Next_state = LD_08_2;
		LD_08_2          : Next_state = WAIT_LD_08_2;
		WAIT_LD_08_2     : Next_state = LD_08_3;
		LD_08_3          : Next_state = WAIT_LD_08_3;
		WAIT_LD_08_3     : Next_state = LD_08_4;
		ADD_09_0         : Next_state = WAIT_ADD_09_0;
		WAIT_ADD_09_0    : Next_state = ADD_09_1;
		LD_0A_0          : Next_state = WAIT_LD_0A_0;
		WAIT_LD_0A_0     : Next_state = LD_0A_1;
		DEC_0B_0         : Next_state = WAIT_DEC_0B_0;
		WAIT_DEC_0B_0    : Next_state = DEC_0B_1;
		LD_0E_0          : Next_state = WAIT_LD_0E_0;
		WAIT_LD_0E_0     : Next_state = LD_0E_1;
		LD_11_0          : Next_state = WAIT_LD_11_0;
		WAIT_LD_11_0     : Next_state = LD_11_1;
		LD_11_1          : Next_state = WAIT_LD_11_1;
		WAIT_LD_11_1     : Next_state = LD_11_2;
		LD_12_0          : Next_state = WAIT_LD_12_0;
		WAIT_LD_12_0     : Next_state = LD_12_1;
		INC_13_0         : Next_state = WAIT_INC_13_0;
		WAIT_INC_13_0    : Next_state = INC_13_1;
		LD_16_0          : Next_state = WAIT_LD_16_0;
		WAIT_LD_16_0     : Next_state = LD_16_1;
		JR_18_0          : Next_state = WAIT_JR_18_0;
		WAIT_JR_18_0     : Next_state = JR_18_1;
		JR_18_1          : Next_state = WAIT_JR_18_1;
		WAIT_JR_18_1     : Next_state = JR_18_2;
		ADD_19_0         : Next_state = WAIT_ADD_19_0;
		WAIT_ADD_19_0    : Next_state = ADD_19_1;
		LD_1A_0          : Next_state = WAIT_LD_1A_0;
		WAIT_LD_1A_0     : Next_state = LD_1A_1;
		DEC_1B_0         : Next_state = WAIT_DEC_1B_0;
		WAIT_DEC_1B_0    : Next_state = DEC_1B_1;
		LD_1E_0          : Next_state = WAIT_LD_1E_0;
		WAIT_LD_1E_0     : Next_state = LD_1E_1;
		JR_20_0          : Next_state = WAIT_JR_20_0;
		WAIT_JR_20_0     : Next_state = JR_20_1;
		JR_20_1          : begin if (Z_flag == 1'b0) Next_state = WAIT_JR_20_1; else Next_state = FETCH; end
		WAIT_JR_20_1     : Next_state = JR_20_2;
		LD_21_0          : Next_state = WAIT_LD_21_0;
		WAIT_LD_21_0     : Next_state = LD_21_1;
		LD_21_1          : Next_state = WAIT_LD_21_1;
		WAIT_LD_21_1     : Next_state = LD_21_2;
		LD_22_0          : Next_state = WAIT_LD_22_0;
		WAIT_LD_22_0     : Next_state = LD_22_1;
		INC_23_0         : Next_state = WAIT_INC_23_0;
		WAIT_INC_23_0    : Next_state = INC_23_1;
		LD_26_0          : Next_state = WAIT_LD_26_0;
		WAIT_LD_26_0     : Next_state = LD_26_1;
		JR_28_0          : Next_state = WAIT_JR_28_0;
		WAIT_JR_28_0     : Next_state = JR_28_1;
		JR_28_1          : Next_state = WAIT_JR_28_1;
		WAIT_JR_28_1     : Next_state = JR_28_2;
		ADD_29_0         : Next_state = WAIT_ADD_29_0;
		WAIT_ADD_29_0    : Next_state = ADD_29_1;
		LD_2A_0          : Next_state = WAIT_LD_2A_0;
		WAIT_LD_2A_0     : Next_state = LD_2A_1;
		DEC_2B_0         : Next_state = WAIT_DEC_2B_0;
		WAIT_DEC_2B_0    : Next_state = DEC_2B_1;
		LD_2E_0          : Next_state = WAIT_LD_2E_0;
		WAIT_LD_2E_0     : Next_state = LD_2E_1;
		JR_30_0          : Next_state = WAIT_JR_30_0;
		WAIT_JR_30_0     : Next_state = JR_30_1;
		JR_30_1          : Next_state = WAIT_JR_30_1;
		WAIT_JR_30_1     : Next_state = JR_30_2;
		LD_31_0          : Next_state = WAIT_LD_31_0;
		WAIT_LD_31_0     : Next_state = LD_31_1;
		LD_31_1          : Next_state = WAIT_LD_31_1;
		WAIT_LD_31_1     : Next_state = LD_31_2;
		LD_32_0          : Next_state = WAIT_LD_32_0;
		WAIT_LD_32_0     : Next_state = LD_32_1;
		INC_33_0         : Next_state = WAIT_INC_33_0;
		WAIT_INC_33_0    : Next_state = INC_33_1;
		INC_34_0         : Next_state = WAIT_INC_34_0;
		WAIT_INC_34_0    : Next_state = INC_34_1;
		INC_34_1         : Next_state = WAIT_INC_34_1;
		WAIT_INC_34_1    : Next_state = INC_34_2;
		DEC_35_0         : Next_state = WAIT_DEC_35_0;
		WAIT_DEC_35_0    : Next_state = DEC_35_1;
		DEC_35_1         : Next_state = WAIT_DEC_35_1;
		WAIT_DEC_35_1    : Next_state = DEC_35_2;
		LD_36_0          : Next_state = WAIT_LD_36_0;
		WAIT_LD_36_0     : Next_state = LD_36_1;
		LD_36_1          : Next_state = WAIT_LD_36_1;
		WAIT_LD_36_1     : Next_state = LD_36_2;
		JR_38_0          : Next_state = WAIT_JR_38_0;
		WAIT_JR_38_0     : Next_state = JR_38_1;
		JR_38_1          : Next_state = WAIT_JR_38_1;
		WAIT_JR_38_1     : Next_state = JR_38_2;
		ADD_39_0         : Next_state = WAIT_ADD_39_0;
		WAIT_ADD_39_0    : Next_state = ADD_39_1;
		LD_3A_0          : Next_state = WAIT_LD_3A_0;
		WAIT_LD_3A_0     : Next_state = LD_3A_1;
		DEC_3B_0         : Next_state = WAIT_DEC_3B_0;
		WAIT_DEC_3B_0    : Next_state = DEC_3B_1;
		LD_3E_0          : Next_state = WAIT_LD_3E_0;
		WAIT_LD_3E_0     : Next_state = LD_3E_1;
		LD_46_0          : Next_state = WAIT_LD_46_0;
		WAIT_LD_46_0     : Next_state = LD_46_1;
		LD_4E_0          : Next_state = WAIT_LD_4E_0;
		WAIT_LD_4E_0     : Next_state = LD_4E_1;
		LD_56_0          : Next_state = WAIT_LD_56_0;
		WAIT_LD_56_0     : Next_state = LD_56_1;
		LD_5E_0          : Next_state = WAIT_LD_5E_0;
		WAIT_LD_5E_0     : Next_state = LD_5E_1;
		LD_66_0          : Next_state = WAIT_LD_66_0;
		WAIT_LD_66_0     : Next_state = LD_66_1;
		LD_6E_0          : Next_state = WAIT_LD_6E_0;
		WAIT_LD_6E_0     : Next_state = LD_6E_1;
		LD_70_0          : Next_state = WAIT_LD_70_0;
		WAIT_LD_70_0     : Next_state = LD_70_1;
		LD_71_0          : Next_state = WAIT_LD_71_0;
		WAIT_LD_71_0     : Next_state = LD_71_1;
		LD_72_0          : Next_state = WAIT_LD_72_0;
		WAIT_LD_72_0     : Next_state = LD_72_1;
		LD_73_0          : Next_state = WAIT_LD_73_0;
		WAIT_LD_73_0     : Next_state = LD_73_1;
		LD_74_0          : Next_state = WAIT_LD_74_0;
		WAIT_LD_74_0     : Next_state = LD_74_1;
		LD_75_0          : Next_state = WAIT_LD_75_0;
		WAIT_LD_75_0     : Next_state = LD_75_1;
		LD_77_0          : Next_state = WAIT_LD_77_0;
		WAIT_LD_77_0     : Next_state = LD_77_1;
		LD_7E_0          : Next_state = WAIT_LD_7E_0;
		WAIT_LD_7E_0     : Next_state = LD_7E_1;
		ADD_86_0         : Next_state = WAIT_ADD_86_0;
		WAIT_ADD_86_0    : Next_state = ADD_86_1;
		ADC_8E_0         : Next_state = WAIT_ADC_8E_0;
		WAIT_ADC_8E_0    : Next_state = ADC_8E_1;
		SUB_96_0         : Next_state = WAIT_SUB_96_0;
		WAIT_SUB_96_0    : Next_state = SUB_96_1;
		SBC_9E_0         : Next_state = WAIT_SBC_9E_0;
		WAIT_SBC_9E_0    : Next_state = SBC_9E_1;
		AND_A6_0         : Next_state = WAIT_AND_A6_0;
		WAIT_AND_A6_0    : Next_state = AND_A6_1;
		XOR_AE_0         : Next_state = WAIT_XOR_AE_0;
		WAIT_XOR_AE_0    : Next_state = XOR_AE_1;
		OR_B6_0          : Next_state = WAIT_OR_B6_0;
		WAIT_OR_B6_0     : Next_state = OR_B6_1;
		CP_BE_0          : Next_state = WAIT_CP_BE_0;
		WAIT_CP_BE_0     : Next_state = CP_BE_1;
		RET_C0_0         : Next_state = WAIT_RET_C0_0;
		WAIT_RET_C0_0    : Next_state = RET_C0_1;
		RET_C0_1         : Next_state = WAIT_RET_C0_1;
		WAIT_RET_C0_1    : Next_state = RET_C0_2;
		RET_C0_2         : Next_state = WAIT_RET_C0_2;
		WAIT_RET_C0_2    : Next_state = RET_C0_3;
		RET_C0_3         : Next_state = WAIT_RET_C0_3;
		WAIT_RET_C0_3    : Next_state = RET_C0_4;
		POP_C1_0         : Next_state = WAIT_POP_C1_0;
		WAIT_POP_C1_0    : Next_state = POP_C1_1;
		POP_C1_1         : Next_state = WAIT_POP_C1_1;
		WAIT_POP_C1_1    : Next_state = POP_C1_2;
		JP_C2_0          : Next_state = WAIT_JP_C2_0;
		WAIT_JP_C2_0     : Next_state = JP_C2_1;
		JP_C2_1          : Next_state = WAIT_JP_C2_1;
		WAIT_JP_C2_1     : Next_state = JP_C2_2;
		JP_C2_2          : Next_state = WAIT_JP_C2_2;
		WAIT_JP_C2_2     : Next_state = JP_C2_3;
		JP_C3_0          : Next_state = WAIT_JP_C3_0;
		WAIT_JP_C3_0     : Next_state = JP_C3_1;
		JP_C3_1          : Next_state = WAIT_JP_C3_1;
		WAIT_JP_C3_1     : Next_state = JP_C3_2;
		JP_C3_2          : Next_state = WAIT_JP_C3_2;
		WAIT_JP_C3_2     : Next_state = JP_C3_3;
		CALL_C4_0        : Next_state = WAIT_CALL_C4_0;
		WAIT_CALL_C4_0   : Next_state = CALL_C4_1;
		CALL_C4_1        : Next_state = WAIT_CALL_C4_1;
		WAIT_CALL_C4_1   : Next_state = CALL_C4_2;
		CALL_C4_2        : Next_state = WAIT_CALL_C4_2;
		WAIT_CALL_C4_2   : Next_state = CALL_C4_3;
		CALL_C4_3        : Next_state = WAIT_CALL_C4_3;
		WAIT_CALL_C4_3   : Next_state = CALL_C4_4;
		CALL_C4_4        : Next_state = WAIT_CALL_C4_4;
		WAIT_CALL_C4_4   : Next_state = CALL_C4_5;
		PUSH_C5_0        : Next_state = WAIT_PUSH_C5_0;
		WAIT_PUSH_C5_0   : Next_state = PUSH_C5_1;
		PUSH_C5_1        : Next_state = WAIT_PUSH_C5_1;
		WAIT_PUSH_C5_1   : Next_state = PUSH_C5_2;
		PUSH_C5_2        : Next_state = WAIT_PUSH_C5_2;
		WAIT_PUSH_C5_2   : Next_state = PUSH_C5_3;
		ADD_C6_0         : Next_state = WAIT_ADD_C6_0;
		WAIT_ADD_C6_0    : Next_state = ADD_C6_1;
		RST_C7_0         : Next_state = WAIT_RST_C7_0;
		WAIT_RST_C7_0    : Next_state = RST_C7_1;
		RST_C7_1         : Next_state = WAIT_RST_C7_1;
		WAIT_RST_C7_1    : Next_state = RST_C7_2;
		RST_C7_2         : Next_state = WAIT_RST_C7_2;
		WAIT_RST_C7_2    : Next_state = RST_C7_3;
		RET_C8_0         : Next_state = WAIT_RET_C8_0;
		WAIT_RET_C8_0    : Next_state = RET_C8_1;
		RET_C8_1         : Next_state = WAIT_RET_C8_1;
		WAIT_RET_C8_1    : Next_state = RET_C8_2;
		RET_C8_2         : Next_state = WAIT_RET_C8_2;
		WAIT_RET_C8_2    : Next_state = RET_C8_3;
		RET_C8_3         : Next_state = WAIT_RET_C8_3;
		WAIT_RET_C8_3    : Next_state = RET_C8_4;
		RET_C9_0         : Next_state = WAIT_RET_C9_0;
		WAIT_RET_C9_0    : Next_state = RET_C9_1;
		RET_C9_1         : Next_state = WAIT_RET_C9_1;
		WAIT_RET_C9_1    : Next_state = RET_C9_2;
		RET_C9_2         : Next_state = WAIT_RET_C9_2;
		WAIT_RET_C9_2    : Next_state = RET_C9_3;
		JP_CA_0          : Next_state = WAIT_JP_CA_0;
		WAIT_JP_CA_0     : Next_state = JP_CA_1;
		JP_CA_1          : Next_state = WAIT_JP_CA_1;
		WAIT_JP_CA_1     : Next_state = JP_CA_2;
		JP_CA_2          : Next_state = WAIT_JP_CA_2;
		WAIT_JP_CA_2     : Next_state = JP_CA_3;
		CALL_CC_0        : Next_state = WAIT_CALL_CC_0;
		WAIT_CALL_CC_0   : Next_state = CALL_CC_1;
		CALL_CC_1        : Next_state = WAIT_CALL_CC_1;
		WAIT_CALL_CC_1   : Next_state = CALL_CC_2;
		CALL_CC_2        : Next_state = WAIT_CALL_CC_2;
		WAIT_CALL_CC_2   : Next_state = CALL_CC_3;
		CALL_CC_3        : Next_state = WAIT_CALL_CC_3;
		WAIT_CALL_CC_3   : Next_state = CALL_CC_4;
		CALL_CC_4        : Next_state = WAIT_CALL_CC_4;
		WAIT_CALL_CC_4   : Next_state = CALL_CC_5;
		CALL_CD_0        : Next_state = WAIT_CALL_CD_0;
		WAIT_CALL_CD_0   : Next_state = CALL_CD_1;
		CALL_CD_1        : Next_state = WAIT_CALL_CD_1;
		WAIT_CALL_CD_1   : Next_state = CALL_CD_2;
		CALL_CD_2        : Next_state = WAIT_CALL_CD_2;
		WAIT_CALL_CD_2   : Next_state = CALL_CD_3;
		CALL_CD_3        : Next_state = WAIT_CALL_CD_3;
		WAIT_CALL_CD_3   : Next_state = CALL_CD_4;
		CALL_CD_4        : Next_state = WAIT_CALL_CD_4;
		WAIT_CALL_CD_4   : Next_state = CALL_CD_5;
		ADC_CE_0         : Next_state = WAIT_ADC_CE_0;
		WAIT_ADC_CE_0    : Next_state = ADC_CE_1;
		RST_CF_0         : Next_state = WAIT_RST_CF_0;
		WAIT_RST_CF_0    : Next_state = RST_CF_1;
		RST_CF_1         : Next_state = WAIT_RST_CF_1;
		WAIT_RST_CF_1    : Next_state = RST_CF_2;
		RST_CF_2         : Next_state = WAIT_RST_CF_2;
		WAIT_RST_CF_2    : Next_state = RST_CF_3;
		RET_D0_0         : Next_state = WAIT_RET_D0_0;
		WAIT_RET_D0_0    : Next_state = RET_D0_1;
		RET_D0_1         : Next_state = WAIT_RET_D0_1;
		WAIT_RET_D0_1    : Next_state = RET_D0_2;
		RET_D0_2         : Next_state = WAIT_RET_D0_2;
		WAIT_RET_D0_2    : Next_state = RET_D0_3;
		RET_D0_3         : Next_state = WAIT_RET_D0_3;
		WAIT_RET_D0_3    : Next_state = RET_D0_4;
		POP_D1_0         : Next_state = WAIT_POP_D1_0;
		WAIT_POP_D1_0    : Next_state = POP_D1_1;
		POP_D1_1         : Next_state = WAIT_POP_D1_1;
		WAIT_POP_D1_1    : Next_state = POP_D1_2;
		JP_D2_0          : Next_state = WAIT_JP_D2_0;
		WAIT_JP_D2_0     : Next_state = JP_D2_1;
		JP_D2_1          : Next_state = WAIT_JP_D2_1;
		WAIT_JP_D2_1     : Next_state = JP_D2_2;
		JP_D2_2          : Next_state = WAIT_JP_D2_2;
		WAIT_JP_D2_2     : Next_state = JP_D2_3;
		CALL_D4_0        : Next_state = WAIT_CALL_D4_0;
		WAIT_CALL_D4_0   : Next_state = CALL_D4_1;
		CALL_D4_1        : Next_state = WAIT_CALL_D4_1;
		WAIT_CALL_D4_1   : Next_state = CALL_D4_2;
		CALL_D4_2        : Next_state = WAIT_CALL_D4_2;
		WAIT_CALL_D4_2   : Next_state = CALL_D4_3;
		CALL_D4_3        : Next_state = WAIT_CALL_D4_3;
		WAIT_CALL_D4_3   : Next_state = CALL_D4_4;
		CALL_D4_4        : Next_state = WAIT_CALL_D4_4;
		WAIT_CALL_D4_4   : Next_state = CALL_D4_5;
		PUSH_D5_0        : Next_state = WAIT_PUSH_D5_0;
		WAIT_PUSH_D5_0   : Next_state = PUSH_D5_1;
		PUSH_D5_1        : Next_state = WAIT_PUSH_D5_1;
		WAIT_PUSH_D5_1   : Next_state = PUSH_D5_2;
		PUSH_D5_2        : Next_state = WAIT_PUSH_D5_2;
		WAIT_PUSH_D5_2   : Next_state = PUSH_D5_3;
		SUB_D6_0         : Next_state = WAIT_SUB_D6_0;
		WAIT_SUB_D6_0    : Next_state = SUB_D6_1;
		RST_D7_0         : Next_state = WAIT_RST_D7_0;
		WAIT_RST_D7_0    : Next_state = RST_D7_1;
		RST_D7_1         : Next_state = WAIT_RST_D7_1;
		WAIT_RST_D7_1    : Next_state = RST_D7_2;
		RST_D7_2         : Next_state = WAIT_RST_D7_2;
		WAIT_RST_D7_2    : Next_state = RST_D7_3;
		RET_D8_0         : Next_state = WAIT_RET_D8_0;
		WAIT_RET_D8_0    : Next_state = RET_D8_1;
		RET_D8_1         : Next_state = WAIT_RET_D8_1;
		WAIT_RET_D8_1    : Next_state = RET_D8_2;
		RET_D8_2         : Next_state = WAIT_RET_D8_2;
		WAIT_RET_D8_2    : Next_state = RET_D8_3;
		RET_D8_3         : Next_state = WAIT_RET_D8_3;
		WAIT_RET_D8_3    : Next_state = RET_D8_4;
		RETI_D9_0        : Next_state = WAIT_RETI_D9_0;
		WAIT_RETI_D9_0   : Next_state = RETI_D9_1;
		RETI_D9_1        : Next_state = WAIT_RETI_D9_1;
		WAIT_RETI_D9_1   : Next_state = RETI_D9_2;
		RETI_D9_2        : Next_state = WAIT_RETI_D9_2;
		WAIT_RETI_D9_2   : Next_state = RETI_D9_3;
		JP_DA_0          : Next_state = WAIT_JP_DA_0;
		WAIT_JP_DA_0     : Next_state = JP_DA_1;
		JP_DA_1          : Next_state = WAIT_JP_DA_1;
		WAIT_JP_DA_1     : Next_state = JP_DA_2;
		JP_DA_2          : Next_state = WAIT_JP_DA_2;
		WAIT_JP_DA_2     : Next_state = JP_DA_3;
		CALL_DC_0        : Next_state = WAIT_CALL_DC_0;
		WAIT_CALL_DC_0   : Next_state = CALL_DC_1;
		CALL_DC_1        : Next_state = WAIT_CALL_DC_1;
		WAIT_CALL_DC_1   : Next_state = CALL_DC_2;
		CALL_DC_2        : Next_state = WAIT_CALL_DC_2;
		WAIT_CALL_DC_2   : Next_state = CALL_DC_3;
		CALL_DC_3        : Next_state = WAIT_CALL_DC_3;
		WAIT_CALL_DC_3   : Next_state = CALL_DC_4;
		CALL_DC_4        : Next_state = WAIT_CALL_DC_4;
		WAIT_CALL_DC_4   : Next_state = CALL_DC_5;
		SBC_DE_0         : Next_state = WAIT_SBC_DE_0;
		WAIT_SBC_DE_0    : Next_state = SBC_DE_1;
		RST_DF_0         : Next_state = WAIT_RST_DF_0;
		WAIT_RST_DF_0    : Next_state = RST_DF_1;
		RST_DF_1         : Next_state = WAIT_RST_DF_1;
		WAIT_RST_DF_1    : Next_state = RST_DF_2;
		RST_DF_2         : Next_state = WAIT_RST_DF_2;
		WAIT_RST_DF_2    : Next_state = RST_DF_3;
		LDH_E0_0         : Next_state = WAIT_LDH_E0_0;
		WAIT_LDH_E0_0    : Next_state = LDH_E0_1;
		LDH_E0_1         : Next_state = WAIT_LDH_E0_1;
		WAIT_LDH_E0_1    : Next_state = LDH_E0_2;
		POP_E1_0         : Next_state = WAIT_POP_E1_0;
		WAIT_POP_E1_0    : Next_state = POP_E1_1;
		POP_E1_1         : Next_state = WAIT_POP_E1_1;
		WAIT_POP_E1_1    : Next_state = POP_E1_2;
		LD_E2_0          : Next_state = WAIT_LD_E2_0;
		WAIT_LD_E2_0     : Next_state = LD_E2_1;
		PUSH_E5_0        : Next_state = WAIT_PUSH_E5_0;
		WAIT_PUSH_E5_0   : Next_state = PUSH_E5_1;
		PUSH_E5_1        : Next_state = WAIT_PUSH_E5_1;
		WAIT_PUSH_E5_1   : Next_state = PUSH_E5_2;
		PUSH_E5_2        : Next_state = WAIT_PUSH_E5_2;
		WAIT_PUSH_E5_2   : Next_state = PUSH_E5_3;
		AND_E6_0         : Next_state = WAIT_AND_E6_0;
		WAIT_AND_E6_0    : Next_state = AND_E6_1;
		RST_E7_0         : Next_state = WAIT_RST_E7_0;
		WAIT_RST_E7_0    : Next_state = RST_E7_1;
		RST_E7_1         : Next_state = WAIT_RST_E7_1;
		WAIT_RST_E7_1    : Next_state = RST_E7_2;
		RST_E7_2         : Next_state = WAIT_RST_E7_2;
		WAIT_RST_E7_2    : Next_state = RST_E7_3;
		ADD_E8_0         : Next_state = WAIT_ADD_E8_0;
		WAIT_ADD_E8_0    : Next_state = ADD_E8_1;
		ADD_E8_1         : Next_state = WAIT_ADD_E8_1;
		WAIT_ADD_E8_1    : Next_state = ADD_E8_2;
		ADD_E8_2         : Next_state = WAIT_ADD_E8_2;
		WAIT_ADD_E8_2    : Next_state = ADD_E8_3;
		LD_EA_0          : Next_state = WAIT_LD_EA_0;
		WAIT_LD_EA_0     : Next_state = LD_EA_1;
		LD_EA_1          : Next_state = WAIT_LD_EA_1;
		WAIT_LD_EA_1     : Next_state = LD_EA_2;
		LD_EA_2          : Next_state = WAIT_LD_EA_2;
		WAIT_LD_EA_2     : Next_state = LD_EA_3;
		XOR_EE_0         : Next_state = WAIT_XOR_EE_0;
		WAIT_XOR_EE_0    : Next_state = XOR_EE_1;
		RST_EF_0         : Next_state = WAIT_RST_EF_0;
		WAIT_RST_EF_0    : Next_state = RST_EF_1;
		RST_EF_1         : Next_state = WAIT_RST_EF_1;
		WAIT_RST_EF_1    : Next_state = RST_EF_2;
		RST_EF_2         : Next_state = WAIT_RST_EF_2;
		WAIT_RST_EF_2    : Next_state = RST_EF_3;
		LDH_F0_0         : Next_state = WAIT_LDH_F0_0;
		WAIT_LDH_F0_0    : Next_state = LDH_F0_1;
		LDH_F0_1         : Next_state = WAIT_LDH_F0_1;
		WAIT_LDH_F0_1    : Next_state = LDH_F0_2;
		POP_F1_0         : Next_state = WAIT_POP_F1_0;
		WAIT_POP_F1_0    : Next_state = POP_F1_1;
		POP_F1_1         : Next_state = WAIT_POP_F1_1;
		WAIT_POP_F1_1    : Next_state = POP_F1_2;
		LD_F2_0          : Next_state = WAIT_LD_F2_0;
		WAIT_LD_F2_0     : Next_state = LD_F2_1;
		PUSH_F5_0        : Next_state = WAIT_PUSH_F5_0;
		WAIT_PUSH_F5_0   : Next_state = PUSH_F5_1;
		PUSH_F5_1        : Next_state = WAIT_PUSH_F5_1;
		WAIT_PUSH_F5_1   : Next_state = PUSH_F5_2;
		PUSH_F5_2        : Next_state = WAIT_PUSH_F5_2;
		WAIT_PUSH_F5_2   : Next_state = PUSH_F5_3;
		OR_F6_0          : Next_state = WAIT_OR_F6_0;
		WAIT_OR_F6_0     : Next_state = OR_F6_1;
		RST_F7_0         : Next_state = WAIT_RST_F7_0;
		WAIT_RST_F7_0    : Next_state = RST_F7_1;
		RST_F7_1         : Next_state = WAIT_RST_F7_1;
		WAIT_RST_F7_1    : Next_state = RST_F7_2;
		RST_F7_2         : Next_state = WAIT_RST_F7_2;
		WAIT_RST_F7_2    : Next_state = RST_F7_3;
		LD_F8_0          : Next_state = WAIT_LD_F8_0;
		WAIT_LD_F8_0     : Next_state = LD_F8_1;
		LD_F8_1          : Next_state = WAIT_LD_F8_1;
		WAIT_LD_F8_1     : Next_state = LD_F8_2;
		LD_F9_0          : Next_state = WAIT_LD_F9_0;
		WAIT_LD_F9_0     : Next_state = LD_F9_1;
		LD_FA_0          : Next_state = WAIT_LD_FA_0;
		WAIT_LD_FA_0     : Next_state = LD_FA_1;
		LD_FA_1          : Next_state = WAIT_LD_FA_1;
		WAIT_LD_FA_1     : Next_state = LD_FA_2;
		LD_FA_2          : Next_state = WAIT_LD_FA_2;
		WAIT_LD_FA_2     : Next_state = LD_FA_3;
		CP_FE_0          : Next_state = WAIT_CP_FE_0;
		WAIT_CP_FE_0     : Next_state = CP_FE_1;
		RST_FF_0         : Next_state = WAIT_RST_FF_0;
		WAIT_RST_FF_0    : Next_state = RST_FF_1;
		RST_FF_1         : Next_state = WAIT_RST_FF_1;
		WAIT_RST_FF_1    : Next_state = RST_FF_2;
		RST_FF_2         : Next_state = WAIT_RST_FF_2;
		WAIT_RST_FF_2    : Next_state = RST_FF_3;
		RLC_06_0         : Next_state = WAIT_RLC_06_0;
		WAIT_RLC_06_0    : Next_state = RLC_06_1;
		RLC_06_1         : Next_state = WAIT_RLC_06_1;
		WAIT_RLC_06_1    : Next_state = RLC_06_2;
		RRC_0E_0         : Next_state = WAIT_RRC_0E_0;
		WAIT_RRC_0E_0    : Next_state = RRC_0E_1;
		RRC_0E_1         : Next_state = WAIT_RRC_0E_1;
		WAIT_RRC_0E_1    : Next_state = RRC_0E_2;
		RL_16_0          : Next_state = WAIT_RL_16_0;
		WAIT_RL_16_0     : Next_state = RL_16_1;
		RL_16_1          : Next_state = WAIT_RL_16_1;
		WAIT_RL_16_1     : Next_state = RL_16_2;
		RR_1E_0          : Next_state = WAIT_RR_1E_0;
		WAIT_RR_1E_0     : Next_state = RR_1E_1;
		RR_1E_1          : Next_state = WAIT_RR_1E_1;
		WAIT_RR_1E_1     : Next_state = RR_1E_2;
		SLA_26_0         : Next_state = WAIT_SLA_26_0;
		WAIT_SLA_26_0    : Next_state = SLA_26_1;
		SLA_26_1         : Next_state = WAIT_SLA_26_1;
		WAIT_SLA_26_1    : Next_state = SLA_26_2;
		SRA_2E_0         : Next_state = WAIT_SRA_2E_0;
		WAIT_SRA_2E_0    : Next_state = SRA_2E_1;
		SRA_2E_1         : Next_state = WAIT_SRA_2E_1;
		WAIT_SRA_2E_1    : Next_state = SRA_2E_2;
		SWAP_36_0        : Next_state = WAIT_SWAP_36_0;
		WAIT_SWAP_36_0   : Next_state = SWAP_36_1;
		SWAP_36_1        : Next_state = WAIT_SWAP_36_1;
		WAIT_SWAP_36_1   : Next_state = SWAP_36_2;
		SRL_3E_0         : Next_state = WAIT_SRL_3E_0;
		WAIT_SRL_3E_0    : Next_state = SRL_3E_1;
		SRL_3E_1         : Next_state = WAIT_SRL_3E_1;
		WAIT_SRL_3E_1    : Next_state = SRL_3E_2;
		BIT_46_0         : Next_state = WAIT_BIT_46_0;
		WAIT_BIT_46_0    : Next_state = BIT_46_1;
		BIT_4E_0         : Next_state = WAIT_BIT_4E_0;
		WAIT_BIT_4E_0    : Next_state = BIT_4E_1;
		BIT_56_0         : Next_state = WAIT_BIT_56_0;
		WAIT_BIT_56_0    : Next_state = BIT_56_1;
		BIT_5E_0         : Next_state = WAIT_BIT_5E_0;
		WAIT_BIT_5E_0    : Next_state = BIT_5E_1;
		BIT_66_0         : Next_state = WAIT_BIT_66_0;
		WAIT_BIT_66_0    : Next_state = BIT_66_1;
		BIT_6E_0         : Next_state = WAIT_BIT_6E_0;
		WAIT_BIT_6E_0    : Next_state = BIT_6E_1;
		BIT_76_0         : Next_state = WAIT_BIT_76_0;
		WAIT_BIT_76_0    : Next_state = BIT_76_1;
		BIT_7E_0         : Next_state = WAIT_BIT_7E_0;
		WAIT_BIT_7E_0    : Next_state = BIT_7E_1;
		RES_86_0         : Next_state = WAIT_RES_86_0;
		WAIT_RES_86_0    : Next_state = RES_86_1;
		RES_86_1         : Next_state = WAIT_RES_86_1;
		WAIT_RES_86_1    : Next_state = RES_86_2;
		RES_8E_0         : Next_state = WAIT_RES_8E_0;
		WAIT_RES_8E_0    : Next_state = RES_8E_1;
		RES_8E_1         : Next_state = WAIT_RES_8E_1;
		WAIT_RES_8E_1    : Next_state = RES_8E_2;
		RES_96_0         : Next_state = WAIT_RES_96_0;
		WAIT_RES_96_0    : Next_state = RES_96_1;
		RES_96_1         : Next_state = WAIT_RES_96_1;
		WAIT_RES_96_1    : Next_state = RES_96_2;
		RES_9E_0         : Next_state = WAIT_RES_9E_0;
		WAIT_RES_9E_0    : Next_state = RES_9E_1;
		RES_9E_1         : Next_state = WAIT_RES_9E_1;
		WAIT_RES_9E_1    : Next_state = RES_9E_2;
		RES_A6_0         : Next_state = WAIT_RES_A6_0;
		WAIT_RES_A6_0    : Next_state = RES_A6_1;
		RES_A6_1         : Next_state = WAIT_RES_A6_1;
		WAIT_RES_A6_1    : Next_state = RES_A6_2;
		RES_AE_0         : Next_state = WAIT_RES_AE_0;
		WAIT_RES_AE_0    : Next_state = RES_AE_1;
		RES_AE_1         : Next_state = WAIT_RES_AE_1;
		WAIT_RES_AE_1    : Next_state = RES_AE_2;
		RES_B6_0         : Next_state = WAIT_RES_B6_0;
		WAIT_RES_B6_0    : Next_state = RES_B6_1;
		RES_B6_1         : Next_state = WAIT_RES_B6_1;
		WAIT_RES_B6_1    : Next_state = RES_B6_2;
		RES_BE_0         : Next_state = WAIT_RES_BE_0;
		WAIT_RES_BE_0    : Next_state = RES_BE_1;
		RES_BE_1         : Next_state = WAIT_RES_BE_1;
		WAIT_RES_BE_1    : Next_state = RES_BE_2;
		SET_C6_0         : Next_state = WAIT_SET_C6_0;
		WAIT_SET_C6_0    : Next_state = SET_C6_1;
		SET_C6_1         : Next_state = WAIT_SET_C6_1;
		WAIT_SET_C6_1    : Next_state = SET_C6_2;
		SET_CE_0         : Next_state = WAIT_SET_CE_0;
		WAIT_SET_CE_0    : Next_state = SET_CE_1;
		SET_CE_1         : Next_state = WAIT_SET_CE_1;
		WAIT_SET_CE_1    : Next_state = SET_CE_2;
		SET_D6_0         : Next_state = WAIT_SET_D6_0;
		WAIT_SET_D6_0    : Next_state = SET_D6_1;
		SET_D6_1         : Next_state = WAIT_SET_D6_1;
		WAIT_SET_D6_1    : Next_state = SET_D6_2;
		SET_DE_0         : Next_state = WAIT_SET_DE_0;
		WAIT_SET_DE_0    : Next_state = SET_DE_1;
		SET_DE_1         : Next_state = WAIT_SET_DE_1;
		WAIT_SET_DE_1    : Next_state = SET_DE_2;
		SET_E6_0         : Next_state = WAIT_SET_E6_0;
		WAIT_SET_E6_0    : Next_state = SET_E6_1;
		SET_E6_1         : Next_state = WAIT_SET_E6_1;
		WAIT_SET_E6_1    : Next_state = SET_E6_2;
		SET_EE_0         : Next_state = WAIT_SET_EE_0;
		WAIT_SET_EE_0    : Next_state = SET_EE_1;
		SET_EE_1         : Next_state = WAIT_SET_EE_1;
		WAIT_SET_EE_1    : Next_state = SET_EE_2;
		SET_F6_0         : Next_state = WAIT_SET_F6_0;
		WAIT_SET_F6_0    : Next_state = SET_F6_1;
		SET_F6_1         : Next_state = WAIT_SET_F6_1;
		WAIT_SET_F6_1    : Next_state = SET_F6_2;
		SET_FE_0         : Next_state = WAIT_SET_FE_0;
		WAIT_SET_FE_0    : Next_state = SET_FE_1;
		SET_FE_1         : Next_state = WAIT_SET_FE_1;
		WAIT_SET_FE_1    : Next_state = SET_FE_2;
		default          : Next_state = FETCH;
	endcase
	
////////// Assign control signals based on current state /////////////////////////////////////////////////////////////////////////////////

	// Default controls signal values
    {OR_ld, SP_ld, PC_ld, A_ld, F_ld, B_ld, C_ld, D_ld, E_ld, H_ld, L_ld, BC_ld, DE_ld, HL_ld}  = 14'b0;
    mem_wren = 1'b0;
    data_out = 8'hXX;
    mem_addr = 8'hXX;

	SP_new = SP;
	PC_new = PC;
	OR_new = OR;

	A_new = A;
	B_new = B;
	C_new = C;
	D_new = D;
	E_new = E;
	H_new = H;
	L_new = L;

	Z_flag_new = Z_flag;
	N_flag_new = N_flag;
	H_flag_new = H_flag;
	C_flag_new = C_flag;

	BC_new = BC;
	DE_new = DE;
	HL_new = HL;

	case (State)
						RESET : begin
							mem_addr = PC;
						end
						FETCH : begin
							mem_addr = PC;
							OR_new = data_in;
							OR_ld = 1'b1;
							PC_new = PC + 1'b1;
							PC_ld = 1'b1;
						end
						PREFIX_CB : begin
							mem_addr = PC;
							OR_new = data_in;
							OR_ld = 1'b1;
							PC_new = PC + 1'b1;
							PC_ld = 1'b1;
						end
/*      NOP      */     NOP_00           : ;
/*   LD BC d16   */     LD_01_0          : ;
                        LD_01_1          : ;
                        LD_01_2          : ;
/*   LD (BC) A   */     LD_02_0          : ;
                        LD_02_1          : ;
/*     INC BC    */     INC_03_0         : ;
                        INC_03_1         : ;
/*     INC B     */     INC_04           : ;
/*     DEC B     */     DEC_05           : ;
/*    LD B d8    */     LD_06_0          : ;
                        LD_06_1          : ;
/*      RLCA     */     RLCA_07          : ;
/*  LD (a16) SP  */     LD_08_0          : ;
                        LD_08_1          : ;
                        LD_08_2          : ;
                        LD_08_3          : ;
                        LD_08_4          : ;
/*   ADD HL BC   */     ADD_09_0         : ;
                        ADD_09_1         : ;
/*   LD A (BC)   */     LD_0A_0          : ;
                        LD_0A_1          : ;
/*     DEC BC    */     DEC_0B_0         : ;
                        DEC_0B_1         : ;
/*     INC C     */     INC_0C           : ;
/*     DEC C     */     DEC_0D           : ;
/*    LD C d8    */     LD_0E_0          : ;
                        LD_0E_1          : ;
/*      RRCA     */     RRCA_0F          : ;
/*      STOP     */     STOP_10          : ;
/*   LD DE d16   */     LD_11_0          : ;
                        LD_11_1          : ;
                        LD_11_2          : ;
/*   LD (DE) A   */     LD_12_0          : ;
                        LD_12_1          : ;
/*     INC DE    */     INC_13_0         : ;
                        INC_13_1         : ;
/*     INC D     */     INC_14           : ;
/*     DEC D     */     DEC_15           : ;
/*    LD D d8    */     LD_16_0          : ;
                        LD_16_1          : ;
/*      RLA      */     RLA_17           : ;
/*     JR r8     */     JR_18_0          : ;
                        JR_18_1          : ;
                        JR_18_2          : ;
/*   ADD HL DE   */     ADD_19_0         : ;
                        ADD_19_1         : ;
/*   LD A (DE)   */     LD_1A_0          : ;
                        LD_1A_1          : ;
/*     DEC DE    */     DEC_1B_0         : ;
                        DEC_1B_1         : ;
/*     INC E     */     INC_1C           : ;
/*     DEC E     */     DEC_1D           : ;
/*    LD E d8    */     LD_1E_0          : ;
                        LD_1E_1          : ;
/*      RRA      */     RRA_1F           : ;
/*    JR NZ r8   */     JR_20_0          : `get_one_byte(OP8)
                        JR_20_1          : ;
                        JR_20_2          : `ADD(PC,`SEXT16(OP8))
/*   LD HL d16   */     LD_21_0          : `get_low_byte(OP16)
                        LD_21_1          : `get_high_byte(OP16)
                        LD_21_2          : `writeRegFromReg(HL,OP16)
/*   LD (HL) A   */     LD_22_0          : ;
                        LD_22_1          : ;
/*     INC HL    */     INC_23_0         : ;
                        INC_23_1         : ;
/*     INC H     */     INC_24           : ;
/*     DEC H     */     DEC_25           : ;
/*    LD H d8    */     LD_26_0          : ;
                        LD_26_1          : ;
/*      DAA      */     DAA_27           : ;
/*    JR Z r8    */     JR_28_0          : ;
                        JR_28_1          : ;
                        JR_28_2          : ;
/*   ADD HL HL   */     ADD_29_0         : ;
                        ADD_29_1         : ;
/*   LD A (HL)   */     LD_2A_0          : ;
                        LD_2A_1          : ;
/*     DEC HL    */     DEC_2B_0         : ;
                        DEC_2B_1         : ;
/*     INC L     */     INC_2C           : ;
/*     DEC L     */     DEC_2D           : ;
/*    LD L d8    */     LD_2E_0          : ;
                        LD_2E_1          : ;
/*      CPL      */     CPL_2F           : ;
/*    JR NC r8   */     JR_30_0          : ;
                        JR_30_1          : ;
                        JR_30_2          : ;
/*   LD SP d16   */     LD_31_0          : `get_low_byte(OP16)
                        LD_31_1          : `get_high_byte(OP16)
                        LD_31_2          : `writeRegFromReg(SP,OP16)
/*   LD (HL-) A  */     LD_32_0          : `writeMemFromReg(HL,A)
                        LD_32_1          : `DEC16(HL)
/*     INC SP    */     INC_33_0         : ;
                        INC_33_1         : ;
/*    INC (HL)   */     INC_34_0         : ;
                        INC_34_1         : ;
                        INC_34_2         : ;
/*    DEC (HL)   */     DEC_35_0         : ;
                        DEC_35_1         : ;
                        DEC_35_2         : ;
/*   LD (HL) d8  */     LD_36_0          : ;
                        LD_36_1          : ;
                        LD_36_2          : ;
/*      SCF      */     SCF_37           : ;
/*    JR C r8    */     JR_38_0          : ;
                        JR_38_1          : ;
                        JR_38_2          : ;
/*   ADD HL SP   */     ADD_39_0         : ;
                        ADD_39_1         : ;
/*   LD A (HL)   */     LD_3A_0          : ;
                        LD_3A_1          : ;
/*     DEC SP    */     DEC_3B_0         : ;
                        DEC_3B_1         : ;
/*     INC A     */     INC_3C           : ;
/*     DEC A     */     DEC_3D           : ;
/*    LD A d8    */     LD_3E_0          : ;
                        LD_3E_1          : ;
/*      CCF      */     CCF_3F           : ;
/*     LD B B    */     LD_40            : ;
/*     LD B C    */     LD_41            : ;
/*     LD B D    */     LD_42            : ;
/*     LD B E    */     LD_43            : ;
/*     LD B H    */     LD_44            : ;
/*     LD B L    */     LD_45            : ;
/*   LD B (HL)   */     LD_46_0          : ;
                        LD_46_1          : ;
/*     LD B A    */     LD_47            : ;
/*     LD C B    */     LD_48            : ;
/*     LD C C    */     LD_49            : ;
/*     LD C D    */     LD_4A            : ;
/*     LD C E    */     LD_4B            : ;
/*     LD C H    */     LD_4C            : ;
/*     LD C L    */     LD_4D            : ;
/*   LD C (HL)   */     LD_4E_0          : ;
                        LD_4E_1          : ;
/*     LD C A    */     LD_4F            : ;
/*     LD D B    */     LD_50            : ;
/*     LD D C    */     LD_51            : ;
/*     LD D D    */     LD_52            : ;
/*     LD D E    */     LD_53            : ;
/*     LD D H    */     LD_54            : ;
/*     LD D L    */     LD_55            : ;
/*   LD D (HL)   */     LD_56_0          : ;
                        LD_56_1          : ;
/*     LD D A    */     LD_57            : ;
/*     LD E B    */     LD_58            : ;
/*     LD E C    */     LD_59            : ;
/*     LD E D    */     LD_5A            : ;
/*     LD E E    */     LD_5B            : ;
/*     LD E H    */     LD_5C            : ;
/*     LD E L    */     LD_5D            : ;
/*   LD E (HL)   */     LD_5E_0          : ;
                        LD_5E_1          : ;
/*     LD E A    */     LD_5F            : ;
/*     LD H B    */     LD_60            : ;
/*     LD H C    */     LD_61            : ;
/*     LD H D    */     LD_62            : ;
/*     LD H E    */     LD_63            : ;
/*     LD H H    */     LD_64            : ;
/*     LD H L    */     LD_65            : ;
/*   LD H (HL)   */     LD_66_0          : ;
                        LD_66_1          : ;
/*     LD H A    */     LD_67            : ;
/*     LD L B    */     LD_68            : ;
/*     LD L C    */     LD_69            : ;
/*     LD L D    */     LD_6A            : ;
/*     LD L E    */     LD_6B            : ;
/*     LD L H    */     LD_6C            : ;
/*     LD L L    */     LD_6D            : ;
/*   LD L (HL)   */     LD_6E_0          : ;
                        LD_6E_1          : ;
/*     LD L A    */     LD_6F            : ;
/*   LD (HL) B   */     LD_70_0          : ;
                        LD_70_1          : ;
/*   LD (HL) C   */     LD_71_0          : ;
                        LD_71_1          : ;
/*   LD (HL) D   */     LD_72_0          : ;
                        LD_72_1          : ;
/*   LD (HL) E   */     LD_73_0          : ;
                        LD_73_1          : ;
/*   LD (HL) H   */     LD_74_0          : ;
                        LD_74_1          : ;
/*   LD (HL) L   */     LD_75_0          : ;
                        LD_75_1          : ;
/*      HALT     */     HALT_76          : ;
/*   LD (HL) A   */     LD_77_0          : ;
                        LD_77_1          : ;
/*     LD A B    */     LD_78            : ;
/*     LD A C    */     LD_79            : ;
/*     LD A D    */     LD_7A            : ;
/*     LD A E    */     LD_7B            : ;
/*     LD A H    */     LD_7C            : ;
/*     LD A L    */     LD_7D            : ;
/*   LD A (HL)   */     LD_7E_0          : ;
                        LD_7E_1          : ;
/*     LD A A    */     LD_7F            : ;
/*    ADD A B    */     ADD_80           : ;
/*    ADD A C    */     ADD_81           : ;
/*    ADD A D    */     ADD_82           : ;
/*    ADD A E    */     ADD_83           : ;
/*    ADD A H    */     ADD_84           : ;
/*    ADD A L    */     ADD_85           : ;
/*   ADD A (HL)  */     ADD_86_0         : ;
                        ADD_86_1         : ;
/*    ADD A A    */     ADD_87           : ;
/*    ADC A B    */     ADC_88           : ;
/*    ADC A C    */     ADC_89           : ;
/*    ADC A D    */     ADC_8A           : ;
/*    ADC A E    */     ADC_8B           : ;
/*    ADC A H    */     ADC_8C           : ;
/*    ADC A L    */     ADC_8D           : ;
/*   ADC A (HL)  */     ADC_8E_0         : ;
                        ADC_8E_1         : ;
/*    ADC A A    */     ADC_8F           : ;
/*     SUB B     */     SUB_90           : ;
/*     SUB C     */     SUB_91           : ;
/*     SUB D     */     SUB_92           : ;
/*     SUB E     */     SUB_93           : ;
/*     SUB H     */     SUB_94           : ;
/*     SUB L     */     SUB_95           : ;
/*    SUB (HL)   */     SUB_96_0         : ;
                        SUB_96_1         : ;
/*     SUB A     */     SUB_97           : ;
/*    SBC A B    */     SBC_98           : ;
/*    SBC A C    */     SBC_99           : ;
/*    SBC A D    */     SBC_9A           : ;
/*    SBC A E    */     SBC_9B           : ;
/*    SBC A H    */     SBC_9C           : ;
/*    SBC A L    */     SBC_9D           : ;
/*   SBC A (HL)  */     SBC_9E_0         : ;
                        SBC_9E_1         : ;
/*    SBC A A    */     SBC_9F           : ;
/*     AND B     */     AND_A0           : ;
/*     AND C     */     AND_A1           : ;
/*     AND D     */     AND_A2           : ;
/*     AND E     */     AND_A3           : ;
/*     AND H     */     AND_A4           : ;
/*     AND L     */     AND_A5           : ;
/*    AND (HL)   */     AND_A6_0         : ;
                        AND_A6_1         : ;
/*     AND A     */     AND_A7           : ;
/*     XOR B     */     XOR_A8           : ;
/*     XOR C     */     XOR_A9           : ;
/*     XOR D     */     XOR_AA           : ;
/*     XOR E     */     XOR_AB           : ;
/*     XOR H     */     XOR_AC           : ;
/*     XOR L     */     XOR_AD           : ;
/*    XOR (HL)   */     XOR_AE_0         : ;
                        XOR_AE_1         : ;
/*     XOR A     */     XOR_AF           : `XOR(A)
/*      OR B     */     OR_B0            : ;
/*      OR C     */     OR_B1            : ;
/*      OR D     */     OR_B2            : ;
/*      OR E     */     OR_B3            : ;
/*      OR H     */     OR_B4            : ;
/*      OR L     */     OR_B5            : ;
/*    OR (HL)    */     OR_B6_0          : ;
                        OR_B6_1          : ;
/*      OR A     */     OR_B7            : ;
/*      CP B     */     CP_B8            : ;
/*      CP C     */     CP_B9            : ;
/*      CP D     */     CP_BA            : ;
/*      CP E     */     CP_BB            : ;
/*      CP H     */     CP_BC            : ;
/*      CP L     */     CP_BD            : ;
/*    CP (HL)    */     CP_BE_0          : ;
                        CP_BE_1          : ;
/*      CP A     */     CP_BF            : ;
/*     RET NZ    */     RET_C0_0         : ;
                        RET_C0_1         : ;
                        RET_C0_2         : ;
                        RET_C0_3         : ;
                        RET_C0_4         : ;
/*     POP BC    */     POP_C1_0         : ;
                        POP_C1_1         : ;
                        POP_C1_2         : ;
/*   JP NZ a16   */     JP_C2_0          : ;
                        JP_C2_1          : ;
                        JP_C2_2          : ;
                        JP_C2_3          : ;
/*     JP a16    */     JP_C3_0          : ;
                        JP_C3_1          : ;
                        JP_C3_2          : ;
                        JP_C3_3          : ;
/*  CALL NZ a16  */     CALL_C4_0        : ;
                        CALL_C4_1        : ;
                        CALL_C4_2        : ;
                        CALL_C4_3        : ;
                        CALL_C4_4        : ;
                        CALL_C4_5        : ;
/*    PUSH BC    */     PUSH_C5_0        : ;
                        PUSH_C5_1        : ;
                        PUSH_C5_2        : ;
                        PUSH_C5_3        : ;
/*    ADD A d8   */     ADD_C6_0         : ;
                        ADD_C6_1         : ;
/*    RST 00H    */     RST_C7_0         : ;
                        RST_C7_1         : ;
                        RST_C7_2         : ;
                        RST_C7_3         : ;
/*     RET Z     */     RET_C8_0         : ;
                        RET_C8_1         : ;
                        RET_C8_2         : ;
                        RET_C8_3         : ;
                        RET_C8_4         : ;
/*      RET      */     RET_C9_0         : ;
                        RET_C9_1         : ;
                        RET_C9_2         : ;
                        RET_C9_3         : ;
/*    JP Z a16   */     JP_CA_0          : ;
                        JP_CA_1          : ;
                        JP_CA_2          : ;
                        JP_CA_3          : ;
/*     PREFIX    */     PREFIX_CB        : ;
/*   CALL Z a16  */     CALL_CC_0        : ;
                        CALL_CC_1        : ;
                        CALL_CC_2        : ;
                        CALL_CC_3        : ;
                        CALL_CC_4        : ;
                        CALL_CC_5        : ;
/*    CALL a16   */     CALL_CD_0        : ;
                        CALL_CD_1        : ;
                        CALL_CD_2        : ;
                        CALL_CD_3        : ;
                        CALL_CD_4        : ;
                        CALL_CD_5        : ;
/*    ADC A d8   */     ADC_CE_0         : ;
                        ADC_CE_1         : ;
/*    RST 08H    */     RST_CF_0         : ;
                        RST_CF_1         : ;
                        RST_CF_2         : ;
                        RST_CF_3         : ;
/*     RET NC    */     RET_D0_0         : ;
                        RET_D0_1         : ;
                        RET_D0_2         : ;
                        RET_D0_3         : ;
                        RET_D0_4         : ;
/*     POP DE    */     POP_D1_0         : ;
                        POP_D1_1         : ;
                        POP_D1_2         : ;
/*   JP NC a16   */     JP_D2_0          : ;
                        JP_D2_1          : ;
                        JP_D2_2          : ;
                        JP_D2_3          : ;
/*   ILLEGAL_D3  */     ILLEGAL_D3_D3    : ;
/*  CALL NC a16  */     CALL_D4_0        : ;
                        CALL_D4_1        : ;
                        CALL_D4_2        : ;
                        CALL_D4_3        : ;
                        CALL_D4_4        : ;
                        CALL_D4_5        : ;
/*    PUSH DE    */     PUSH_D5_0        : ;
                        PUSH_D5_1        : ;
                        PUSH_D5_2        : ;
                        PUSH_D5_3        : ;
/*     SUB d8    */     SUB_D6_0         : ;
                        SUB_D6_1         : ;
/*    RST 10H    */     RST_D7_0         : ;
                        RST_D7_1         : ;
                        RST_D7_2         : ;
                        RST_D7_3         : ;
/*     RET C     */     RET_D8_0         : ;
                        RET_D8_1         : ;
                        RET_D8_2         : ;
                        RET_D8_3         : ;
                        RET_D8_4         : ;
/*      RETI     */     RETI_D9_0        : ;
                        RETI_D9_1        : ;
                        RETI_D9_2        : ;
                        RETI_D9_3        : ;
/*    JP C a16   */     JP_DA_0          : ;
                        JP_DA_1          : ;
                        JP_DA_2          : ;
                        JP_DA_3          : ;
/*   ILLEGAL_DB  */     ILLEGAL_DB_DB    : ;
/*   CALL C a16  */     CALL_DC_0        : ;
                        CALL_DC_1        : ;
                        CALL_DC_2        : ;
                        CALL_DC_3        : ;
                        CALL_DC_4        : ;
                        CALL_DC_5        : ;
/*   ILLEGAL_DD  */     ILLEGAL_DD_DD    : ;
/*    SBC A d8   */     SBC_DE_0         : ;
                        SBC_DE_1         : ;
/*    RST 18H    */     RST_DF_0         : ;
                        RST_DF_1         : ;
                        RST_DF_2         : ;
                        RST_DF_3         : ;
/*   LDH (a8) A  */     LDH_E0_0         : ;
                        LDH_E0_1         : ;
                        LDH_E0_2         : ;
/*     POP HL    */     POP_E1_0         : ;
                        POP_E1_1         : ;
                        POP_E1_2         : ;
/*    LD (C) A   */     LD_E2_0          : ;
                        LD_E2_1          : ;
/*   ILLEGAL_E3  */     ILLEGAL_E3_E3    : ;
/*   ILLEGAL_E4  */     ILLEGAL_E4_E4    : ;
/*    PUSH HL    */     PUSH_E5_0        : ;
                        PUSH_E5_1        : ;
                        PUSH_E5_2        : ;
                        PUSH_E5_3        : ;
/*     AND d8    */     AND_E6_0         : ;
                        AND_E6_1         : ;
/*    RST 20H    */     RST_E7_0         : ;
                        RST_E7_1         : ;
                        RST_E7_2         : ;
                        RST_E7_3         : ;
/*   ADD SP r8   */     ADD_E8_0         : ;
                        ADD_E8_1         : ;
                        ADD_E8_2         : ;
                        ADD_E8_3         : ;
/*     JP HL     */     JP_E9            : ;
/*   LD (a16) A  */     LD_EA_0          : ;
                        LD_EA_1          : ;
                        LD_EA_2          : ;
                        LD_EA_3          : ;
/*   ILLEGAL_EB  */     ILLEGAL_EB_EB    : ;
/*   ILLEGAL_EC  */     ILLEGAL_EC_EC    : ;
/*   ILLEGAL_ED  */     ILLEGAL_ED_ED    : ;
/*     XOR d8    */     XOR_EE_0         : ;
                        XOR_EE_1         : ;
/*    RST 28H    */     RST_EF_0         : ;
                        RST_EF_1         : ;
                        RST_EF_2         : ;
                        RST_EF_3         : ;
/*   LDH A (a8)  */     LDH_F0_0         : ;
                        LDH_F0_1         : ;
                        LDH_F0_2         : ;
/*     POP AF    */     POP_F1_0         : ;
                        POP_F1_1         : ;
                        POP_F1_2         : ;
/*    LD A (C)   */     LD_F2_0          : ;
                        LD_F2_1          : ;
/*       DI      */     DI_F3            : ;
/*   ILLEGAL_F4  */     ILLEGAL_F4_F4    : ;
/*    PUSH AF    */     PUSH_F5_0        : ;
                        PUSH_F5_1        : ;
                        PUSH_F5_2        : ;
                        PUSH_F5_3        : ;
/*     OR d8     */     OR_F6_0          : ;
                        OR_F6_1          : ;
/*    RST 30H    */     RST_F7_0         : ;
                        RST_F7_1         : ;
                        RST_F7_2         : ;
                        RST_F7_3         : ;
/*    LD HL SP   */     LD_F8_0          : ;
                        LD_F8_1          : ;
                        LD_F8_2          : ;
/*    LD SP HL   */     LD_F9_0          : ;
                        LD_F9_1          : ;
/*   LD A (a16)  */     LD_FA_0          : ;
                        LD_FA_1          : ;
                        LD_FA_2          : ;
                        LD_FA_3          : ;
/*       EI      */     EI_FB            : ;
/*   ILLEGAL_FC  */     ILLEGAL_FC_FC    : ;
/*   ILLEGAL_FD  */     ILLEGAL_FD_FD    : ;
/*     CP d8     */     CP_FE_0          : ;
                        CP_FE_1          : ;
/*    RST 38H    */     RST_FF_0         : ;
                        RST_FF_1         : ;
                        RST_FF_2         : ;
                        RST_FF_3         : ;
/*     RLC B     */     RLC_00           : ;
/*     RLC C     */     RLC_01           : ;
/*     RLC D     */     RLC_02           : ;
/*     RLC E     */     RLC_03           : ;
/*     RLC H     */     RLC_04           : ;
/*     RLC L     */     RLC_05           : ;
/*    RLC (HL)   */     RLC_06_0         : ;
                        RLC_06_1         : ;
                        RLC_06_2         : ;
/*     RLC A     */     RLC_07           : ;
/*     RRC B     */     RRC_08           : ;
/*     RRC C     */     RRC_09           : ;
/*     RRC D     */     RRC_0A           : ;
/*     RRC E     */     RRC_0B           : ;
/*     RRC H     */     RRC_0C           : ;
/*     RRC L     */     RRC_0D           : ;
/*    RRC (HL)   */     RRC_0E_0         : ;
                        RRC_0E_1         : ;
                        RRC_0E_2         : ;
/*     RRC A     */     RRC_0F           : ;
/*      RL B     */     RL_10            : ;
/*      RL C     */     RL_11            : ;
/*      RL D     */     RL_12            : ;
/*      RL E     */     RL_13            : ;
/*      RL H     */     RL_14            : ;
/*      RL L     */     RL_15            : ;
/*    RL (HL)    */     RL_16_0          : ;
                        RL_16_1          : ;
                        RL_16_2          : ;
/*      RL A     */     RL_17            : ;
/*      RR B     */     RR_18            : ;
/*      RR C     */     RR_19            : ;
/*      RR D     */     RR_1A            : ;
/*      RR E     */     RR_1B            : ;
/*      RR H     */     RR_1C            : ;
/*      RR L     */     RR_1D            : ;
/*    RR (HL)    */     RR_1E_0          : ;
                        RR_1E_1          : ;
                        RR_1E_2          : ;
/*      RR A     */     RR_1F            : ;
/*     SLA B     */     SLA_20           : ;
/*     SLA C     */     SLA_21           : ;
/*     SLA D     */     SLA_22           : ;
/*     SLA E     */     SLA_23           : ;
/*     SLA H     */     SLA_24           : ;
/*     SLA L     */     SLA_25           : ;
/*    SLA (HL)   */     SLA_26_0         : ;
                        SLA_26_1         : ;
                        SLA_26_2         : ;
/*     SLA A     */     SLA_27           : ;
/*     SRA B     */     SRA_28           : ;
/*     SRA C     */     SRA_29           : ;
/*     SRA D     */     SRA_2A           : ;
/*     SRA E     */     SRA_2B           : ;
/*     SRA H     */     SRA_2C           : ;
/*     SRA L     */     SRA_2D           : ;
/*    SRA (HL)   */     SRA_2E_0         : ;
                        SRA_2E_1         : ;
                        SRA_2E_2         : ;
/*     SRA A     */     SRA_2F           : ;
/*     SWAP B    */     SWAP_30          : ;
/*     SWAP C    */     SWAP_31          : ;
/*     SWAP D    */     SWAP_32          : ;
/*     SWAP E    */     SWAP_33          : ;
/*     SWAP H    */     SWAP_34          : ;
/*     SWAP L    */     SWAP_35          : ;
/*   SWAP (HL)   */     SWAP_36_0        : ;
                        SWAP_36_1        : ;
                        SWAP_36_2        : ;
/*     SWAP A    */     SWAP_37          : ;
/*     SRL B     */     SRL_38           : ;
/*     SRL C     */     SRL_39           : ;
/*     SRL D     */     SRL_3A           : ;
/*     SRL E     */     SRL_3B           : ;
/*     SRL H     */     SRL_3C           : ;
/*     SRL L     */     SRL_3D           : ;
/*    SRL (HL)   */     SRL_3E_0         : ;
                        SRL_3E_1         : ;
                        SRL_3E_2         : ;
/*     SRL A     */     SRL_3F           : ;
/*    BIT 0 B    */     BIT_40           : ;
/*    BIT 0 C    */     BIT_41           : ;
/*    BIT 0 D    */     BIT_42           : ;
/*    BIT 0 E    */     BIT_43           : ;
/*    BIT 0 H    */     BIT_44           : ;
/*    BIT 0 L    */     BIT_45           : ;
/*   BIT 0 (HL)  */     BIT_46_0         : ;
                        BIT_46_1         : ;
/*    BIT 0 A    */     BIT_47           : ;
/*    BIT 1 B    */     BIT_48           : ;
/*    BIT 1 C    */     BIT_49           : ;
/*    BIT 1 D    */     BIT_4A           : ;
/*    BIT 1 E    */     BIT_4B           : ;
/*    BIT 1 H    */     BIT_4C           : ;
/*    BIT 1 L    */     BIT_4D           : ;
/*   BIT 1 (HL)  */     BIT_4E_0         : ;
                        BIT_4E_1         : ;
/*    BIT 1 A    */     BIT_4F           : ;
/*    BIT 2 B    */     BIT_50           : ;
/*    BIT 2 C    */     BIT_51           : ;
/*    BIT 2 D    */     BIT_52           : ;
/*    BIT 2 E    */     BIT_53           : ;
/*    BIT 2 H    */     BIT_54           : ;
/*    BIT 2 L    */     BIT_55           : ;
/*   BIT 2 (HL)  */     BIT_56_0         : ;
                        BIT_56_1         : ;
/*    BIT 2 A    */     BIT_57           : ;
/*    BIT 3 B    */     BIT_58           : ;
/*    BIT 3 C    */     BIT_59           : ;
/*    BIT 3 D    */     BIT_5A           : ;
/*    BIT 3 E    */     BIT_5B           : ;
/*    BIT 3 H    */     BIT_5C           : ;
/*    BIT 3 L    */     BIT_5D           : ;
/*   BIT 3 (HL)  */     BIT_5E_0         : ;
                        BIT_5E_1         : ;
/*    BIT 3 A    */     BIT_5F           : ;
/*    BIT 4 B    */     BIT_60           : ;
/*    BIT 4 C    */     BIT_61           : ;
/*    BIT 4 D    */     BIT_62           : ;
/*    BIT 4 E    */     BIT_63           : ;
/*    BIT 4 H    */     BIT_64           : ;
/*    BIT 4 L    */     BIT_65           : ;
/*   BIT 4 (HL)  */     BIT_66_0         : ;
                        BIT_66_1         : ;
/*    BIT 4 A    */     BIT_67           : ;
/*    BIT 5 B    */     BIT_68           : ;
/*    BIT 5 C    */     BIT_69           : ;
/*    BIT 5 D    */     BIT_6A           : ;
/*    BIT 5 E    */     BIT_6B           : ;
/*    BIT 5 H    */     BIT_6C           : ;
/*    BIT 5 L    */     BIT_6D           : ;
/*   BIT 5 (HL)  */     BIT_6E_0         : ;
                        BIT_6E_1         : ;
/*    BIT 5 A    */     BIT_6F           : ;
/*    BIT 6 B    */     BIT_70           : ;
/*    BIT 6 C    */     BIT_71           : ;
/*    BIT 6 D    */     BIT_72           : ;
/*    BIT 6 E    */     BIT_73           : ;
/*    BIT 6 H    */     BIT_74           : ;
/*    BIT 6 L    */     BIT_75           : ;
/*   BIT 6 (HL)  */     BIT_76_0         : ;
                        BIT_76_1         : ;
/*    BIT 6 A    */     BIT_77           : ;
/*    BIT 7 B    */     BIT_78           : ;
/*    BIT 7 C    */     BIT_79           : ;
/*    BIT 7 D    */     BIT_7A           : ;
/*    BIT 7 E    */     BIT_7B           : ;
/*    BIT 7 H    */     BIT_7C           : `BIT(7,H)
/*    BIT 7 L    */     BIT_7D           : ;
/*   BIT 7 (HL)  */     BIT_7E_0         : ;
                        BIT_7E_1         : ;
/*    BIT 7 A    */     BIT_7F           : ;
/*    RES 0 B    */     RES_80           : ;
/*    RES 0 C    */     RES_81           : ;
/*    RES 0 D    */     RES_82           : ;
/*    RES 0 E    */     RES_83           : ;
/*    RES 0 H    */     RES_84           : ;
/*    RES 0 L    */     RES_85           : ;
/*   RES 0 (HL)  */     RES_86_0         : ;
                        RES_86_1         : ;
                        RES_86_2         : ;
/*    RES 0 A    */     RES_87           : ;
/*    RES 1 B    */     RES_88           : ;
/*    RES 1 C    */     RES_89           : ;
/*    RES 1 D    */     RES_8A           : ;
/*    RES 1 E    */     RES_8B           : ;
/*    RES 1 H    */     RES_8C           : ;
/*    RES 1 L    */     RES_8D           : ;
/*   RES 1 (HL)  */     RES_8E_0         : ;
                        RES_8E_1         : ;
                        RES_8E_2         : ;
/*    RES 1 A    */     RES_8F           : ;
/*    RES 2 B    */     RES_90           : ;
/*    RES 2 C    */     RES_91           : ;
/*    RES 2 D    */     RES_92           : ;
/*    RES 2 E    */     RES_93           : ;
/*    RES 2 H    */     RES_94           : ;
/*    RES 2 L    */     RES_95           : ;
/*   RES 2 (HL)  */     RES_96_0         : ;
                        RES_96_1         : ;
                        RES_96_2         : ;
/*    RES 2 A    */     RES_97           : ;
/*    RES 3 B    */     RES_98           : ;
/*    RES 3 C    */     RES_99           : ;
/*    RES 3 D    */     RES_9A           : ;
/*    RES 3 E    */     RES_9B           : ;
/*    RES 3 H    */     RES_9C           : ;
/*    RES 3 L    */     RES_9D           : ;
/*   RES 3 (HL)  */     RES_9E_0         : ;
                        RES_9E_1         : ;
                        RES_9E_2         : ;
/*    RES 3 A    */     RES_9F           : ;
/*    RES 4 B    */     RES_A0           : ;
/*    RES 4 C    */     RES_A1           : ;
/*    RES 4 D    */     RES_A2           : ;
/*    RES 4 E    */     RES_A3           : ;
/*    RES 4 H    */     RES_A4           : ;
/*    RES 4 L    */     RES_A5           : ;
/*   RES 4 (HL)  */     RES_A6_0         : ;
                        RES_A6_1         : ;
                        RES_A6_2         : ;
/*    RES 4 A    */     RES_A7           : ;
/*    RES 5 B    */     RES_A8           : ;
/*    RES 5 C    */     RES_A9           : ;
/*    RES 5 D    */     RES_AA           : ;
/*    RES 5 E    */     RES_AB           : ;
/*    RES 5 H    */     RES_AC           : ;
/*    RES 5 L    */     RES_AD           : ;
/*   RES 5 (HL)  */     RES_AE_0         : ;
                        RES_AE_1         : ;
                        RES_AE_2         : ;
/*    RES 5 A    */     RES_AF           : ;
/*    RES 6 B    */     RES_B0           : ;
/*    RES 6 C    */     RES_B1           : ;
/*    RES 6 D    */     RES_B2           : ;
/*    RES 6 E    */     RES_B3           : ;
/*    RES 6 H    */     RES_B4           : ;
/*    RES 6 L    */     RES_B5           : ;
/*   RES 6 (HL)  */     RES_B6_0         : ;
                        RES_B6_1         : ;
                        RES_B6_2         : ;
/*    RES 6 A    */     RES_B7           : ;
/*    RES 7 B    */     RES_B8           : ;
/*    RES 7 C    */     RES_B9           : ;
/*    RES 7 D    */     RES_BA           : ;
/*    RES 7 E    */     RES_BB           : ;
/*    RES 7 H    */     RES_BC           : ;
/*    RES 7 L    */     RES_BD           : ;
/*   RES 7 (HL)  */     RES_BE_0         : ;
                        RES_BE_1         : ;
                        RES_BE_2         : ;
/*    RES 7 A    */     RES_BF           : ;
/*    SET 0 B    */     SET_C0           : ;
/*    SET 0 C    */     SET_C1           : ;
/*    SET 0 D    */     SET_C2           : ;
/*    SET 0 E    */     SET_C3           : ;
/*    SET 0 H    */     SET_C4           : ;
/*    SET 0 L    */     SET_C5           : ;
/*   SET 0 (HL)  */     SET_C6_0         : ;
                        SET_C6_1         : ;
                        SET_C6_2         : ;
/*    SET 0 A    */     SET_C7           : ;
/*    SET 1 B    */     SET_C8           : ;
/*    SET 1 C    */     SET_C9           : ;
/*    SET 1 D    */     SET_CA           : ;
/*    SET 1 E    */     SET_CB           : ;
/*    SET 1 H    */     SET_CC           : ;
/*    SET 1 L    */     SET_CD           : ;
/*   SET 1 (HL)  */     SET_CE_0         : ;
                        SET_CE_1         : ;
                        SET_CE_2         : ;
/*    SET 1 A    */     SET_CF           : ;
/*    SET 2 B    */     SET_D0           : ;
/*    SET 2 C    */     SET_D1           : ;
/*    SET 2 D    */     SET_D2           : ;
/*    SET 2 E    */     SET_D3           : ;
/*    SET 2 H    */     SET_D4           : ;
/*    SET 2 L    */     SET_D5           : ;
/*   SET 2 (HL)  */     SET_D6_0         : ;
                        SET_D6_1         : ;
                        SET_D6_2         : ;
/*    SET 2 A    */     SET_D7           : ;
/*    SET 3 B    */     SET_D8           : ;
/*    SET 3 C    */     SET_D9           : ;
/*    SET 3 D    */     SET_DA           : ;
/*    SET 3 E    */     SET_DB           : ;
/*    SET 3 H    */     SET_DC           : ;
/*    SET 3 L    */     SET_DD           : ;
/*   SET 3 (HL)  */     SET_DE_0         : ;
                        SET_DE_1         : ;
                        SET_DE_2         : ;
/*    SET 3 A    */     SET_DF           : ;
/*    SET 4 B    */     SET_E0           : ;
/*    SET 4 C    */     SET_E1           : ;
/*    SET 4 D    */     SET_E2           : ;
/*    SET 4 E    */     SET_E3           : ;
/*    SET 4 H    */     SET_E4           : ;
/*    SET 4 L    */     SET_E5           : ;
/*   SET 4 (HL)  */     SET_E6_0         : ;
                        SET_E6_1         : ;
                        SET_E6_2         : ;
/*    SET 4 A    */     SET_E7           : ;
/*    SET 5 B    */     SET_E8           : ;
/*    SET 5 C    */     SET_E9           : ;
/*    SET 5 D    */     SET_EA           : ;
/*    SET 5 E    */     SET_EB           : ;
/*    SET 5 H    */     SET_EC           : ;
/*    SET 5 L    */     SET_ED           : ;
/*   SET 5 (HL)  */     SET_EE_0         : ;
                        SET_EE_1         : ;
                        SET_EE_2         : ;
/*    SET 5 A    */     SET_EF           : ;
/*    SET 6 B    */     SET_F0           : ;
/*    SET 6 C    */     SET_F1           : ;
/*    SET 6 D    */     SET_F2           : ;
/*    SET 6 E    */     SET_F3           : ;
/*    SET 6 H    */     SET_F4           : ;
/*    SET 6 L    */     SET_F5           : ;
/*   SET 6 (HL)  */     SET_F6_0         : ;
                        SET_F6_1         : ;
                        SET_F6_2         : ;
/*    SET 6 A    */     SET_F7           : ;
/*    SET 7 B    */     SET_F8           : ;
/*    SET 7 C    */     SET_F9           : ;
/*    SET 7 D    */     SET_FA           : ;
/*    SET 7 E    */     SET_FB           : ;
/*    SET 7 H    */     SET_FC           : ;
/*    SET 7 L    */     SET_FD           : ;
/*   SET 7 (HL)  */     SET_FE_0         : ;
                        SET_FE_1         : ;
                        SET_FE_2         : ;
/*    SET 7 A    */     SET_FF           : ;
						default          : ;
	endcase
end 



endmodule