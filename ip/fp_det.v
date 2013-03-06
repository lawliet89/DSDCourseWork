module fp_det(
	clk,
	clk_en,
	start,
	reset,
	dataa,
	datab,
	n,
	done,
	result
);

input wire	clk;
input wire	clk_en;
input wire	start;
input wire	reset;
input wire	[31:0] dataa;
input wire	[31:0] datab;
input wire	[4:0] n;
output reg	done;
output reg	[31:0] result;

reg [31:0] matrix[4:0][4:0];
wire doolittle_done;
wire [31:0] doolittle_result;

// Instantiate the Richard Module
fp_alu_r	doolittle(
	.clk(clk),
	.clk_en(clk_en),
	.start(start),
	.reset(reset),
	.n(n),
	.matrix(matrix)
	.done(doolittle_done),		//output
	.result(doolittle_result)	//output
);

endmodule