// Sign extension: http://stackoverflow.com/questions/4176556/how-to-sign-extend-a-number-in-verilog

/*
    TODO:
        - FIFO word length --> 8
        
*/

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
	parameter COEFF_SCALING = 30;		// bit shifts
	parameter DIVIDER_LATENCY = 16;
	parameter SDRAM_WORD_SKIP = 4;
	
	reg forceReset = 0;
	
    // default coefficients
    //a = 1	-1.89436042308807	0.913743853569031
    //b = 0.505116066895425	-1	0.505116066895425
	// a = 1073741824 -2034054015 981124992
	// b = 542364246 -1073741824 542364246

    // the parameters below are scaled versions   
    reg [31:0] a1 = 32'h86C2CC81; // -2034054079
    reg [31:0] a2 = 32'd981124992;
    reg [31:0] b0 = 32'd542364246;
    reg [31:0] b1 = 32'hC0000000; // -2,034,054,079
    reg [31:0] b2 = 32'd542364246;
	
	
	reg [7:0] x_n = 0;		// x(N)
	reg [7:0] x_n1 = 0;	// x(n-1)
	reg [7:0] x_n2 = 0;	// x(n-2)
		
	reg [40:0] yIntermediate = 0;	// y(n)
	
	reg [40:0] yAccumulateIntermediate1;	// accumulator intermediate
	reg [40:0] yAccumulateIntermediate2;

	
	reg [7:0] y_n1 = 0;		// y(n-1)
	reg [7:0] y_n2 = 0;		// y(n-2)
	
	
	reg [1:0] stage = 0;
	reg [23:0] sdBase = 0;	// base address to write result to.
    reg [23:0] writeAddress = 0;
	reg [23:0] readAddress = 0; 
	
	reg startSdRead = 0;
	reg [31:0] sdDiscardedRead = 0;
	reg [31:0] sdReceiveCount = 0;
	
	reg [3:0] calculationStage = 0;
	reg [31:0] calculationCount = 0;
    reg [3:0] writeStage = 0;
	reg [4:0] divideCounter;
	
	// control registers
	reg writeToResult = 0;
	
	
    /* 
        FIFO Instantiation
    */
	reg [7:0] reqFifoWrite = NO_SAMPLES;	// write jibberish. doesn't matter
	reg reqFifoReadRequest = 0;
	reg reqFifoClear = 0;
	reg reqFifoWriteRequest = 0;
	wire reqFifoEmpty;
	wire reqFifoFull;
	wire reqFifoAlmostFull;
	wire [7:0] reqFifoOutput;
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

	reg [7:0] readFifoWrite;
	reg readFifoReadRequest = 0;
	reg readFifoClear = 0;
	reg readFifoWriteRequest = 0;
	wire readFifoEmpty;
	wire readFifoFull;
	wire readFifoAlmostFull;
	wire [7:0] readFifoOutput;
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
	
	reg [7:0] writeFifoWrite;
	reg writeFifoReadRequest = 0;
	reg writeFifoClear = 0;
	reg writeFifoWriteRequest = 0;
	wire writeFifoAlmostFull;
	wire writeFifoEmpty;
	wire writeFifoFull;
	wire [7:0] writeFifoOutput;
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
        Multipliers Instantiation
    */
	reg [31:0] mul_a1_a;
	reg [7:0] mul_a1_b;
	wire [39:0] mul_a1_result;
	
	mul_32	mul_32_a1 (
		.clock ( clk ),
		.dataa ( mul_a1_a ),
		.datab ( mul_a1_b ),
		.result ( mul_a1_result )
	);
	

	reg [31:0] mul_a2_a;
	reg [7:0] mul_a2_b;
	wire [39:0] mul_a2_result;
	
	mul_32	mul_32_a2 (
		.clock ( clk ),
		.dataa ( mul_a2_a ),
		.datab ( mul_a2_b ),
		.result ( mul_a2_result )
	);
	
	reg [31:0] mul_b0_a;
	reg [7:0] mul_b0_b;
	wire [39:0] mul_b0_result;
	
	mul_32	mul_32_b0 (
		.clock ( clk ),
		.dataa ( mul_b0_a ),
		.datab ( mul_b0_b ),
		.result ( mul_b0_result )
	);
	
	reg [31:0] mul_b1_a;
	reg [7:0] mul_b1_b;
	wire [39:0] mul_b1_result;
	
	mul_32	mul_32_b1 (
		.clock ( clk ),
		.dataa ( mul_b1_a ),
		.datab ( mul_b1_b ),
		.result ( mul_b1_result )
	);
	
	reg [31:0] mul_b2_a;
	reg [7:0] mul_b2_b;
	wire [39:0] mul_b2_result;
	
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
				13:		slave_readdata <= { {30{1'd0}}, writeToResult };
            endcase
        
        end else if (slave_write) begin
			case (slave_address)
				0:		writeToResult <= slave_writedata[0];
				1:		a1 <= slave_writedata;
				2:		a2 <= slave_writedata;
				3:		b0 <= slave_writedata;
				4:		b1 <= slave_writedata;
				5:		b2 <= slave_writedata;
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
			
			divideCounter <= 0;
			
			// purge
			
			reqFifoClear <= 1;
			writeFifoClear <= 1;
			readFifoClear <= 1;
			
			reqFifoReadRequest <= 0;
			reqFifoWriteRequest <= 0;
			readFifoReadRequest <= 0;
			readFifoWriteRequest <= 0;
			writeFifoReadRequest <= 0;
			writeFifoWriteRequest <= 0;
			
			sdread <= 0;
			sdwrite <= 0;
			sdaddress <= 0;
						
		end else if (stage == 0) begin
			
			if (start) begin
				
				if (dataa != 0) begin		// begin processing
					done <= 1;
					result <= 99;		// indicate acceptance of start
					
					stage <= 1;
					
					sdBase <= dataa[23:0];
					writeAddress <= dataa[23:0];
					readAddress <= dataa[23:0];
					
					startSdRead <= 1;
					
					reqFifoReadRequest <= 0;
					reqFifoWriteRequest <= 0;
					readFifoReadRequest <= 0;
					readFifoWriteRequest <= 0;
					writeFifoReadRequest <= 0;
					writeFifoWriteRequest <= 0;

				end else begin			// status check
					done <= 1;
					result <= -1;
					
				end
			
			end else begin
				done <= 0;	//idle
			end
			
			// clear purge flags
			reqFifoClear <= 0;
			writeFifoClear <= 0;
			readFifoClear <= 0;
					
		end else if (stage == 1) begin	// stage 1 - reading and calculating
            
            if (start) begin	// handle request checks
				done <= 1;
				result <= (writeAddress-sdBase)/SDRAM_WORD_SKIP;
			end else begin
				done <= 0;
			end

			if (startSdRead) begin
				startSdRead <= 0;
				
				sdread <= 1;
				sdaddress <= sdBase;
			end		
						
			
			// SD pipeline
			if (writeAddress >= sdBase + NO_SAMPLES*SDRAM_WORD_SKIP) begin	// we are done!
				stage <= 2;
				irq <= 1;
				sdread <= 0;
				sdwrite <= 0;
					
			end else if (sdread) begin		// reading
			
				// Wait request
				if (!sdwaitrequest && sdread) begin		// request accepted
					// save this request to Fifo
					reqFifoWriteRequest <= 1;
					
					readAddress <= readAddress + SDRAM_WORD_SKIP;
							
					if (readAddress >= sdBase + NO_SAMPLES*SDRAM_WORD_SKIP -SDRAM_WORD_SKIP) begin	// done!
						sdread <= 0;		// yield read forever
					
					end else if (reqFifoAlmostFull) begin // request fifo  "almost" full
						sdread <= 0;		//  yield
						
					end else begin		// not almost full? continue to request
						sdread <= 1;
						sdaddress <= readAddress + SDRAM_WORD_SKIP;
					end
					
				end else begin
					reqFifoWriteRequest <= 0;
					
				end
			
			end else if (writeStage != 0 || sdwrite) begin		// writing
				reqFifoWriteRequest <= 0;
				
				if (writeStage == 1) begin
					// fetch from fifo
					writeFifoReadRequest <= 1;
					writeStage <= 2;
				
				end else if (writeStage == 2) begin	// fetch latency
					
					writeFifoReadRequest <= 0;
					writeStage <= 3;
					
				
				end else if (writeStage == 3) begin
					sdwrite <= 1;
					sdwritedata <= { {25{writeFifoOutput[7]}}, writeFifoOutput[6:0] };
					sdaddress <= writeAddress;
					writeStage <= 4;
				
				end else if (writeStage == 4) begin
					if (!sdwaitrequest && sdwrite) begin // write has been accepted
						sdwrite <= 0;
						writeAddress <= writeAddress + SDRAM_WORD_SKIP;
						writeStage <= 0;
					end
				
				end
			
			end else begin		// neither reading nor writing
				reqFifoWriteRequest <= 0;
				
				// decide if we should read or write
				if (readAddress < sdBase + NO_SAMPLES*SDRAM_WORD_SKIP && !reqFifoAlmostFull) begin	// read has priority
					sdread <= 1; //read
				
				end else if (writeAddress < sdBase + NO_SAMPLES*SDRAM_WORD_SKIP)  begin // handle any necessary writes
					if (writeStage == 0 && !writeFifoEmpty) begin
						writeStage <= 1;
					end
			
				end 
				// if control reaches here, then let's not do anything
	
			end
				
			
			// incoming data
			if (sdreaddatavalid) begin
				
				// receive FIFO handling
				if(readFifoFull) begin		// discarded! THIS SHOULDN'T HAPPEN AT ALL!
					sdDiscardedRead <= sdDiscardedRead + 1;
					
				end else begin
					readFifoWriteRequest <= 1;	// save to calculation pipeline
					readFifoWrite <= sdreaddata[7:0]];
				
					sdReceiveCount <= sdReceiveCount + 1;
				end
				
			end else begin
				readFifoWriteRequest <= 0;		// don't write!
			
			end

			// calculation pipeline
			if (calculationStage == 0) begin
				if (!readFifoEmpty) begin
					// in the pipeline. fetch
					readFifoReadRequest <= 1;
					calculationStage <= 1;
					
					reqFifoReadRequest <= 1;	// drain request FIFO
				end
			
			end else if (calculationStage == 1) begin
				// fetch latency
				readFifoReadRequest <= 0;
				reqFifoReadRequest <= 0;
				
				calculationStage <= 2;
				
			end else if (calculationStage == 2) begin	
				
				x_n <= readFifoOutput[7:0];
				x_n1 <= x_n;			// optimisation potential
				x_n2 <= x_n1;
							
				calculationStage <= 3;
			
			end else if (calculationStage == 3) begin	
				// let the multiplications begin
				
				// a1
				mul_a1_a <= a1;
				mul_a1_b <= y_n1;
				
				// a2
				mul_a2_a <= a2;
				mul_a2_b <= y_n2;
				
				//b0
				mul_b0_a <= b0;
				mul_b0_b <= x_n;
				
				//b1
				mul_b1_a <= b1;
				mul_b1_b <= x_n1;
				
				
				//b2
				mul_b2_a <= b2;
				mul_b2_b <= x_n2;
				
				calculationStage <= 4;
			
			end else if (calculationStage == 4) begin	
				// multiplier latency
				calculationStage <= 5;
			
			end else if (calculationStage == 5) begin	
				// start to accumulate
				yIntermediate <= { {1{mul_b0_result[39]}}, mul_b0_result[38:0] }  + { {1{mul_b1_result[39]}}, mul_b1_result[38:0] };
				yAccumulateIntermediate1 <= { {1{mul_b2_result[39]}}, mul_b2_result[38:0] } - { {1{mul_a1_result[39]}}, mul_a1_result[38:0] };
				yAccumulateIntermediate2 <= { {1{mul_a2_result[39]}}, mul_a2_result[38:0] };
				
				calculationStage <= 6;
			
				
			end else if (calculationStage == 6) begin		
				// final accumulation				//yIntermediate <= $signed($signed(yIntermediate) + $signed(yAccumulateIntermediate1) - $signed(yAccumulateIntermediate2));
				yIntermediate <= yIntermediate + yAccumulateIntermediate1 - yAccumulateIntermediate2;
				
				calculationStage <= 7;
				
			end else if (calculationStage == 7) begin  // get rid of coefficient scaling
				y_n2 <= y_n1;
				y_n1 <= yIntermediate[37:30];			// potential optimisation?
				
				
				calculationStage <= 9;
				
			end else if (calculationStage == 9) begin
				if (!writeFifoAlmostFull) begin
								
                    writeFifoWriteRequest <= 1;
					
					if (writeToResult)
						writeFifoWrite <= yIntermediate[37:30];
					
                    else 
						writeFifoWrite <= x_n[7:0];
						
					calculationStage <= 10;
	
                end 			
			end else if (calculationStage == 10) begin	// reset
				calculationCount <= calculationCount + 1;
                writeFifoWriteRequest <= 0;
                calculationStage <= 0;
					
			end

		
		end else if (stage == 2) begin      // wait for IRQ to be serviced
			if (start) begin	// handle request checks
				done <= 1;
				result <= -2;
			end else begin
				done <= 0;
			end
										
            if (slave_read) begin   /// doesn't matter what they read. we consider it serviced
                irq <= 0;
                forceReset <= 1;	// reset
				
            end
		end
		
	end

endmodule
