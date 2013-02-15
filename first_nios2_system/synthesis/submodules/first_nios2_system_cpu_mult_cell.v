//Legal Notice: (C)2013 Altera Corporation. All rights reserved.  Your
//use of Altera Corporation's design tools, logic functions and other
//software and tools, and its AMPP partner logic functions, and any
//output files any of the foregoing (including device programming or
//simulation files), and any associated documentation or information are
//expressly subject to the terms and conditions of the Altera Program
//License Subscription Agreement or other applicable license agreement,
//including, without limitation, that your use is for the sole purpose
//of programming logic devices manufactured by Altera and sold by Altera
//or its authorized distributors.  Please refer to the applicable
//agreement for further details.

// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on

// turn off superfluous verilog processor warnings 
// altera message_level Level1 
// altera message_off 10034 10035 10036 10037 10230 10240 10030 

module first_nios2_system_cpu_mult_cell (
                                          // inputs:
                                           M_mul_src1,
                                           M_mul_src2,
                                           clk,
                                           reset_n,

                                          // outputs:
                                           M_mul_cell_result
                                        )
;

  output  [ 31: 0] M_mul_cell_result;
  input   [ 31: 0] M_mul_src1;
  input   [ 31: 0] M_mul_src2;
  input            clk;
  input            reset_n;

  wire    [ 31: 0] M_mul_cell_result;
  wire             mul_clr;
  assign mul_clr = ~reset_n;
  altmult_add the_altmult_add
    (
      .aclr3 (mul_clr),
      .clock0 (clk),
      .dataa (M_mul_src1),
      .datab (M_mul_src2[3 : 0]),
      .ena0 (1'b1),
      .result (M_mul_cell_result)
    );

  defparam the_altmult_add.addnsub_multiplier_pipeline_aclr1 = "ACLR3",
           the_altmult_add.addnsub_multiplier_pipeline_register1 = "CLOCK0",
           the_altmult_add.addnsub_multiplier_register1 = "UNREGISTERED",
           the_altmult_add.dedicated_multiplier_circuitry = "NO",
           the_altmult_add.input_register_a0 = "UNREGISTERED",
           the_altmult_add.input_register_b0 = "UNREGISTERED",
           the_altmult_add.input_source_a0 = "DATAA",
           the_altmult_add.input_source_b0 = "DATAB",
           the_altmult_add.intended_device_family = "CYCLONEIII",
           the_altmult_add.lpm_type = "altmult_add",
           the_altmult_add.multiplier1_direction = "ADD",
           the_altmult_add.multiplier_aclr0 = "ACLR3",
           the_altmult_add.multiplier_register0 = "CLOCK0",
           the_altmult_add.number_of_multipliers = 1,
           the_altmult_add.output_register = "UNREGISTERED",
           the_altmult_add.port_addnsub1 = "PORT_UNUSED",
           the_altmult_add.port_signa = "PORT_UNUSED",
           the_altmult_add.port_signb = "PORT_UNUSED",
           the_altmult_add.representation_a = "UNSIGNED",
           the_altmult_add.representation_b = "UNSIGNED",
           the_altmult_add.signed_pipeline_aclr_a = "ACLR3",
           the_altmult_add.signed_pipeline_aclr_b = "ACLR3",
           the_altmult_add.signed_pipeline_register_a = "CLOCK0",
           the_altmult_add.signed_pipeline_register_b = "CLOCK0",
           the_altmult_add.signed_register_a = "UNREGISTERED",
           the_altmult_add.signed_register_b = "UNREGISTERED",
           the_altmult_add.width_a = 32,
           the_altmult_add.width_b = 4,
           the_altmult_add.width_result = 32;


endmodule

