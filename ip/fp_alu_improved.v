// Improved ALU to bypass ALU on 0, NaN, or infinity calculations

module fp_alu_improved(
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
input wire	[1:0] n;
output reg	done;
output reg	[31:0] result;

wire aludone;
wire [31:0] aluresult;

parameter NaN = 32'h7fffffff;

// Instantiate the original ALU
fp_alu	improved_instance(
	.clk(clk),
	.clk_en(clk_en),
	.start(start),
	.reset(reset),
	.dataa(dataa),
	.datab(datab),
	.n(n),
	.done(aludone),
	.result(aluresult)
);

always @ (posedge clk) begin

	// References: http://en.wikipedia.org/wiki/NaN#Floating_point
	// http://www.gnu.org/software/libc/manual/html_node/FP-Exceptions.html#FP-Exceptions
	if (start == 1) begin
		// NaN Operation
		if ( (dataa[30:23] == 'h255 && dataa[22:0] != 0) || (datab[30:23] == 'h255 && datab[22:0] != 0) ) begin
			done <= 1;
			result <= NaN;
		end else if ( dataa[30:0] == 31'h7F800000 || datab[30:0] == 31'h7F800000) begin // Infinity operations
			done <= 1;
			result <= NaN;
		end else if (datab == 0 && n == 3) begin  // Divide by zero
			if (dataa == 0) begin
				done <= 1;
				result <= NaN;
			end else if (dataa[31] == 0) begin
				// +infinity
				done <= 1;
				result = 32'h7f800000;
			end else if (dataa[31] == 1) begin
				// -infinity
				done <= 1;
				result = 32'hff800000;
			end
		end else if (dataa == 0 || datab == 0)  begin	// zero arithmetic
			if (n == 0) begin // addition
				done <= 1;
				result <= (dataa == 0) ? datab : dataa;
			end else if (n == 1) begin // subtraction
				done <= 1;
				if (dataa == 0) begin
					result[30:0] <= datab[30:0];
					result[31] <= ~datab[31];
				end else begin
					result <= dataa;
				end
			end else begin // multiplication or division
				result <= 0;
			end
		end else if ( (dataa == 1 || datab == 1) && n == 2) begin 	// one multipication
			done <= 1;
			result <= (dataa == 1) ? datab : dataa;
		end else if ( datab == 1 && n == 3 ) begin	// divide by 1
			done <= 1;
			result <= dataa;
		end  // No need to assign, since the ALU won't be done in a single cycle anyway
		
	end else begin
		done <= aludone;
		result <= aluresult;
	end
end


endmodule