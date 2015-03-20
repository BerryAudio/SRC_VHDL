library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

library work;
use work.utils.all;
use work.sig_gen_pkg.all;

ENTITY i2s_util_tb IS
	port (
		i2s_bclk : in  std_logic;
		i2s_lrck : in  std_logic;
		i2s_data : out std_logic := '0'
	);
END i2s_util_tb;
 
ARCHITECTURE behavior OF i2s_util_tb IS 
	constant freq0			: real :=  1.0; 
	constant freq1			: real := 20.0;

	shared variable sig0	: SIG_TYPE := sig_type_init;
	shared variable sig1	: SIG_TYPE := sig_type_init;

	signal data		: signed( 23 downto 0 ) := ( others => '0' );
	signal ws_buf	: std_logic_vector( 1 downto 0 ) := "00";
	signal wsp	 	: std_logic := '0';
	
	impure function gen_sig0 return signed is
	begin
		fetch_sample( sig0 );
		return sig0.sig( 34 downto 11 );
	end function;
	
	impure function gen_sig1 return signed is
	begin
		fetch_sample( sig1 );
		return sig1.sig( 34 downto 11 );
	end function;
	
	impure function gen_sig_mix return signed is
		variable sample0	: signed( 22 downto 0 ) := ( others => '0' );
		variable sample1	: signed( 22 downto 0 ) := ( others => '0' );
		variable sample	: signed( 23 downto 0 ) := ( others => '0' );
	begin
		fetch_sample( sig0 ); sample0 := sig0.sig( 34 downto 12 );
		fetch_sample( sig1 ); sample1 := sig1.sig( 34 downto 12 );
		sample := RESIZE( sample0, 24 ) + RESIZE( sample1, 24 );
		return sample;
	end function;
BEGIN

	process
	begin
		sig0.freq := freq0;
		sig1.freq := freq1;
		wait;
	end process;

	wsp <= ws_buf( 0 ) xor ws_buf( 1 );
	i2s_data <= data( 23 );

	i2s_process : process( i2s_bclk )
		variable sample	: signed( 23 downto 0 ) := ( others => '0' );
	begin
		if falling_edge( i2s_bclk ) then
			if wsp = '1' then
				if ws_buf( 0 ) = '0' then
					sample := gen_sig0;
					data <= sample;
				else
					data <= RESIZE( sample( 23 downto 20 ), 24 );
				end if;
			else
				data <= data( 22 downto 0 ) & '0';
			end if;
		end if;
	
		if rising_edge( i2s_bclk ) then
			ws_buf <= ws_buf( 0 ) & i2s_lrck;
		end if;
	end process i2s_process;

END;
