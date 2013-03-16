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
		.aclr ( reqFifoClear ),
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
		.aclr ( readFifoClear ),
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
		.aclr ( writeFifoClear ),
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
			startSdRead <= 0;
			
			sdDiscardedRead <= 0;
			sdReceiveCount <= 0;
			
			// purge
			
			reqFifoClear <= 1;
			writeFifoClear <= 1;
			readFifoClear <= 1;
			
			reqFifoReadRequest <= 0;
			reqFifoWriteRequest <= 0;
			readFifoReadRequest <= 0;
			readFifoWriteRequest <= 0;
			writeFifoReadRequest <= 0;
			writeFifoReadRequest <= 0;
						
		end else if (stage == 0) begin
			
			if (start) begin
				done <= 1;
				
				if (dataa != 0) begin		// begin processing
					result <= 99;		// indicate acceptance of start
					
					stage <= 1;
					
					sdBase <= dataa[23:0];
					writeAddress <= dataa[23:0];
					readAddress <= dataa[23:0];

				end else begin			// status check
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
				result <= (writeAddress-sdBase)/4;
			end else begin
				done <= 0;
			end
			
			stage <= 2;
			
		
		end else if (stage == 2) begin      // wait for IRQ to be serviced
			if (start) begin	// handle request checks
				done <= 1;
				result <= stage;
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
