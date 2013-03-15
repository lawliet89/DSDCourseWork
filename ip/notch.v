// Sign extension: http://stackoverflow.com/questions/4176556/how-to-sign-extend-a-number-in-verilog

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
        input [3:0]       slave_address,    //                              .address    
        output reg        irq              //              interrupt_sender.irq
    );
   
	parameter N = 2;		// order
	parameter NO_SAMPLES = 963144;
	parameter SAMPLE_SCALING = 2147483647;
	parameter COEFF_SCALING = 16383;
	parameter FLASH_BASE_ADDRESS = 0;
	parameter FIFO_DEPTH = 32;
	parameter DIVIDER_LATENCY = 16;
	
	reg forceReset = 0;
	
    // default coefficients
    //a = 1	-1.89436042308807	0.913743853569031
    //b = 0.505116066895425	-1	0.505116066895425
    // the parameters below are scaled versions
	parameter A1 = -16'd31035;
    parameter A2 = 16'd14969;
    parameter B0 = 16'd8275;
    parameter B1 = -16'd16383;
    parameter B2 = 16'd8275;
    
    reg [15:0] a1 = A1;
    reg [15:0] a2 = A2;
    reg [15:0] b0 = B0;
    reg [15:0] b1 = B1;
    reg [15:0] b2 = B2;
	
	
	reg [31:0] x_n = 0;		// x(N)
	reg [31:0] x_n1 = 0;	// x(n-1)
	reg [31:0] x_n2 = 0;	// x(n-2)
		
	reg [63:0] yIntermediate = 0;	// y(n)
	reg [63:0] a1Intermediate;
	reg [63:0] a2Intermediate;
	reg [63:0] b0Intermediate;
	reg [63:0] b1Intermediate;
	reg [63:0] b2Intermediate;
	
	reg [31:0] y_n1 = 0;		// y(n-1)
	reg [31:0] y_n2 = 0;		// y(n-2)
	
	
	reg [1:0] stage = 0;
	reg [31:0] writeBase = 0;	// base address to write result to.
    reg [31:0] writeAddress = 0;
	reg startFlashRead = 0;
	reg [21:0] flashReadMemory = 0;
	reg [31:0] flashReceiveCount = 0;
	reg [31:0] flashDiscardedCount = 0;	// should be ZERO
	reg [3:0] calculationStage = 0;
	reg [31:0] calculationCount = 0;
    reg [2:0] writeStage = 0;
    reg [31:0] writeCache;
	reg [3:0] divideCounter;
	reg [3:0] requestFifoDrainCounter = 0;
	
	
	reg [31:0] reqFifoWrite = NO_SAMPLES;	// write jibberish. doesn't matter
	reg reqFifoReadRequest = 0;
	reg reqFifoClear = 0;
	reg reqFifoWriteRequest = 0;
	wire reqFifoEmpty;
	wire reqFifoFull;
	wire reqFifoAlmostFull;
	wire [31:0] reqFifoOutput;
	wire [4:0] reqFifoUsed;
	
	fifo_32	reqFifo (
		.clock ( clk ),
		.data ( reqFifoWrite ),
		.rdreq ( reqFifoReadRequest ),
		.sclr ( reqFifoClear ),
		.wrreq ( reqFifoWriteRequest ),
		.almost_full ( reqFifoAlmostFull ),
		.empty ( reqFifoEmpty ),
		.full ( reqFifoFull ),
		.q ( reqFifoOutput ),
		.usedw ( reqFifoUsed )
		);	

	reg [31:0] readFifoWrite;
	reg readFifoReadRequest = 0;
	reg readFifoClear = 0;
	reg readFifoWriteRequest = 0;
	wire readFifoEmpty;
	wire readFifoFull;
	wire readFifoAlmostFull;
	wire [31:0] readFifoOutput;
	wire [4:0] readFifoUsed;
	
	fifo_32	readFifo (
		.clock ( clk ),
		.data ( readFifoWrite ),
		.rdreq ( readFifoReadRequest ),
		.sclr ( readFifoClear ),
		.wrreq ( readFifoWriteRequest ),
		.almost_full ( readFifoAlmostFull ),
		.empty ( readFifoEmpty ),
		.full ( readFifoFull ),
		.q ( readFifoOutput ),
		.usedw ( readFifoUsed )
		);
	
	reg [31:0] writeFifoWrite;
	reg writeFifoReadRequest = 0;
	reg writeFifoClear = 0;
	reg writeFifoWriteRequest = 0;
	wire writeFifoAlmostFull;
	wire writeFifoEmpty;
	wire writeFifoFull;
	wire [31:0] writeFifoOutput;
	wire [4:0] writeFifoUsed;
		
	fifo_32	writeFifo (
		.clock ( clk ),
		.data ( writeFifoWrite ),
		.rdreq ( writeFifoReadRequest ),
		.sclr ( writeFifoClear ),
		.wrreq ( writeFifoWriteRequest ),
		.almost_full ( writeFifoAlmostFull ),
		.empty ( writeFifoEmpty ),
		.full ( writeFifoFull ),
		.q ( writeFifoOutput ),
		.usedw ( writeFifoUsed )
		);	
		
	
	reg [31:0] dividerNumerator;
	reg [31:0] dividerDenominator;
	wire [31:0] dividerQuotient;
	wire [31:0] dividerRemainder;
	
	div_64	divider (
		.clock ( clk ),
		.denom ( dividerDenominator ),
		.numer ( dividerNumerator ),
		.quotient ( dividerQuotient ),
		.remain ( dividerRemainder )
	);
	
	
	always @ (posedge clk) begin
	
		if (reset || forceReset) begin
			forceReset <= 0;
		
			x_n <= 0;
			x_n1 <= 0;
			x_n2 <= 0;
			yIntermediate <= 0;
			y_n1 <= 0;
			y_n2 <= 0;
			
			stage <= 0;
			writeBase <= 0;
            writeAddress <= 0;
			startFlashRead <= 0;
			flashReceiveCount <= 0;
			flashDiscardedCount <= 0;
			calculationStage <= 0;
			calculationCount <= 0;
            writeStage <= 0;
			requestFifoDrainCounter <= 0;
			
			fladdress <= 0;
			flashReadMemory <= 0;
			flread <= 0;
			
			reqFifoClear <= 1;
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
                writeAddress <= dataa;
				fladdress <= 0;
				flashReadMemory <= 0;
				flashReceiveCount <= 0;
				flashDiscardedCount <= 0;
				calculationStage <= 0;
				calculationCount <= 0;
				startFlashRead <= 1;
                writeStage <= 0;
				requestFifoDrainCounter <= 0;
				
				x_n <= 0;
				x_n1 <= 0;
				x_n2 <= 0;
				yIntermediate <= 0;
				y_n1 <= 0;
				y_n2 <= 0;
				
				reqFifoClear <= 1;
				writeFifoClear <= 1;
				readFifoClear <= 1;
				
				reqFifoReadRequest <= 0;
				reqFifoWriteRequest <= 0;
				readFifoReadRequest <= 0;
				readFifoWriteRequest <= 0;
				writeFifoReadRequest <= 0;
				writeFifoReadRequest <= 0;
				
				done <= 1;
				result <= 99;
					
			end else if (start && dataa == 0) begin		// status check
				done <= 1;
				result <= -1;
			end else begin		// idle
				done <= 0;
			end
			
			writeFifoClear <= 0;
			readFifoClear <= 0;
			
		end else if (stage == 1) begin	// stage 1 - reading and calculating
			if (start) begin	// handle request checks
				done <= 1;
				result <= (writeAddress-writeBase)/4;
			end else begin
				done <= 0;
			end
			
			// slave status read
			if (slave_read) begin
				case (slave_address) 
					0:  	slave_readdata <= { {10{1'd0}}, flashReadMemory };
					1: 		slave_readdata <= { {29{1'd0}}, readFifoUsed };
					2: 		slave_readdata <= { {31{1'd0}}, flwaitrequest }; 
					3: 		slave_readdata <= { {31{1'd0}}, flreaddatavalid };
					4: 		slave_readdata <= { {31{1'd0}}, flread };
					5:		slave_readdata <= flashReceiveCount;
					6: 		slave_readdata <= { {28{1'd0}}, calculationStage };
					7:		slave_readdata <= calculationCount;
					8: 		slave_readdata <= { {29{1'd0}}, writeFifoUsed };
					9: 		slave_readdata <= { {31{1'd0}}, sdwaitrequest };
					10: 	slave_readdata <= { {31{1'd0}}, sdwrite };
					11: 	slave_readdata <= (writeAddress-writeBase);
					12:		slave_readdata <= { {29{1'd0}}, reqFifoUsed };
					13:		slave_readdata <= flashDiscardedCount;
				endcase
			
			end
			
			if (startFlashRead) begin
				startFlashRead <= 0;
				flread <= 1;
				
				reqFifoClear <= 0;
				writeFifoClear <= 0;
				readFifoClear <= 0;
			end		
						
						
			// Flash read request pipeline
			if (flashReadMemory < NO_SAMPLES*4) begin
			
				// Wait request
				if (!flwaitrequest && flread) begin		// request accepted
					// save this request to Fifo
					reqFifoWriteRequest <= 1;
					
					flashReadMemory = flashReadMemory + 4;
					fladdress <= flashReadMemory;
										
				
					if (flashReadMemory >= NO_SAMPLES*4) begin	// done!
						flread <= 0;
					
					end else if (reqFifoAlmostFull) begin // request fifo  "almost" full
						flread <= 0;
						
					end else begin		// not almost full? continue to request
						flread <= 1;
					end
					
				end else begin			// waiting for requests to be accepted
					reqFifoWriteRequest <= 0;
					
					if (!flread && !reqFifoAlmostFull) begin	// see if fifo buffer is not full again and restart requests
						flread <= 1;
					end
				end
			
			end else begin
				reqFifoWriteRequest <= 0;
				flread <= 0;
				
			end
		
			// incoming data
			if (flreaddatavalid) begin
				
				// receive FIFO handling
				if(readFifoFull) begin		// discarded! THIS SHOULDN'T HAPPEN AT ALL!
					flashDiscardedCount <= flashDiscardedCount + 1;
					
				end else begin
					readFifoWriteRequest <= 1;	// save to calculation pipeline
					readFifoWrite <= flreaddata;
				
					flashReceiveCount <= flashReceiveCount + 1;
				end
								
			end else begin
				readFifoWriteRequest <= 0;		// don't write!
			
			end
		
					
			// calculation pipeline

			if (!readFifoEmpty && calculationStage == 0) begin	// request
				readFifoReadRequest <= 1;
				calculationStage <= 1;
				
				reqFifoReadRequest <= 0;
				
			end else if (calculationStage == 1) begin
				readFifoReadRequest <= 0;
				
				x_n <= readFifoOutput;
				x_n1 <= x_n;
				x_n2 <= x_n1;
				
				calculationStage <= 2;
			end else if (calculationStage == 2) begin   // multiply  - potential problem area
				// sign extend the numbers - http://stackoverflow.com/questions/4176556/how-to-sign-extend-a-number-in-verilog
				
				a1Intermediate <= { {33{y_n1[31]}}, y_n1[30:0] }* { {49{a1[15]}}, a1[14:0] };
				a2Intermediate <= { {33{y_n2[31]}}, y_n2[30:0] }* { {49{a2[15]}}, a2[14:0] };
				b0Intermediate <= { {33{x_n[31]}}, x_n[30:0] }* { {49{b0[15]}}, b0[14:0] };
				b1Intermediate <= { {33{x_n1[31]}}, x_n1[30:0] }* { {49{b1[15]}}, b1[14:0] };
				b2Intermediate <= { {33{x_n2[31]}}, x_n2[30:0] }* { {49{b2[15]}}, b2[14:0] };
                calculationStage <= 3;
			 
			end else if (calculationStage == 3) begin   // accumulate - potential problem area
                yIntermediate <= b0Intermediate + b1Intermediate;
                calculationStage <= 4;
				
			end else if (calculationStage == 4) begin   // accumulate - potential problem area
                yIntermediate <= yIntermediate + b2Intermediate;
                calculationStage <= 5;
				
			end else if (calculationStage == 5) begin   
                yIntermediate <= yIntermediate - a1Intermediate;
                calculationStage <= 6;	
				
			end else if (calculationStage == 6) begin   
                yIntermediate <= yIntermediate - a2Intermediate;
                calculationStage <= 7;					
				
            end else if (calculationStage == 7) begin // get rid of coefficient scaling, and buffer
                y_n2 <= y_n1;	
				calculationStage <= 8;
				
				dividerNumerator <= yIntermediate;
				dividerDenominator <= COEFF_SCALING;
				
				divideCounter <= DIVIDER_LATENCY-1;
			
			end else if (calculationStage == 8) begin
				// divider latency
				if (divideCounter != 0) begin
					divideCounter <= divideCounter - 1;
				
				end else begin		
					calculationStage <= 9;
				
				end
				
            end else if (calculationStage == 9) begin // write
                if (!writeFifoFull) begin
					y_n1 <= dividerQuotient;
                    writeFifoWriteRequest <= 1;
                    writeFifoWrite <= dividerQuotient;
                    calculationStage <= 10;
                end else begin
                    writeFifoWriteRequest <= 0;
                end
				
            end else if (calculationStage == 10) begin // reset
				calculationCount <= calculationCount + 1;
                writeFifoWriteRequest <= 0;
                calculationStage <= 0;
				
				reqFifoReadRequest <= 1;	// drain request FIFO
			end
            
            // write to SDRAM pipeline
			/*
				0 - Request Fetch
				1 - Fetch received
				2 - Send write request
				3 - Request Written
			*/
            if (writeAddress < writeBase + NO_SAMPLES*4) begin
                if (writeStage == 0 && !writeFifoEmpty) begin
                    writeFifoReadRequest <= 1;
                    writeStage <= 1;
                    
                end else if (writeStage == 1) begin
                    writeCache <= writeFifoOutput;
                    writeFifoReadRequest <= 0;
                    writeStage <= 2;
                    
                end else if (writeStage == 2) begin
                    sdwrite <= 1;
                    sdwritedata <= writeCache;
                    sdaddress <= writeAddress;
                    writeStage <= 3;
                    
                end else if (writeStage == 3) begin
                    if (!sdwaitrequest) begin
                        sdwrite <= 0;
                        writeAddress <= writeAddress + 4;
                        writeStage <= 0;
                    end
                end
            end else begin      // we are done
                stage <= 2;
                irq <= 1;
            end
			
		
		end else if (stage == 2) begin      // wait for IRQ to be serviced
			if (start) begin	// handle request checks
				done <= 1;
				result <= stage;
			end else begin
				done <= 0;
			end
		
            if (slave_read) begin
                slave_readdata <= NO_SAMPLES;
                irq <= 0;
                stage <= 0;
            end
		end
		
	end

endmodule
