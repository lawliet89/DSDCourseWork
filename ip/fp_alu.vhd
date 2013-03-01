-- Copyright (C) 1991-2012 Altera Corporation
-- Your use of Altera Corporation's design tools, logic functions 
-- and other software and tools, and its AMPP partner logic 
-- functions, and any output files from any of the foregoing 
-- (including device programming or simulation files), and any 
-- associated documentation or information are expressly subject 
-- to the terms and conditions of the Altera Program License 
-- Subscription Agreement, Altera MegaCore Function License 
-- Agreement, or other applicable license agreement, including, 
-- without limitation, that your use is for the sole purpose of 
-- programming logic devices manufactured by Altera and sold by 
-- Altera or its authorized distributors.  Please refer to the 
-- applicable agreement for further details.

-- PROGRAM		"Quartus II 64-Bit"
-- VERSION		"Version 12.0 Build 178 05/31/2012 SJ Full Version"
-- CREATED		"Fri Mar 01 19:24:42 2013"

LIBRARY ieee;
USE ieee.std_logic_1164.all; 

LIBRARY work;

ENTITY fp_alu IS 
	PORT
	(
		clk :  IN  STD_LOGIC;
		clk_en :  IN  STD_LOGIC;
		start :  IN  STD_LOGIC;
		reset :  IN  STD_LOGIC;
		dataa :  IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		datab :  IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		n :  IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
		done :  OUT  STD_LOGIC;
		result :  OUT  STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
END fp_alu;

ARCHITECTURE bdf_type OF fp_alu IS 

COMPONENT fp_add
	PORT(add_sub : IN STD_LOGIC;
		 clock : IN STD_LOGIC;
		 clk_en : IN STD_LOGIC;
		 aclr : IN STD_LOGIC;
		 dataa : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		 datab : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		 NaN : OUT STD_LOGIC;
		 zero : OUT STD_LOGIC;
		 result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
END COMPONENT;

COMPONENT fp_mult
	PORT(clk_en : IN STD_LOGIC;
		 clock : IN STD_LOGIC;
		 aclr : IN STD_LOGIC;
		 dataa : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		 datab : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		 nan : OUT STD_LOGIC;
		 zero : OUT STD_LOGIC;
		 result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
END COMPONENT;

COMPONENT const_6
	PORT(		 result : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
	);
END COMPONENT;

COMPONENT const_4
	PORT(		 result : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
	);
END COMPONENT;

COMPONENT fp_div
	PORT(clock : IN STD_LOGIC;
		 clk_en : IN STD_LOGIC;
		 aclr : IN STD_LOGIC;
		 dataa : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		 datab : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		 NaN : OUT STD_LOGIC;
		 zero : OUT STD_LOGIC;
		 result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
END COMPONENT;

COMPONENT const_5
	PORT(		 result : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
	);
END COMPONENT;

COMPONENT four_input_bus_mux
	PORT(data0x : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		 data1x : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		 data2x : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		 data3x : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		 sel : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
		 result : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
END COMPONENT;

COMPONENT fp_alu_counter
	PORT(sload : IN STD_LOGIC;
		 clock : IN STD_LOGIC;
		 clk_en : IN STD_LOGIC;
		 aclr : IN STD_LOGIC;
		 data : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		 q : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
	);
END COMPONENT;

COMPONENT four_input_4bit_mux
	PORT(data0x : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		 data1x : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		 data2x : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		 data3x : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		 sel : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
		 result : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
	);
END COMPONENT;

SIGNAL	counter :  STD_LOGIC_VECTOR(3 DOWNTO 0);
SIGNAL	SYNTHESIZED_WIRE_0 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_10 :  STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL	SYNTHESIZED_WIRE_3 :  STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL	SYNTHESIZED_WIRE_4 :  STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL	SYNTHESIZED_WIRE_5 :  STD_LOGIC_VECTOR(3 DOWNTO 0);
SIGNAL	SYNTHESIZED_WIRE_11 :  STD_LOGIC_VECTOR(3 DOWNTO 0);
SIGNAL	SYNTHESIZED_WIRE_8 :  STD_LOGIC_VECTOR(3 DOWNTO 0);
SIGNAL	SYNTHESIZED_WIRE_9 :  STD_LOGIC_VECTOR(3 DOWNTO 0);


BEGIN 



b2v_inst : fp_add
PORT MAP(add_sub => SYNTHESIZED_WIRE_0,
		 clock => clk,
		 clk_en => clk_en,
		 aclr => reset,
		 dataa => dataa,
		 datab => datab,
		 result => SYNTHESIZED_WIRE_10);


b2v_inst1 : fp_mult
PORT MAP(clk_en => clk_en,
		 clock => clk,
		 aclr => reset,
		 dataa => dataa,
		 datab => datab,
		 result => SYNTHESIZED_WIRE_3);


b2v_inst10 : const_6
PORT MAP(		 result => SYNTHESIZED_WIRE_11);


b2v_inst11 : const_4
PORT MAP(		 result => SYNTHESIZED_WIRE_8);


b2v_inst2 : fp_div
PORT MAP(clock => clk,
		 clk_en => clk_en,
		 aclr => reset,
		 dataa => dataa,
		 datab => datab,
		 result => SYNTHESIZED_WIRE_4);


SYNTHESIZED_WIRE_0 <= NOT(n(0));



b2v_inst5 : const_5
PORT MAP(		 result => SYNTHESIZED_WIRE_9);


b2v_inst6 : four_input_bus_mux
PORT MAP(data0x => SYNTHESIZED_WIRE_10,
		 data1x => SYNTHESIZED_WIRE_10,
		 data2x => SYNTHESIZED_WIRE_3,
		 data3x => SYNTHESIZED_WIRE_4,
		 sel => n,
		 result => result);


b2v_inst7 : fp_alu_counter
PORT MAP(sload => start,
		 clock => clk,
		 clk_en => clk_en,
		 aclr => reset,
		 data => SYNTHESIZED_WIRE_5,
		 q => counter);


done <= NOT(counter(3) OR counter(1) OR counter(2) OR counter(0));


b2v_inst9 : four_input_4bit_mux
PORT MAP(data0x => SYNTHESIZED_WIRE_11,
		 data1x => SYNTHESIZED_WIRE_11,
		 data2x => SYNTHESIZED_WIRE_8,
		 data3x => SYNTHESIZED_WIRE_9,
		 sel => n,
		 result => SYNTHESIZED_WIRE_5);


END bdf_type;