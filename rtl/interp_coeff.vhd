library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity interp_lagrange is
	port (
		clk			 : in  std_logic;
		rst			 : in  std_logic;
		
		delta			 : in  unsigned( 21 downto 0 );
		delta_en		 : in  std_logic;
		
		i_mac			 : out mac_i := mac_i_init;
		o_mac			 : in  mac_o;
		
		lagrange_h0	 : out signed( 34 downto 0 ) := ( others => '0' );
		lagrange_h1	 : out signed( 34 downto 0 ) := ( others => '0' );
		lagrange_h2	 : out signed( 34 downto 0 ) := ( others => '0' );
		lagrange_h3	 : out signed( 34 downto 0 ) := ( others => '0' );
		lagrange_en	 : out std_logic := '0'
	);
end interp_lagrange;

architecture rtl of interp_lagrange is
	constant ONE_THIRD	: signed( 34 downto 0 ) := b"0000_0101_0101_0101_0101_0101_0101_0101_010";
	constant ONE_THIRD_N	: signed( 34 downto 0 ) := b"1111_1010_1010_1010_1010_1010_1010_1010_110";

	signal state_count : unsigned( 2 downto 0 ) := ( others => '0' );
	
	signal d				: unsigned( 21 downto 0 ) := ( others => '0' );
	signal d0			:   signed( 34 downto 0 ) := ( others => '0' );
	signal d1			:   signed( 34 downto 0 ) := ( others => '0' );
	signal d2			:   signed( 34 downto 0 ) := ( others => '0' );
	signal d3			:   signed( 34 downto 0 ) := ( others => '0' );
	
	signal buf0			: signed( 34 downto 0 ) := ( others => '0' );
	signal buf1			: signed( 34 downto 0 ) := ( others => '0' );
	
	constant D_N0			: signed( 24 downto 0 ) := "0000000000000000000000000";
	constant D_N1			: signed( 24 downto 0 ) := "1110000000000000000000000";
	constant D_N2			: signed( 24 downto 0 ) := "1100000000000000000000000";
	constant D_N3			: signed( 24 downto 0 ) := "1010000000000000000000000";
begin

	d0 <= ( D_N0 + to_integer( delta ) ) & b"00_0000_0000";
	d1 <= ( D_N1 + to_integer( delta ) ) & b"00_0000_0000";
	d2 <= ( D_N2 + to_integer( delta ) ) & b"00_0000_0000";
	d3 <= ( D_N3 + to_integer( delta ) ) & b"00_0000_0000";

	state_process : process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				state_count	<= ( others => '0' );
				lagrange_en	<= '0';
				i_mac.cmp	<= '0';
			else
				lagrange_en <= '0';
				i_mac.cmp	<= '0';
				
				case to_integer( state_count ) is
					when 0 =>
						i_mac.data00 <= d0; -- D0 S2.22 - 25 bits
						i_mac.data01 <= d1; -- D1 S2.22
						i_mac.data10 <= d2; -- D2 S2.22
						i_mac.data11 <= d3; -- D3 S2.22
						i_mac.cmp <= delta_en;
					
						if delta_en = '1' then
							state_count <= o"1";
						end if;
						
					when 1 =>
						i_mac.data00 <= o_mac.data0( 69 downto 35 ); -- D0*D1 - h3 - 35 bits
						i_mac.data01 <= d2;			  						-- D2    -    - 35 bits
						
						i_mac.data10 <= o_mac.data1( 69 downto 35 ); -- D2*D3 - h0 - 35
						i_mac.data11 <= d1;									-- D1    -    - 35 bits
						
						i_mac.cmp <= o_mac.en;
						
						if o_mac.en = '1' then
							state_count <= o"2";
						end if;
					
					when 2 =>
						i_mac.data01 <= d3; -- (D0*D1)* D3 - h2
						i_mac.data11 <= d0; -- (D2*D3)* D0 - h1
						i_mac.cmp <= '1';
							
						state_count <= o"3";
						
					when 3 =>
						if o_mac.en = '1' then
							buf0	 <= o_mac.data0( 64 downto 30 ); -- D0*D1*D2/2 - h3
							buf1	 <= o_mac.data1( 64 downto 30 ); -- D1*D2*D3/2 - h0
							state_count <= o"4";
						end if;
						
					when 4 =>
						
						-- Divide by 3 = multiply by 1/3
						i_mac.data00 <= buf1;
						i_mac.data01 <= ONE_THIRD_N;
						
						i_mac.data10 <= buf0;
						i_mac.data11 <= ONE_THIRD;
						
						i_mac.cmp <= o_mac.en;
						
						if o_mac.en = '1' then
							lagrange_h2 <= COMPLEMENT( o_mac.data0( 64 downto 30 ) ); -- D0*D1*D3/2 - h2
							lagrange_h1 <=					o_mac.data1( 64 downto 30 )  ; -- D0*D2*D3/2 - h1
							state_count <= o"5";
						end if;
						
					when 5 =>
						lagrange_en <= o_mac.en;
						
						if o_mac.en = '1' then
							lagrange_h0 <= o_mac.data0( 65 downto 31 );
							lagrange_h3 <= o_mac.data1( 65 downto 31 );
							state_count <= o"0";
						end if;
						
					when others =>
						state_count <= o"0";
					
				end case;
			end if;
		end if;
	end process state_process;

end rtl;
