library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity fir_buffer is
	port (
		clk			: in  std_logic;
		rst			: in  std_logic;
		
		buf_ini		: in  std_logic;
		
		int_en		: in  std_logic;
		int_dat		: in  signed( 34 downto 0 );
		
		fir_en		: in  std_logic;
		fir_cnt		: out unsigned( 6 downto 0 ) := ( others => '0' );
		fir_dat		: out signed( 34 downto 0 ) := ( others => '0' );
		fir_accum	: out signed( 34 downto 0 ) := ( others => '0' )
	);
end fir_buffer;

architecture rtl of fir_buffer is
	type RAM_TYPE is array( 64 downto 0 ) of signed( 34 downto 0 );
	signal ram	: RAM_TYPE := ( others => ( others => '0' ) );
	
	signal ptr_int		: unsigned(  6 downto 0 ) := ( others => '0' );
	signal ptr_fir		: unsigned(  6 downto 0 ) := ( others => '0' );
	signal coe_accum	: signed( 34 downto 0 ) := ( others => '0' );
begin

	fir_cnt <= ptr_int - ptr_fir;
	fir_accum <= coe_accum;

	int_process : process( clk )
	begin
		if rising_edge( clk ) then
			if ( rst or buf_ini ) = '1' then
				ptr_int <= ( others => '0' );
				coe_accum <= ( others => '0' );
			elsif int_en = '1' and ptr_int < 65 then
				ptr_int <= ptr_int + 1;
				ram( to_integer( ptr_int ) ) <= int_dat;
				coe_accum <= coe_accum + int_dat;
			end if;
		end if;
	end process int_process;
	
	fir_process : process( clk )
	begin
		if rising_edge( clk ) then
			if ( rst or buf_ini ) = '1' then
				ptr_fir <= ( others => '0' );
			elsif fir_en = '1' and ptr_fir < 65 then
				ptr_fir <= ptr_fir + 1;
			end if;
			
			if rst = '1' then
				fir_dat <= ( others => '0' );
			elsif ptr_fir < 65 then
				fir_dat <= ram( to_integer( ptr_fir ) );
			end if;
		end if;
	end process fir_process;

end rtl;

