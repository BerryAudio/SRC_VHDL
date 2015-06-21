-- ************************************************************************
-- ISE Configuration Requirements
--		- Synthesis
--			- Register Balancing: Yes
--		- Map
--			- LUT Combining: Auto
-- ************************************************************************
-- SPI Register Format
-- 9-8	: Data bit length
--			: 00 = 24 bit ( default )
--			: 01 = 20 bit
--			: 10 = 18 bit
--			: 11 = 16 bit
-- 7		: Input Select
--			: 0 = SPDIF
--			: 1 = I2S
-- 6-5	: SPDIF Input Select
--			: 00 = Input 1
--			: 01 = Input 2
--			: 10 = Input 3
--			: 11 = Input 4
-- 4		: I2S Base Clock Select
--			: 0 = 22.5792 MHz (44.1 kHz Base)
--			: 1 = 24.576  MHz (48   kHz Base)
-- 3-2	: I2S Data Rate Select
--			: 00 =  44.1 kHz /  48 kHz
--			: 01 =  44.1 kHz /  48 kHz
--			: 10 =  88.2 kHz /  96 kHz
--			: 11 = 176.4 kHz / 192 kHz
-- 1		: Mute
-- 0		: Reset
-- ************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.audio.all;

entity audio_top is
	port (
		clk_24			: in  std_logic;
		ctrl_rst			: in  std_logic;
		ctrl_lock		: out std_logic := '0';
		ctrl_rdy			: out std_logic := '0';
		
		spi_clk			: in  std_logic;
		spi_cs_n			: in  std_logic_vector( 2 downto 0 );
		spi_mosi			: in  std_logic;
		spi_miso			: out std_logic := '0';

		i2s_data			: in  std_logic;
		i2s_bclk			: out std_logic := '0';
		i2s_lrck			: out std_logic := '0';
		
		spdif_chan0		: in  std_logic;
		spdif_chan1		: in  std_logic;
		spdif_chan2		: in  std_logic;
		spdif_chan3		: in  std_logic;
		spdif_o			: out std_logic;
		
		-- **********************************************************s**************
		-- DSP 0 = Left Channel
		-- ************************************************************************
		dsp0_rst			: out std_logic := '0';
		dsp0_mute		: out std_logic := '0';
		
		dsp0_i2s_lrck	: out std_logic := '0';
		dsp0_i2s_bclk	: out std_logic := '0';
		dsp0_i2s_data0	: out std_logic := '0';
		dsp0_i2s_data1	: out std_logic := '0';
		
		dsp0_spi_clk	: out std_logic := '0';
		dsp0_spi_cs_n	: out std_logic := '0';
		dsp0_spi_mosi	: out	std_logic := '0';
		dsp0_spi_miso	: in  std_logic;
		
		-- ************************************************************************
		-- DSP 1 = Right Channel
		-- ************************************************************************
		dsp1_rst			: out std_logic := '0';
		dsp1_mute		: out std_logic := '0';
		
		dsp1_i2s_lrck	: out std_logic := '0';
		dsp1_i2s_bclk	: out std_logic := '0';
		dsp1_i2s_data0	: out std_logic := '0';
		dsp1_i2s_data1	: out std_logic := '0';
		
		dsp1_spi_clk	: out std_logic := '0';
		dsp1_spi_cs_n	: out std_logic := '0';
		dsp1_spi_mosi	: out std_logic := '0';
		dsp1_spi_miso	: in  std_logic

	);
end audio_top;

architecture rtl of audio_top is
	signal spi_register	: std_logic_vector( 9 downto 0 ) := ( others => '0' );
	signal spi_reg_buf	: std_logic_vector( 9 downto 0 ) := ( others => '0' );
	signal spi_change		: std_logic := '0';

	alias spi_reg_bits	: std_logic_vector( 1 downto 0 ) is spi_register( 9 downto 8 );
	alias spi_reg_input	: std_logic is spi_register( 7 );
	alias spi_reg_spdif	: std_logic_vector( 1 downto 0 ) is spi_register( 6 downto 5 );
	alias spi_reg_clock	: std_logic is spi_register( 4 );
	alias spi_reg_rate	: std_logic_vector( 1 downto 0 ) is spi_register( 3 downto 2 );
	alias spi_reg_mute	: std_logic is spi_register( 1 );
	alias spi_reg_rst		: std_logic is spi_register( 0 );
	
	signal dac_rst			: std_logic := '0';
	signal pll_lock		: std_logic := '0';
	signal rst				: std_logic := '0';
	signal rst_buf			: std_logic_vector( 1 downto 0 ) := "00";
	signal clk				: std_logic := '0';
	signal clk_out			: std_logic := '0';
	signal clk_i2s			: std_logic := '0';
	
	signal i_output0	: signed( 23 downto 0 ) := ( others => '0' );
	signal i_output1	: signed( 23 downto 0 ) := ( others => '0' );
	signal i_output_en	: std_logic := '0';
	
	signal src_lock		: std_logic := '0';
	signal src_data0		: signed( 23 downto 0 ) := ( others => '0' );
	signal src_data1		: signed( 23 downto 0 ) := ( others => '0' );
	signal src_data_en	: std_logic := '0';
	signal o_sample_en	: std_logic := '0';
	
	signal dsp_i2s_sclk	: std_logic := '0';
	signal dsp_i2s_lrck	: std_logic := '0';
	signal dsp_i2s_bclk	: std_logic := '0';
	signal dsp_i2s_data0	: std_logic := '0';
	signal dsp_i2s_data1	: std_logic := '0';

