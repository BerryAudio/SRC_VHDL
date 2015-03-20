library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

library std;
use std.textio.all;

library work;
use work.src.all;

entity fir_filter_rom is
	generic (
		ROM_FILE : string := ROM_FILE_SRC
	);
	port (
		clk	: in  std_logic;
		rst	: in  std_logic;
		
		addr0	: in  unsigned( 12 downto 0 );
		addr1	: in  unsigned( 12 downto 0 );
		
		data0	: out   signed( 27 downto 0 ) := ( others => '0' );
		data1	: out   signed( 27 downto 0 ) := ( others => '0' )
	);
end fir_filter_rom;

architecture rtl of fir_filter_rom is
	type FIR_ROM_TYPE is array( 2047 downto 0 ) of signed( 27 downto 0 );
	
	impure function FIR_ROM_INIT( rom_file_name : in string ) return FIR_ROM_TYPE is
		file rom_file		: text open read_mode is rom_file_name;
		variable rom_line	: line;
		variable temp_bv	: std_logic_vector( 27 downto 0 );
		variable temp_mem	: FIR_ROM_TYPE;
	begin
		for i in 0 to 2047 loop
			readline( rom_file, rom_line );
			HREAD( rom_line, temp_bv );
			temp_mem( i ) := signed( temp_bv );
		end loop;
		return temp_mem;
	end function FIR_ROM_INIT;
	
	function FIR_ROM_CENTRE( rom_file_name : in string ) return signed is
		file rom_file		: text open read_mode is rom_file_name;
		variable rom_line	: line;
		variable temp_bv	: std_logic_vector( 27 downto 0 );
		variable temp_coe	: signed( 27 downto 0 );
	begin
		for i in 0 to 2047 loop
			readline( rom_file, rom_line );
		end loop;
		HREAD( rom_line, temp_bv );
		temp_coe := signed( temp_bv );
		return temp_coe;
	end function FIR_ROM_CENTRE;
	
	signal rom : FIR_ROM_TYPE := FIR_ROM_INIT( ROM_FILE );
	constant CENTRE_COEFF	: signed( 27 downto 0 ) := FIR_ROM_CENTRE( ROM_FILE );
	
	signal buf_addr0	 : unsigned( 12 downto 0 ) := ( others => '0' );
	signal buf_addr1	 : unsigned( 12 downto 0 ) := ( others => '0' );
	
	signal trans_data0 : signed( 27 downto 0 ) := ( others => '0' );
	signal trans_data1 : signed( 27 downto 0 ) := ( others => '0' );
	
	signal trans_addr0 : unsigned( 12 downto 0 );
	signal trans_addr1 : unsigned( 12 downto 0 );
begin

	trans_addr0 <= addr0 when addr0 < 2048 
			else ( 4096 + COMPLEMENT( addr0 ) );
			
	trans_addr1 <= addr1 when addr1 < 2048
			else ( 4096 + COMPLEMENT( addr1 ) );
	
	data0 <= ( others => '0' ) when buf_addr0 > 4096
			else CENTRE_COEFF    when buf_addr0 = 2048
			else trans_data0;
	
	data1 <= ( others => '0' ) when buf_addr1 > 4096
			else CENTRE_COEFF    when buf_addr1 = 2048
			else trans_data1;
	
	rom_process : process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				trans_data0 <= ( others => '0' );
				trans_data1 <= ( others => '0' );
				buf_addr0	<= ( others => '0' );
				buf_addr1	<= ( others => '0' );
			else
				buf_addr0	<= addr0;
				buf_addr1	<= addr1;
				trans_data0 <= rom( to_integer( trans_addr0( 10 downto 0 ) ) );
				trans_data1 <= rom( to_integer( trans_addr1( 10 downto 0 ) ) );
			end if;
		end if;
	end process rom_process;
	
end rtl;
