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
        input [2:0]       address,          //                              .address    TODO
        output reg        irq              //              interrupt_sender.irq
    );
   
	parameter N = 2;		// order
	parameter NO_SAMPLES = 963144;
	parameter SAMPLE_SCALING = 2147483647;
	parameter COEFF_SCALING = 16383;
	parameter FLASH_BASE_ADDRESS = 0;
	
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
	reg [47:0] b0Intermediate;
	reg [47:0] b1Intermediate;
	reg [47:0] b2Intermediate;
	
	reg [31:0] y_n1 = 0;		// y(n-1)
	reg [31:0] y_n2 = 0;		// y(n-2)
	
	
	reg [1:0] stage = 0;
	reg [31:0] writeBase = 0;	// base address to write result to.
    reg [31:0] writeAddress = 0;
	reg startFlashRead = 0;
	reg [21:0] flashReadMemory = 0;
	reg [2:0] calculationStage = 0;
    reg [2:0] writeStage = 0;
    reg [31:0] writeCache;

	reg [31:0] readFifoWrite;
	reg readFifoReadRequest = 0;
	reg readFifoClear = 0;
	reg readFifoWriteRequest = 0;
	wire readFifoEmpty;
	wire readFifoFull;
	wire [31:0] readFifoOutput;
	wire [3:0] readFifoUsed;
	
	fifo_16	readFifo (
		.clock ( clk ),
		.data ( readFifoWrite ),
		.rdreq ( readFifoReadRequest ),
		.sclr ( readFifoClear ),
		.wrreq ( readFifoWriteRequest ),
		.empty ( readFifoEmpty ),
		.full ( readFifoFull ),
		.q ( readFifoOutput ),
		.usedw ( readFifoUsed )
		);
	
	reg [31:0] writeFifoWrite;
	reg writeFifoReadRequest = 0;
	reg writeFifoClear = 0;
	reg writeFifoWriteRequest = 0;
	wire writeFifoEmpty;
	wire writeFifoFull;
	wire [31:0] writeFifoOutput;
	wire [3:0] writeFifoUsed;
		
	fifo_16	writeFifo (
		.clock ( clk ),
		.data ( writeFifoWrite ),
		.rdreq ( writeFifoReadRequest ),
		.sclr ( writeFifoClear ),
		.wrreq ( writeFifoWriteRequest ),
		.empty ( writeFifoEmpty ),
		.full ( writeFifoFull ),
		.q ( writeFifoOutput ),
		.usedw ( writeFifoUsed )
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
			calculationStage <= 0;
            writeStage <= 0;
			
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
                writeAddress <= dataa;
				fladdress <= 0;
				flashReadMemory <= 0;
				calculationStage <= 0;
				startFlashRead <= 1;
                writeStage <= 0;
				
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
				case (address) 
					0:  slave_readdata <= { {10{1'd0}}, flashReadMemory };
					1: 	slave_readdata <= { {28{1'd0}}, readFifoUsed };
					2: 	slave_readdata <= { {31{1'd0}}, flwaitrequest }; 
					3: 	slave_readdata <= { {31{1'd0}}, flreaddatavalid };
					4: 	slave_readdata <= { {29{1'd0}}, calculationStage };
					5: 	slave_readdata <= { {28{1'd0}}, writeFifoUsed };
					6: 	slave_readdata <= { {31{1'd0}}, sdwaitrequest };
					7: 	slave_readdata <= (writeAddress-writeBase);
				endcase
			
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
					flread <= 1;
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
			end else if (calculationStage == 2) begin   // multiply  - potential problem area
				a1Intermediate <= $signed($signed(y_n1)*$signed(a1));
				a2Intermediate <= $signed($signed(y_n2)*$signed(a2));
				b0Intermediate <= $signed($signed(x_n)*$signed(b0));
				b1Intermediate <= $signed($signed(x_n1)*$signed(b1));
				b2Intermediate <= $signed($signed(x_n2)*$signed(b2));
                calculationStage <= 3;
			 
			end else if (calculationStage == 3) begin   // accumulate - potential problem area
                yIntermediate <= $signed( $signed(b0Intermediate) + $signed(b1Intermediate) + $signed(b2Intermediate) - $signed(a1Intermediate)  - $signed(a2Intermediate));
                calculationStage <= 4;
				
            end else if (calculationStage == 4) begin // get rid of coefficient scaling, and buffer
                y_n2 <= y_n1;
                y_n1 <= ($signed($signed(yIntermediate)/COEFF_SCALING));
				calculationStage <= 5;
            
            end else if (calculationStage == 5) begin // write
                if (!writeFifoFull) begin
                    writeFifoWriteRequest <= 1;
                    writeFifoWrite <= y_n1;
                    calculationStage <= 6;
                end else begin
                    writeFifoWriteRequest <= 0;
                end
				
            end else if (calculationStage == 6) begin // reset
                writeFifoWriteRequest <= 0;
                calculationStage <= 0;

			end
            
            // write to SDRAM pipeline
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
