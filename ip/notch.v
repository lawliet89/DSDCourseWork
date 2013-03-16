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
/*		output reg [21:0] fladdress,       //               (flash) avalon_master.address
        output reg        flread,          //                              .read
        input  wire [31:0] flreaddata,      //                              .readdata
        input  wire        flreaddatavalid, //                              .readdatavalid
        input  wire        flwaitrequest,   //                              .waitrequest
        output wire        flwrite,         //                              .write
        output wire [31:0] flwritedata,     //                              .writedata*/
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
	parameter DIVIDER_LATENCY = 5'd16;
	
	
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
	/*wire [63:0] a1Intermediate;
	wire [63:0] a2Intermediate;
	wire [63:0] b0Intermediate;
	wire [63:0] b1Intermediate;
	wire [63:0] b2Intermediate;*/
	
	reg [63:0] y_n1 = 0;		// y(n-1)
	reg [63:0] y_n2 = 0;		// y(n-2)
	
	
	reg [1:0] stage = 0;
	reg [23:0] sdBase = 0;	// base address to write result to.
    reg [23:0] writeAddress = 0;
	reg [23:0] readAddress = 0; 
	
	reg startSdRead = 0;
	reg [31:0] sdDiscardedRead = 0;
	reg [31:0] sdReceiveCount = 0;
	
	reg [3:0] calculationStage = 0;
	reg [31:0] calculationCount = 0;
    reg [2:0] writeStage = 0;
    reg [31:0] writeCache;
	reg [4:0] divideCounter;
	
	
    /* 
        FIFO Instantiation
    */
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
		
	
    /*
        Divider Instantiation
    */
	reg [63:0] dividerNumerator;
	reg [31:0] dividerDenominator;
	wire [63:0] dividerQuotient;
	wire [31:0] dividerRemainder;
	
	div_64	divider (
		.clock ( clk ),
		.denom ( dividerDenominator ),
		.numer ( dividerNumerator ),
		.quotient ( dividerQuotient ),
		.remain ( dividerRemainder )
	);
	
    /*
        Multipliers Instantiation
    */
	reg [63:0] mul_a1_a;
	reg [15:0] mul_a1_b;
	wire [63:0] mul_a1_result;
	
	mul_64	mul_64_a1 (
		.clock ( clk ),
		.dataa ( mul_a1_a ),
		.datab ( mul_a1_b ),
		.result ( mul_a1_result )
	);
	

	reg [63:0] mul_a2_a;
	reg [15:0] mul_a2_b;
	wire [63:0] mul_a2_result;
	
	mul_64	mul_64_a2 (
		.clock ( clk ),
		.dataa ( mul_a2_a ),
		.datab ( mul_a2_b ),
		.result ( mul_a2_result )
	);
	
	reg [31:0] mul_b0_a;
	reg [15:0] mul_b0_b;
	wire [63:0] mul_b0_result;
	
	mul_32	mul_32_b0 (
		.clock ( clk ),
		.dataa ( mul_b0_a ),
		.datab ( mul_b0_b ),
		.result ( mul_b0_result )
	);
	
	reg [31:0] mul_b1_a;
	reg [15:0] mul_b1_b;
	wire [63:0] mul_b1_result;
	
	mul_32	mul_32_b1 (
		.clock ( clk ),
		.dataa ( mul_b1_a ),
		.datab ( mul_b1_b ),
		.result ( mul_b1_result )
	);
	
	reg [31:0] mul_b2_a;
	reg [15:0] mul_b2_b;
	wire [63:0] mul_b2_result;
	
	mul_32	mul_32_b2 (
		.clock ( clk ),
		.dataa ( mul_b2_a ),
		.datab ( mul_b2_b ),
		.result ( mul_b2_result )
	);	
	
    /*
        Processing
    */
	always @ (posedge clk) begin
    
        // slave status read
        if (slave_read) begin
            case (slave_address) 
                0:  	slave_readdata <= (readAddress-sdBase);
                1:		slave_readdata <= { {27{1'd0}}, reqFifoUsed };
                2: 		slave_readdata <= { {27{1'd0}}, readFifoUsed };
                3:		slave_readdata <= sdReceiveCount;
                4:		slave_readdata <= sdDiscardedRead;
                5: 		slave_readdata <= { {28{1'd0}}, calculationStage };
                6:		slave_readdata <= calculationCount;
                7:	 	slave_readdata <= (writeAddress-sdBase);
                8: 		slave_readdata <= { {27{1'd0}}, writeFifoUsed };
                9: 		slave_readdata <= { {31{1'd0}}, sdread };
                10:		slave_readdata <= { {31{1'd0}}, sdwaitrequest };
                11: 	slave_readdata <= { {31{1'd0}}, sdwrite };		
				12:		slave_readdata <= { {30{1'd0}}, stage };		
            endcase
        
        end
    
	
		if (reset || forceReset) begin
			forceReset <= 0;
		
			x_n <= 0;
			x_n1 <= 0;
			x_n2 <= 0;
			yIntermediate <= 0;
			y_n1 <= 0;
			y_n2 <= 0;
			
			stage <= 0;
			sdBase <= 0;
            writeAddress <= 0;
			readAddress <= 0;
			startSdRead <= 0;
			calculationStage <= 0;
			calculationCount <= 0;
            writeStage <= 0;
			
			sdDiscardedRead <= 0;
			sdReceiveCount <= 0;
			
			reqFifoClear <= 1;
			writeFifoClear <= 1;
			readFifoClear <= 1;
			
			readFifoReadRequest <= 0;
			readFifoWriteRequest <= 0;
			writeFifoReadRequest <= 0;
			writeFifoReadRequest <= 0;
						
		end else if (stage == 0) begin
			
			if (start) begin
				done <= 1;
				
				if (dataa) begin		// begin processing
					result <= 99;		// indicate acceptance of start
					
					stage <= 1;
					
					sdBase <= dataa[23:0];
					writeAddress <= dataa[23:0];
					readAddress <= dataa[23:0];
					
					sdDiscardedRead <= 0;
					sdReceiveCount <= 0;
					
					calculationStage <= 0;
					calculationCount <= 0;
					startSdRead <= 1;
					writeStage <= 0;
					
					x_n <= 0;
					x_n1 <= 0;
					x_n2 <= 0;
					yIntermediate <= 0;
					y_n1 <= 0;
					y_n2 <= 0;
										
					reqFifoReadRequest <= 0;
					reqFifoWriteRequest <= 0;
					readFifoReadRequest <= 0;
					readFifoWriteRequest <= 0;
					writeFifoReadRequest <= 0;
					writeFifoReadRequest <= 0;
					
				end else begin			// status check
					result <= -1;
				
				end
			
			end else begin
				done <= 0;	//idle
			end
			
			
		end else if (stage == 1) begin	// stage 1 - reading and calculating
            
            if (start) begin	// handle request checks
				done <= 1;
				result <= (writeAddress-sdBase)/4;
			end else begin
				done <= 0;
			end
			
			if (startSdRead) begin
				startSdRead <= 0;
				sdread <= 1;
			end		
						
						
			// SD read request pipeline
			if (readAddress < sdBase + NO_SAMPLES*4) begin
			
				// Wait request
				if (!sdwaitrequest && sdread && !sdwrite) begin		// request accepted
					// save this request to Fifo
					reqFifoWriteRequest <= 1;
					
					readAddress = readAddress + 24'd4;
					sdaddress <= readAddress;
										
				
					if (readAddress >= sdBase + NO_SAMPLES*4) begin	// done!
						sdread <= 0;
					
					end else if (reqFifoAlmostFull) begin // request fifo  "almost" full
						sdread <= 0;
						
					end else begin		// not almost full? continue to request
						sdread <= 1;
					end
					
				end else begin			// waiting for requests to be accepted
					reqFifoWriteRequest <= 0;
					
					if (!sdread && !reqFifoAlmostFull && !sdwrite) begin	// see if fifo buffer is not full again and restart requests
						sdread <= 1;
					end
				end
			
			end else begin
				reqFifoWriteRequest <= 0;
				sdread <= 0;
				
			end
		
			// incoming data
			if (sdreaddatavalid) begin
				
				// receive FIFO handling
				if(readFifoFull) begin		// discarded! THIS SHOULDN'T HAPPEN AT ALL!
					sdDiscardedRead <= sdDiscardedRead + 1;
					
				end else begin
					readFifoWriteRequest <= 1;	// save to calculation pipeline
					readFifoWrite <= sdreaddata;
				
					sdReceiveCount <= sdReceiveCount + 1;
				end
				
				if (!sdReceiveCount) begin
					done <= 1;
					result <= sdreaddata;
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
				
				/*
				a1Intermediate <= y_n1 * { {49{a1[15]}}, a1[14:0] };
				a2Intermediate <= y_n2 * { {49{a2[15]}}, a2[14:0] };
				b0Intermediate <= { {33{x_n[31]}}, x_n[30:0] }* { {49{b0[15]}}, b0[14:0] };
				b1Intermediate <= { {33{x_n1[31]}}, x_n1[30:0] }* { {49{b1[15]}}, b1[14:0] };
				b2Intermediate <= { {33{x_n2[31]}}, x_n2[30:0] }* { {49{b2[15]}}, b2[14:0] };
				*/
				
				// a1
				mul_a1_a <= y_n1;
				mul_a1_b <= a1;
				
				// a2
				mul_a2_a <= y_n2;
				mul_a2_b <= a2;
				
				//b0
				mul_b0_a <= x_n;
				mul_b0_b <= b0;
				
				//b1
				mul_b1_a <= x_n1;
				mul_b1_b <= b1;
				
				
				//b2
				mul_b2_a <= x_n2;
				mul_b2_b <= b2;
				
                calculationStage <= 3;
			 
			end else if (calculationStage == 3) begin   
				// multiply latency
				calculationStage <= 4;
			 
			end else if (calculationStage == 4) begin   // accumulate - potential problem area
                yIntermediate <= mul_b0_result + mul_b1_result;
                calculationStage <= 5;
				
			end else if (calculationStage == 5) begin   // accumulate - potential problem area
                yIntermediate <= yIntermediate + mul_b2_result;
                calculationStage <= 6;
				
			end else if (calculationStage == 6) begin   
                yIntermediate <= yIntermediate - mul_a1_result;
                calculationStage <= 7;	
				
			end else if (calculationStage == 7) begin   
                yIntermediate <= yIntermediate - mul_a2_result;
                calculationStage <= 8;					
				
            end else if (calculationStage == 8) begin // get rid of coefficient scaling, and buffer
                y_n2 <= y_n1;	
				calculationStage <= 9;
				
				dividerNumerator <= yIntermediate;
				dividerDenominator <= COEFF_SCALING;
				
				divideCounter <= DIVIDER_LATENCY-5'd1;
			
			end else if (calculationStage == 9) begin
				// divider latency
				if (divideCounter != 0) begin
					divideCounter <= divideCounter - 5'd1;
				
				end else begin		
					calculationStage <= 10;
				
				end
				
            end else if (calculationStage == 10) begin // write
                if (!writeFifoFull) begin
					y_n1 <= dividerQuotient;
                    writeFifoWriteRequest <= 1;
                    writeFifoWrite <= dividerQuotient[31:0];
                    writeFifoWrite <= x_n;
					calculationStage <= 11;
					
                end else begin
                    writeFifoWriteRequest <= 0;
                end
				
            end else if (calculationStage == 11) begin // reset
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
            if (writeAddress < sdBase + NO_SAMPLES*4) begin
                if (writeStage == 0 && !writeFifoEmpty) begin
                    writeFifoReadRequest <= 1;
                    writeStage <= 1;
                    
                end else if (writeStage == 1) begin
                    writeCache <= writeFifoOutput;
                    writeFifoReadRequest <= 0;
                    writeStage <= 2;
                    
                end else if (writeStage == 2) begin
				
					if (!sdread) begin
						sdwrite <= 1;
						sdwritedata <= writeCache;
						sdaddress <= writeAddress[23:0];
						writeStage <= 3;
					end
                    
                end else if (writeStage == 3) begin
                    if (!sdwaitrequest && sdwrite) begin
                        sdwrite <= 0;
                        writeAddress <= writeAddress + 24'd4;
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
			
			// purge Fifos
			reqFifoClear <= 1;
			writeFifoClear <= 1;
			readFifoClear <= 1;
					
			reqFifoReadRequest <= 0;
			reqFifoWriteRequest <= 0;
			readFifoReadRequest <= 0;
			readFifoWriteRequest <= 0;
			writeFifoReadRequest <= 0;
			writeFifoReadRequest <= 0;
		
            if (slave_read) begin   /// doesn't matter what they read. we consider it serviced
                irq <= 0;
                stage <= 0;
				
				// turn off Fifo purging
				reqFifoClear <= 0;
				writeFifoClear <= 0;
				readFifoClear <= 0;
            end
		end
		
	end

endmodule
