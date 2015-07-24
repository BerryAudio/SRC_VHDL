library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spdif_rx_top is
	port (
		clk			: in  std_logic;
		sel			: in  std_logic_vector( 1 downto 0 );
	
		i_data0		: in  std_logic;
		i_data1		: in  std_logic;
		i_data2		: in  std_logic;
		i_data3		: in  std_logic;
		
		o_data0		: out signed( 23 downto 0 ) := ( others => '0' );
		o_data1		: out signed( 23 downto 0 ) := ( others => '0' );
		o_data_en	: out std_logic := '0'
	);
end spdif_rx_top;

architecture rtl of spdif_rx_top is
	component spdif_rx is
		port (
			clk			: in  std_logic;
		
			i_data		: in  std_logic;
			
			o_data0		: out signed( 23 downto 0 );
			o_data1		: out signed( 23 downto 0 );
			o_data_en	: out std_logic
		);
	end component spdif_rx;

	signal buf_data0 : std_logic_vector( 1 downto 0 ) := ( others => '0' );
	signal buf_data1 : std_logic_vector( 1 downto 0 ) := ( others => '0' );
	signal buf_data2 : std_logic_vector( 1 downto 0 ) := ( others => '0' );
	signal buf_data3 : std_logic_vector( 1 downto 0 ) := ( others => '0' );
	signal buf_data  : std_logic := '0';	
begin
	
	INST_SPDIF_RX : spdif_rx
		port map (
			clk			=> clk,
			i_data		=> buf_data,
			o_data0		=> o_data0,
			o_data1		=> o_data1,
			o_data_en	=> o_data_en
		);

	buf_process : process( clk )
	begin
		if rising_edge( clk ) then
			buf_data0 <= buf_data0( 0 ) & i_data0;
			buf_data1 <= buf_data1( 0 ) & i_data1;
			buf_data2 <= buf_data2( 0 ) & i_data2;
			buf_data3 <= buf_data3( 0 ) & i_data3;
			
			case sel is
				when "11"	=> buf_data <= buf_data3( 1 );
				when "10"	=> buf_data <= buf_data2( 1 );
				when "01"	=> buf_data <= buf_data1( 1 );
				when others	=> buf_data <= buf_data0( 1 );
			end case;
		end if;
	end process buf_process;
	
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spdif_rx is
	port (
		clk			: in  std_logic;
	
		i_data		: in  std_logic;
		
		o_data0		: out signed( 23 downto 0 ) := ( others => '0' );
		o_data1		: out signed( 23 downto 0 ) := ( others => '0' );
		o_data_en	: out std_logic := '0'
	);
end spdif_rx;

architecture rtl of spdif_rx is
	constant X				: unsigned(  7 downto 0 ) := "11100010";
	constant Y				: unsigned(  7 downto 0 ) := "11100100";
	constant Z				: unsigned(  7 downto 0 ) := "11101000";
	signal x_match			: std_logic := '0';
	signal y_match			: std_logic := '0';
	
	signal buf_data		: std_logic := '0';
	signal buf_edge		: std_logic := '0';
	
	signal p_width_l		: std_logic := '0';
	signal p_width_s		: std_logic := '0';
	signal p_width_cnt	: unsigned(  9 downto 0 ) := ( others => '0' );
	signal p_width_comp	: unsigned(  9 downto 0 ) := ( others => '0' );
	signal p_width_en		: std_logic := '0';
	signal p_width			: unsigned(  9 downto 0 ) := ( others => '0' );
	
	signal b_width			: unsigned(  9 downto 0 ) := ( others => '0' );
	signal b_width_1p5	: unsigned( 10 downto 0 ) := ( others => '0' );
	signal b_width_2p5	: unsigned( 11 downto 0 ) := ( others => '0' );
	signal b_num			: unsigned(  5 downto 0 ) := ( others => '0' );
	signal b_load			: std_logic := '0';
	signal b_new			: std_logic := '0';
	signal b_new_buf		: std_logic := '0';
	signal b_good			: std_logic := '0';
	signal b_updown		: std_logic := '0';
	signal b_detect		: std_logic := '0';
	
	signal parity			: std_logic := '0';
	signal pre				: unsigned(  7 downto 0 ) := ( others => '0' );
	signal pre_shift		: unsigned(  1 downto 0 ) := ( others => '0' );
	signal pre_shift_en	: std_logic := '0';
	signal pre_sync_en	: std_logic := '0';
	signal pre_sync		: std_logic := '0';
	signal pre_detect		: std_logic := '0';
	signal trig_viol		: std_logic := '0';
	signal chan_sel		: std_logic := '0';
	signal n_dat_shift	: std_logic := '0';
	signal o_load			: std_logic := '0';
	signal o_load_buf		: std_logic := '0';
	
	signal frame			: signed( 27 downto 0 ) := ( others => '0' );
