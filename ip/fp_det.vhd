LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE work.all;

entity fp_det IS
	GENERIC( vsize: INTEGER := 12); -- length of vectors
	PORT(
		 clk			:IN std_logic;
		 clk_en		:IN std_logic;
		 start		:IN std_logic; 
		 reset		:IN std_logic;
		 n				:IN std_logic_vector(4 DOWNTO 0);
		 readdata		:IN std_logic_vector(31 DOWNTO 0);
		 writedata		: OUT std_logic_vector(31 DOWNTO 0);
		 wraddress	:IN std_logic_vector(9 DOWNTO 0);
		 rdaddress	:IN std_logic_vector(9 DOWNTO 0);
		 wren			:OUT std_logic;
		 done 		:OUT std_logic;
		 result		:OUT std_logic_vector(31 DOWNTO 0);
	);
END fp_det;

ARCHITECTURE Determinant  of fp_det IS
	TYPE value_t IS ARRAY (31 DOWNTO 0) OF std_logic;
	TYPE column_t IS ARRAY (vsize DOWNTO 0) OF value_t;
	TYPE matrix_t IS ARRAY (vsize DOWNTO 0) OF column_t;

signal a :std_logic_vector(31 DOWNTO 0);
signal m :matrix_t;


C1:
PROCESS  
BEGIN 

	for I in 0 to vsize loop
		for J in 0 to I loop
			a <= getAt(m, I, J, vsize);
			for P in 0 to J loop
				a <-= getAt(m, I, P, vsize) * getAt(m, I, J, vsize);
			end loop;
			putAt(m, I, J, vsize, a/getAt(m, J, J, vsize));
		end loop;
		for J in I to vsize loop
			a <= getAt(m, I, J, vsize);
			for P in 0 to I loop 
				a <-= getAt(m, I, P, vsize) * getAt(m, P, J, vsize);
			end loop;		
			putAt(m, I, J, vsize, a);
		end loop;
	end loop; 
	
	
--    for (i = 0; i < dimension; i++){
--        for (j = 0; j < i; j++){
--            a = getAt(m, i, j, dimension);
--            for (p = 0; p < j; p++){
--                a -= getAt(m, i, p, dimension) * getAt(m, p, j, dimension);
--            }
--            putAt(m, i, j, dimension, a/getAt(m, j, j, dimension));
--        }
--        for (j = i; j < dimension; j++){
--            a = getAt(m, i, j, dimension);
--            for (p = 0; p < i; p++){
--                a -= getAt(m, i, p, dimension) * getAt(m, p, j, dimension);
--            }
--            putAt(m, i, j, dimension, a);
--        }
--    }

function getAt (m :matrix_t, i : std_logic_vector, j : std_logic_vector, vsize: std_logic_vector )
				
				return something : std_logic_vector is
		variable TMP : std_logic_vector := (others => '0'); 
		begin
			TMP := m + i*vsize + j;
			return TMP;	
		end getAt
		
				

--// Based on i and j, and a float pointer, get the value at row i column j
--float getAt(float *m, int i, int j, int dimension){
--    return *(m + i*dimension + j);
--}

function putAt(m :matrix_t, i : std_logic_vector, j : std_logic_vector, vsize: std_logic_vector, value : std_logic_vector)
		return 

--// Based on i and j, and a float pointer, put the value at row i column j
--void putAt(float *m, int i, int j, int dimension, float value){
--    *(m + i*dimension + j) = value;
--}


