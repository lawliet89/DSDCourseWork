
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
        output reg [23:0] address,       //                 avalon_master.address
        output reg        read,          //                              .read
        input  wire [31:0] readdata,      //                              .readdata
        input  wire        readdatavalid, //                              .readdatavalid
        input  wire        waitrequest,   //                              .waitrequest
        output reg        write,         //                              .write
        output reg [31:0] writedata,     //                              .writedata
        input  wire        n_set,         //                  avalon_slave.write
        input  wire [7:0]  n              //                              .writedata
    );

	parameter AUTO_CLOCK_SINK_CLOCK_RATE = "-1";
	parameter DEFAULT_DIMENSION = 10;
	
	reg [7:0] dimension = DEFAULT_DIMENSION;	// stored dimension of matrix, minus 1
	reg [15:0] readRequestCounter;
	reg [15:0] readReceiveCounter;
	reg [23:0] sdReadAddress;
	reg [23:0] sdWriteAddress;
	reg [9:0] ramLoadAddress;
	
	/* Stages:
		0 - Idle, waiting for CPU start
		1 - Reading from SDRAM
		2 - Passing control off to calculate, when done, output
	*/
	reg [1:0] stage = 0;		// stage of computation
	reg [31:0] finalResult = 0;
	
	reg [9:0] ramReadAddress;
	reg [9:0] ramWriteAddress;
	wire [31:0] ramReadData;
	reg [31:0] ramWriteData;
	reg ramWriteEnable;
	reg ramReadEnable;
	
	// instantiate ram
	ram_det ram_inst(
		.clock(clk),
		.data(ramWriteData),
		.rdaddress(ramReadAddress),
		.wraddress(ramWriteAddress),
		.wren(ramWriteEnable),
		.rden(ramReadEnable),
		.q(ramReadData)	
	);
	
	
	reg detStart;
	wire detDone;
	wire [31:0] detResult;
	wire [9:0] detRamReadAddress;
	wire [9:0] detRamWriteAddress;
	reg [31:0] detRamReadData;
	wire [31:0] detRamWriteData;
	wire detRamWriteEnable;
	wire detRamReadEnable;
	
	// instantiate determinant calculating module
/*	fp_det det_inst(
		.clk(clk),
		.clk_en(clk_en),
		.start(detStart),
		.reset(reset),
		.n(dimension[5:0]),
		.readdata(detRamReadData),
		.writedata(detRamWriteData),
		.wraddress(detRamWriteAddress),
		.raddress(detRamReadAddress),
		.wren(detRamWriteEnable),
		.rden(detRamReadEnable)
		.done(detDone),
		.result(detResult)
	); */

    //assign result = 32'b00000000000000000000000000000000;
    //assign done = 1'b0;
    //assign writedata = 32'b00000000000000000000000000000000;
    //assign address = 24'b000000000000000000000000;
    //assign write = 1'b0;
    //assign read = 1'b0;

	
	// handle setting of dimension
	always @ (posedge avalon_clk) begin
		if (n_set && stage == 0) begin
			if (n >= 2 && n <= 32) begin	// check for bounds
				dimension <= n;
			end
		end
	end
	
	// handle nios custom instruction
	always @ (posedge clk) begin
		// we get a reset command
		if (reset) begin
			stage <= 0;
			done <= 0;
			result <= 0;
			
			// Avalon master
			read <= 0;
			write <= 0;
			address <= 0;
			writedata <= 0;
			
			detStart <= 0;
			
			// RAM stuff
			ramReadAddress <= 0;
			ramWriteAddress <= 0;
			ramWriteData <= 0;
			ramWriteEnable <= 0;
			ramReadEnable <= 0;
			
		end else if (stage == 0) begin   // start command
			if (start) begin
				stage <= 1;
				readRequestCounter <= dimension*dimension;
				readReceiveCounter <= dimension*dimension;
				sdReadAddress <= dataa[23:0];
				sdWriteAddress <= datab[23:0];
				ramLoadAddress <= 0;
			end
			result <= 0;
			done <= 0;
			
			// Avalon master
			read <= 0;
			write <= 0;
			address <= 0;
			writedata <= 0;
			
			detStart <= 0;
			
			// RAM stuff
			ramReadAddress <= 0;
			ramWriteAddress <= 0;
			ramWriteData <= 0;
			ramWriteEnable <= 0;
			ramReadEnable <= 0;
			
		end else if (stage == 1) begin  // read from SDRAM
			result <= 0;
			done <= 0;
			
			write <= 0;
			writedata <= 0;
					
			if (readRequestCounter > 0) begin
				read <= 1;
				address <= sdReadAddress;
			end 
			
			// Request Pipeline
			if (!waitrequest && readRequestCounter > 0) begin
				sdReadAddress <= sdReadAddress + 4;
				readRequestCounter <= readRequestCounter - 1;
			end else if (!waitrequest && readRequestCounter == 0) begin // potential problem area
				address <= sdReadAddress;
				read <= 0;
			end
			
			// Receive pipeline
			if (readdatavalid) begin
				ramWriteEnable <= 1;
				ramWriteAddress  <= ramLoadAddress;
				ramWriteData <= readdata;
				ramLoadAddress <= ramLoadAddress + 4;
				readReceiveCounter <= readReceiveCounter - 1;
			end else if (!readdatavalid) begin
				ramWriteEnable <= 0;
				ramWriteAddress  <= 0;
				ramWriteData <= 0;
			end
			
			if (readReceiveCounter == 0) begin		// start calculating
				detStart <= 1;
				stage <= 2;
				
				// RAM stuff - connect RAM controls with determinant module
				//ramReadAddress <= detRamReadAddress;
				//ramWriteAddress <= detRamWriteAddress;
				//ramWriteData <= detRamWriteAddress;
				//ramWriteEnable <= detRamWriteAddress;
				//ramReadEnable <= detRamReadEnable;
				//detRamReadData <= ramReadData;
			end
			
		end else if (stage == 2) begin	// calculating
			ramReadAddress <= 0;
			ramReadEnable <= 1;
			result <= 0;
			done <= 0;
			stage <= 3;
		/*	if (detDone) begin  // done
				stage <= 0;
				finalResult <= detResult;
				
				result <= detResult;
				done <= 1;
				
				// RAM stuff
				ramReadAddress <= 0;
				ramWriteAddress <= 0;
				ramWriteData <= 0;
				ramWriteEnable <= 0;
				ramReadEnable <= 0;
			end else begin    // still calculating
				done <= 0;
				result <= 0;
							
				// RAM stuff - connect RAM controls with determinant module
				ramReadAddress <= detRamReadAddress;
				ramWriteAddress <= detRamWriteAddress;
				ramWriteData <= detRamWriteAddress;
				ramWriteEnable <= detRamWriteAddress;
				ramReadEnable <= detRamReadEnable;
				detRamReadData <= ramReadData;
			end
		*/	
			// Avalon master
			read <= 0;
			write <= 0;
			address <= 0;
			writedata <= 0;
			
			detStart <= 0;
		end else if (stage == 3) begin
			done <= 1;
			result <= ramReadData;
			ramReadAddress <= 0;
			ramReadEnable <= 0;
			stage <= 0;
		end
	end

endmodule
