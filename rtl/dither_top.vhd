library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity dither_top is
	generic (
		LFSR_WIDTH	: integer range 11 to 34 := 12;
		FILT_WIDTH	: integer range 11 to 34 := 34
	);
	port (
		clk			: in  std_logic;
		rst			: in  std_logic;
		ctrl_width	: in  std_logic_vector( 1 downto 0 );
		
		i_data_en	: in  std_logic;
		i_data0		: in  signed( 34 downto 0 );
		i_data1		: in  signed( 34 downto 0 );
		
		o_data_en	: out std_logic := '0';
		o_data0		: out signed( 23 downto 0 ) := ( others => '0' );
		o_data1		: out signed( 23 downto 0 ) := ( others => '0' );
		
		i_mac			: out mac_i := mac_i_init;
		o_mac			: in  mac_o
	);
end dither_top;

architecture rtl of dither_top is
	component lfsr_top is
		generic (
			LFSR_WIDTH	: integer := LFSR_WIDTH
		);
		port (
			clk			: in  std_logic;
			
			i_data_en	: in  std_logic;
			
			lfsr0			: out signed( LFSR_WIDTH-1 downto 0 );
			lfsr1			: out signed( LFSR_WIDTH-1 downto 0 )
		);
	end component lfsr_top;

	component noise_filter_top is
		generic (
			FILT_WIDTH	: integer := FILT_WIDTH
		);
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
			
			i_noise_en	: in  std_logic;
			i_noise0		: in  signed( FILT_WIDTH-1 downto 0 );
			i_noise1		: in  signed( FILT_WIDTH-1 downto 0 );
			
			o_noise_en	: out std_logic;
			o_noise0		: out signed( FILT_WIDTH-1 downto 0 );
			o_noise1		: out signed( FILT_WIDTH-1 downto 0 );
			
			i_mac			: out mac_i;
			o_mac			: in  mac_o
		);
	end component noise_filter_top;
	
	function CLIP( val : signed ) return   signed is
		variable tmp	: signed( val'range );
	begin
		tmp := val;
		if ( tmp( 34 ) xor tmp( 33 ) ) = '1' then
			if tmp( 34 ) = '0' then
				tmp := ( 34 downto 33 => '0', others => '1' );
			else
				tmp := ( 34 downto 33 => '1', others => '0' );
			end if;
		end if;
		return tmp( 33 downto 10 );
	end function CLIP;
	
	-- en buffer
	signal buf_en	: std_logic_vector( 1 downto 0 ) := ( others => '0' );
	
	-- shift input data some number of bits
	signal sll_cnt	: unsigned( 2 downto 0 ) := ( others => '0' );
	signal sll_q0	: signed( 34 downto 0 ) := ( others => '0' );
	signal sll_q1	: signed( 34 downto 0 ) := ( others => '0' );
	
	-- noise filter i/o
	signal ni0		: signed( FILT_WIDTH-1 downto 0 ) := ( others => '0' );
	signal ni1		: signed( FILT_WIDTH-1 downto 0 ) := ( others => '0' );
	signal no0		: signed( FILT_WIDTH-1 downto 0 ) := ( others => '0' );
	signal no1		: signed( FILT_WIDTH-1 downto 0 ) := ( others => '0' );
	signal no_en	: std_logic := '0';
	
	-- error calculation
	signal e0		: signed( 34 downto 0 ) := ( others => '0' );
	signal e1		: signed( 34 downto 0 ) := ( others => '0' );
	
	-- dither output
	signal d0		: signed( LFSR_WIDTH-1 downto 0 ) := ( others => '0' );
	signal d1		: signed( LFSR_WIDTH-1 downto 0 ) := ( others => '0' );
	
	-- quantiser i/o
	signal q0		: signed( 34 downto 0 ) := ( others => '0' );
	signal q1		: signed( 34 downto 0 ) := ( others => '0' );
begin
	
	o_data_en <= no_en;
	
	sll_q0 <= shift_left( q0, to_integer( sll_cnt & '0' ) );
	sll_q1 <= shift_left( q1, to_integer( sll_cnt & '0' ) );
	
	sll_process : process( ctrl_width, i_data0, i_data1 )
	begin
		case ctrl_width is
			when "11"   => sll_cnt <= o"4";
			when "10"   => sll_cnt <= o"3";
			when "01"   => sll_cnt <= o"2";
			when others => sll_cnt <= o"0";
		end case;
	end process sll_process;
	
	clock_process : process( clk )
		variable tmp_q0, tmp_q1 : signed( 34 downto 0 );
	begin
		if rising_edge( clk ) then
			buf_en <= buf_en( 0 ) & i_data_en;
			
			if i_data_en = '1' then
				e0 <= i_data0 - no0;
				e1 <= i_data1 - no1;
			end if;
			
			if buf_en( 0 ) = '1' then
				q0 <= e0 + d0;
				q1 <= e1 + d1;
			end if;
			
			if buf_en( 1 ) = '1' then
				ni0 <= q0( FILT_WIDTH-1 downto 10 ) & b"00_0000_0000" - e0( FILT_WIDTH-1 downto 0 );
				ni1 <= q1( FILT_WIDTH-1 downto 10 ) & b"00_0000_0000" - e1( FILT_WIDTH-1 downto 0 );
				
				-- bit width manipulation for full scale output
				o_data0 <= CLIP( sll_q0 );
				o_data1 <= CLIP( sll_q1 );
			end if;
		end if;
	end process clock_process;
	
	INST_LFSR : lfsr_top
		port map (
			clk			=> clk,
			
			i_data_en	=> buf_en( 0 ),
			lfsr0			=> d0,
			lfsr1			=> d1
		);
	
	INST_NOISE : noise_filter_top
		port map (
			clk			=> clk,
			rst			=> rst,
			
			i_noise_en	=> buf_en( 1 ),
			i_noise0		=> ni0( FILT_WIDTH-1 downto 0 ),
			i_noise1		=> ni1( FILT_WIDTH-1 downto 0 ),
			
			o_noise_en	=> no_en,
			o_noise0		=> no0,
			o_noise1		=> no1,
			
			i_mac			=> i_mac,
			o_mac			=> o_mac
		);
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity noise_filter_top is
	generic (
		FILT_WIDTH	: integer := 16
	);
	port (
		clk			: in  std_logic;
		rst			: in  std_logic;
		
		i_noise_en	: in  std_logic;
		i_noise0		: in  signed( FILT_WIDTH-1 downto 0 );
		i_noise1		: in  signed( FILT_WIDTH-1 downto 0 );
		
		o_noise_en	: out std_logic := '0';
		o_noise0		: out signed( FILT_WIDTH-1 downto 0 ) := ( others => '0' );
		o_noise1		: out signed( FILT_WIDTH-1 downto 0 ) := ( others => '0' );
		
		i_mac			: out mac_i := mac_i_init;
		o_mac			: in  mac_o
	);
end noise_filter_top;

architecture rtl of noise_filter_top is
	type STATE_TYPE is ( S0_WAIT, S1_DF2A, S1_DF2A_FIN, S2_DF2B, S2_DF2B_FIN );
	signal state	: STATE_TYPE := S0_WAIT;
	
	type FILTER_TYPE is array( 3 downto 0 ) of signed( 23 downto 0 );
	
	constant INIT_B : FILTER_TYPE := ( x"645c02", x"49f3ee", x"3f9ec2", x"01bc8c" );
	constant INIT_A : FILTER_TYPE := ( x"abfdb4", x"a3b250", x"cfe25b", x"f61358" );
	
	signal b		: FILTER_TYPE := INIT_B;
	signal a		: FILTER_TYPE := INIT_A;
	
	type NOISE_TYPE  is array( 3 downto 0 ) of signed( FILT_WIDTH-1 downto 0 );
	signal n0			: NOISE_TYPE := ( others => ( others => '0' ) );
	signal n1			: NOISE_TYPE := ( others => ( others => '0' ) );
	signal n				: std_logic_vector( 3 downto 0 ) := x"1";
	
	constant N_HI		: integer := 23 + FILT_WIDTH - 1;
	constant N_LO		: integer := 23;
	
	signal mac_data1	: signed( 34 downto 0 ) := ( others => '0' );
begin

	i_mac.en		 <= not n( 3 ) when state = S1_DF2A or state = S2_DF2B else '0';
	i_mac.acc	 <= not n( 0 ) when state = S1_DF2A or state = S2_DF2B else '0';
	i_mac.cmp	 <=     n( 3 ) when state = S1_DF2A or state = S2_DF2B else '0';
	
	i_mac.data00 <= RESIZE( n0( 3 ), 35 );
	i_mac.data10 <= RESIZE( n1( 3 ), 35 );
	
	mac_data1	 <= RESIZE( a ( 3 ), 35 ) when state = S1_DF2A else
						 RESIZE( b ( 3 ), 35 );
	i_mac.data01 <= mac_data1;
	i_mac.data11 <= mac_data1;
	
	state_process : process( clk )
	begin
		if rising_edge( clk ) then
			o_noise_en <= '0';
			if rst = '1' then
				state <= S0_WAIT;
			else
				case state is
					when S0_WAIT =>
						if i_noise_en = '1' then
							state <= S1_DF2A;
						end if;
						
					when S1_DF2A =>
						if n( 3 ) = '1' then
							state <= S1_DF2A_FIN;
						end if;
					
					when S1_DF2A_FIN =>
						if o_mac.en = '1' then
							state <= S2_DF2B;
						end if;
					
					when S2_DF2B =>
						if n( 3 ) = '1' then
							state <= S2_DF2B_FIN;
						end if;
						
					when S2_DF2B_FIN =>
						if o_mac.en = '1' then
							o_noise0 <= o_mac.data0( N_HI downto N_LO );
							o_noise1 <= o_mac.data1( N_HI downto N_LO );
							o_noise_en <= '1';
							state <= S0_WAIT;
						end if;
						
				end case;
			end if;
		end if;
	end process state_process;
	
	sr_process : process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				n0 <= ( others => ( others => '0' ) );
				n1 <= ( others => ( others => '0' ) );
				b	<= INIT_B;
				a	<= INIT_A;
				n	<= x"1";
			else
				if state = S1_DF2A_FIN and o_mac.en = '1' then
					n0 <= ( o_mac.data0( N_HI downto N_LO ) + i_noise0 ) & n0( 3 downto 1 );
					n1 <= ( o_mac.data1( N_HI downto N_LO ) + i_noise1 ) & n1( 3 downto 1 );
				elsif state = S1_DF2A or state = S2_DF2B then
					n0 <= n0( 2 downto 0 ) & n0( 3 );
					n1 <= n1( 2 downto 0 ) & n1( 3 );
					a  <= a ( 2 downto 0 ) & a ( 3 );
					b  <= b ( 2 downto 0 ) & b ( 3 );
					n  <= n ( 2 downto 0 ) & n ( 3 );
				end if;
			end if;
		end if;
	end process sr_process;
	
end rtl;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity lfsr_top is
	generic (
		LFSR_WIDTH	: integer := 12
	);
	port (
		clk			: in  std_logic;
		
		i_data_en	: in  std_logic;
		
		lfsr0			: out signed( LFSR_WIDTH-1 downto 0 ) := ( others => '0' );
		lfsr1			: out signed( LFSR_WIDTH-1 downto 0 ) := ( others => '0' )
	);
end lfsr_top;

architecture rtl of lfsr_top is
	type TYPE_TAP is array( 3 downto 0 ) of integer range 0 to 95;
	constant lfsr_taps	: TYPE_TAP := ( 95, 93, 48, 46 );
	
	signal lfsr			: signed( 95 downto 0 ) := ( others => '0' );
	
	signal gen_lfsr0	: signed( LFSR_WIDTH-1 downto 0 ) := ( others => '0' );
	signal gen_lfsr1	: signed( LFSR_WIDTH-1 downto 0 ) := ( others => '0' );
	
	signal feedback	: std_logic := '0';
	
	attribute register_balancing: string;
	attribute register_balancing of lfsr: signal is "no";
begin

	lfsr0 <= gen_lfsr0;
	lfsr1 <= gen_lfsr1;
	
	feedback_process : process( lfsr )
		variable gate : std_logic;
	begin
		gate := '0';
		for i in lfsr_taps'range loop
			gate := gate xor lfsr( lfsr_taps( i ) );
		end loop;
		feedback <= not gate;
	end process feedback_process;
	
	lfsr_process : process( clk )
	begin
		if rising_edge( clk ) then
			lfsr <= lfsr( lfsr'length-2 downto 0 ) & feedback;
			if i_data_en = '1' then
				gen_lfsr0 <= lfsr( 95 downto 96-LFSR_WIDTH ) + lfsr( 72 downto 73-LFSR_WIDTH );
				gen_lfsr1 <= lfsr( 47 downto 48-LFSR_WIDTH ) + lfsr( 23 downto 24-LFSR_WIDTH );
			end if;
		end if;
	end process lfsr_process;
	
end rtl;
