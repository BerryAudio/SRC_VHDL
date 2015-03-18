library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity dac_util_tb is
	port(
		i_lrck 		: in  std_logic;
		i_bclk 		: in  std_logic;
		i_data0 		: in  std_logic;
		i_data1 		: in  std_logic;
		
		o_data0 		: out signed(23 downto 0) := ( others => '0' );
		o_data1 		: out signed(23 downto 0) := ( others => '0' );
		o_data_en	: out std_logic := '0'
	);
end dac_util_tb;
 
architecture rtl OF dac_util_tb is
	signal lrck		: std_logic := '0';
	signal data0	: std_logic := '0';
	signal data1	: std_logic := '0';
	
	signal cnt		: unsigned( 4 downto 0 ) := ( others => '0' );
	signal d0		: signed(31 downto 0) := ( others => '0' );
	signal d1		: signed(31 downto 0) := ( others => '0' );
	signal d_buf	: std_logic := '0';
	
	-- delayed signals because isim is stuffed
begin

	process( i_bclk )
	begin
		if rising_edge( i_bclk ) then
			lrck	<= i_lrck;
			data0 <= i_data0;
			data1 <= i_data1;
		end if;
	end process;
	
	process( i_bclk )
	begin
		if rising_edge( i_bclk ) then
			-- if i_lrck = '1' then -- AD1955
			if ( ( i_lrck xor lrck ) and not( i_lrck ) ) = '1' then -- PCM1794A
				cnt <= ( others => '1' );
			else
				cnt <= cnt - 1;
			end if;
		end if;
	end process;
	
	process( i_bclk )
	begin
		if rising_edge( i_bclk ) then
			d0( to_integer( cnt ) ) <= data0;
			d1( to_integer( cnt ) ) <= data1;
			d_buf <= ( i_lrck xor lrck ) and lrck;
			
			o_data_en <= d_buf;
			if d_buf = '1' then
				o_data0 <= d0( 23 downto 0 );
				o_data1 <= d1( 23 downto 0 );
			end if;
		end if;
	end process;
	
end;
