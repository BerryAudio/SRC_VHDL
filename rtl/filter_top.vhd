library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity filter_top is
	port (
		clk				: in  std_logic;
		rst				: in  std_logic;
		
		i_phase			: in  unsigned(  5 downto 0 );
		i_delta			: in  unsigned( 19 downto 0 );
		i_en				: in  std_logic;

		rd_en				: out std_logic := '0';
		rd_step			: out std_logic := '0';
		rd_data0			: in  signed( 23 downto 0 );
		rd_data1			: in  signed( 23 downto 0 );
		
		o_data_en		: out std_logic := '0';
		o_data0			: out signed( 34 downto 0 ) := ( others => '0' );
		o_data1			: out signed( 34 downto 0 ) := ( others => '0' );
		
		-- mac signals
		mac_sel			: out std_logic_vector( 1 downto 0 ) := ( others => '0' );
		
		o_mac0			: in  mac_o;
		o_mac2			: in  mac_o;
		
		i_mac0			: out mac_i := mac_i_init;
		i_mac1			: out mac_i := mac_i_init;
		i_mac2			: out mac_i := mac_i_init;
		
		-- divider signals
		i_div_remainder: in  unsigned( 25 downto 0 );
		o_div_en			: out std_logic := '0';
		o_div_dividend	: out unsigned( 25 downto 0 ) := ( others => '0' );
		o_div_divisor	: out unsigned( 25 downto 0 ) := ( others => '0' )
	);
end filter_top;

architecture rtl of filter_top is
	-- state machine
	type STATE_TYPE is ( S0_INIT, S1_INTERP, S2_FIR );
	signal state			: STATE_TYPE := S0_INIT;

	-- interpolator control interfaces
	signal int_en			: std_logic := '0';
	signal int_fin			: std_logic := '0';
	
	-- fir control interfaces
	signal fir_en			: std_logic := '0';
	signal fir_fin			: std_logic := '0';
	
	-- fir buf interfaces
	signal fbuf_ini		: std_logic := '1';
	signal fbuf_int_en	: std_logic := '0';
	signal fbuf_int_dat	: signed( 34 downto 0 ) := ( others => '0' );
	signal fbuf_fir_en	: std_logic := '0';
	signal fbuf_fir_cnt	: unsigned( 6 downto 0 ) := ( others => '0' );
	signal fbuf_fir_dat	: signed( 34 downto 0 ) := ( others => '0' );
	signal fbuf_fir_accum: signed( 34 downto 0 ) := ( others => '0' );
	
begin

	mac_sel( 1 ) <= '1' when state = S2_FIR else '0';

	state_process : process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				state <= S0_INIT;
				fbuf_ini <= '1';
				fir_en <= '0';
				
			else
				fbuf_ini <= '0';
				fir_en <= '0';
				
				case state is
					when S0_INIT =>
						fbuf_ini <= '1';
						if i_en = '1' then
							state <= S1_INTERP;
						end if;
					
					when S1_INTERP =>
						if int_fin = '1' then
							fir_en <= '1';
							state <= S2_FIR;
						end if;
					
					when S2_FIR =>
						if fir_fin = '1' then
							state <= S0_INIT;
						end if;
					
				end case;
			end if;
		end if;
	end process state_process;

	INST_INTERPOLATOR : interpolator
		port map (
			clk				=> clk,
			rst				=> rst,
			
			int_en			=> i_en,
			int_fin			=> int_fin,
			
			i_phase			=> i_phase,
			i_delta			=> i_delta,
			
			fbuf_en			=> fbuf_int_en,
			fbuf_data		=> fbuf_int_dat,
			
			mac_sel			=> mac_sel( 0 ),
			o_mac				=> o_mac0,
			i_mac0			=> i_mac0,
			i_mac1			=> i_mac1
		);
	
	INST_FIR : fir
		port map (
			clk				=> clk,
			rst				=> rst,
			
			fir_en			=> fir_en,
			fir_fin			=> fir_fin,
			
			o_data_en		=> o_data_en,
			o_data0			=> o_data0,
			o_data1			=> o_data1,
			
			fbuf_en			=> fbuf_fir_en,
			fbuf_cnt			=> fbuf_fir_cnt,
			fbuf_data		=> fbuf_fir_dat,
			fbuf_accum		=> fbuf_fir_accum,
			
			rbuf_en			=> rd_en,
			rbuf_step		=> rd_step,
			rbuf_data0		=> rd_data0,
			rbuf_data1		=> rd_data1,
			
			i_mac				=> i_mac2,
			o_mac				=> o_mac2,
			
			i_div_remainder=> i_div_remainder,
			o_div_en			=> o_div_en,
			o_div_dividend	=> o_div_dividend,
			o_div_divisor	=> o_div_divisor
		);

	INST_FIR_BUF : fir_buffer
		port map (
			clk				=> clk,
			rst				=> rst,
				
			buf_ini			=> fbuf_ini,
			int_en			=> fbuf_int_en,
			int_dat			=> fbuf_int_dat,
			fir_en			=> fbuf_fir_en,
			fir_cnt			=> fbuf_fir_cnt,
			fir_dat			=> fbuf_fir_dat,
			fir_accum		=> fbuf_fir_accum
		);

end rtl;

