--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   14:25:07 03/12/2015
-- Design Name:   
-- Module Name:   /home/charlie/projects/SRC_V1.1.0/tb/halfband_tb.vhd
-- Project Name:  SRC_V1.1.0
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: hb_filter_top
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
use ieee.numeric_std.all;

library std;
use std.textio.all;

library work;
use work.src.all;
use work.utils.all;
use work.sig_gen_pkg.all;
 
ENTITY halfband_tb IS
END halfband_tb;
 
ARCHITECTURE behavior OF halfband_tb IS 
	constant s_width	: natural := 35;
	constant s_rate	: real	 := 768.0;
	constant s_freq	: real	 := 1.0;
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT hb_filter_top
    PORT(
         clk : IN  std_logic;
         rst : IN  std_logic;
         i_data_en0 : IN  std_logic;
         i_data_en1 : IN  std_logic;
         i_data0 : IN  signed(34 downto 0);
         i_data1 : IN  signed(34 downto 0);
         o_data_en : OUT  std_logic := '0';
         o_data0 : OUT  signed(34 downto 0) := ( others => '0' );
         o_data1 : OUT  signed(34 downto 0) := ( others => '0' );
         o_mac : IN  mac_o;
         i_mac : OUT  mac_i := mac_i_init
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal rst : std_logic := '0';
   signal i_data_en0 : std_logic := '0';
   signal i_data_en1 : std_logic := '0';
   signal i_data0 : signed(34 downto 0) := (others => '0');
   signal i_data1 : signed(34 downto 0) := (others => '0');
   signal o_mac : mac_o := mac_o_init;

 	--Outputs
   signal o_data_en : std_logic;
   signal o_data0 : signed(34 downto 0);
   signal o_data1 : signed(34 downto 0);
   signal i_mac : mac_i := mac_i_init;

   -- Clock period definitions
   constant clk_period : time := 5.0863 ns;
	signal cnt : unsigned( 8 downto 0 ) := ( others => '0' );
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: hb_filter_top PORT MAP (
          clk => clk,
          rst => rst,
          i_data_en0 => i_data_en0,
          i_data_en1 => i_data_en1,
          i_data0 => i_data0,
          i_data1 => i_data1,
          o_data_en => o_data_en,
          o_data0 => o_data0,
          o_data1 => o_data1,
          o_mac => o_mac,
          i_mac => i_mac
        );
	
	INST_MAC : mac
		port map (
			clk	=> clk,
			rst	=> rst,
			
			i_mac	=> i_mac,
			o_mac => o_mac
		);

	data_process : process( clk )
	begin
		if rising_edge( clk ) then
			i_data_en0 <= '0';
			i_data_en1 <= '0';
			cnt <= cnt + 1;
			if cnt( 7 downto 0 ) = 0 then
				i_data_en0 <= not cnt( 8 );
				i_data_en1 <= cnt( 8 );
				i_data0 <= fetch_sample;
				i_data1 <= fetch_sample;
			end if;
		end if;
	end process;
	
	
	capture_process : process( clk )
		file		outfile0	: text is out "./tb/test/hb_test_0.txt";
		variable outline0	: line;
	begin
		if rising_edge( clk ) then
			if o_data_en = '1' then
				write( outline0, to_integer( o_data0(34 downto 11) ) );
				writeline( outfile0, outline0 );
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
		set_sig( s_freq, s_rate, s_width );
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
