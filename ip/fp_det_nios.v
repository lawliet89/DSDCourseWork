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
        input  wire        result_read,     //                  avalon_slave.read
        output reg [31:0] result_readdata, //                              .readdata
        output reg        irq              //              interrupt_sender.irq
    );

	parameter AUTO_CLOCK_SINK_CLOCK_RATE = "-1";
	parameter DEFAULT_DIMENSION = 8'd16;
	
	reg [7:0] dimension = DEFAULT_DIMENSION;
	reg [23:0] sdReadBase;
	reg [23:0] sdReadAddress;
	reg [9:0] ramLoadAddress;
	reg startSdRead = 0;
	reg ramWriteDone = 0;
	
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
	fp_det det_inst(
		.clk(clk),
		.clk_en(clk_en),
		.start(detStart),
		.reset(reset),
		.n(dimension[5:0]),
		.readdata(detRamReadData),
		.writedata(detRamWriteData),
		.wraddress(detRamWriteAddress),
		.rdaddress(detRamReadAddress),
		.wren(detRamWriteEnable),
		.rden(detRamReadEnable),
		.done(detDone),
		.result(detResult)
	); 


	

	always @ (posedge clk) begin
			
		// we get a reset command
		if (reset) begin
			stage <= 0;
			done <= 0;
			result <= 0;
			irq <= 0;
			
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
			
			startSdRead <= 0;
			ramWriteDone <= 0;
			sdReadAddress <= 0;
			ramLoadAddress <= 0;
			
			dimension <= DEFAULT_DIMENSION;
			finalResult <= 0;
			

		end else if (stage == 0) begin   // idle state. doing nothing
			if (start) begin  // start
					stage <= 1;
					sdReadAddress <= dataa[23:0];
					sdReadBase <= dataa[23:0];
					if (datab != 0) begin
						dimension <= datab[7:0];
					end else begin
						dimension <= DEFAULT_DIMENSION;
					end
					
					ramLoadAddress <= 0;
					startSdRead <= 1;
					ramWriteDone <= 0;
					
					done <= 1;
					result <= 0;
			end else begin
				done <= 0;
				result <= 999;
			end
			
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
		
			if (start) begin		// invalid start - we are not ready
				result <= 1;
				done <= 1;
			end else begin
				result <= 998;
				done <= 0;
			
			end
			
			write <= 0;
			writedata <= 0;
			
			
			if (startSdRead) begin
				read <= 1;
				address <= sdReadAddress;
				startSdRead <= 0;
			end
								
			// Request Pipeline
			if (!waitrequest && read) begin
				sdReadAddress = sdReadAddress + 24'd4;
				address <= sdReadAddress;
				
				if (sdReadAddress == sdReadBase + dimension*dimension*4) begin
					read <= 0;
				end
			end
			
			// Receive pipeline
			if (readdatavalid && !ramWriteDone) begin
				ramWriteEnable <= 1;
				ramWriteAddress <= ramLoadAddress;
				ramWriteData <= readdata;
				ramLoadAddress <= ramLoadAddress + 10'd1;

				if (ramLoadAddress == dimension*dimension-1) begin
					ramWriteDone <= 1;
				end
			end else if (!readdatavalid) begin
				ramWriteEnable <= 0;
			end
			
			if (ramWriteDone) begin		// start calculating
				detStart <= 1;
				stage <= 2;
				
				// RAM stuff - connect RAM controls with determinant module
				ramReadAddress <= detRamReadAddress;
				ramWriteAddress <= detRamWriteAddress;
				ramWriteData <= detRamWriteAddress;
				ramWriteEnable <= detRamWriteEnable;
				ramReadEnable <= detRamReadEnable;
				detRamReadData <= ramReadData;
			end
			
		end else if (stage == 2) begin	// calculating
			if (start) begin		// invalid start - we are not ready
				result <= 2;
				done <= 1;
			end else begin
				result <= 997;
				done <= 0;
			
			end
			
			if (detDone) begin  // done
				stage <= 3;		// stage 3, waiting for interrupt to be cleared
				
				finalResult <= detResult;		// RAISE AN INTERRUPT
				irq <= 1;
				
				// RAM stuff
				ramReadAddress <= 0;
				ramWriteAddress <= 0;
				ramWriteData <= 0;
				ramWriteEnable <= 0;
				ramReadEnable <= 0;
			end else begin    // still calculating
							
				// RAM stuff - connect RAM controls with determinant module
				ramReadAddress <= detRamReadAddress;
				ramWriteAddress <= detRamWriteAddress;
				ramWriteData <= detRamWriteAddress;
				ramWriteEnable <= detRamWriteEnable;
				ramReadEnable <= detRamReadEnable;
				detRamReadData <= ramReadData;
			end
		
			// Avalon master
			read <= 0;
			write <= 0;
			address <= 0;
			writedata <= 0;
			
			detStart <= 0;
		
		end else if (stage == 3) begin
			if (start) begin		// invalid start - we are not ready
				result <= 3;
				done <= 1;
			end else begin
				result <= 996;
				done <= 0;
			
			end
			
			if (result_read) begin
				result_readdata <= finalResult;
				irq <= 0;
				stage <= 0;		// reset to zero
			end
		end	
	end

endmodule
