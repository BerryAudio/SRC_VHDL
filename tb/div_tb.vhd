--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   17:22:41 06/24/2015
-- Design Name:   
-- Module Name:   /home/charlie/projects/SRC_VHDL/tb/div_tb.vhd
-- Project Name:  SRC_PRJ
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: div
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
 
ENTITY div_tb IS
END div_tb;
 
ARCHITECTURE behavior OF div_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT div
    PORT(
         clk : IN  std_logic;
         rst : IN  std_logic;
         i_en : IN  std_logic;
         i_divisor : IN  unsigned(26 downto 0);
         i_dividend : IN  unsigned(26 downto 0);
         o_busy : OUT  std_logic;
         o_remainder : OUT  unsigned(24 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal rst : std_logic := '0';
   signal i_en : std_logic := '0';
   signal i_divisor : unsigned(26 downto 0) := (others => '0');
   signal i_dividend : unsigned(26 downto 0) := (others => '0');

 	--Outputs
   signal o_busy : std_logic;
   signal o_remainder : unsigned(24 downto 0);

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: div PORT MAP (
          clk => clk,
          rst => rst,
          i_en => i_en,
          i_divisor => i_divisor,
          i_dividend => i_dividend,
          o_busy => o_busy,
          o_remainder => o_remainder
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;
		
		i_en <= '1';
		i_divisor <= to_unsigned( 2, i_divisor'length );
		i_dividend <= to_unsigned( 1, i_dividend'length );
		wait until rising_edge( clk );
		
		i_en <= '0';
		wait until rising_edge( clk );
		
		wait until o_busy = '0';
		
		i_en <= '1';
		i_divisor <= to_unsigned( 4, i_divisor'length );
		i_dividend <= to_unsigned( 1, i_dividend'length );
		wait until rising_edge( clk );
		
		i_en <= '0';
		wait until rising_edge( clk );
		
		wait until o_busy = '0';
		
		i_en <= '1';
		i_divisor <= to_unsigned( 8, i_divisor'length );
		i_dividend <= to_unsigned( 1, i_dividend'length );
		wait until rising_edge( clk );
		
		i_en <= '0';
		wait until rising_edge( clk );
		
		
      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
