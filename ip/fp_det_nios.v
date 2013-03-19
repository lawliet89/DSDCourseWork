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
    //reg [5:0] i;
    reg [5:0] j;
    reg [5:0] p;
    reg [5:0] k;
    
    reg [9:0] luStage = 0;
    reg [9:0] pStage = 0;
    reg [9:0] diagonalStage = 0;
    reg [9:0] counter;
	reg [9:0] calcStage = 0;
    
    reg [31:0] ajj;
    reg [31:0] aij;
    reg [31:0] aip;
    reg [31:0] apj;
    
    // row swap related
    reg [5:0] swapCount = 0;
    reg negateSign = 0;
	
	// simple calculation
	reg [31:0] a;
    reg [31:0] b;
	reg [31:0] c;
	reg [31:0] d;
	reg [31:0] e;
	reg [31:0] f;
	reg [31:0] g;
	reg [31:0] h;
	reg [31:0] i;
	
	reg [31:0] temp1;
	reg [31:0] temp2;
	reg [31:0] temp3;
	
	
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
	
	// instantiate FP multiplier
    // 5 cycles latency
    reg [31:0] mul2Dataa;
    reg [31:0] mul2Datab;
    wire mul2Nan;
    wire [31:0] mul2Result;
    wire mul2Zero;
    
    fp_mult mul2(
        .aclr(reset),
        .clk_en(clk_en),
        .clock(clk),
        .dataa(mul2Dataa),
        .datab(mul2Datab),
        .nan(mul2Nan),
        .result(mul2Result),
        .zero(mul2Zero)    
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
			calcStage <= 0;

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
				
				case (ramLoadAddress)
					0: a <= readdata;
					1: b <= readdata;
					2: c <= readdata;
					3: d <= readdata;
					4: e <= readdata;
					5: f <= readdata;
					6: g <= readdata;
					7: h <= readdata;
					8: i <= readdata;

				endcase
			
			end else if (!readdatavalid) begin
				ramWriteEnable <= 0;
			end
			
			// initialise row address
            if (i < dimension) begin
                rowAddress[i] <= i*dimension;
                i <= i+1;
				
            end else if (ramWriteDone) begin		// start calculating
				stage <= 2;
				
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
			
			if (calcStage == 0) begin	// e*i & h*f
				mulDataa <= e;
				mulDatab <= i;
				
				mul2Dataa <= h;
				mul2Datab <= f;
				
				calcStage <= 1;
				
			end else if (calcStage == 1) begin  // d*i & g*f
				mulDataa <= d;
				mulDatab <= i;
				
				mul2Dataa <= g;
				mul2Datab <= f;
				
				calcStage <= 2;
				
			end else if (calcStage == 2) begin  // d*h & e*g
				mulDataa <= d;
				mulDatab <= h;
				
				mul2Dataa <= e;
				mul2Datab <= g;
				
				calcStage <= 3;
				
				counter <= 3;
			end else if (calcStage == 3) begin  
				// latency
				
				if (counter)
					counter <= counter - 1;
				else
					calcStage <= 4;
				
			end else if (calcStage == 4) begin  //a*e*i & a*h*f
				done <= 1;
				result <= mulResult;
			
				mulDataa <= a;
				mulDatab <= mulResult;
				
				mul2Dataa <= a;
				mul2Datab <= mul2Result;
				
				calcStage <= 5;
				
			end else if (calcStage == 5) begin  //b*d*i & b*g*f
				mulDataa <= b;
				mulDatab <= mulResult;
				
				mul2Dataa <= b;
				mul2Datab <= mul2Result;
				
				calcStage <= 6;
				
			end else if (calcStage == 6) begin  // c*d*h & c*e*g
				mulDataa <= c;
				mulDatab <= mulResult;
				
				mul2Dataa <= c;
				mul2Datab <= mul2Result;
				
				calcStage <= 7;
				counter <= 3;
				
			end else if (calcStage == 7) begin  
				// latency
				
				if (counter)
					counter <= counter - 1;
				else
					calcStage <= 8;
				
			end else if (calcStage == 8) begin // aef + ahf
				adderMode <= 1;
				adderDataa <= mulResult;
				adderDatab <= mul2Result;
				
				calcStage <= 9;
				
			end else if (calcStage == 9) begin // bdi + bgf
				adderMode <= 1;
				adderDataa <= mulResult;
				adderDatab <= mul2Result;
				
				calcStage <= 10;
				
			end else if (calcStage == 10) begin // c*d*h + c*e*g
				adderMode <= 1;
				adderDataa <= mulResult;
				adderDatab <= mul2Result;
				
				calcStage <= 11;
				counter <= 5;
				
			end else if (calcStage == 11) begin 
				// latency
				if (counter)
					counter <= counter - 1;
				else
					calcStage <= 12;
				
			end else if (calcStage == 12) begin 	// aef + ahf done
				temp1 <= adderResult;
				
				calcStage <= 13;
				
			end else if (calcStage == 13) begin // aef + ahf - (bdi + bgf)
				adderMode <= 0;
				adderDataa <= temp1;
				adderDatab <= adderResult;
				calcStage <= 14;
				
			end else if (calcStage == 14) begin // c*d*h + c*e*g done
				temp2 <= adderResult;
			
				calcStage <= 15;
				
				counter <= 6;
				
			end else if (calcStage == 15) begin 
				// latency
				if (counter)
					counter <= counter - 1;
				else
					calcStage <= 16;
					
			end else if (calcStage == 16) begin 
				adderMode <= 1;
				adderDataa <= temp2;
				adderDatab <= adderResult;
				calcStage <= 17;
				
				counter <= 7;
				
			end else if (calcStage == 17) begin 
				// latency
				if (counter)
					counter <= counter - 1;
				else
					calcStage <= 18;
					
			end else if (calcStage == 18) begin
				finalResult <= adderResult;
			end

		end else if (stage == 3) begin
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
