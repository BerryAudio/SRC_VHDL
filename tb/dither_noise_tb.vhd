--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   10:41:05 11/25/2014
-- Design Name:   
-- Module Name:   /home/charlie/projects/SRC_V0.9.2/tb/dither_noise_tb.vhd
-- Project Name:  SRC_V0.9.2
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: noise_filter_top
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

LIBRARY work;
use work.src.all;

LIBRARY std;
use std.textio.all;
 
ENTITY dither_noise_tb IS
END dither_noise_tb;
 
ARCHITECTURE behavior OF dither_noise_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
	constant LFSR_WIDTH : integer := 11;
	constant FILT_WIDTH : integer := 20;
	
   component dither_top is
		generic (
			LFSR_WIDTH	: integer := LFSR_WIDTH;
			FILT_WIDTH	: integer := FILT_WIDTH
		);
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
			
			i_data_en	: in  std_logic;
			i_data0		: in  signed( 34 downto 0 );
			i_data1		: in  signed( 34 downto 0 );
			
			o_data_en	: out std_logic := '0';
			o_data0		: out signed( 23 downto 0 ) := ( others => '0' );
			o_data1		: out signed( 23 downto 0 ) := ( others => '0' );
			
			i_mac			: out mac_i := mac_i_init;
			o_mac			: in  mac_o
		);
	end component dither_top;
	
	component mac is
		port (
			clk		: in  std_logic;
			rst		: in  std_logic;
			
			i_mac		: in  mac_i;
			o_mac		: out mac_o
		);
	end component mac;
    
	signal clk				: std_logic := '0';
	signal rst				: std_logic := '0';

   --Inputs
	signal i_data_en		: std_logic := '0';
	signal i_data0			: signed( 34 downto 0 ) := ( others => '0' );
	signal i_data1			: signed( 34 downto 0 ) := ( others => '0' );
	signal o_mac			: mac_o := mac_o_init;

 	--Outputs
	signal o_data_en		: std_logic := '0';
	signal o_data0			: signed( 23 downto 0 ) := ( others => '0' );
	signal o_data1			: signed( 23 downto 0 ) := ( others => '0' );
	
	signal i_mac			: mac_i := mac_i_init;

	--signals
	signal run	 : std_logic := '0';
	signal count : unsigned( 4 downto 0 ) := ( others => '0' );
   -- Clock period definitions
   constant clk_period : time := 1 ns;
 
BEGIN

	process(clk)
		file		outfile0	: text is out "./tb/test/noise_test_0.txt";
		variable outline0	: line;
	begin
		if rising_edge( clk ) then
			if o_data_en = '1' then
				write( outline0, to_integer( o_data0 ) );
				writeline( outfile0, outline0 );
			end if;
		end if;
	end process;
	
	process(clk)
	begin
		if rising_edge( clk ) then
			i_data_en <= o_data_en;
			if run = '0' then
				i_data_en <= '1';
				run <= '1';
			end if;
		end if;
	end process;
 
	-- Instantiate the Unit Under Test (UUT)
   uut: dither_top 
		port map (
			clk			=> clk,
			rst			=> rst,
			
			i_data_en	=> i_data_en,
			i_data0		=> i_data0,
			i_data1		=> i_data1,
			
			o_data_en	=> o_data_en,
			o_data0		=> o_data0,
			o_data1		=> o_data1,
			
			i_mac			=> i_mac,
			o_mac			=> o_mac
		);
	
	INST_MAC : mac
		port map(
			clk		=> clk,
			rst		=> rst,
			
			i_mac		=> i_mac,
			o_mac		=> o_mac
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
		wait until rising_edge(clk);

      wait;
   end process;

END;
