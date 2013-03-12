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
// CREATED		"Fri Feb 08 12:27:14 2013"

module hello_world(
	CLOCK_50,
	DRAM_CAS_N,
	DRAM_CKE,
	DRAM_CS_N,
	DRAM_RAS_N,
	DRAM_WE_N,
	DRAM_CLK,
	DRAM_DQ,
	DRAM_A,
	DRAM_BA,
	DRAM_DQM,
	fl_addr,
	fl_ce_n,
	fl_oe_n,
	fl_we_n,
	fl_rst_n,
	fl_dq
);


input wire	CLOCK_50;
output wire	DRAM_CAS_N;
output wire	DRAM_CKE;
output wire	DRAM_CS_N;
output wire	DRAM_RAS_N;
output wire	DRAM_WE_N;
output wire	DRAM_CLK;
inout wire	[15:0] DRAM_DQ;
output wire	[11:0] DRAM_A;
output wire	[1:0] DRAM_BA;
output wire	[1:0] DRAM_DQM;
//output wire	[7:0] LEDG;

// flash stuff
output wire [21:0] fl_addr;
output wire fl_ce_n;
output wire fl_oe_n;
output wire fl_we_n;
output wire fl_rst_n;
inout wire [7:0] fl_dq;


wire	SYNTHESIZED_WIRE_0;
assign	SYNTHESIZED_WIRE_0 = 1;

wire PLL_external_clk;
assign DRAM_CLK = PLL_external_clk;

first_nios2_system	b2v_inst(
	.clk_clk(CLOCK_50),
	.reset_reset_n(SYNTHESIZED_WIRE_0),
//	.led_pio_external_connection_export(LEDG),
	.sdram_wire_addr                    (DRAM_A),                    // sdram_wire.addr - not entirely sure???
	.sdram_wire_ba                      (DRAM_BA),                      //                            .ba
	.sdram_wire_cas_n                   (DRAM_CAS_N),                   //                            .cas_n
	.sdram_wire_cke                     (DRAM_CKE),                     //                            .cke
	.sdram_wire_cs_n                    (DRAM_CS_N),                    //                            .cs_n
	.sdram_wire_dq                      (DRAM_DQ),                      //                            .dq
	.sdram_wire_dqm                     (DRAM_DQM),                     //                            .dqm
	.sdram_wire_ras_n                   (DRAM_RAS_N),                   //                            .ras_n
	.sdram_wire_we_n                    (DRAM_WE_N),                     //                            .we_n
	.pll_c0_clk             (PLL_external_clk),            
	.flash_slave_conduit_ADDR  (fl_addr),  // flash_slave_conduit.ADDR
	.flash_slave_conduit_CE_N  (fl_ce_n),  //                    .CE_N
	.flash_slave_conduit_OE_N  (fl_oe_n),  //                    .OE_N
	.flash_slave_conduit_WE_N  (fl_we_n),  //                    .WE_N
	.flash_slave_conduit_RST_N (fl_rst_n), //                    .RST_N
	.flash_slave_conduit_DQ    (fl_dq)     //                    .DQ  
	);



endmodule
