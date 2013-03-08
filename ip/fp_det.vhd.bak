LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE work.all;

entity fp_det IS
	GENERIC( vsize: INTEGER := 3); -- length of vectors
	PORT(
		 clk			:IN std_logic;
		 clk_en		:IN std_logic;
		 start		:IN std_logic; 
		 reset		:IN std_logic;
		 wraddress	:OUT std_logic_vector(9 DOWNTO 0); --
		 rdaddress	:OUT std_logic_vector(9 DOWNTO 0); 
		 n				:IN std_logic_vector(5 DOWNTO 0); --
		 readdata	:IN std_logic_vector(31 DOWNTO 0); 
		 writedata	:OUT std_logic_vector(31 DOWNTO 0); --
		 rden			:OUT std_logic;
		 wren			:OUT std_logic; --
		 done 		:OUT std_logic; 
		 result		:OUT std_logic_vector(31 DOWNTO 0)
	);
END ENTITY fp_det;

ARCHITECTURE Determinant  of fp_det IS
--	TYPE value_t IS ARRAY (31 DOWNTO 0) OF std_logic;
--	TYPE column_t IS ARRAY (vsize-1 DOWNTO 0) OF value_t;
--	TYPE matrix_t IS ARRAY (vsize-1 DOWNTO 0) OF column_t;
	TYPE state_t IS (IDLE, read_addr, read_data, mult1, mult2, mult3, mult4, mult5, mult6, mult7, mult8, mult9, mult10, mult11, mult12, ADD1, ADD2, ADD3, ADD4, ADD5, ADD6);
	
signal a :std_logic_vector(31 DOWNTO 0);
signal m :matrix_t;
signal det: std_logic_vector(31 DOWNTO 0);
signal dataa_add_sig, dataa_mult_sig, datab_add_sig, datab_mult_sig, result_add_sig, result_mult_sig : std_logic_vector(31 DOWNTO 0);
signal aclr_add_sig, aclr_mult_sig, add_sub_sig, clk_en_add_sig, clk_en_mult_sig, clock1_mult_sig, clock_add_sig : std_logic;
signal nan_add_sig, nan_mult_sig, zero_add_sig, zero_mult_sig :std_logic;
signal add_mult : std_logic;



BEGIN 
	
	dut1 : ENTITY fp_add PORT MAP (
		aclr	 	=> aclr_add_sig,
		add_sub 	=> add_sub_sig,
		clk_en	=> clk_en_add_sig,
		clock	 	=> clock_add_sig,
		dataa	 	=> dataa_add_sig,
		datab	 	=> datab_add_sig,
		nan	 	=> nan_add_sig,
		result	=> result_add_sig,
		zero	 	=> zero_add_sig
	);

	dut2 : ENTITY fp_mult PORT MAP (
		aclr	 => aclr_mult_sig,
		clk_en => clk_en_mult_sig,
		clock	 => clock1_mult_sig,
		dataa	 => dataa_mult_sig,
		datab	 => datab_mult_sig,
		nan	 => nan_mult_sig,
		result => result_mult_sig,
		zero	 => zero_mult_sig
	);
	

C1:
PROCESS(state, m, nstate, det)


variable mat1, mat2, mat3, mat4, mat5, mat6, det : std_logic_vector(31 DOWNTO 0);
variable iterator :integer; 
variable loc: integer;
BEGIN
		
iterator := '0';
loc := '0';
add_sub_sig <= '1';
done <= '0';
add_mult <= '1';
rden <=0;

if start <= '1' then
	nstate <= mult1;
end if; 

