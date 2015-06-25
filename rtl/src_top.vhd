library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity src_top is
	generic (
		CLOCK_COUNT				: integer := 512
	);
	port (
		clk						: in  std_logic;
		rst						: in  std_logic;
		
		ctrl_width				: in  std_logic_vector( 1 downto 0 );
		ctrl_locked				: out std_logic := '0';
		
		i_sample_en_i			: in  std_logic;
		i_sample_en_o			: in  std_logic;
		i_data0					: in  signed( 23 downto 0 );
		i_data1					: in  signed( 23 downto 0 );
		
		o_data_en				: out std_logic := '0';
		o_data0					: out signed( 23 downto 0 ) := ( others => '0' );
		o_data1					: out signed( 23 downto 0 ) := ( others => '0' )
	);
end src_top;

architecture rtl of src_top is
	-- state machine
	type STATE_TYPE_SRC is ( S0_RESET, S1_WAIT, S2_REGULATOR, S3_FILTER );
	signal state_src			: STATE_TYPE_SRC := S0_RESET;
	
	type STATE_TYPE_HB  is ( S0_WAIT, S1_FIR, S2_DITHER );
	signal state_hb			: STATE_TYPE_HB  := S0_WAIT;
	
	signal i_sample_sel		: std_logic := '0';
	signal i_sample_en_o0	: std_logic := '0';
	signal i_sample_en_o1	: std_logic := '0';
	
	signal i_sample_shift	: unsigned( 3 downto 0 ) := ( others => '0' );
	signal i_sample0			: signed( 23 downto 0 ) := ( others => '0' );
	signal i_sample1			: signed( 23 downto 0 ) := ( others => '0' );

	-- general control signals
	signal fifo_level			: unsigned( 10 downto 0 ) := ( others => '0' );
	signal fifo_ptr			: unsigned( 27 downto 0 ) := ( others => '0' );
	signal locked				: std_logic := '0';
	signal ratio				: unsigned( 23 + REG_AVE_WIDTH downto 0 ) := ( others => '0' );
	signal ratio_in			: unsigned( 29 downto 0 ) := ( others => '0' );
	signal ratio_en			: std_logic := '0';
	signal buf_rdy				: std_logic := '0';
	signal reg_rst				: std_logic := '0';
	
	signal phase				: unsigned(  5 downto 0 ) := ( others => '0' );
	signal delta				: unsigned( 21 downto 0 ) := ( others => '0' );
	signal filter_en			: std_logic := '0';
	signal filter_fin			: std_logic := '0';
	
	signal rbuf_en				: std_logic := '0';
	signal rbuf_step			: std_logic := '0';
	signal rbuf_data0			: signed( 23 downto 0 ) := ( others => '0' );
	signal rbuf_data1			: signed( 23 downto 0 ) := ( others => '0' );
	
	signal filter_data_en	: std_logic := '0';
	signal filter_data0		: signed( 34 downto 0 ) := ( others => '0' );
	signal filter_data1		: signed( 34 downto 0 ) := ( others => '0' );
	signal filter_rst			: std_logic := '0';
	
	signal hb_data_en			: std_logic := '0';
	signal hb_data0			: signed( 34 downto 0 ) := ( others => '0' );
	signal hb_data1			: signed( 34 downto 0 ) := ( others => '0' );
	
	signal dither_data0		: signed( 23 downto 0 ) := ( others => '0' );
	signal dither_data1		: signed( 23 downto 0 ) := ( others => '0' );
	signal dither_data_en	: std_logic := '0';
	
	-- MAC signals
	-- MAC - SRC signals
	signal src_mac_sel		: std_logic_vector( 1 downto 0 ) := ( others => '0' );
	signal src_o_mac0			: mac_o := mac_o_init;
	signal src_o_mac2			: mac_o := mac_o_init;
	signal src_i_mac0			: mac_i := mac_i_init;
	signal src_i_mac1			: mac_i := mac_i_init;
	signal src_i_mac2			: mac_i := mac_i_init;
	
	-- MAC - HALFBAND signals	
	signal hb_mac_sel			: std_logic := '0';
	signal hb_o_mac0			: mac_o := mac_o_init;
	signal hb_o_mac1			: mac_o := mac_o_init;
	signal hb_i_mac0			: mac_i := mac_i_init;
	signal hb_i_mac1			: mac_i := mac_i_init;
	
	-- Divider signals
	signal div_sel				: std_logic := '0';
	signal div0_en				: std_logic := '0';
	signal div0_divisor		: unsigned( 26 downto 0 ) := ( others => '0' );
	signal div0_dividend		: unsigned( 26 downto 0 ) := ( others => '0' );
	signal div1_en				: std_logic := '0';
	signal div1_divisor		: unsigned( 26 downto 0 ) := ( others => '0' );
	signal div1_dividend		: unsigned( 26 downto 0 ) := ( others => '0' );
	signal div_busy			: std_logic := '0';
	signal div_remainder		: unsigned( 24 downto 0 ) := ( others => '0' );
