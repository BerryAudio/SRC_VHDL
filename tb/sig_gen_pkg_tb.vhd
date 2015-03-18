--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   08:45:50 11/26/2014
-- Design Name:   
-- Module Name:   /home/charlie/projects/SRC_V0.9.2/tb/sig_gen_pkg_tb.vhd
-- Project Name:  SRC_V0.9.2
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: audio_top
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

library std;
use std.textio.all;

library work;
use work.sig_gen_pkg.all;
 
ENTITY sig_gen_pkg_tb IS
END sig_gen_pkg_tb;
 
ARCHITECTURE behavior OF sig_gen_pkg_tb IS 
 

   -- Clock period definitions
   constant clk_period : time := 22.676 us;
	
	signal clk : std_logic := '0';
	signal run : std_logic := '0';
	signal sine : signed( 23 downto 0 ) := ( others => '0' );
	
BEGIN
 
   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
	
	process( clk )
		file		outfile	: text is out "./tb/test/sine_test.txt";
		variable outline	: line;
		variable sig : signed( 23 downto 0 );
		variable sigr : real;
	begin
		if rising_edge( clk ) then
			if run = '1' then
				sig := fetch_sample;
				write( outline, to_integer( sig ) );
				writeline( outfile, outline );
				sine <= sig;
			end if;
		end if;
	end process;

   -- Stimulus process
   stim_proc: process
   begin
      
      wait until rising_edge( clk );
		run <= '1';

      wait until rising_edge( clk );
      wait;
   end process;

END;