case state is

	WHEN IDLE =>
		if start = '1' then
		nstate <= read_addr;		
		end if;
		
	when read_addr=>
		rden <= '1';
		readaddr <= iterator; 
		next_state <= read_data;
		i := iterator mod 4;
		i := i-1;
		state <= read_data;
		
	when read_data=>
		m(i) <= readdata;	
		iterator := iterator + '4';
		if iterator = 36 then
		state<= mult1;
		else
		state<= read_addr;
		end if;
		
		
	WHEN mult1 =>
		dataa_mult_sig <= m(0);
		datab_mult_sig <= m(4);
		nstate <= mult2;
	WHEN mult2 =>
		mat1 := result_mult_sig;
		dataa_mult_sig <= m(8);
		datab_mult_sig <= mat1;
		nstate <= mult3;
		
	WHEN mult3 =>
		mat1 := result_mult_sig;
		dataa_mult_sig <= m(1);
		datab_mult_sig <= m(5);
		nstate <= mult4;
	WHEN mult4 =>	
		mat2 := result_mult_sig;
		dataa_mult_sig <= m(6);
		datab_mult_sig <=	mat2;
		nstate <= mult5;
		
	WHEN mult5 =>	
		mat2 := result_mult_sig;
		dataa_mult_sig <= m(2);
		datab_mult_sig <=	m(3);
		nstate <= mult6;
		
	WHEN mult6 =>	
		mat3 := result_mult_sig;
		dataa_mult_sig <= m(7);
		datab_mult_sig <=	mat3;
		nstate <= mult7;
		
	WHEN mult7 =>	
		mat3 := result_mult_sig;
		dataa_mult_sig <= m(2);
		datab_mult_sig <=	m(4);	
		nstate <= mult8;
		
	WHEN mult8 =>	
		mat4 := result_mult_sig;
		dataa_mult_sig <= m(6);
		datab_mult_sig <=	mat4;
		nstate <= mult9;
		
	WHEN mult9 =>	
		mat4 := result_mult_sig;
		dataa_mult_sig <= m(1);
		datab_mult_sig <=	m(3);
		nstate <= mult10;
		
	WHEN mult10 =>	
		mat5 := result_mult_sig;
		dataa_mult_sig <= m(8);
		datab_mult_sig <=	mat5;
		nstate <= mult11;
		
	WHEN mult11 =>	
		mat5 := result_mult_sig;
		dataa_mult_sig <= m(0);
		datab_mult_sig <=	m(5);
		nstate <= mult12;
		
	WHEN mult12 =>	
		mat6	:= result_mult_sig;
		dataa_mult_sig <= m(6);
		datab_mult_sig <=	mat6;	
		nstate <= mult13;
	WHEN mult13 =>	
		mat6 := result_mult_sig;
		nstate <= ADD1;
		
	WHEN ADD1 =>
		add_mult <= '0';
		add_sub_sig <= '1';
		dataa_add_sig <= mat1;
		datab_add_sig <= mat2;
		nstate <= ADD2;
	WHEN ADD2 =>
		add_mult <= '0';
		det <= result_add_sig;
		add_sub_sig <= '1';
		dataa_add_sig <= mat3;
		datab_add_sig <= det;
		nstate <= ADD3;
		
	WHEN ADD3 =>	
		add_mult <= '0';
		det <= result_add_sig;
		add_sub_sig <= '0';
		dataa_add_sig <= mat4;
		datab_add_sig <= det;
		nstate <= ADD4;
		
	WHEN ADD4 =>	
		add_mult <= '0';
		det <= result_add_sig;
		add_sub_sig <= '0';
		dataa_add_sig <= mat5;
		datab_add_sig <= det;
		nstate <= ADD5;
		
	WHEN ADD5 =>	
		add_mult <= '0';
		det <= result_add_sig;
		add_sub_sig <= '0';
		dataa_add_sig <= mat6;
		datab_add_sig <= det;		
		nstate <= ADD6;
		
	WHEN ADD6 =>
		add_mult <= '0';
		det <= result_add_sig;		
		result <= det;
		done <= 1;
		nstate <= IDLE;		
END CASE;	
	
	
	
		
		
--mat1 := m(0)(0)*m(1)(1)*m(2)(2);
--mat2 := m(0)(1)*m(1)(2)*m(2)(0);
--mat3 := m(0)(2)*m(1)(0)*m(2)(1);
--mat4 := m(0)(2)*m(1)(1)*m(2)(0);
--mat5 := m(0)(1)*m(1)(0)*m(2)(2);
--mat6 := m(0)(0)*m(1)(2)*m(2)(1);
--
--det <= mat1 + mat2 + mat3 - mat4 - mat5 - mat6;

END PROCESS C1;

R4: -- state register with reset
PROCESS
variable count :std_logic_vector(2 DOWNTO 0);
BEGIN

  WAIT UNTIL clk'EVENT and clk='1';
	if count = '5' and add_mult = '1' then
	count <= 0;
	state <= nstate;
	elsif count = '7' and add_mult ='0' then
	count <= 0;
	state <= nstate;
	else 
	count <= count+1;
	end if; 

	if reset = '1' then
	state <= IDLE;
	end if; 
	
	
END PROCESS R4;

END ARCHITECTURE Determinant;



















--C1:
--PROCESS  
--BEGIN 
--
--	for I in 0 to vsize loop
--		for J in 0 to I loop
--			a <= getAt(m, I, J, vsize);
--			for P in 0 to J loop
--				a <-= getAt(m, I, P, vsize) * getAt(m, I, J, vsize);
--			end loop;
--			putAt(m, I, J, vsize, a/getAt(m, J, J, vsize));
--		end loop;
--		for J in I to vsize loop
--			a <= getAt(m, I, J, vsize);
--			for P in 0 to I loop 
--				a <-= getAt(m, I, P, vsize) * getAt(m, P, J, vsize);
--			end loop;		
--			putAt(m, I, J, vsize, a);
--		end loop;
--	end loop; 
--	
--	
----    for (i = 0; i < dimension; i++){
----        for (j = 0; j < i; j++){
----            a = getAt(m, i, j, dimension);
----            for (p = 0; p < j; p++){
----                a -= getAt(m, i, p, dimension) * getAt(m, p, j, dimension);
----            }
----            putAt(m, i, j, dimension, a/getAt(m, j, j, dimension));
----        }
----        for (j = i; j < dimension; j++){
----            a = getAt(m, i, j, dimension);
----            for (p = 0; p < i; p++){
----                a -= getAt(m, i, p, dimension) * getAt(m, p, j, dimension);
----            }
----            putAt(m, i, j, dimension, a);
----        }
----    }
--
--function getAt (m :matrix_t, i : std_logic_vector, j : std_logic_vector, vsize: std_logic_vector )
--				
--				return something : std_logic_vector is
--		variable TMP : std_logic_vector := (others => '0'); 
--		begin
--			TMP := m + i*vsize + j;
--			return TMP;	
--		end getAt
--		
--				
--
----// Based on i and j, and a float pointer, get the value at row i column j
----float getAt(float *m, int i, int j, int dimension){
----    return *(m + i*dimension + j);
----}
--
--function putAt(m :matrix_t, i : std_logic_vector, j : std_logic_vector, vsize: std_logic_vector, value : std_logic_vector)
--		return 
--
----// Based on i and j, and a float pointer, put the value at row i column j
----void putAt(float *m, int i, int j, int dimension, float value){
----    *(m + i*dimension + j) = value;
----}


