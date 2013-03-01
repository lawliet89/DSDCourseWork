fp_div_inst : fp_div PORT MAP (
		aclr	 => aclr_sig,
		clk_en	 => clk_en_sig,
		clock	 => clock_sig,
		dataa	 => dataa_sig,
		datab	 => datab_sig,
		nan	 => nan_sig,
		result	 => result_sig,
		zero	 => zero_sig
	);
