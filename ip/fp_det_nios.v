
// fp_det_nios.v

// This file was auto-generated as a prototype implementation of a module
// created in component editor.  It ties off all outputs to ground and
// ignores all inputs.  It needs to be edited to make it do something
// useful.
// 
// This file will not be automatically regenerated.  You should check it in
// to your version control system if you want to keep it.

//`timescale 1 ps / 1 ps
module fp_det_nios (
	    input  wire        avalon_clk,    //                    clock_sink.clk
        input  wire        avalon_reset,  //                    reset_sink.reset
        input  wire        clk,           // nios_custom_instruction_slave.clk
        input  wire [31:0] dataa,         //                              .dataa
        input  wire [31:0] datab,         //                              .datab
        output reg [31:0] result,        //                              .result
        input  wire        clk_en,        //                              .clk_en
        input  wire        start,         //                              .start
        output reg        done,          //                              .done
		input  wire	      reset,		//								 .reset
        output wire [23:0] address,       //                 avalon_master.address
        output wire        read,          //                              .read
        input  wire [31:0] readdata,      //                              .readdata
        input  wire        readdatavalid, //                              .readdatavalid
        input  wire        waitrequest,   //                              .waitrequest
        output wire        write,         //                              .write
        output wire [31:0] writedata,     //                              .writedata
        input  wire        n_set,         //                  avalon_slave.write
        input  wire [7:0]  n              //                              .writedata
    );

	parameter AUTO_CLOCK_SINK_CLOCK_RATE = "-1";
	parameter DEFAULT_DIMENSION = 10;
	reg [7:0] dimension = DEFAULT_DIMENSION;

    //assign result = 32'b00000000000000000000000000000000;

    //assign done = 1'b0;

    //assign writedata = 32'b00000000000000000000000000000000;

    //assign address = 24'b000000000000000000000000;

    //assign write = 1'b0;

    //assign read = 1'b0;

	
	// handle setting of dimension
	always @ (posedge avalon_clk) begin
		if (n_set) begin
			if (n >= 2 && n <= 32) begin	// check for bounds
				dimension <= n;
			end
		end
	end
	
	// handle nios custom instruction
	always @ (posedge clk) begin
		if (start) begin
			done <= 1;
			result <= dimension;
		end
	
	end

endmodule
