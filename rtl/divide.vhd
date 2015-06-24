library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity div_mux is 
	port (
		clk			: in  std_logic;
		rst			: in  std_logic;
		sel			: in  std_logic;
		
		i0_en			: in  std_logic;
		i0_divisor	: in  unsigned( 26 downto 0 );
		i0_dividend	: in  unsigned( 26 downto 0 );
		
		i1_en			: in  std_logic;
		i1_divisor	: in  unsigned( 26 downto 0 );
		i1_dividend	: in  unsigned( 26 downto 0 );
		
		o_busy		: out std_logic := '0';
		o_remainder	: out unsigned( 24 downto 0 ) := ( others => '0' )
	);
end entity div_mux;

architecture rtl of div_mux is
	signal div_en			: std_logic := '0';
	signal div_divisor	: unsigned( 26 downto 0 ) := ( others => '0' );
	signal div_dividend	: unsigned( 26 downto 0 ) := ( others => '0' );
begin
	
	clock_process : process( clk )
	begin
		if rising_edge( clk ) then
			div_en		 <= i0_en;
			div_divisor	 <= i0_divisor;
			div_dividend <= i0_dividend;
			if sel = '1' then
				div_en		 <= i1_en;
				div_divisor	 <= i1_divisor;
				div_dividend <= i1_dividend;
			end if;
		end if;
	end process clock_process;

	INST_DIVIDER : div
		port map (
			clk			=> clk,
			rst			=> rst,
			
			i_en			=> div_en,
			i_divisor	=> div_divisor,
			i_dividend	=> div_dividend,
			
			o_busy		=> o_busy,
			o_remainder	=> o_remainder
		);
		
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity div is 
	port (
		clk			: in  std_logic;
		rst			: in  std_logic;
		
		i_en			: in  std_logic;
		i_divisor	: in  unsigned( 26 downto 0 );
		i_dividend	: in  unsigned( 26 downto 0 );
		
		o_busy		: out std_logic := '0';
		o_remainder	: out unsigned( 24 downto 0 ) := ( others => '0' )
	);
end entity div;

architecture rtl of div is
	constant R_COUNT_MAX : unsigned(  5 downto 0 ) := b"11_0100";

	signal a				 : unsigned( 26 downto 0 ) := ( others => '0' );
	signal b				 : unsigned( 26 downto 0 ) := ( others => '0' );
	signal acc			 : unsigned( 26 downto 0 ) := ( others => '0' );
	signal add_op_u	 : unsigned(  0 downto 0 ) := ( others => '0' );
	alias  add_op		 : std_logic is add_op_u( 0 );
	signal a_neg		 : std_logic := '0';
	signal b_neg		 : std_logic := '0';
	signal en			 : std_logic := '0';
	signal result_neg	 : std_logic := '0';
	signal sum			 : unsigned( 26 downto 0 ) := ( others => '0' );
	signal count		 : unsigned(  5 downto 0 ) := ( others => '0' );
	signal result		 : unsigned( 26 downto 0 ) := ( others => '0' );
	signal add_op_rep	 : unsigned( 26 downto 0 ) := ( others => '0' );
begin

	result_neg <= a_neg XOR b_neg;

	add_op_rep <= ( others => NOT add_op );

	sum <= acc + ( a XOR add_op_rep ) + not( add_op_u );

	-- register the divisor into storage register a.
	process( clk )
	begin
		if rising_edge( clk ) then
			if (rst = '1') then
				a <= ( others => '0' );
				a_neg <= '0';
			elsif (i_en = '1') then
				if i_divisor( 25 downto 0 ) = 0 then
					a_neg <= '0';
					a <= ( 26 => '0', others => '1' );
				elsif i_divisor( 26 ) = '1' then
					a_neg <= '1';
					a <= '0' & COMPLEMENT( i_divisor( 25 downto 0 ) );
				else 
					a_neg <= '0';
					a <= i_divisor;
				end if;
			end if;
		end if;
	end process;

	-- load b with the dividend, but shift by one for the first subtraction.
	process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				b <= ( others => '0' );
				b_neg <= '0';
			elsif i_en = '1' then
				if i_dividend( 25 downto 0 ) = 0 then
					b_neg <= '0';
					b <= ( others => '0' );
				elsif i_dividend( 26 ) = '1' then
					b_neg <= '1';
					b <= COMPLEMENT( i_dividend( 25 downto 0 ) ) & '0';
				else 
					b_neg <= '0';
					b <= i_dividend( 25 downto 0 ) & '0';
				end if;
			else
				b <= b( 25 downto 0 ) & '0';
			end if;
		end if;
	end process;

	-- load the bits of the dividend into the accumulator and shift through the dividend.
	process( clk )
	begin
		if rising_edge( clk ) then
			if ( rst or i_en ) = '1' then
				acc <= ( others => '0' );
			else
				acc <= sum( 25 downto 0 ) & b( 26 );
			end if;
		end if;
	end process;

	-- first operation is always a subtraction ( assumes positive values ).
	process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				add_op <= '0';
			elsif i_en = '1' then
				add_op <= '0';
			else
				add_op <= sum( 26 );
			end if;
		end if;
	end process;

	-- delay line of one for capturing the result bits.
	process( clk )
	begin
		if rising_edge( clk ) then
			en <= i_en;
		end if;
	end process;

	-- counter for timing the storage of the results. not needed if done externally.
	process( clk )
	begin
		if rising_edge( clk ) then
			if ( i_en or rst ) = '1' then
				count <= ( others => '0' );
			elsif count /= ( R_COUNT_MAX + 1 ) then
				count <= count + 1;
			end if;	  
		end if;
	end process;

	-- capture each bit as it is generated.
	process( clk )
	begin
		if rising_edge( clk ) then
			if ( en or rst ) = '1' then
				result <=  ( others => '0' );
			else
				result <= result( 25 downto 0 ) & not( sum( 26 ) );
			end if;
		end if;
	end process;

	-- capture the integer and fraction bits when they are alligned in the result register.
	process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				o_remainder <= ( others => '0' );
			elsif count = R_COUNT_MAX then
				if result_neg = '1' then
					o_remainder <= '1' & COMPLEMENT( result( 24 downto 1 ) );
				else
					o_remainder <= '0' &             result( 24 downto 1 )  ;
				end if;
			end if;
		end if;
	end process;

	process( clk )
	begin
		if rising_edge( clk ) then
			if ( i_en or rst ) = '1' then
				o_busy <= '1';
			elsif count = R_COUNT_MAX then
				o_busy <= '0';
			end if;
		end if;
	end process;

end architecture rtl;
