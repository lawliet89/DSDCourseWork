// Copyright (C) 1991-2012 Altera Corporation
// Your use of Altera Corporation's design tools, logic functions 
// and other software and tools, and its AMPP partner logic 
// functions, and any output files from any of the foregoing 
// (including device programming or simulation files), and any 
// associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License 
// Subscription Agreement, Altera MegaCore Function License 
// Agreement, or other applicable license agreement, including, 
// without limitation, that your use is for the sole purpose of 
// programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the 
// applicable agreement for further details.

// PROGRAM		"Quartus II 64-Bit"
// VERSION		"Version 12.0 Build 178 05/31/2012 SJ Full Version"
// CREATED		"Fri Feb 22 10:42:29 2013"

module fp_alu(
	clk,
	clk_en,
	start,
	reset,
	dataa,
	datab,
	n,
	done,
	result
);


input wire	clk;
input wire	clk_en;
input wire	start;
input wire	reset;
input wire	[31:0] dataa;
input wire	[31:0] datab;
input wire	[1:0] n;
output wire	done;
output wire	[31:0] result;

wire	[3:0] counter;
wire	SYNTHESIZED_WIRE_0;
wire	[31:0] SYNTHESIZED_WIRE_10;
wire	[31:0] SYNTHESIZED_WIRE_3;
wire	[31:0] SYNTHESIZED_WIRE_4;
wire	[3:0] SYNTHESIZED_WIRE_5;
wire	[3:0] SYNTHESIZED_WIRE_11;
wire	[3:0] SYNTHESIZED_WIRE_8;





fp_add	b2v_inst(
	.add_sub(SYNTHESIZED_WIRE_0),
	.clock(clk),
	.clk_en(clk_en),
	.aclr(reset),
	.dataa(dataa),
	.datab(datab),
	
	
	
	
	.result(SYNTHESIZED_WIRE_10));


fp_mult	b2v_inst1(
	.clk_en(clk_en),
	.clock(clk),
	.aclr(reset),
	.dataa(dataa),
	.datab(datab),
	
	
	
	
	.result(SYNTHESIZED_WIRE_3));


const_13	b2v_inst10(
	.result(SYNTHESIZED_WIRE_11));


const_10	b2v_inst11(
	.result(SYNTHESIZED_WIRE_8));


fp_div	b2v_inst2(
	.clock(clk),
	.clk_en(clk_en),
	.aclr(reset),
	.dataa(dataa),
	.datab(datab),
	
	
	
	
	.result(SYNTHESIZED_WIRE_4));

assign	SYNTHESIZED_WIRE_0 =  ~n[0];


four_input_bus_mux	b2v_inst6(
	.data0x(SYNTHESIZED_WIRE_10),
	.data1x(SYNTHESIZED_WIRE_10),
	.data2x(SYNTHESIZED_WIRE_3),
	.data3x(SYNTHESIZED_WIRE_4),
	.sel(n),
	.result(result));


fp_alu_counter	b2v_inst7(
	.sload(start),
	.clock(clk),
	.clk_en(clk_en),
	.aclr(reset),
	.data(SYNTHESIZED_WIRE_5),
	.q(counter));

assign	done = ~(counter[3] | counter[1] | counter[2] | counter[0]);


four_input_4bit_mux	b2v_inst9(
	.data0x(SYNTHESIZED_WIRE_11),
	.data1x(SYNTHESIZED_WIRE_11),
	.data2x(SYNTHESIZED_WIRE_8),
	.data3x(SYNTHESIZED_WIRE_11),
	.sel(n),
	.result(SYNTHESIZED_WIRE_5));


endmodule
