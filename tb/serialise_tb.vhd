--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   12:20:17 06/19/2015
-- Design Name:   
-- Module Name:   /home/charlie/projects/SRC_VHDL/tb/serialise_tb.vhd
-- Project Name:  SRC_PRJ
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: serialise_top
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
 
ENTITY serialise_tb IS
END serialise_tb;
 
ARCHITECTURE behavior OF serialise_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT serialise_top
    PORT(
         clk : IN  std_logic;
         i_sample_0 : IN  signed(23 downto 0);
         i_sample_1 : IN  signed(23 downto 0);
         i_sample_en : IN  std_logic;
         o_sample_0_0 : OUT  signed(23 downto 0);
         o_sample_0_1 : OUT  signed(23 downto 0);
         o_sample_0_en : OUT  std_logic;
         o_sample_1_0 : OUT  signed(23 downto 0);
         o_sample_1_1 : OUT  signed(23 downto 0);
         o_sample_1_en : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal i_sample_0 : signed(23 downto 0) := (others => '0');
   signal i_sample_1 : signed(23 downto 0) := (23 => '1', others => '0');
   signal i_sample_en : std_logic := '0';

 	--Outputs
   signal o_sample_0_0 : signed(23 downto 0);
   signal o_sample_0_1 : signed(23 downto 0);
   signal o_sample_0_en : std_logic;
   signal o_sample_1_0 : signed(23 downto 0);
   signal o_sample_1_1 : signed(23 downto 0);
   signal o_sample_1_en : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
	signal cnt : unsigned( 5 downto 0 ) := ( others => '0' );
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: serialise_top PORT MAP (
          clk => clk,
          i_sample_0 => i_sample_0,
          i_sample_1 => i_sample_1,
          i_sample_en => i_sample_en,
          o_sample_0_0 => o_sample_0_0,
          o_sample_0_1 => o_sample_0_1,
          o_sample_0_en => o_sample_0_en,
          o_sample_1_0 => o_sample_1_0,
          o_sample_1_1 => o_sample_1_1,
          o_sample_1_en => o_sample_1_en
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 
	cnt_process : process( clk )
	begin
		if rising_edge( clk ) then
			cnt <= cnt + 1;
			i_sample_en <= '0';
			if cnt = 0 then
				i_sample_0 <= i_sample_0 + 1;
				i_sample_1 <= i_sample_1 + 1;
				i_sample_en <= '1';
			end if;
		end if;
	end process;

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
