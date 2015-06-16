library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;
use ieee_proposed.float_pkg.all;

package sig_gen_pkg is
	
	type SIG_TYPE is record
		freq		: real;
		count		: natural;
		seed1 	: positive;
		seed2 	: positive;
		sig		: signed( 34 downto 0 );
		rnd		: signed( 12 downto 0 );
	end record SIG_TYPE;
	constant sig_type_init : SIG_TYPE := ( 1.0, 0, 1, 1, ( others => '0' ), ( others => '0' ) );
	
	shared variable s_rate	: real := 44.1;
	shared variable s_scale	: real range 0.5 to 1.0 := 1.0;
	
	procedure set_rate( i_rate : in real );
	procedure set_scale( i_scale : in real );
	
	procedure fetch_sample( io_sig : inout SIG_TYPE );
	procedure random( io_sig : inout SIG_TYPE );
end sig_gen_pkg;

package body sig_gen_pkg is
	
	procedure set_rate( i_rate : in real ) is
	begin
		s_rate := i_rate;
	end procedure;
	
	procedure set_scale( i_scale : in real ) is
	begin
		s_scale := i_scale;
	end procedure;
	
	procedure fetch_sample( io_sig : inout SIG_TYPE ) is
		variable w					: real; -- radians
		variable x					: real;
		variable sample_real 	: real;
		variable sample_sfixed	: sfixed( 0  downto -34 );
		variable sample_signed	: signed( 34 downto   0 );
		variable sample 		 	: signed( 35 downto   0 );
	begin
		 w := MATH_2_PI * io_sig.freq * 1000.0;
		 x := w * real( io_sig.count ) / ( s_rate * 1000.0 );
		sample_real := sin( x ) * s_scale;
		sample_sfixed := to_sfixed( sample_real, sample_sfixed );
		sample_signed := signed( std_logic_vector( sample_sfixed ) );
		
		random( io_sig );
		sample := ( sample_signed( 34 ) & sample_signed );
		
		if ( sample( 35 ) xor sample( 34 ) ) = '1' then
			if sample( 35 ) = '1' then
				sample := ( 35 downto 34 => '1', others => '0' );
			else
				sample := ( 35 downto 34 => '0', others => '1' );
			end if;
		end if;
		
		io_sig.count := io_sig.count + 1;
		io_sig.sig := sample( 34 downto 0 );
	end procedure;
	
	procedure random( io_sig : inout SIG_TYPE ) is
		variable rand : real;
		variable rand_sfixed : sfixed(  0 downto -12 );
		variable rand_fixed :  signed( 12 downto   0 );
	begin
		UNIFORM( io_sig.seed1, io_sig.seed2, rand );
		rand_sfixed := to_sfixed( rand, rand_sfixed );
		rand_fixed := signed( std_logic_vector( rand_sfixed ) );
		io_sig.rnd := RESIZE( rand_fixed, 13 );
	end procedure;

end sig_gen_pkg;
