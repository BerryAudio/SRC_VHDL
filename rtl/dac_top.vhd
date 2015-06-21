library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dac_top is
	generic (
		DAC_IF		: string := "PCM1794"
	);
	port (
		clk			: in  std_logic;
		rst			: in  std_logic;
		clk_cnt		: unsigned( 6 downto 0 );
		
		i_data0		: in  signed( 23 downto 0 );
		i_data1		: in  signed( 23 downto 0 );
		
		o_lrck		: out std_logic := '0';
		o_bclk		: out std_logic := '0';
		o_data0		: out std_logic := '0';
		o_data1		: out std_logic := '0'
	);
end dac_top;

architecture rtl of dac_top is
	signal CLOCK_START	: natural;
	
	signal data_ext0		: signed( 31 downto 0 ) := ( others => '0' );
	signal data_ext1		: signed( 31 downto 0 ) := ( others => '0' );
	
	signal buf_data0		: signed( 31 downto 0 ) := ( others => '0' );
	signal buf_data1		: signed( 31 downto 0 ) := ( others => '0' );
	signal buf_shift		: std_logic := '0';
begin
	
	buf_shift <= '1' when clk_cnt( 1 downto 0 ) = "00" else '0';
	
	o_data0 <= buf_data0( 31 );
	o_data1 <= buf_data1( 31 );
	
	buffer1_process : process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				buf_data0 <= ( others => '0' );
				buf_data1 <= ( others => '0' );
			else
				if clk_cnt = CLOCK_START then
					buf_data0 <= data_ext0;
					buf_data1 <= data_ext1;
				elsif buf_shift = '1' then
					buf_data0 <= buf_data0( 30 downto 0 ) & '0';
					buf_data1 <= buf_data1( 30 downto 0 ) & '0';
				end if;
			end if;
		end if;
	end process buffer1_process;

	GEN_AD1955 : if DAC_IF = "AD_1955" generate
	begin
		CLOCK_START <= 4;
	
		data_ext0 <= i_data0 & x"00";
		data_ext1 <= i_data1 & x"00";
		
		output_process : process( clk )
		begin
			if rising_edge( clk ) then
				o_bclk <= not clk_cnt( 1 );
				o_lrck <= '0';
				if clk_cnt( 6 downto 2 ) = 0 then
					o_lrck <= '1';
				end if;
			end if;
		end process output_process;
	end generate GEN_AD1955;

	GEN_PCM1794 : if DAC_IF = "PCM1794" generate
	begin
		CLOCK_START <= 0;
	
		data_ext0 <= RESIZE( i_data0, 32 );
		data_ext1 <= RESIZE( i_data1, 32 );
		
		output_process : process( clk )
		begin
			if rising_edge( clk ) then
				o_bclk <= clk_cnt( 1 );
				o_lrck <= clk_cnt( 6 );
			end if;
		end process output_process;
	end generate GEN_PCM1794;
	
end rtl;
