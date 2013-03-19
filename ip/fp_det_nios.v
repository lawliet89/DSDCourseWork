// This module supports AT MOST 32 x 32 matrices
/*
	Status return Code
		0 - ready
		1 - reading SDRAM
		2 - calculating
		3 - waiting for interrupt to be serviced
		99 - start calculation request received and valid
*/
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
	parameter DEFAULT_DIMENSION = 6'd16;
    parameter ADDER_LATENCY = 7;
    parameter MULTPLIER_LATENCY = 5;
    parameter DIVIDER_LATENCY = 6;
    parameter MAX_DIMENSION = 32;
    parameter NaN = 32'h7FC00000;
	
	parameter FLOAT_ONE = 32'h3f800000;
	
	reg [5:0] dimension = DEFAULT_DIMENSION;
	reg [23:0] sdReadBase;
	reg [23:0] sdReadAddress;
	reg [9:0] ramLoadAddress;
	reg startSdRead = 0;
	reg ramWriteDone = 0;
    reg forceReset = 1;
	
	/* Stages:
		0 - Idle, waiting for CPU start
		1 - Reading from SDRAM
		2 - Passing control off to calculate, when done, output
	*/
	reg [3:0] stage = 0;		// stage of computation
	reg [31:0] finalResult = 32'h3f800000;
	
	/*
        Doolittle's algorithm's registers
    
    */
    reg [9:0] rowAddress[4:0]; 
    
    // loop indices
    reg [5:0] i;
    reg [5:0] j;
    reg [5:0] p;
    reg [5:0] k;
    
    reg [9:0] luStage = 0;
    reg [9:0] pStage = 0;
    reg [9:0] diagonalStage = 0;
    reg [9:0] counter;
    
    reg [31:0] ajj;
    reg [31:0] aij;
    reg [31:0] aip;
    reg [31:0] apj;
    
    // row swap related
    reg [5:0] swapCount = 0;
    reg negateSign = 0;
    
	
	// instantiate ram
    reg [9:0] ramReadAddress;
	reg [9:0] ramWriteAddress;
	wire [31:0] ramReadData;
	reg [31:0] ramWriteData;
	reg ramWriteEnable;
	reg ramReadEnable;
    
	ram_det ram_inst(
		.clock(clk),
		.data(ramWriteData),
		.rdaddress(ramReadAddress),
		.wraddress(ramWriteAddress),
		.wren(ramWriteEnable),
		.rden(ramReadEnable),
		.q(ramReadData)	
	);
       
    // instantiate FP add/sub unit
    // 7 cycles latency
    reg adderMode = 0;      // 1 to add,  0 to sub
    reg [31:0] adderDataa;
    reg [31:0] adderDatab;
    wire adderNan; 
    wire [31:0] adderResult;
    wire adderZero;
	
	
    fp_add addsub(
        .aclr(reset),
        .add_sub(adderMode),
        .clk_en(clk_en),
        .clock(clk),
        .dataa(adderDataa),
        .datab(adderDatab),
        .nan(adderNan),
        .result(adderResult),
        .zero(adderZero)    
    );

    // instantiate FP multiplier
    // 5 cycles latency
    reg [31:0] mulDataa;
    reg [31:0] mulDatab;
    wire mulNan;
    wire [31:0] mulResult;
    wire mulZero;
    
    fp_mult mul(
        .aclr(reset),
        .clk_en(clk_en),
        .clock(clk),
        .dataa(mulDataa),
        .datab(mulDatab),
        .nan(mulNan),
        .result(mulResult),
        .zero(mulZero)    
    );
	
    // instantiate FP divider
    reg [31:0] divNumerator;
    reg [31:0] divDenominator;
    wire divNan;
    wire [31:0] divResult;
    wire divZero;
    
    fp_div div(
        .aclr(reset),
        .clk_en(clk_en),
        .clock(clk),
        .dataa(divNumerator),
        .datab(divDenominator),
        .nan(divNan),
        .result(divResult),
        .zero(divZero)
    
    );

    
    // clock edged triggered
	always @ (posedge clk) begin
			
		// we get a reset command
		if (reset || forceReset) begin
            forceReset <= 0;
            
			stage <= 0;
			done <= 0;
			result <= 0;
			irq <= 0;
			
			// Avalon master
			read <= 0;
			write <= 0;
			address <= 0;
			writedata <= 0;
		
			
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
			finalResult <= 32'h3F800000;
            
            i <= 0;
            j <= 0;
            p <= 0;
            k <= 0;
            
            luStage <= 0;
            diagonalStage <= 0;
			swapCount <= 0;
            negateSign <= 0;

		end else if (stage == 0) begin   // idle state. doing nothing
			if (start && datab > 1) begin  // start
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
					
					//done <= 1;
					result <= 99;
			end else if (start && datab <= 1) begin		// send dimension <= 1 to check for ready status
				done <= 1;
				result <= -1;
			end else begin
				done <= 0;
				result <= 0;
			end
			
			
		end else if (stage == 1) begin  // read from SDRAM
		
			if (start) begin		// invalid start - we are not ready
				result <= 1;
				done <= 1;
			end else begin
				result <= 0;
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
			
			// initialise row address
            if (i < dimension) begin
                rowAddress[i] <= i*dimension;
                i <= i+1;
				
            end else if (ramWriteDone) begin		// start calculating
				stage <= 3;
				
				ramReadAddress <= 0;
				ramWriteAddress <= 0;
				ramWriteData <= 0;
				ramWriteEnable <= 0;
				ramReadEnable <= 0;
				
				i <= 0;
			end
			
		end else if (stage == 2) begin	// calculating
			if (start) begin		// invalid start - we are not ready
				result <= 2;
				done <= 1;
			end else begin
				result <= 0;
				done <= 0;
			
			end
			
			// begin LU decomposition
            /*
                LU stages
                    0 - Fetch ajj
                    1 - ajj latency
                    2 - receive ajj
                    3 - swap rows, if necessary
                    4 - fetch aij
                    5 - aij latency
                    6 - receive aij 
                    7 - p Loop
                    8 - divide aij/ajj
                    9 - divider latency
                    10 - write aij
                    11 - loop back or continue
                    
                    
                    12 - fetch aij
                    13 - aij latency
                    14 - receive aij
                    15 - p loop
                    16 - write aij
                    17 - increment j or i
            */
			if (i < dimension) begin
               
                if (luStage == 0) begin
					if (i == 0) begin
						luStage <= 12;
					
					end else begin
					
						ramReadAddress <= rowAddress[j] + j;
						ramReadEnable <= 1;
						
						luStage <= 1;
						
					end
                
                end else if (luStage == 1) begin
                    // latency
                    // optimise?
                    ramReadEnable <= 0;
                    luStage <= 2;
                
                end else if (luStage == 2) begin
                    ajj = ramReadData;
                    
                    if (ajj == 0) begin
                        luStage <= 3;
                    end else begin
                        luStage <= 4;
                    end
                    
                end else if (luStage == 3) begin
                    // swap
                    
                    if (swapCount > dimension) begin    // NaN
                        finalResult <= NaN;
                        irq <= 1;
                        stage <= 4;
                    end else begin
                        // find row to swap
                        // TODO Row swapping
                        
                        
                        luStage <= 4;
                    end
                
                end else if (luStage == 4) begin    // fetch aij
                    ramReadAddress <= rowAddress[i] + j;
                    ramReadEnable <= 1;
                    luStage <= 5;
                    
                end else if (luStage == 5) begin // latency
                    ramReadEnable <= 0;
                    luStage <= 6;
                
                end else if (luStage == 6) begin
                    aij <= ramReadData;
                    
                    p <= 0;
                    pStage <= 0;
                    luStage <= 7;
           
                end else if (luStage == 7) begin
                    if (p < j) begin
                        
                        /*  
                            pStage
                                0 - fetch aip
                                1 - fetch apj
                                2 - receive aip
                                3 - receive apj
                                4 - multiply latency
                                5 - subtract start
                                6 - adder latency
                        */
                        if (pStage == 0) begin
                            ramReadAddress <= rowAddress[i] + p;
                            ramReadEnable <= 1;
                            pStage <= 1;
                            
                        end else if (pStage == 1) begin
                            ramReadAddress <= rowAddress[p] + j;
                            pStage <= 2;
                            
                        end else if (pStage == 2) begin
                            aip <= ramReadData;
                            ramReadEnable <= 0; 
                            pStage <= 3;
                        end else if (pStage == 3) begin
                            apj = ramReadData;
                            
                            // start multiplication
                            counter <= MULTPLIER_LATENCY;
                            mulDataa <= aip;
                            mulDatab <= apj;
                            
                            pStage <= 4;
                            
                        end else if (pStage == 4) begin
                            
                            if (counter) begin
                                counter <= counter - 1;
                                
                            end else begin
                                pStage <= 5;
                            end
                            
                        end else if (pStage == 5) begin
                            adderMode <= 0;
                            adderDataa <= aij;
                            adderDatab <= mulResult;
                            
                            counter <= ADDER_LATENCY;
                            
                            pStage <= 6;
                            
                        end else if (pStage == 6) begin
                            if (counter) begin
                                counter <= counter - 1;
                                
                            end else begin
                                pStage <= 7;
                            end
                        
                        end else if (pStage == 7) begin
                            aij <= adderResult;
                            
                            p <= p + 1;
                            pStage <= 0;
                        
                        end
                    
                    end else begin
                        
                        luStage <= 8;
                    end
                
                end else if (luStage == 8) begin
                    divNumerator <= aij;
                    divDenominator <= ajj;
                    
                    counter <= DIVIDER_LATENCY;
                    
                    luStage <= 9;
                
                end else if (luStage == 9) begin
                    if (counter) begin
                        counter <= counter - 1;
                        
                    end else begin
                        luStage <= 10;
                    end
                
                end else if (luStage == 10) begin
                    // save aij
                    ramWriteEnable <= 1;
                    ramWriteAddress <= rowAddress[i] + j;
                    ramWriteData <= divResult;
                    
                    luStage <= 11;
                
                end else if (luStage == 11) begin
                    j = j + 1;
                    
                    if (j < i) begin
                        luStage <= 0;
                        
                    end else begin
                        luStage <= 12;
                        
                    end
                    
                end else if (luStage == 12) begin
                    ramReadAddress <= rowAddress[i] + j;
                    ramReadEnable <= 1;
                    
					luStage <= 13;
				                
                end else if (luStage == 13) begin
                    ramReadEnable <= 0;
                    luStage <= 14;
                end else if (luStage == 14) begin
					aij <= ramReadData;
                    
                    p <= 0;
                    pStage <= 0;
                    
                    luStage <= 15;
                
                end else if (luStage == 15) begin
                    if (p < i) begin
                        
                        /*  
                            pStage
                                0 - fetch aip
                                1 - fetch apj
                                2 - receive aip
                                3 - receive apj
                                4 - multiply latency
                                5 - subtract start
                                6 - adder latency
                        */
                        if (pStage == 0) begin
                            ramReadAddress <= rowAddress[i] + p;
                            ramReadEnable <= 1;
                            pStage <= 1;
                            
                        end else if (pStage == 1) begin
                            ramReadAddress <= rowAddress[p] + j;
                            pStage <= 2;
                            
                        end else if (pStage == 2) begin
                            aip <= ramReadData;
                            ramReadEnable <= 0; 
                            pStage <= 3;
                        end else if (pStage == 3) begin
                            apj = ramReadData;
                            
                            // start multiplication
                            counter <= MULTPLIER_LATENCY;
                            mulDataa <= aip;
                            mulDatab <= apj;
                            
                            pStage <= 4;
                            
                        end else if (pStage == 4) begin
                            
                            if (counter) begin
                                counter <= counter - 1;
                                
                            end else begin
                                pStage <= 5;
                            end
                            
                        end else if (pStage == 5) begin
                            adderMode <= 0;
                            adderDataa <= aij;
                            adderDatab <= mulResult;
                            
                            counter <= ADDER_LATENCY;
                            
                            pStage <= 6;
                            
                        end else if (pStage == 6) begin
                            if (counter) begin
                                counter <= counter - 1;
                                
                            end else begin
                                pStage <= 7;
                            end
                        
                        end else if (pStage == 7) begin
                            aij <= adderResult;
                            
                            p <= p + 1;
                            pStage <= 0;
                        
                        end
                    
                    end else begin
                        
                        luStage <= 16;
                   
                   end
                
                end else if (luStage == 16) begin
                    // save aij
                    ramWriteEnable <= 1;
                    ramWriteAddress <= rowAddress[i] + j;
                    ramWriteData <= aij;
                    
                    luStage <= 17;
                
                end else if (luStage == 17) begin
                    ramWriteEnable <= 0;
                    
                    j = j + 1;
                    
                    if (j < dimension) begin
                        luStage <= 12;
                    
                    end else begin
                        i <= i + 1;
                        j <= 0;
                        luStage <= 0;
                        
                    end
                end
               
            end else begin
                stage <= 3;
                
            end
		
		end else if (stage == 3) begin
		
			if (start) begin		// invalid start - we are not ready
				result <= 3;
				done <= 1;
			end else begin
				result <= 0;
				done <= 0;
			
			end
		
			// oh we are done
			// start to multiply diagonal
			if (k < dimension) begin
				/*
					Diagonal stage
					0 - fetch akk
					1 - fetch latency
					2 - multiply
					3 - multiply latency
					4 - loop check
				*/                    
				if (diagonalStage == 0) begin
					ramReadEnable <= 1;
					ramReadAddress <= rowAddress[k] + k;
					
					diagonalStage <= 1;
				
				end else if (diagonalStage == 1) begin
					ramReadEnable <= 0;
					diagonalStage <= 2;
				
				end else if (diagonalStage == 2) begin
					done <= 1;
					result <= finalResult;
				
					mulDataa <= finalResult;
					mulDatab <= ramReadData;
					
					counter <= MULTPLIER_LATENCY+1;
					
					diagonalStage <= 3;
					
				end else if (diagonalStage == 3) begin
					if (counter) begin
						counter <= counter - 1;
						
					end else begin
						diagonalStage <= 4;
					end
				
				end else if (diagonalStage == 4) begin
					finalResult <= mulResult;
					
					k <= k+1;
					diagonalStage <= 0;
					
				end
			
			end else begin
				if (negateSign) begin
					finalResult[31] = ~finalResult[31];
				end
				
				irq <= 1;
				stage <= 4;
			
			end
			
		
		end else if (stage == 4) begin
			if (start) begin		// invalid start - we are not ready
				result <= 3;
				done <= 1;
			end else begin
				result <= 0;
				done <= 0;
			
			end
			
			if (result_read) begin
				result_readdata <= finalResult;
				irq <= 0;
				stage <= 0;		// reset to zero
				forceReset <= 1;
			end
		end	
	end

endmodule
