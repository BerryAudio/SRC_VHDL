library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package utils is

	component audio_top
		port(
			clk_24			: in  std_logic;
			clk_22			: in  std_logic;
			ctrl_rst			: in  std_logic;
			ctrl_lock		: out std_logic;
			ctrl_rdy			: out std_logic;
			spi_clk			: in  std_logic;
			spi_cs_n			: in  std_logic_vector(2 downto 0);
			spi_mosi			: in  std_logic;
			spi_miso			: out std_logic;
			i2s_data			: in  std_logic;
			i2s_bclk			: out std_logic;
			i2s_lrck			: out std_logic;
			spdif_chan0		: in  std_logic;
			spdif_chan1		: in  std_logic;
			spdif_chan2		: in  std_logic;
			spdif_chan3		: in  std_logic;
			spdif_o			: out std_logic;
			dsp0_rst			: out std_logic;
			dsp0_mute		: out std_logic;
			dsp0_i2s_lrck	: out std_logic;
			dsp0_i2s_bclk	: out std_logic;
			dsp0_i2s_data0	: out std_logic;
			dsp0_i2s_data1	: out std_logic;
			dsp0_spi_clk	: out std_logic;
			dsp0_spi_cs_n	: out std_logic;
			dsp0_spi_mosi	: out std_logic;
			dsp0_spi_miso	: in  std_logic;
			dsp1_rst			: out std_logic;
			dsp1_mute		: out std_logic;
			dsp1_i2s_lrck	: out std_logic;
			dsp1_i2s_bclk	: out std_logic;
			dsp1_i2s_data0	: out std_logic;
			dsp1_i2s_data1	: out std_logic;
			dsp1_spi_clk	: out std_logic;
			dsp1_spi_cs_n	: out std_logic;
			dsp1_spi_mosi	: out std_logic;
			dsp1_spi_miso	: in  std_logic
		);
	end component;

	component spi_util_tb is
		port (
			clk		: in std_logic;
			spi_en	: in std_logic;
			spi_data	: in std_logic_vector( 7 downto 0 );
			
			spi_clk	: out std_logic;
			spi_cs_n	: out std_logic;
			spi_mosi	: out std_logic
		);
	end component spi_util_tb;
	
	component i2s_util_tb is
		port (
			i2s_bclk : in  std_logic;
			i2s_lrck : in  std_logic;
			i2s_data : out std_logic
		);
	end component i2s_util_tb;
	
	component spdif_util_tb is
		generic (
			FREQ : natural
		);
		port (
			reset : in  std_logic;
			spdif : out std_logic
		);
	end component spdif_util_tb;
	
	component dac_util_tb is
		port(
			i_lrck 		: in  std_logic;
			i_bclk 		: in  std_logic;
			i_data0 		: in  std_logic;
			i_data1 		: in  std_logic;
			
			o_data0 		: out signed(23 downto 0);
			o_data1 		: out signed(23 downto 0);
			o_data_en	: out std_logic
		);
	end component dac_util_tb;

	-- Channel A: sinewave with frequency=Freq/12
	signal wav_cnt : unsigned( 3 downto 0 ) := x"0";
	type sine16 is array ( 0 to 15 ) of signed( 15 downto 0 );
	signal channel_a : sine16 := ( ( x"0000" ), ( x"30fb" ), ( x"5a82" ), ( x"7641" ),
											 ( x"7fff" ), ( x"7641" ), ( x"5a82" ), ( x"30fb" ),
											 ( x"0000" ), ( x"cf04" ), ( x"a57d" ), ( x"89be" ),
											 ( x"8000" ), ( x"89be" ), ( x"a57d" ), ( x"cf04" ) );
											
	-- channel B: sinewave with frequency=Freq/24
	type sine8 is array (0 to 7) of signed(0 to 15);
	signal channel_b : sine8 := ( ( x"0000" ), ( x"5a82" ), ( x"7fff" ), ( x"5a82" ),
										   ( x"0000" ), ( x"a57d" ), ( x"8000" ), ( x"a57d" ) );
											
	impure function fetch_channel_a( cnt : unsigned( 3 downto 0 ) ) return signed;
	impure function fetch_channel_b( cnt : unsigned( 3 downto 0 ) ) return signed;
end utils;

package body utils is
	
	impure function fetch_channel_a( cnt : unsigned( 3 downto 0 ) )
		return signed is
		variable int : integer;
	begin
		int := to_integer( channel_a( to_integer( cnt ) ) );
		
		return to_signed( int * 2**8, 24 );
	end function fetch_channel_a;
	
	impure function fetch_channel_b( cnt : unsigned( 3 downto 0 ) )
		return signed is
		variable int : integer;
		variable tmp : signed( 27 downto 0 );
	begin
		int := to_integer( channel_b( to_integer( cnt( 2 downto 0 ) ) ) ) * 2**8;
		int := int + to_integer( fetch_channel_a( cnt ) );
		
		tmp := to_signed( int, 27 );
		
		return tmp( 25 downto 2 );
	end function fetch_channel_b;
	
end utils;
