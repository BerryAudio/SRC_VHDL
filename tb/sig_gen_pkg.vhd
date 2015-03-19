library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;
use ieee_proposed.float_pkg.all;

package sig_gen_pkg is
	shared variable FREQ	: real := 1.0; -- kHz
	shared variable W		: real := MATH_2_PI * FREQ * 1000.0; -- radians
	
	shared variable s_rate	: real := 44.1; -- kHz
	shared variable s_width	: natural := 35;
	shared variable s_count	: unsigned( 31 downto 0 ) := ( others => '0' );
	shared variable seed1 : positive := 1;
	shared variable seed2 : positive := 1;
	
	procedure sig_reset;
	procedure set_sig( s_freq : in real; s_rate : in real; w_width : in natural );
	procedure set_rate( rate : in real );
	procedure set_width( width : in natural );
	
	impure function fetch_sample return signed;
	impure function fetch_sample return real;
	impure function random return signed;
end sig_gen_pkg;

package body sig_gen_pkg is

	procedure sig_reset is
	begin
		s_rate := 44.1;
		s_count := ( others => '0' );
	end procedure sig_reset;
	
	procedure set_sig( s_freq : in real; s_rate : in real; w_width : in natural ) is
	begin
		s_count := ( others => '0' );
		s_width := w_width;
		FREQ := s_freq;
		W := MATH_2_PI * FREQ * 1000.0;
		set_rate( s_rate );
	end procedure set_sig;
	
	procedure set_rate( rate : in real ) is
	begin
		s_rate := rate;
	end procedure set_rate;
	
	procedure set_width( width : in natural ) is
	begin
		s_width := 35;
	end procedure set_width;
	
	impure function fetch_sample return signed is
		variable x				: real;
		variable sample_real : real;
		variable sample_sfixed : sfixed( 0 downto -( s_width - 1 ) );
		variable sample_signed : signed( s_width - 1 downto 0 );
		variable sample 		  : signed( s_width     downto 0 );
	begin
		x := W * real( to_integer( s_count ) ) / ( s_rate * real( 1000 ) );
		sample_real := sin( x ) * 1.0;
		sample_sfixed := to_sfixed( sample_real, sample_sfixed );
		sample_signed := signed( std_logic_vector( sample_sfixed ) );
		sample := ( sample_signed( s_width-1 ) & sample_signed ) + random;
		
		if ( sample( s_width ) xor sample( s_width-1 ) ) = '1' then
			if sample( s_width ) = '1' then
				sample := ( s_width downto s_width-1 => '1', others => '0' );
			else
				sample := ( s_width downto s_width-1 => '0', others => '1' );
			end if;
		end if;
		
		
		s_count := s_count + 1;
		return sample( s_width - 1 downto 0 );
	end function fetch_sample;
	
	impure function fetch_sample return real is
		variable x				: real;
		variable sample_real : real;
	begin
		x := W * real( to_integer( s_count ) ) / ( s_rate * real( 1000 ) );
		sample_real := sin( x ) * 0.99;
		s_count := s_count + 1;
		return sample_real;
	end function fetch_sample;
	
	impure function random return signed is
		variable rand : real;
		variable rand_sfixed : sfixed( 0 downto -12 );
		variable rand_fixed : signed( 12 downto 0 );
	begin
		UNIFORM( seed1, seed2, rand );
		rand_sfixed := to_sfixed( rand, rand_sfixed );
		rand_fixed := signed( std_logic_vector( rand_sfixed ) );
		return RESIZE( rand_fixed, s_width );
	end function random;

end sig_gen_pkg;
