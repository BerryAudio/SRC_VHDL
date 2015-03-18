--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   08:59:56 11/18/2014
-- Design Name:   
-- Module Name:   /home/charlie/projects/SRC_V0.9.1/tb/spi_util_tb.vhd
-- Project Name:  SRC_V0.9.1
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: spi_top
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
 
ENTITY spi_util_tb IS
	port (
		clk		: in std_logic := '0';
		spi_en	: in std_logic := '0';
		spi_data	: in std_logic_vector( 7 downto 0 ) := ( others => '0' );
		
      spi_clk	: out std_logic := '0';
      spi_cs_n	: out std_logic := '1';
      spi_mosi	: out std_logic := '0'
	);
END spi_util_tb;
 
ARCHITECTURE behavior OF spi_util_tb IS 
 
   signal spi_gen_clk: std_logic := '0';
   signal en			: std_logic := '0';
   signal mask			: std_logic := '1';
	signal data_buf	: std_logic_vector( 7 downto 0 ) := ( others => '0' );
	
   signal cs_n			: std_logic := '1';
   signal mosi			: std_logic := '0';
	
	constant spi_clk_period : time := 500 ns;
 
BEGIN
	spi_clk <= spi_gen_clk and not( cs_n ) and not( mask );
	spi_cs_n <= cs_n;

	spi_process : process( spi_gen_clk )
		variable clock : integer := 0;
	begin
		if rising_edge( spi_gen_clk ) then
			spi_mosi <= '0';
			if en = '1' then
				cs_n <= '0';
				clock := 7;
			elsif clock < 0 then
				mask <= '1';
				cs_n <= '1';
			else
				mask <= '0';
				spi_mosi <= data_buf( clock );
				clock := clock - 1;
			end if;
		end if;
	end process spi_process;

	buffer_process : process( clk )
	begin
		if rising_edge( clk ) then
			if spi_en = '1' then
				data_buf <= spi_data;
				en <= '1';
			elsif cs_n = '0' then
				en <= '0';
			end if;
		end if;
	end process buffer_process;

	spi_clock_process : process
	begin
		spi_gen_clk <= '0';
		wait for spi_clk_period/2;
		spi_gen_clk <= '1';
		wait for spi_clk_period/2;
	end process spi_clock_process;

END;
