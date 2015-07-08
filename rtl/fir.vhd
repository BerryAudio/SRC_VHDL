--*****************************************************************************
--** TODO:
--**	- add accumulator divide (1/coe_accum)
--**		* this can happen in parrallel with the FIR calculations
--**			# FIR = 64 cycles
--**			# DIV = 57 cycles
--**	- multiply output data (0 & 1) by the divider output
--**	- Modify state machine to do this
--*****************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity fir is
	port (
		clk			 	: in  std_logic;
		rst			 	: in  std_logic;
		
		-- start/end the fir convolution
		fir_en		 	: in  std_logic;
		fir_fin		 	: out std_logic := '0';
		
		-- convolution output
		o_data_en	 	: out std_logic := '0';
		o_data0		 	: out signed( 34 downto 0 ) := ( others => '0' );
		o_data1		 	: out signed( 34 downto 0 ) := ( others => '0' );
		
		-- coefficient buffer interface
		fbuf_en		 	: out std_logic := '0';
		fbuf_cnt		 	: in  unsigned( 6 downto 0 );
		fbuf_data	 	: in  signed( 34 downto 0 );
		fbuf_accum	 	: in  signed( 34 downto 0 );
		
		-- ring buffer interface
		rbuf_en		 	: out std_logic := '0';
		rbuf_step	 	: out std_logic := '0';
		rbuf_data0	 	: in  signed( 23 downto 0 ) := ( others => '0' );
		rbuf_data1	 	: in  signed( 23 downto 0 ) := ( others => '0' );
		
		-- mac interfaces
		i_mac				: out mac_i := mac_i_init;
		o_mac				: in  mac_o;
		
		-- divider interfaces
		i_div_remainder: in  unsigned( 25 downto 0 );
		o_div_en			: out std_logic := '0';
		o_div_dividend	: out unsigned( 25 downto 0 ) := ( 25 => '1', others => '0' );
		o_div_divisor	: out unsigned( 25 downto 0 ) := ( others => '0' )
	);
end fir;

architecture rtl of fir is
	type STATE_TYPE is ( S0_WAIT, S1_FIR_RUN, S1_FIR_FIN, S2_NORMALISE );
	signal state		: STATE_TYPE := S0_WAIT;
	signal fir_pipe	: std_logic_vector( 3 downto 0 ) := ( others => '0' );
	signal fir_cmp		: std_logic_vector( 1 downto 0 ) := ( others => '0' );
	signal fir_run		: std_logic := '0';
	
	signal norm_cmp	: std_logic := '0';
	
	signal mac_data	: signed( 34 downto 0 ) := ( others => '0' );
begin
	-- start the division as soon as the FIR
	-- filter is enabled
	o_div_divisor <= unsigned( fbuf_accum( 30 downto 5 ) );
	o_div_en <= fir_en;
	
	-- Ring Buffer Synchronisation
	rbuf_en		 <= fir_en;
	rbuf_step	 <= fir_pipe( 0 );
	
	-- Coefficient Buffer Synchronisation
	fbuf_en		 <= fir_pipe( 1 );
	
	-- MAC Synchronisation
	i_mac.en		 <= fir_pipe( 2 );
	i_mac.acc	 <= fir_pipe( 3 );
	i_mac.cmp	 <= fir_cmp ( 1 ) when state = S1_FIR_FIN else norm_cmp;
	
	i_mac.data00 <= rbuf_data0 & b"000_0000_0000" when fir_run = '1'
						 else o_mac.data0( 69 downto 35 );
	i_mac.data10 <= rbuf_data1 & b"000_0000_0000" when fir_run = '1'
						 else o_mac.data1( 69 downto 35 );
	
	
	mac_data <= fbuf_data  when fir_run = '1' else 
					signed( '0' & i_div_remainder ) & b"0000_0000";
	i_mac.data01 <= mac_data;
	i_mac.data11 <= mac_data;
	
	
	-- State Machine to control everything
	state_process : process( clk )
	begin
		if rising_edge( clk ) then
			if rst  = '1' then
				state    <= S0_WAIT;
				
				fir_fin  <= '0';
				fir_run  <= '0';
				fir_cmp  <= ( others => '0' );
				fir_pipe <= ( others => '0' );
				norm_cmp <= '0';
			else
				fir_fin  <= '0';
				fir_cmp  <= fir_cmp( 0 ) & '0';
				fir_pipe <= fir_pipe( fir_pipe'length-2 downto 0 ) & '0';
				norm_cmp <= '0';
				
				case state is
					when S0_WAIT =>
						fir_pipe( 0 ) <= fir_en;
						if fir_en = '1' then
							state <= S1_FIR_RUN;
						end if;
					
					-- run all coefficients and data
					-- through the MAC
					when S1_FIR_RUN =>
						fir_run <= '1';
						fir_pipe( 0 ) <= '1';
						if fbuf_cnt = 2 then
							fir_pipe( 0 ) <= '0';
							fir_cmp ( 0 ) <= '1';
							state <= S1_FIR_FIN;
						end if;
					
					-- wait for MAC to complete
					when S1_FIR_FIN =>
						if o_mac.en = '1' then
							fir_run <= '0';
							norm_cmp <= '1';
							state <= S2_NORMALISE;
						end if;
					
					when S2_NORMALISE =>
						if o_mac.en = '1' then
							state <= S0_WAIT;
							fir_fin <= '1';
						end if;
						
				end case;
			end if;
		end if;
	end process state_process;
	
	output_process : process( clk )
	begin
		if rising_edge( clk ) then
			o_data_en <= '0';
			if rst = '1' then
				o_data0 <= ( others => '0' );
				o_data1 <= ( others => '0' );
				
			elsif state = S2_NORMALISE and o_mac.en = '1' then
				o_data0 <= o_mac.data0( 64 downto 30 );
				o_data1 <= o_mac.data1( 64 downto 30 );
				o_data_en <= '1';
			end if;
		end if;
	end process output_process;

end rtl;

