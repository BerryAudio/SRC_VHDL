library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package audio is

	--******************************************************************
	-- Constants - CLOCK RATE
	--******************************************************************
	
	constant CLOCK_COUNT				: integer := 512;
	
	-- currently valid are AD_1955 and PCM1794
	constant DAC_IF					: string := "PCM1794";
	
	--******************************************************************
	-- Components
	--******************************************************************
	
	component dac_top is
		generic (
			DAC_IF		: string := DAC_IF
		);
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
			
			i_data0		: in  signed( 23 downto 0 );
			i_data1		: in  signed( 23 downto 0 );
			i_data_en	: in  std_logic;
			
			o_sample_en	: out std_logic := '0';
			o_lrck		: out std_logic := '0';
			o_bclk		: out std_logic := '0';
			o_data0		: out std_logic := '0';
			o_data1		: out std_logic := '0'
		);
	end component dac_top;
	
	component i2s_top is
		port (
			clk			: in  std_logic;
			
			i2s_clk		: in  std_logic;
			i2s_data		: in  std_logic;
			i2s_bclk		: out std_logic;
			i2s_lrck		: out std_logic;
			i2s_rate		: in  std_logic_vector( 1 downto 0 );
			
			o_data0		: out signed( 23 downto 0 );
			o_data1		: out signed( 23 downto 0 );
			o_data_en	: out std_logic
		);
	end component i2s_top;
	
	component mux_top is
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
			sel			: in  std_logic;
			
			i_data0_0	: in  signed( 23 downto 0 );
			i_data0_1	: in  signed( 23 downto 0 );
			i_data0_en	: in  std_logic;
			
			i_data1_0	: in  signed( 23 downto 0 );
			i_data1_1	: in  signed( 23 downto 0 );
			i_data1_en	: in  std_logic;
			
			o_data0		: out signed( 23 downto 0 );
			o_data1		: out signed( 23 downto 0 );
			o_data_en	: out std_logic
		);
	end component mux_top;
	
	component pll_top is
		port (
			clk			: in  std_logic;
			clk_sel		: in  std_logic;
			clk_lock		: out std_logic := '0';
			
			clk_src		: out std_logic := '0';
			clk_i2s		: out std_logic := '0'
		);
	end component pll_top;
	
	component spdif_top is
		port (
			clk			: in  std_logic;
			sel			: in  std_logic_vector( 1 downto 0 );
		
			i_data0		: in  std_logic;
			i_data1		: in  std_logic;
			i_data2		: in  std_logic;
			i_data3		: in  std_logic;
			
			o_data0		: out signed( 23 downto 0 );
			o_data1		: out signed( 23 downto 0 );
			o_data_en	: out std_logic;
		
			spdif_o		: out std_logic
		);
	end component spdif_top;
	
	component spi_top is
		port (
			clk			: in  std_logic;
			
			spi_clk		: in  std_logic;
			spi_cs_n		: in  std_logic;
			spi_mosi		: in  std_logic;
			
			o_data		: out std_logic_vector( 15 downto 0 )
		);
	end component spi_top;
	
	component src_top is
		generic (
			CLOCK_COUNT				: integer := CLOCK_COUNT
		);
		port (
			clk						: in  std_logic;
			rst						: in  std_logic;
			
			ctrl_width				: in  std_logic_vector( 1 downto 0 );
			ctrl_locked				: out std_logic;
			ctrl_ratio				: out unsigned( 23 downto 0 );
			
			i_sample_en_i			: in  std_logic;
			i_sample_en_o			: in  std_logic;
			i_data0					: in  signed( 23 downto 0 );
			i_data1					: in  signed( 23 downto 0 );
			
			o_data_en				: out std_logic := '0';
			o_data0					: out signed( 23 downto 0 );
			o_data1					: out signed( 23 downto 0 )
		);
	end component src_top;
	
end audio;

package body audio is

end audio;
