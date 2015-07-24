--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   12:28:09 06/19/2015
-- Design Name:   
-- Module Name:   /home/charlie/projects/SRC_VHDL/tb/spdif_tx_tb.vhd
-- Project Name:  SRC_PRJ
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: spdif_tx_top
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

library work;
use work.audio.all;
 
ENTITY spdif_tx_tb IS
END spdif_tx_tb;
 
ARCHITECTURE behavior OF spdif_tx_tb IS 
 
   --Inputs
   signal clk : std_logic := '0';
   signal rst : std_logic := '0';
   signal clk_cnt : std_logic := '0';
   signal i_sample_0 : signed(23 downto 0) := (           0 => '1', others => '0');
   signal i_sample_1 : signed(23 downto 0) := (23 => '1', 0 => '1', others => '0');
   signal i_sample_en : std_logic := '0';
	
	
   signal o_sample_0 : signed(23 downto 0) := (others => '0');
   signal o_sample_1 : signed(23 downto 0) := (others => '0');
   signal o_sample_en : std_logic := '0';

 	--Outputs
   signal o_spdif : std_logic;

   -- Clock period definitions
   constant clk_period : time := 5.086 ns;
	signal cnt : unsigned( 6 downto 0 ) := ( others => '0' );
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: spdif_tx_top PORT MAP (
          clk => clk,
          rst => rst,
			 clk_cnt => clk_cnt,
          i_data0 => i_sample_0,
          i_data1 => i_sample_1,
          i_data_en => i_sample_en,
          o_spdif => o_spdif
        );
	
	rxer : spdif_rx_top
		port map (
			clk			=> clk,
			sel			=> "00",
		
			i_data0		=> o_spdif,
			i_data1		=> '0',
			i_data2		=> '0',
			i_data3		=> '0',
			
			o_data0		=> o_sample_0,
			o_data1		=> o_sample_1,
			o_data_en	=> o_sample_en
		) ;

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 
	process( clk )
	begin
		if rising_edge( clk ) then
			cnt <= cnt + 1;
			i_sample_en <= '0';
			if cnt = 0 then
				i_sample_0 <= i_sample_0 + 1;
				i_sample_1 <= i_sample_1 + 1;
				i_sample_en <= '1';
			end if;
			
			clk_cnt <= '0';
			if cnt( 1 downto 0 ) = 0 then
				clk_cnt <= '1';
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
