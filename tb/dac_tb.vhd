--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   17:04:38 11/12/2014
-- Design Name:   
-- Module Name:   /home/charlie/projects/SRC_V0.7/tb/dac_tb.vhd
-- Project Name:  SRC_V0.7
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: dac_top
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
 
ENTITY dac_tb IS
END dac_tb;
 
ARCHITECTURE behavior OF dac_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
   COMPONENT dac_top
		generic (
			DAC_IF : string := "AD1955"
		);
		PORT(
         clk : IN  std_logic;
			rst : IN  std_logic;
         i_data0 : IN  signed(23 downto 0);
         i_data1 : IN  signed(23 downto 0);
         i_data_en : IN  std_logic;
         o_sample_en0 : OUT  std_logic;
         o_sample_en1 : OUT  std_logic;
         o_lrck : OUT  std_logic;
         o_bclk : OUT  std_logic;
         o_data0 : OUT  std_logic;
         o_data1 : OUT  std_logic
        );
   END COMPONENT;
    
   --Inputs
   signal clk : std_logic := '0';
   signal i_data0 : signed(23 downto 0) := (23 => '1', others => '0');
   signal i_data1 : signed(23 downto 0) := (others => '0');
   signal i_data_en : std_logic := '0';

 	--Outputs
   signal o_sample_en0 : std_logic;
   signal o_sample_en1 : std_logic;
   signal o_lrck : std_logic;
   signal o_bclk : std_logic;
   signal o_data0 : std_logic;
   signal o_data1 : std_logic;

   -- Clock period definitions
   constant clk_period : time := 5.0856 ns;
	signal count : unsigned( 7 downto 0 ) := ( others => '0' );
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: dac_top PORT MAP (
          clk => clk,
			 rst => '0',
          i_data0 => i_data0,
          i_data1 => i_data1,
          i_data_en => i_data_en,
          o_sample_en0 => o_sample_en0,
          o_sample_en1 => o_sample_en1,
          o_lrck => o_lrck,
          o_bclk => o_bclk,
          o_data0 => o_data0,
          o_data1 => o_data1
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 
	
	count_process : process( clk )
	begin
		if rising_edge( clk ) then
			count <= count + 1;
			i_data_en <= '0';
			if count = 255 then
				i_data0 <= i_data0 + 1;
				i_data1 <= i_data1 + 1;
				i_data_en <= '1';
			end if;
		end if;
	end process count_process;

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
