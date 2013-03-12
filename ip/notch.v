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

	

	always @ (posedge clk) begin
			

	end

endmodule
