--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   14:28:04 11/18/2014
-- Design Name:   
-- Module Name:   /home/charlie/projects/SRC_V0.9.1/tb/audio_tb.vhd
-- Project Name:  SRC_V0.9.1
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
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

library work;
use work.utils.all;
use work.sig_gen_pkg.all;
 
ENTITY audio_tb IS
END audio_tb;
 
ARCHITECTURE behavior OF audio_tb IS 
	constant s_rate	: real 	 := 96.0;
 
   --Inputs
   signal clk_24 : std_logic := '0';
   signal clk_22 : std_logic := '0';
   signal ctrl_rst : std_logic := '0';
   signal spi_clk : std_logic := '0';
   signal spi_cs_n : std_logic_vector(2 downto 0) := (others => '1');
   signal spi_mosi : std_logic := '0';
   signal i2s_data : std_logic := '0';
   signal spdif_chan0 : std_logic := '0';
   signal spdif_chan1 : std_logic := '0';
   signal spdif_chan2 : std_logic := '0';
   signal spdif_chan3 : std_logic := '0';
   signal dsp0_spi_miso : std_logic := '0';
   signal dsp1_spi_miso : std_logic := '0';

 	--Outputs
   signal ctrl_lock : std_logic;
	signal ctrl_rdy : std_logic;
   signal spi_miso : std_logic;
   signal i2s_bclk : std_logic;
   signal i2s_lrck : std_logic;
   signal spdif_o : std_logic;
   signal dsp0_rst : std_logic;
   signal dsp0_mute : std_logic;
   signal dsp0_i2s_lrck : std_logic;
   signal dsp0_i2s_bclk : std_logic;
   signal dsp0_i2s_data0 : std_logic;
   signal dsp0_i2s_data1 : std_logic;
   signal dsp0_spi_clk : std_logic;
   signal dsp0_spi_cs_n : std_logic;
   signal dsp0_spi_mosi : std_logic;
   signal dsp1_rst : std_logic;
   signal dsp1_mute : std_logic;
   signal dsp1_i2s_lrck : std_logic;
   signal dsp1_i2s_bclk : std_logic;
   signal dsp1_i2s_data0 : std_logic;
   signal dsp1_i2s_data1 : std_logic;
   signal dsp1_spi_clk : std_logic;
   signal dsp1_spi_cs_n : std_logic;
   signal dsp1_spi_mosi : std_logic;

   -- Clock period definitions
   constant clk_24_period : time := 40.69 ns;
   constant clk_22_period : time := 44.29 ns;
	
	signal spi_en		: std_logic := '0';
	signal spi_data	: std_logic_vector( 7 downto 0 ) := ( others => '0' );
 
	signal dac_data0	: signed( 23 downto 0 ) := ( others => '0' );
	signal dac_data1	: signed( 23 downto 0 ) := ( others => '0' );
	signal dac_data_en: std_logic := '0';
	
	procedure spi_write( 
		constant i_spi		: in  std_logic_vector( 7 downto 0 );
		signal o_spi		: out std_logic_vector( 7 downto 0 );
		signal o_spi_en	: out std_logic
	) is begin
		wait until rising_edge( clk_24 );
		o_spi <= i_spi;
		o_spi_en <= '1';
		
		wait until rising_edge( clk_24 );
		o_spi_en <= '0';
		
		wait for 500 us;
	end procedure;
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: audio_top PORT MAP (
          clk_24 => clk_24,
          clk_22 => clk_22,
          ctrl_rst => ctrl_rst,
          ctrl_lock => ctrl_lock,
			 ctrl_rdy  => ctrl_rdy,
          spi_clk => spi_clk,
          spi_cs_n => spi_cs_n,
          spi_mosi => spi_mosi,
          spi_miso => spi_miso,
          i2s_data => i2s_data,
          i2s_bclk => i2s_bclk,
          i2s_lrck => i2s_lrck,
          spdif_chan0 => spdif_chan0,
          spdif_chan1 => spdif_chan1,
          spdif_chan2 => spdif_chan2,
          spdif_chan3 => spdif_chan3,
          spdif_o => spdif_o,
          dsp0_rst => dsp0_rst,
          dsp0_mute => dsp0_mute,
          dsp0_i2s_lrck => dsp0_i2s_lrck,
          dsp0_i2s_bclk => dsp0_i2s_bclk,
          dsp0_i2s_data0 => dsp0_i2s_data0,
          dsp0_i2s_data1 => dsp0_i2s_data1,
          dsp0_spi_clk => dsp0_spi_clk,
          dsp0_spi_cs_n => dsp0_spi_cs_n,
          dsp0_spi_mosi => dsp0_spi_mosi,
          dsp0_spi_miso => dsp0_spi_miso,
          dsp1_rst => dsp1_rst,
          dsp1_mute => dsp1_mute,
          dsp1_i2s_lrck => dsp1_i2s_lrck,
          dsp1_i2s_bclk => dsp1_i2s_bclk,
          dsp1_i2s_data0 => dsp1_i2s_data0,
          dsp1_i2s_data1 => dsp1_i2s_data1,
          dsp1_spi_clk => dsp1_spi_clk,
          dsp1_spi_cs_n => dsp1_spi_cs_n,
          dsp1_spi_mosi => dsp1_spi_mosi,
          dsp1_spi_miso => dsp1_spi_miso
        );
	
	-- SPI
	spi_tb : spi_util_tb
		port map (
			clk		=> clk_24,
			spi_en	=> spi_en,
			spi_data	=> spi_data,
			
			spi_clk	=> spi_clk,
			spi_cs_n	=> spi_cs_n(0),
			spi_mosi	=> spi_mosi
		);
	
	-- i2s
	i2s_tb : i2s_util_tb
		port map (
			i2s_bclk => i2s_bclk,
			i2s_lrck => i2s_lrck,
			i2s_data => i2s_data
		);
	
	-- spdif
	spdif_tb : spdif_util_tb
		generic map (
			FREQ	=> 44100
		)
		port map (
			reset => ctrl_rst,
			spdif => spdif_chan0
		);
	
	-- dac
	dac_tb : dac_util_tb
		port map (
			i_lrck 		=> dsp0_i2s_lrck,
			i_bclk 		=> dsp0_i2s_bclk,
			i_data0 		=> dsp0_i2s_data0,
			i_data1 		=> dsp0_i2s_data1,
			
			o_data0 		=> dac_data0,
			o_data1 		=> dac_data1,
			o_data_en	=> dac_data_en
		);

	capture_process : process( dsp0_i2s_bclk )
		file		outfile0	: text is out "./tb/test/master_test_0.txt";
		variable outline0	: line;
		file		outfile1	: text is out "./tb/test/master_test_1.txt";
		variable outline1	: line;
	begin
		if rising_edge( dsp0_i2s_bclk ) then
			if dac_data_en = '1' then
				write( outline0, to_integer( dac_data0 ) );
				writeline( outfile0, outline0 );
				write( outline1, to_integer( dac_data1 ) );
				writeline( outfile1, outline1 );
			end if;
		end if;
	end process;

   -- Clock process definitions
   clk_24_process :process
   begin
		clk_24 <= '0';
		wait for clk_24_period/2;
		clk_24 <= '1';
		wait for clk_24_period/2;
   end process;
 
   clk_22_process :process
   begin
		clk_22 <= '0';
		wait for clk_22_period/2;
		clk_22 <= '1';
		wait for clk_22_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
		set_rate( s_rate );
		wait until ctrl_rdy = '1';
		
		if		s_rate =  44.1 then spi_write( "10000000", spi_data, spi_en );
		elsif s_rate =  48.0 then spi_write( "10010000", spi_data, spi_en );
		elsif s_rate =  88.2 then spi_write( "10001000", spi_data, spi_en );
		elsif s_rate =  96.0 then spi_write( "10011000", spi_data, spi_en );
		elsif s_rate = 176.4 then spi_write( "10001100", spi_data, spi_en );
		elsif s_rate = 192.0 then spi_write( "10011110", spi_data, spi_en );
		end if;
		
		wait for 0.5 ms;
		
		--set_sig( s_freq, 96.0, s_width );
		--spi_write( "10011000", spi_data, spi_en );
		--wait until rising_edge(clk_24 );

      wait;
   end process;

END;
