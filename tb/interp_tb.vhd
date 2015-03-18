--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   11:30:32 11/10/2014
-- Design Name:   
-- Module Name:   /home/charlie/projects/src_top/tb/interp_tb.vhd
-- Project Name:  src_top
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: interpolator
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
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

library work;
use work.src.all;
 
ENTITY interp_tb IS
END interp_tb;
 
ARCHITECTURE behavior OF interp_tb IS
    
   --Inputs
   signal clk : std_logic := '0';
   signal rst : std_logic := '0';
   signal int_en : std_logic := '0';
   signal i_phase : unsigned(5 downto 0) := (others => '0');
   signal i_delta : unsigned(21 downto 0) := (others => '0');
   signal i_mac_en : std_logic := '0';
   signal i_mac_data0 : signed(69 downto 0) := (others => '0');
   signal i_mac_data1 : signed(69 downto 0) := (others => '0');

 	--Outputs
   signal int_fin : std_logic;
   signal fbuf_en : std_logic;
   signal fbuf_data : signed(34 downto 0);
   signal o_mac_en : std_logic;
   signal o_mac_acc : std_logic;
   signal o_mac_cmp : std_logic;
   signal o_mac_data00 : signed(34 downto 0);
   signal o_mac_data01 : signed(34 downto 0);
   signal o_mac_data10 : signed(34 downto 0);
   signal o_mac_data11 : signed(34 downto 0);

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
	
	INST_MAC : mac
		port map (
			clk			=> clk,
			rst			=> rst,
			
			i_en			=> o_mac_en,
			i_acc			=> o_mac_acc,
			i_cmp			=> o_mac_cmp,
			i_data00		=> o_mac_data00,
			i_data01		=> o_mac_data01,
			i_data10		=> o_mac_data10,
			i_data11		=> o_mac_data11,
			
			o_en			=> i_mac_en,
			o_data0		=> i_mac_data0,
			o_data1		=> i_mac_data1
		);
 
	-- Instantiate the Unit Under Test (UUT)
   uut: interpolator PORT MAP (
          clk => clk,
          rst => rst,
          int_en => int_en,
          int_fin => int_fin,
          i_phase => i_phase,
          i_delta => i_delta,
          fbuf_en => fbuf_en,
          fbuf_data => fbuf_data,
          i_mac_en => i_mac_en,
          i_mac_data0 => i_mac_data0( 69 downto 35 ),
          i_mac_data1 => i_mac_data1( 69 downto 35 ),
          o_mac_en => o_mac_en,
          o_mac_acc => o_mac_acc,
          o_mac_cmp => o_mac_cmp,
          o_mac_data00 => o_mac_data00,
          o_mac_data01 => o_mac_data01,
          o_mac_data10 => o_mac_data10,
          o_mac_data11 => o_mac_data11
        );
		  
	pipe_process : process( clk )
		file		outfile	: text is out "./tb/fir_test.txt";
		variable outline	: line;
	begin
		if rising_edge( clk ) then
			if fbuf_en = '1' then
				write( outline, to_integer( fbuf_data ) );
				writeline( outfile, outline );
			end if;
		end if;
	end process;

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
		wait until rising_edge( clk );
		int_en <= '1';
		wait until rising_edge( clk );
		int_en <= '0';
		wait until rising_edge( clk );

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
