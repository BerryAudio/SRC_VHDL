library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2s_top is
	port (
		clk			: in  std_logic;
		
		i2s_clk		: in  std_logic;
		i2s_data		: in  std_logic;
		i2s_bclk		: out std_logic := '0';
		i2s_lrck		: out std_logic := '0';
		i2s_rate		: in  std_logic_vector( 1 downto 0 );
		
		o_data0		: out signed( 23 downto 0 ) := ( others => '0' );
		o_data1		: out signed( 23 downto 0 ) := ( others => '0' );
		o_data_en	: out std_logic := '0'
	);
end i2s_top;

architecture rtl of i2s_top is
	component i2s_rx is
		port (
			clk			: in  std_logic;
			
			i2s_data		: in  std_logic;
			i2s_bclk		: in  std_logic;
			i2s_lrck		: in  std_logic;
			
			o_data0		: out signed( 23 downto 0 );
			o_data1		: out signed( 23 downto 0 );
			o_data_en	: out std_logic
		);
	end component i2s_rx;
	
	type RATE_TYPE is array( 1 downto 0 ) of std_logic_vector( 1 downto 0 );
	signal rate_buf	: RATE_TYPE := ( others => ( others => '0' ) );
	
	signal clk_count	: unsigned( 8 downto 0 ) := ( others => '0' );
	signal bclk			: std_logic := '0';
	signal lrck			: std_logic := '0';
begin

	i2s_bclk <= bclk;
	i2s_lrck <= lrck;
	
	INST_I2S_RX : i2s_rx
		port map (
			clk			=> clk,
			
			i2s_data		=> i2s_data,
			i2s_bclk		=> bclk,
			i2s_lrck		=> lrck,
			
			o_data0		=> o_data0,
			o_data1		=> o_data1,
			o_data_en	=> o_data_en
		);
	
	rate_process : process( i2s_clk )
	begin
		if rising_edge( i2s_clk ) then
			rate_buf <= rate_buf( 0 ) & i2s_rate;
		end if;
	end process rate_process;
	
	count_process : process( i2s_clk )
	begin
		if rising_edge( i2s_clk ) then
			clk_count <= clk_count + 1;
		end if;
	end process count_process;
	
	i2s_generate_process : process( i2s_clk )
	begin
		if rising_edge( i2s_clk ) then
			case rate_buf( 1 ) is
				when "11" => -- 176.2/192
					lrck <= clk_count( 6 );
					bclk <= clk_count(  0 );
					
				when "10" => -- 88.1/96
					lrck <= clk_count( 7 );
					bclk <= clk_count(  1 );
				
				when others => -- 44.1/48
					lrck <= clk_count( 8 );
					bclk <= clk_count(  2 );
					
			end case;
		end if;
	end process i2s_generate_process;
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2s_rx is
	port (
		clk			: in  std_logic;
		
		i2s_lrck		: in  std_logic;
		i2s_bclk		: in  std_logic;
		i2s_data		: in  std_logic;
		
		o_data0		: out signed( 23 downto 0 ) := ( others => '0' );
		o_data1		: out signed( 23 downto 0 ) := ( others => '0' );
		o_data_en	: out std_logic := '0'
	);
end i2s_rx;

architecture rtl of i2s_rx is
	signal data_stb		: std_logic := '0';
	signal data_rd			: std_logic := '0';
	
	signal data				: signed( 23 downto 0 ) := ( others => '0' );
	signal data0			: signed( 23 downto 0 ) := ( others => '0' );
	signal data1			: signed( 23 downto 0 ) := ( others => '0' );
	signal data_en_0		: std_logic := '0';
	signal data_en_buf_0	: std_logic_vector( 2 downto 0 ) := ( others => '0' );
	signal data_en_1		: std_logic := '0';
	signal data_en_buf_1	: std_logic_vector( 2 downto 0 ) := ( others => '0' );
	
	signal bit_count		: unsigned( 4 downto 0 ) := ( others => '0' );
	signal trig0			: std_logic := '0';
	signal trig1			: std_logic := '0';
	
	signal lrck_prev		: std_logic := '0';
	signal lrck_rise		: std_logic := '0';
	signal lrck_fall		: std_logic := '0';
	
	alias bclk				: std_logic is i2s_bclk;
	alias lrck				: std_logic is i2s_lrck;
begin
	
	lrck_rise <= i2s_lrck and not( lrck_prev );
	lrck_fall <= not( i2s_lrck ) and lrck_prev;
	
	-- acquire data in the i2s clock domain
	i2s_clock_process : process( bclk )
	begin
		if rising_edge( bclk ) then
			data_stb <= '0';
			if bit_count /= 0 then
				data_stb <= '1';
			end if;
			
			trig0		 <= lrck_rise;
			trig1		 <= lrck_fall;
			data_rd	 <= i2s_data;
			lrck_prev <= lrck;
			
			if data_stb = '1' then
				data <= data( 22 downto 0 ) & data_rd;
			end if;
			
			if ( lrck_rise or lrck_fall ) = '1' then
				bit_count <= to_unsigned( 24, 5 );
			elsif bit_count > 0 then
				bit_count <= bit_count - 1;
			end if;
			
			data_en_0 <= '0';
			data_en_1 <= '0';
			if trig0 = '1' then
				data0 <= data;
				data_en_0 <= '1';
			elsif trig1 = '1' then
				data1 <= data;
				data_en_1 <= '1';
			end if;
		end if;
	end process i2s_clock_process;
	
	-- synchronise to src clock domain
	src_clock_process : process( clk )
	begin
		if rising_edge( clk ) then
			data_en_buf_0 <= data_en_buf_0( 1 downto 0 ) & data_en_0;
			data_en_buf_1 <= data_en_buf_1( 1 downto 0 ) & data_en_1;
			
			if ( not( data_en_buf_0( 2 ) ) and data_en_buf_0( 1 ) ) = '1' then
				o_data0 <= data0;
			end if;
			
			o_data_en <= '0';
			if ( not( data_en_buf_1( 2 ) ) and data_en_buf_1( 1 ) ) = '1' then
				o_data1 <= data1;
				o_data_en <= '1';
			end if;
		end if;
	end process src_clock_process;
	
end rtl;