begin

	-- *******************************************************************
	-- ** SYSTEM RESET
	-- *******************************************************************
	
	ctrl_rdy  <= pll_lock;
	ctrl_lock <= src_lock;
	
	rst <= rst_buf( 1 );
	
	rst_process : process( clk )
	begin
		if rising_edge( clk ) then
			dac_rst <= rst or not( src_lock );
			rst_buf <= rst_buf( 0 ) & ( ctrl_rst or spi_reg_rst or spi_change or not( pll_lock ) );
		end if;
	end process rst_process;
	
	spi_change_process : process( clk )
	begin
		if rising_edge( clk ) then
			spi_reg_buf <= spi_register;
			if spi_change <= '1' then
				spi_change <= '0';
			elsif spi_reg_buf /= spi_register then
				spi_change <= '1';
			end if;
		end if;
	end process spi_change_process;
	
	-- *******************************************************************
	-- ** SYSTEM CONTROL
	-- *******************************************************************
	-- ** PLL Configuration
	-- *******************************************************************
	
	INST_PLL : pll_top
		port map (
			clk			=> clk_24,
			clk_sel		=> spi_reg_clock,
			clk_lock		=> pll_lock,
			
			clk_src		=> clk,
			clk_out		=> clk_out,
			clk_i2s		=> clk_i2s
		);
	
	-- *******************************************************************
	-- ** S Configuration
	-- *******************************************************************
	dsp0_rst			<= spi_reg_rst;
	dsp0_mute		<= spi_reg_mute or spi_reg_rst;
	dsp0_spi_clk	<= spi_clk;
	dsp0_spi_cs_n	<= spi_cs_n( 1 );
	dsp0_spi_mosi	<= spi_mosi;
	
	dsp1_rst			<= spi_reg_rst;
	dsp1_mute		<= spi_reg_mute or spi_reg_rst;
	dsp1_spi_clk	<= spi_clk;
	dsp1_spi_cs_n	<= spi_cs_n( 2 );
	dsp1_spi_mosi	<= spi_mosi;
	
	spi_miso <= dsp0_spi_miso when spi_cs_n( 1 ) = '1' else
					dsp1_spi_miso when spi_cs_n( 2 ) = '1' else
					'0';
	
	INST_SPI : spi_top
		port map (
			clk			=> clk,
			
			spi_clk		=> spi_clk,
			spi_cs_n		=> spi_cs_n( 0 ),
			spi_mosi		=> spi_mosi,
			
			o_data		=> spi_register
		);
		
	-- *******************************************************************
	-- ** AUDIO INPUTS
	-- *******************************************************************
	
	INST_INPUTS : inputs_top
		port map (
			clk			=> clk,
			clk_i2s		=> clk_i2s,
			rst			=> rst,
			
			mux_sel		=> spi_reg_input,
			
			i2s_rate		=> spi_reg_rate,
			i2s_data		=> i2s_data,
			i2s_bclk		=> i2s_bclk,
			i2s_lrck		=> i2s_lrck,
			
			spdif_sel	=> spi_reg_spdif,
			spdif_chan0	=> spdif_chan0,
			spdif_chan1	=> spdif_chan1,
			spdif_chan2	=> spdif_chan2,
			spdif_chan3	=> spdif_chan3,
			
			o_data0		=> i_output0,
			o_data1		=> i_output1,
			o_data_en	=> i_output_en
		);
		
	-- *******************************************************************
	-- ** Sample Rate Converter
	-- *******************************************************************
	
	INST_SRC : src_top
		generic map (
			CLOCK_COUNT		=> CLOCK_COUNT
		)
		port map (
			clk				=> clk,
			rst				=> rst,
			
			ctrl_width		=> spi_reg_bits,
			ctrl_locked		=> src_lock,
			ctrl_ratio		=> open,
			
			i_sample_en_i	=> i_output_en,
			i_sample_en_o	=> o_sample_en,
			i_data0			=> i_output0,
			i_data1			=> i_output1,
			
			o_data0			=> src_data0,
			o_data1			=> src_data1,
			o_data_en		=> src_data_en
		);
	
	-- *******************************************************************
	-- ** Audio Output
	-- *******************************************************************
	
	dsp0_i2s_lrck	<= dsp_i2s_lrck;
	dsp0_i2s_bclk	<= dsp_i2s_bclk;
	dsp0_i2s_data0	<= dsp_i2s_data0;
	dsp0_i2s_data1	<= dsp_i2s_data1;
	
	dsp1_i2s_lrck	<= dsp_i2s_lrck;
	dsp1_i2s_bclk	<= dsp_i2s_bclk;
	dsp1_i2s_data0	<= dsp_i2s_data0;
	dsp1_i2s_data1	<= dsp_i2s_data1;
	
	INST_OUTPUTS : outputs_top
		generic map (
			DAC_IF		=> DAC_IF
		)
		port map (
			clk_src		=> clk,
			clk_out		=> clk_out,
			rst			=> dac_rst,
			
			i_data0		=> src_data0,
			i_data1		=> src_data1,
			i_data_en	=> src_data_en,
			
			o_sample_en	=> o_sample_en,
			
			o_i2s_lrck	=> dsp_i2s_lrck,
			o_i2s_bclk	=> dsp_i2s_bclk,
			o_i2s_data0	=> dsp_i2s_data0,
			o_i2s_data1	=> dsp_i2s_data1,
			
			o_spdif		=> spdif_o
		);
	
end rtl;
