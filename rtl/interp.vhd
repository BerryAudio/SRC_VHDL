library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity interpolator is
	port (
		clk				: in  std_logic;
		rst				: in  std_logic;
		
		int_en			: in  std_logic;
		int_fin			: out std_logic := '0';
		
		i_phase			: in  unsigned(  5 downto 0 );
		i_delta			: in  unsigned( 19 downto 0 );
		
		fbuf_en			: out std_logic := '0';
		fbuf_data		: out signed( 34 downto 0 ) := ( others => '0' );
		
		mac_sel			: out std_logic := '0';
		o_mac				: in  mac_o;
		i_mac0			: out mac_i := mac_i_init;
		i_mac1			: out mac_i := mac_i_init
	);
end interpolator;

architecture rtl of interpolator is
	type STATE_TYPE is ( S0_INIT, S1_LAGRANGE, S2_INTERPOLATE );
	signal state		: STATE_TYPE := S0_INIT;

	--******************************************************************
	-- Lagrange Coefficient Calculator Ports
	--******************************************************************
	signal lagrange_h0	: signed( 34 downto 0 );
	signal lagrange_h1	: signed( 34 downto 0 );
	signal lagrange_h2	: signed( 34 downto 0 );
	signal lagrange_h3	: signed( 34 downto 0 );
	signal lagrange_en	: std_logic := '0';
	
	--******************************************************************
	-- FIR Interpolator Ports
	--******************************************************************
	signal fir_fin			: std_logic := '0';
begin

	int_fin <= fir_fin;
	mac_sel <= '1' when state = S2_INTERPOLATE else '0';
	
	state_process : process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				state <= S0_INIT;
			else
				case state is
					when S0_INIT =>
						if int_en = '1' then
							state <= S1_LAGRANGE;
						end if;
					
					when S1_LAGRANGE =>
						if lagrange_en = '1' then
							state <= S2_INTERPOLATE;
						end if;
					
					when S2_INTERPOLATE =>
						if fir_fin = '1' then
							state <= S0_INIT;
						end if;
				
				end case;
			end if;
		end if;
	end process state_process;
	
	INST_LAGRANGE_COEFFICIENT : interp_lagrange
		port map (
			clk			 => clk,
			rst			 => rst,
			
			delta			 => i_delta,
			delta_en		 => int_en,
			
			i_mac			 => i_mac0,
			o_mac			 => o_mac,
			
			lagrange_h0	 => lagrange_h0,
			lagrange_h1	 => lagrange_h1,
			lagrange_h2	 => lagrange_h2,
			lagrange_h3	 => lagrange_h3,
			lagrange_en	 => lagrange_en
		);
	
	INST_COEFFICIENT_INTERPOLATOR : interp_fir
		port map (
			clk			 => clk,
			rst			 => rst,
			
			o_fir_step	 => fbuf_en,
			o_fir_fin	 => fir_fin,
			o_fir_data	 => fbuf_data,
			
			phase			 => i_phase,
			phase_en		 => int_en,
			
			i_mac			 => i_mac1,
			o_mac			 => o_mac,
			
			lagrange_h0	 => lagrange_h0,
			lagrange_h1	 => lagrange_h1,
			lagrange_h2	 => lagrange_h2,
			lagrange_h3	 => lagrange_h3,
			lagrange_en	 => lagrange_en
		);

end rtl;
