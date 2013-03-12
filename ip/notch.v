module notch (
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
        output reg [23:0] sdaddress,       //               (sd) avalon_master.address
        output reg        sdread,          //                              .read
        input  wire [31:0] sdreaddata,      //                              .readdata
        input  wire        sdreaddatavalid, //                              .readdatavalid
        input  wire        sdwaitrequest,   //                              .waitrequest
        output reg        sdwrite,         //                              .write
        output reg [31:0] sdwritedata,     //                              .writedata
		output reg [21:0] fladdress,       //               (flash) avalon_master.address
        output reg        flread,          //                              .read
        input  wire [31:0] flreaddata,      //                              .readdata
        input  wire        flreaddatavalid, //                              .readdatavalid
        input  wire        flwaitrequest,   //                              .waitrequest
        output reg        flwrite,         //                              .write
        output reg [31:0] flwritedata,     //                              .writedata
        input  wire        slave_read,     //                  avalon_slave.read
        output reg [31:0] slave_readdata, //                              .readdata
		input wire		  slave_write,		//								.write
		input [31:0]	  slave_writedata,	//								.writedata
		output			slave_waitrequest,	//								.waitrequest							.
        output reg        irq              //              interrupt_sender.irq
    );

	
	
	parameter N = 2;		// order
	parameter NO_SAMPLES = 963144;
	parameter SAMPLE_SCALING = 2147483647;
	parameter COEFF_SCALING = 17297;
	parameter FLASH_BASE_ADDRESS = 0;
	
	parameter A1 = TODO;
	
	
	reg [31:0] x_n = 0;		// x(N)
	reg [31:0] x_n1 = 0;	// x(n-1)
	reg [31:0] x_n2 = 0;	// x(n-2)
		
	reg [63:0] yIntermediate = 0;	// y(n)
	reg [47:0] a1Intermediate;
	reg [47:0] a2Intermediate;
	reg [47:0] b0Intermediate;
	reg [47:0] b1Intermediate;
	reg [47:0] b2Intermediate;
	
	reg [31:0] y_n1 = 0;		// y(n-1)
	reg [31:0] y_n2 = 0;		// y(n-2)
	
	
	reg [1:0] stage = 0;
	reg [31:0] writeBase = 0;	// base address to write result to.
	reg startFlashRead = 0;
	reg [21:0] flashReadMemory = 0;
	reg [2:0] calculationStage = 0;
	reg [19:0] iteration = 0;

	reg [31:0] readFifoWrite;
	reg readFifoReadRequest = 0;
	reg readFifoClear = 0;
	reg readFifoWriteRequest = 0;
	wire readFifoEmpty;
	wire readFifoFull;
	wire [31:0] readFifoOutput;
	
	fifo_16	readFifo (
		.clock ( clk ),
		.data ( readFifoWrite ),
		.rdreq ( readFifoReadRequest ),
		.sclr ( readFifoClear ),
		.wrreq ( readFifoWriteRequest ),
		.empty ( readFifoEmpty ),
		.full ( readFifoFull ),
		.q ( readFifoOutput )
		);
	
	reg [31:0] writeFifoWrite;
	reg writeFifoReadRequest = 0;
	reg writeFifoClear = 0;
	reg writeFifoWriteRequest = 0;
	wire writeFifoEmpty;
	wire writeFifoFull;
	wire [31:0] writeFifoOutput;
		
	fifo_16	writeFifo (
		.clock ( clk ),
		.data ( writeFifoWrite ),
		.rdreq ( writeFifoReadRequest ),
		.sclr ( writeFifoClear ),
		.wrreq ( writeFifoWriteRequest ),
		.empty ( writeFifoEmpty ),
		.full ( writeFifoFull ),
		.q ( writeFifoOutput )
		);	
		
	
	always @ (posedge clk) begin
	
		if (reset) begin
			x_n <= 0;
			x_n1 <= 0;
			x_n2 <= 0;
			yIntermediate <= 0;
			y_n1 <= 0;
			y_n2 <= 0;
			
			stage <= 0;
			writeBase <= 0;
			startFlashRead <= 0;
			calculationStage <= 0;
			iteration <= 0;
			
			fladdress <= 0;
			flashReadMemory <= 0;
			flread <= 0;
			
			writeFifoClear <= 1;
			readFifoClear <= 1;
			
			readFifoReadRequest <= 0;
			readFifoWriteRequest <= 0;
			writeFifoReadRequest <= 0;
			writeFifoReadRequest <= 0;
			
		end else if (stage == 0) begin
			if (start && dataa != 0) begin		// start
				stage <= 1;
				writeBase <= dataa;
				fladdress <= 0;
				flashReadMemory <= 0;
				iteration <= 0;
				calculationStage <= 0;
				startFlashRead <= 1;
				
				x_n <= 0;
				x_n1 <= 0;
				x_n2 <= 0;
				yIntermediate <= 0;
				y_n1 <= 0;
				y_n2 <= 0;
				
				writeFifoClear <= 1;
				readFifoClear <= 1;
				
				readFifoReadRequest <= 0;
				readFifoWriteRequest <= 0;
				writeFifoReadRequest <= 0;
				writeFifoReadRequest <= 0;
				
				//done <= 1;
				//result <= 99;
					
			end else if (start && dataa == 0) begin		// status check
				done <= 1;
				result <= 0;
			end else begin		// idle
				done <= 0;
			end
			
			writeFifoClear <= 0;
			readFifoClear <= 0;
			
		end else if (stage == 1) begin	// stage 1 - reading and calculating
			if (start) begin	// handle request checks
				done <= 1;
				result <= stage;
			end else begin
				done <= 0;
			end
			
			if (startFlashRead) begin
				startFlashRead <= 0;
				flread <= 1;
				
				writeFifoClear <= 0;
				readFifoClear <= 0;
			end			
			
			
			// Request Pipeline
			if (flashReadMemory < NO_SAMPLES*4) begin
			
				// Wait request
				if (!flwaitrequest && flread) begin
					if (readFifoFull) begin		// fifo full
						flread <= 0;
					end 
						
					flashReadMemory = flashReadMemory + 4;
					fladdress <= flashReadMemory;
					if (flashReadMemory == NO_SAMPLES*4) begin
						flread <= 0;
					end
					
				end
				
				if (!flread && !readFifoFull) begin	// see if fifo buffer is not full again and restart requests
					flread <= 0;
				end
			
			end
			
			// Receive Pipeline
			if (flreaddatavalid) begin
				readFifoWriteRequest <= 1;
				readFifoWrite <= flreaddata;
			end else begin
				readFifoWriteRequest <= 0;
			end
			
			// calculation pipeline
			/*
				0 - fetch
				1 - get
				2 - multiply
				3 - acc
				4 - write
			*/
			if (!readFifoEmpty && calculationStage == 0) begin	// request
				readFifoReadRequest <= 1;
				calculationStage <= 1;
			end else if (calculationStage == 1) begin
				x_n <= readFifoOutput;
				x_n1 <= x_n;
				x_n2 <= x_n1;
				
				calculationStage <= 2;
			end else if (calculationStage == 2) begin
				a1Intermediate = ;
				a2Intermediate;
				b0Intermediate;
				b1Intermediate;
				b2Intermediate;
			
			end
			
			
		
		end else if (stage == 2) begin
			done <= 1;
			stage <= 0;
		
		end
		
	end

endmodule
