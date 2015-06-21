library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.audio.all;

entity inputs_top is
	port (
		clk			: in  std_logic;
		clk_i2s		: in  std_logic;
		rst			: in  std_logic;
		
		-- mux inputs
		mux_sel		: in  std_logic;
		
		-- i2s signals 
		i2s_rate		: in  std_logic_vector( 1 downto 0 );
		i2s_data		: in  std_logic;
		i2s_bclk		: out std_logic := '0';
		i2s_lrck		: out std_logic := '0';
		
		-- spdif inputs
		spdif_sel	: in  std_logic_vector( 1 downto 0 );
		spdif_chan0	: in  std_logic;
		spdif_chan1	: in  std_logic;
		spdif_chan2	: in  std_logic;
		spdif_chan3	: in  std_logic;
		
		-- data out
		o_data0		: out signed( 23 downto 0 ) := ( others => '0' );
		o_data1		: out signed( 23 downto 0 ) := ( others => '0' );
		o_data_en	: out std_logic := '0'
	);
end inputs_top;

architecture rtl of inputs_top is
	
	signal i2s_output0		: signed( 23 downto 0 ) := ( others => '0' );
	signal i2s_output1		: signed( 23 downto 0 ) := ( others => '0' );
	signal i2s_output_en	: std_logic := '0';
	
	signal spdif_output0	: signed( 23 downto 0 ) := ( others => '0' );
	signal spdif_output1	: signed( 23 downto 0 ) := ( others => '0' );
	signal spdif_output_en: std_logic := '0';

begin
	
	INST_I2S : i2s_top
		port map (
			clk			=> clk,
			
			i2s_clk		=> clk_i2s,
			i2s_data		=> i2s_data,
			i2s_bclk		=> i2s_bclk,
			i2s_lrck		=> i2s_lrck,
			i2s_rate		=> i2s_rate,
			
			o_data0		=> i2s_output0,
			o_data1		=> i2s_output1,
			o_data_en	=> i2s_output_en
		);
	
	INST_SPDIF_RX : spdif_rx_top
		port map (
			clk			=> clk,
			sel			=> spdif_sel,
		
			i_data0		=> spdif_chan0,
			i_data1		=> spdif_chan1,
			i_data2		=> spdif_chan2,
			i_data3		=> spdif_chan3,
			
			o_data0		=> spdif_output0,
			o_data1		=> spdif_output1,
			o_data_en	=> spdif_output_en
		);
	
	INST_MUX : mux_top
		port map (
			clk			=> clk,
			rst			=> rst,
			sel			=> mux_sel,
			
			i_data0_0	=> spdif_output0,
			i_data0_1	=> spdif_output1,
			i_data0_en	=> spdif_output_en,
			
			i_data1_0	=> i2s_output0,
			i_data1_1	=> i2s_output1,
			i_data1_en	=> i2s_output_en,
			
			o_data0		=> o_data0,
			o_data1		=> o_data1,
			o_data_en	=> o_data_en
		);
end rtl;