begin

	o_data_en	<= dither_data_en;
	o_data0	<= dither_data0;
	o_data1	<= dither_data1;
	
	ctrl_locked <= locked;
	
	phase <= fifo_ptr( 27 downto 22 );
	delta <= fifo_ptr( 21 downto  0 );
	
	reg_rst <= not buf_rdy;
	div_sel <= '1'  when state_src = S3_FILTER else '0';
	
	i_sample_en_o0 <= i_sample_en_o and not( i_sample_sel );
	i_sample_en_o1 <= i_sample_en_o and      i_sample_sel;
	
	i_sample0 <= shift_right( i_data0, to_integer( i_sample_shift ) );
	i_sample1 <= shift_right( i_data1, to_integer( i_sample_shift ) );
	
	ratio_in <= RESIZE( ratio, 30 ) sll ( 6 - REG_AVE_WIDTH );
	
	sample_sel_process : process( clk )
	begin
		if rising_edge( clk ) then
			if i_sample_en_o = '1' then
				i_sample_sel <= not( i_sample_sel );
			end if;
		end if;
	end process sample_sel_process;
	
	srl_process : process( clk )
	begin
		if rising_edge( clk ) then
			case ctrl_width is
				when "11"   => i_sample_shift <= x"8";
				when "10"   => i_sample_shift <= x"6";
				when "01"   => i_sample_shift <= x"4";
				when others => i_sample_shift <= x"0";
			end case;
		end if;
	end process srl_process;
	
	state_src_process : process( clk )
	begin
		if rising_edge( clk ) then
			filter_en <= '0';
			filter_rst <= not( locked ) or rst;
			
			if filter_rst = '1' then
				state_src <= S0_RESET;
			else
				case state_src is
					when S0_RESET =>
						if buf_rdy = '1' then
							state_src <= S1_WAIT;
						end if;
					
					when S1_WAIT =>
						if i_sample_en_o0 = '1' then
							state_src <= S2_REGULATOR;
						end if;
					
					when S2_REGULATOR =>
						if ratio_en = '1' then
							state_src <= S1_WAIT;
							filter_en <= locked;
							if locked = '1' then
								state_src <= S3_FILTER;
							end if;
						end if;
					
					when S3_FILTER =>
						if filter_data_en = '1' then
							state_src <= S1_WAIT;
						end if;
					
				end case;
			end if;
		end if;
	end process state_src_process;
	
	state_hb_process : process( clk )
	begin
		if rising_edge( clk ) then
			hb_mac_sel <= '0';
			
			if rst = '1' then
				state_hb <= S0_WAIT;
			else
				case state_hb is
					when S0_WAIT =>
						if i_sample_en_o = '1' then
							state_hb <= S1_FIR;
						end if;
					
					when S1_FIR =>
						if hb_data_en = '1' then
							state_hb <= S2_DITHER;
						end if;
						
					when S2_DITHER =>
						hb_mac_sel <= '1';
						if dither_data_en = '1' then
							state_hb <= S0_WAIT;
						end if;
					
				end case;
			end if;
		end if;
	end process state_hb_process;

	INST_REGULATOR : regulator_top
		generic map (
			CLOCK_COUNT		=> CLOCK_COUNT
		)
		port map (
			clk				=> clk,
			rst				=> reg_rst,
			
			i_sample_en		=> i_sample_en_i,
			o_sample_en		=> i_sample_en_o0,
			i_fifo_level	=> fifo_level,
			
			o_locked			=> locked,
			o_ratio			=> ratio,
			o_ratio_en		=> ratio_en,
			
			div_en			=> div0_en,
			div_divisor		=> div0_divisor,
			div_dividend	=> div0_dividend,
			
			div_busy			=> div_busy,
			div_remainder	=> div_remainder
		);
	
	INST_FILTER : filter_top
		port map (
			clk				=> clk,
			rst				=> filter_rst,
			
			i_phase			=> phase,
			i_delta			=> delta,
			i_en				=> filter_en,

			rd_en				=> rbuf_en,
			rd_step			=> rbuf_step,
			rd_data0			=> rbuf_data0,
			rd_data1			=> rbuf_data1,
			
			o_data_en		=> filter_data_en,
			o_data0			=> filter_data0,
			o_data1			=> filter_data1,
		
			mac_sel			=> src_mac_sel,
			o_mac0			=> src_o_mac0,
			o_mac2			=> src_o_mac2,
			i_mac0			=> src_i_mac0,
			i_mac1			=> src_i_mac1,
			i_mac2			=> src_i_mac2,
			
			i_div_remainder=> div_remainder,
			o_div_en			=> div1_en,
			o_div_dividend	=> div1_dividend,
			o_div_divisor	=> div1_divisor
		);
	
	INST_HALFBAND : hb_filter_top
		port map (
			clk				=> clk,
			rst				=> filter_rst,
			
			i_data_en0		=> i_sample_en_o0,
			i_data_en1		=> i_sample_en_o1,
			i_data0			=> filter_data0,
			i_data1			=> filter_data1,
			
			o_data_en		=> hb_data_en,
			o_data0			=> hb_data0,
			o_data1			=> hb_data1,
			
			o_mac				=> hb_o_mac0,
			i_mac				=> hb_i_mac0
		);
	
	INST_DITHER : dither_top
		port map (
			clk				=> clk,
			rst				=> filter_rst,
			ctrl_width		=> ctrl_width,
			
			i_data_en		=> hb_data_en,
			i_data0			=> hb_data0,
			i_data1			=> hb_data1,
			
			o_data_en		=> dither_data_en,
			o_data0			=> dither_data0,
			o_data1			=> dither_data1,
			
			i_mac				=> hb_i_mac1,
			o_mac				=> hb_o_mac1
		);
	
	INST_RING_BUFFER : ring_buffer
		port map (
			clk				=> clk,
			rst				=> rst,
			
			buf_rdy			=> buf_rdy,
			buf_level		=> fifo_level,
			buf_ptr			=> fifo_ptr,
			
			fir_en			=> rbuf_en,
			fir_step			=> rbuf_step,
			fir_fin			=> filter_data_en,
			
			locked			=> locked,
			ratio				=> ratio_in,
			
			wr_en				=> i_sample_en_i,
			wr_data0			=> i_sample0,
			wr_data1			=> i_sample1,
			
			rd_data0			=> rbuf_data0,
			rd_data1			=> rbuf_data1
		);
	
	INST_MAC_MUX_HB : mac_mux_2
		port map (
			clk				=> clk,
			rst				=> filter_rst,
			sel				=> hb_mac_sel,
		
			i_mac0			=> hb_i_mac0,
			o_mac0			=> hb_o_mac0,
			
			i_mac1			=> hb_i_mac1,
			o_mac1			=> hb_o_mac1
		);
	
	INST_MAC_MUX_SRC : mac_mux_3
		port map (
			clk				=> clk,
			rst				=> filter_rst,
			sel				=> src_mac_sel,
		
			i_mac0			=> src_i_mac0,
			i_mac1			=> src_i_mac1,
			i_mac2			=> src_i_mac2,
			
			o_mac0			=> src_o_mac0,
			o_mac2			=> src_o_mac2
		);
		
	INST_DIV_MUX : div_mux
		port map (
			clk				=> clk,
			rst				=> rst,
			sel				=> div_sel,
			
			i0_en				=> div0_en,
			i0_divisor		=> div0_divisor,
			i0_dividend		=> div0_dividend,
			
			i1_en				=> div1_en,
			i1_divisor		=> div1_divisor,
			i1_dividend		=> div1_dividend,
			
			o_busy			=> div_busy,
			o_remainder		=> div_remainder
		);

end rtl;