begin

	trig_viol <= '1' when ( "0" & p_width & "0" ) > b_width_2p5 else '0';
	b_new		 <= '1' when (       p_width & "0" ) < b_width_1p5 else '0';

	buffer_process : process( clk )
	begin
		if rising_edge( clk ) then
			buf_data <= i_data;
			buf_edge <= i_data xor buf_data;
			p_width_en <= buf_edge;
		end if;
	end process buffer_process;
	
	width_cnt_process : process( clk )
	begin
		if rising_edge( clk ) then
			p_width_cnt <= p_width_cnt + 2;
			if buf_edge = '1' then
				p_width_cnt <= ( 1 => '1', others => '0' );
				p_width <= p_width_cnt;
			end if;
		end if;
	end process width_cnt_process;
	
	width_ref_process : process( clk )
	begin
		if rising_edge( clk ) then
			p_width_s <= '0';
			if ( b_width( 9 downto 1 ) > p_width ) then
				p_width_s <= '1';
			end if;
			
			p_width_l <= '0';
			if ( p_width( 9 downto 2 ) > b_width ) then
				p_width_l <= '1';
			end if;
			
			b_load <= p_width_s or p_width_l;
		end if;
	end process width_ref_process;
	
	width_comp_process : process( clk )
	begin
		if rising_edge( clk ) then
			p_width_comp <= "0" & p_width( 9 downto 1 );
			if b_new = '1' then
				p_width_comp <= p_width;
			end if;
		end if;
	end process width_comp_process;
	
	bit_width_process : process( clk )
	begin
		if rising_edge( clk ) then
			b_good <= '0';
			b_updown <= '0';
			if p_width_comp = b_width then
				b_good <= '1';
			elsif p_width_comp > b_width then
				b_updown <= '1';
			end if;
			
			if b_load = '1' then
				b_width <= p_width;
			elsif ( b_good = '0' ) and ( p_width_en = '1' ) then
				b_width <= b_width - 1;
				if b_updown = '1' then
					b_width <= b_width + 1;
				end if;
			end if;
		end if;
	end process bit_width_process;

	preamble_process : process( clk )
	begin
		if rising_edge( clk ) then
			b_width_1p5 <= ( b_width &  "0" ) + ( "0"  & b_width );
			b_width_2p5 <= ( b_width & "00" ) + ( "00" & b_width );
			
			pre_sync_en <= '0';
			if ( b_num = 0 ) and ( buf_edge = '1' ) then
				pre_sync_en <= '1';
			end if;
			
			pre_sync <= '0';
			if  ( pre_sync_en and trig_viol ) = '1' then
				pre_sync <= '1';
			end if;
			
			if pre_sync = '1' then
				pre_detect <= '1';
			elsif ( pre_detect and p_width_en ) = '1' then
				pre_detect <= '0';
			end if;
			
			pre_shift_en <= '0';
			pre_shift <= "01";
			if b_num < 3 and p_width_en = '1' then
				pre_shift_en <= '1';
				if trig_viol = '1' then
					pre_shift <= "11";
				elsif b_new = '0' then
					pre_shift <= "10";
				end if;
			end if;
			
			if pre_shift_en = '1' then
				pre <= pre sll to_integer( pre_shift );
				pre( to_integer( pre_shift - 1 ) downto 0 ) <= ( others => not( pre( 0 ) ) );
			end if;
		end if;
	end process preamble_process;
	
	bit_process : process( clk )
	begin
		if rising_edge( clk ) then
			b_new_buf <= b_new;
			
			if b_new_buf = '0' then
				b_detect <= '0';
			elsif ( b_new and buf_edge ) = '1' then
				b_detect <= not b_detect;
			end if;
			
			n_dat_shift <= p_width_en and ( not( b_new ) or b_detect );
			if n_dat_shift = '1' then
				frame <= b_new & frame( 27 downto 1 );
			end if;
		end if;
	end process bit_process;
	
	match_process : process( clk )
	begin
		if rising_edge( clk ) then
			x_match <= '0';
			y_match <= '0';
			
			if pre = X or pre = not( X ) or pre = Z or pre = not( Z ) then
				x_match <= '1';
			end if;
					
			if pre = Y or pre = not( Y ) then
				y_match <= '1';
			end if;
		end if;
	end process match_process;
	
	output_process : process( clk )
	begin
		if rising_edge( clk ) then
			o_load <= '0';
			o_load_buf <= o_load;
			if b_num = 31 then
				o_load <= '1';
			end if;
			
			if o_load = '1' then
				b_num <= to_unsigned( 0, b_num'length );
			elsif pre_sync = '1' then
				b_num <= to_unsigned( 1, b_num'length );
			elsif ( n_dat_shift = '1' ) and b_num /= 0 then
				b_num <= b_num + 1;
			end if;
			
			o_data_en <= '0';
			if ( o_load and not( o_load_buf ) ) = '1' then
				if    x_match = '1' then
					o_data0 <= frame( 23 downto 0 );
				elsif y_match = '1' then
					o_data1 <= frame( 23 downto 0 );
					o_data_en <= '1';
				end if;
			end if;
		end if;
	end process output_process;
	
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spdif_tx_top is
	port ( 
		clk			: in  std_logic;
		rst			: in  std_logic;
		clk_cnt		: in  std_logic;
		
		i_data0		: in  signed( 23 downto 0 );
		i_data1		: in  signed( 23 downto 0 );
		i_data_en	: in  std_logic;
		
		o_spdif		: out std_logic := '0'
	);
end spdif_tx_top;

architecture rtl of spdif_tx_top is
	signal load			: std_logic := '0';
	signal o_buf		: std_logic := '0';

	signal buf_sample_0	: signed( 23 downto 0 ) := ( others => '0' );
	signal buf_sample_1	: signed( 23 downto 0 ) := ( others => '0' );
	signal buf_sample		: signed( 23 downto 0 ) := ( others => '0' );
	signal shift_sample	: signed( 63 downto 0 ) := ( others => '0' );

	signal bit_en		: std_logic := '0';
	signal smp_cnt		: unsigned( 1 downto 0 ) := ( others => '0' );
	
	signal frm_cnt		: unsigned( 14 downto 0 ) := ( others => '0' );
	alias  frm_num		: unsigned(  7 downto 0 ) is frm_cnt( 14 downto 7 );
	alias  frm_sub 	: std_logic is frm_cnt( 6 );
	alias  frm_bit 	: unsigned(  5 downto 0 ) is frm_cnt(  5 downto 0 );
	
	signal preamble	: signed( 7 downto 0 ) := ( others => '0' );
	constant PRE_B		: signed( 7 downto 0 ) := "00111001";
	constant PRE_M		: signed( 7 downto 0 ) := "11001001";
	constant PRE_W		: signed( 7 downto 0 ) := "01101001";
	
	function PARITY( i : signed ) return std_logic is
		variable parity_bit : std_logic;
	begin
		parity_bit := '0';
		for j in i'range loop
			parity_bit := parity_bit xor i( j );
		end loop;
		return parity_bit;
	end function PARITY;
begin
	
	o_spdif <= o_buf;
	
	preamble <= PRE_B when frm_cnt =  0  else
					PRE_M when frm_sub = '0' else
					PRE_W;
	
	load <= '1' when frm_bit = "000000" and bit_en = '1' else '0';
	
	buf_sample <= buf_sample_0 when frm_sub = '0' else buf_sample_1;
	
	--**************************************************************
	--* output process
	--**************************************************************
	output_process : process( clk )
	begin
		if rising_edge( clk ) then
			if bit_en = '1' then
				o_buf <= o_buf xor shift_sample( 0 ) xor '0';
			end if;
		end if;
	end process output_process;
	
	--**************************************************************
	--* input buffer process
	--**************************************************************
	buffer_process : process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				buf_sample_0 <= ( others => '0' );
				buf_sample_1 <= ( others => '0' );
			elsif i_data_en = '1' then
				smp_cnt <= smp_cnt + 1;
				if smp_cnt = 0 then
					buf_sample_0 <= i_data0;
					buf_sample_1 <= i_data1;
				end if;
			end if;
		end if;
	end process buffer_process;
	
	sample_shift_process : process( clk )
	begin
		if rising_edge( clk ) then
			if load = '1' then
				shift_sample <= PARITY( buf_sample & "000" ) & "1010101" &
						buf_sample( 23 ) & '1' & buf_sample( 22 ) & '1' & buf_sample( 21 ) & '1' & buf_sample( 20 ) & '1' & 
						buf_sample( 19 ) & '1' & buf_sample( 18 ) & '1' & buf_sample( 17 ) & '1' & buf_sample( 16 ) & '1' & 
						buf_sample( 15 ) & '1' & buf_sample( 14 ) & '1' & buf_sample( 13 ) & '1' & buf_sample( 12 ) & '1' & 
						buf_sample( 11 ) & '1' & buf_sample( 10 ) & '1' & buf_sample(  9 ) & '1' & buf_sample(  8 ) & '1' & 
						buf_sample(  7 ) & '1' & buf_sample(  6 ) & '1' & buf_sample(  5 ) & '1' & buf_sample(  4 ) & '1' & 
						buf_sample(  3 ) & '1' & buf_sample(  2 ) & '1' & buf_sample(  1 ) & '1' & buf_sample(  0 ) & '1' & 
						preamble;
			elsif bit_en = '1' then
				shift_sample <= '0' & shift_sample( 63 downto 1 );
			end if;
		end if;
	end process sample_shift_process;
	
	--**************************************************************
	--* Frame Counter
	--*	- counts bit_ens
	--**************************************************************
	frm_cnt_process : process( clk )
	begin
		if rising_edge( clk ) then
			if bit_en = '1' then
				frm_cnt <= frm_cnt + 1;
				if frm_num = x"C0" & "1111111" then
					frm_cnt <= ( others => '0' );
				end if;
			end if;
		end if;
	end process frm_cnt_process;
	
	--**************************************************************
	--* Bit Enable
	--*	- strobe on a bit clock edge
	--*	- this handles preamble and data
	--**************************************************************
	bit_en <= clk_cnt;
	
end rtl;
