library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity regulator_top is
	generic (
		CLOCK_COUNT			: integer := 512;
		REG_FIFO_WIDTH		: integer range 4 to 11 := 11
	);
	port (
		clk					: in  std_logic;
		rst					: in  std_logic;
		
		-- input/output sample has arrived
		-- input from ring buffer
		-- let's us know how full the buffer is
		i_sample_en			: in  std_logic;
		o_sample_en			: in  std_logic;
		i_fifo_level		: in  unsigned( 10 downto 0 );
		
		-- ratio data - indicate that a ratio has been calculated
		-- locked status indicator
		o_ratio				: out unsigned( 23 downto 0 ) := ( others => '0' );
		o_locked				: out std_logic := '0';
		o_ratio_en			: out std_logic := '0';
		
		-- shared divider i/o
		div_busy				: in  std_logic;
		div_remainder		: in  unsigned( 24 downto 0 );
		
		div_en				: out std_logic := '0';
		div_divisor			: out unsigned( 26 downto 0 ) := ( others => '0' );
		div_dividend		: out unsigned( 26 downto 0 ) := to_unsigned( CLOCK_COUNT * 4, 27 )
		
	);
end regulator_top;

architecture rtl of regulator_top is
	type STATE_TYPE is ( S0_WAIT, S1_DIVIDE, S2_DIVIDE_WAIT, S3_AVERAGE, S4_RATIO );
	signal state			: STATE_TYPE := S0_WAIT;

	signal sample_en		: std_logic := '0';
	signal count_en		: std_logic := '0';
	signal count_ack		: std_logic := '0';
	signal count			: unsigned( 19 downto 0 ) := ( others => '0' );
	signal locked			: std_logic := '0';
	
	signal ptr_rst			: std_logic := '0';
	
	signal ratio			: unsigned( 23 downto 0 ) := ( others => '0' );
	signal ratio_en		: std_logic := '0';
	
	signal ratio_ave		: unsigned( 23 downto 0 ) := ( others => '0' );
	signal ratio_ave_en	: std_logic := '0';
	
	signal ratio_reg_in	: unsigned( 23 downto 0 ) := ( others => '0' );
	signal ratio_reg		: unsigned( 23 downto 0 ) := ( others => '0' );
	signal ratio_reg_en	: std_logic := '0';
begin
	o_locked <= locked;
	
	ptr_rst <= not locked;
	
	div_divisor <= RESIZE( count, div_divisor'length );
	
	state_process : process( clk )
	begin
		if rising_edge( clk ) then
			div_en <= '0';
			ratio_en <= '0';
			o_ratio <= ratio_reg;
			o_ratio_en <= ratio_reg_en;
			count_ack <= '0';
			
			if rst = '1' then
				state <= S0_WAIT;
				o_ratio_en <= '0';
			else
				case state is
					when S0_WAIT =>
						if o_sample_en = '1' then
							if count_en = '1' then
								count_ack <= '1';
								state <= S1_DIVIDE;
							else
								o_ratio_en <= '1';
							end if;
						end if;
					
					when S1_DIVIDE =>
						div_en <= not div_busy;
						if div_busy = '1' then
							state <= S2_DIVIDE_WAIT;
						end if;
					
					when S2_DIVIDE_WAIT =>
						ratio_en <= not div_busy;
						if div_busy = '0' then
							ratio_ave <= div_remainder( 23 downto 0 );
							state <= S3_AVERAGE;
						end if;
					
					when S3_AVERAGE =>
						if ratio_ave_en = '1' then
							state <= S4_RATIO;
						end if;
					
					when S4_RATIO =>
						if ratio_reg_en = '1' then
							state <= S0_WAIT;
						end if;
					
				end case;
			end if;
		end if;
	end process state_process;

	INST_COUNTER : reg_count
		port map (
			clk				=> clk,
			rst				=> rst,
			
			i_sample_en		=> i_sample_en,
			i_reg_ack		=> count_ack,
			o_reg				=> count,
			o_reg_en			=> count_en
		);
	
	INST_AVERAGE : reg_average
		generic map (
			REG_FIFO_WIDTH	=> REG_FIFO_WIDTH
		)
		port map (
			clk				=> clk,
			rst				=> rst,
			
			ptr_rst			=> ptr_rst,
			
			ratio				=> ratio_ave,
			ratio_en			=> ratio_en,
			
			ave_out			=> ratio_reg_in,
			ave_valid		=> ratio_ave_en
		);
	
	INST_RATIO : reg_ratio
		port map (
			clk				=> clk,
			rst				=> rst,
			
			i_fifo_level	=> i_fifo_level,
			i_ratio			=> ratio_reg_in,
			i_ratio_en		=> ratio_ave_en,
			o_sample_en		=> o_sample_en,
			
			o_locked			=> locked,
			o_ratio			=> ratio_reg,
			o_ratio_en		=> ratio_reg_en
		);
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity reg_ratio is
	port (
		clk				: in  std_logic;
		rst				: in  std_logic;
		
		i_fifo_level	: in  unsigned( 10 downto 0 ); -- 9.4
		i_ratio			: in  unsigned( 23 downto 0 ); -- 4.20
		i_ratio_en		: in  std_logic;
		o_sample_en		: in  std_logic;
		
		o_locked			: out std_logic := '0';
		o_ratio			: out unsigned( 23 downto 0 ) := ( others => '0' );
		o_ratio_en		: out std_logic := '0'
	);
end reg_ratio;

architecture rtl of reg_ratio is
	constant FIFO_SET_PT		: integer := 16;
	constant THRESHOLD_LOCK	: integer := 32;
	constant THRESHOLD_VARI	: integer := 96;
	
	signal ratio_buf		: unsigned( 23 downto 0 ) := ( others => '0' );
	signal err_term		: unsigned( 10 downto 0 ) := ( others => '0' );
	signal err_mag			: unsigned( 10 downto 0 ) := ( others => '0' );
	signal err_sign		: std_logic := '0';
	
	signal sum_vari		: unsigned( 23 downto 0 ) := ( others => '0' );
	signal sum_lock		: unsigned( 23 downto 0 ) := ( others => '0' );
	
	signal locked			: std_logic := '0';
	signal reg_ratio		: unsigned( 23 downto 0 ) := ( others => '0' );
	
	signal lock_en			: std_logic := '0';
	signal lock_en_buf	: std_logic_vector( 3 downto 0 ) := ( others => '0' );
	signal ratio_en_buf	: std_logic_vector( 5 downto 0 ) := ( others => '0' );
begin

	o_ratio  <= reg_ratio;
	o_locked <= locked;

	reg_ratio_process : process( clk )
	begin
		if rising_edge( clk ) then
			o_ratio_en <= ratio_en_buf( 5 );
			if rst = '1' then
				reg_ratio <= ( others => '0' );
				o_ratio_en <= '0';
			elsif ratio_en_buf( 5 ) = '1' then
				reg_ratio <= sum_vari;
				if locked = '1' then
					reg_ratio <= sum_lock;
				end if;
			end if;
		end if;
	end process reg_ratio_process;
	
	ratio_buf_process : process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				ratio_buf <= ( others => '0' );
				ratio_en_buf <= ( others => '0' );
			else
				ratio_en_buf <= ratio_en_buf( 4 downto 0 ) & i_ratio_en;
				
				if i_ratio_en = '1' then
					ratio_buf <= i_ratio;
				end if;
			end if;
		end if;
	end process ratio_buf_process;
	
	lock_process : process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				lock_en_buf <= ( others => '0' );
				lock_en <= '0';
				locked <= '0';
			else
				if err_mag < THRESHOLD_LOCK and ratio_buf >= 1024 then
					lock_en <= '1';
				elsif o_sample_en = '1' then
					lock_en <= '0';
				end if;
				
				if i_ratio_en = '1' then
					lock_en_buf <= lock_en_buf( 2 downto 0 ) & lock_en;
				end if;
				
				if err_mag > THRESHOLD_VARI then
					locked <= '0';
				elsif lock_en & lock_en_buf = "11111" then
					locked <= '1';
				end if;
			end if;
		end if;
	end process lock_process;
	
	-------------------------------------------------------------------------
	-- Error magnitude terms
	-------------------------------------------------------------------------
	err_term <= i_fifo_level - ( FIFO_SET_PT * 16 );
	
	err_mag_process : process( clk )
	begin
		if rising_edge( clk ) then
			err_sign <= err_term( err_term'length-1 );
			err_mag <= err_term;
			if err_term( err_term'length-1 ) = '1' then
				err_mag <= COMPLEMENT( err_term );
			end if;
		end if;
	end process err_mag_process;
	
	-------------------------------------------------------------------------
	-- Variable rate error calculations
	-------------------------------------------------------------------------
	VARI_ERROR_BLOCK : block
		constant VARI_DEADZONE : natural range 0 to 4 := 0;
		constant VARI_GAIN_LOG : natural range 0 to 4 := 0;
	
		signal vari_gain		: unsigned(  2 downto 0 ) := ( others => '0' );
		signal err_vari_tmp	: unsigned( 19 downto 0 ) := ( others => '0' );
		signal err_vari_mag	: unsigned( 19 downto 0 ) := ( others => '0' );
	begin
		
		vari_gain_process : process( err_mag )
			variable gate : std_logic;
		begin
			for i in 2 downto 0 loop
				gate := err_mag( err_mag'length-1 );
				for j in err_mag'length-2 downto i+3 loop
					gate := gate or err_mag( j );
				end loop;
				vari_gain( i ) <= gate;
			end loop;
		end process vari_gain_process;
		
		err_vari_tmp <= RESIZE( err_mag, err_vari_tmp'length ) sll ( to_integer( vari_gain ) + VARI_GAIN_LOG )
							 when ( err_mag > VARI_DEADZONE ) 
							 else ( others => '0' );
		
		clock_process : process( clk )
		begin
			if rising_edge( clk ) then
				err_vari_mag <= err_vari_tmp;
			end if;
		end process clock_process;
		
		sum_vari <= ( ratio_buf + err_vari_mag ) when err_sign = '1' 
						else ratio_buf - err_vari_mag;
		
	end block VARI_ERROR_BLOCK;
	
	-------------------------------------------------------------------------
	-- Locked rate error calculations
	-------------------------------------------------------------------------
	LOCK_ERROR_BLOCK : block
		constant LOCK_SLEW		: integer range 0 to 15 := 1;
		constant LOCK_DEADZONE	: integer range 0 to  4 := 2;
		
		signal err_slew	: unsigned( 3 downto 0 ) := ( others => '0' );
		signal err_buf		: unsigned( 10 downto 0 ) := ( others => '0' );
		alias  err_en		: std_logic is ratio_en_buf( 4 );
	begin
		
		clock_process : process( clk )
		begin
			if rising_edge( clk ) then
				
				-- *******************************************************
				-- ** 1st cycle after input sample
				-- ** - err_buf
				-- *******************************************************
				if ratio_en_buf( 1 ) = '1' then
					err_buf <= ( others => '0' );
					if err_mag > LOCK_DEADZONE then
						err_buf <= err_mag - LOCK_DEADZONE;
					end if;
				end if;
				
				-- *******************************************************
				-- ** 2nd cycle after input sample
				-- ** - err_slew
				-- *******************************************************
				if ratio_en_buf( 2 ) = '1' then
					err_slew <= err_buf( err_slew'range );
					if err_buf > LOCK_SLEW then
						err_slew <= to_unsigned( LOCK_SLEW, err_slew'length );
					end if;
				end if;
				
				-- *******************************************************
				-- ** 3rd cycle after input sample
				-- ** - err_inc
				-- ** - err_dec
				-- *******************************************************
				if ratio_en_buf( 3 ) = '1' then
					sum_lock <= reg_ratio;
					if err_slew /= 0 then
						if ( reg_ratio < ratio_buf ) then
							sum_lock <= reg_ratio + err_slew;
						elsif ( reg_ratio > ratio_buf ) then
							sum_lock <= reg_ratio - err_slew;
						end if;
					end if;
				end if;
			end if;
		end process clock_process;
		
	end block LOCK_ERROR_BLOCK;
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reg_average_fifo is
	generic (
		REG_FIFO_WIDTH	: integer range 4 to 11 := 11
	);
	port (
		clk			: in  std_logic;
		
		i_reg_ratio	: in  unsigned( 23 downto 0 );
		i_reg_en		: in  std_logic;
		
		o_reg_ratio	: out unsigned( 23 downto 0 ) := ( others => '0' )
	);
end reg_average_fifo;

architecture rtl of reg_average_fifo is
	type FIFO_TYPE is array( 2**REG_FIFO_WIDTH - 1 downto 0 ) of unsigned( 23 downto 0 );
	signal fifo	: FIFO_TYPE := ( others => ( others => '0' ) );
	
	signal addr_rd	: unsigned( REG_FIFO_WIDTH-1 downto 0 ) := ( others => '0' );
	signal addr_wr	: unsigned( REG_FIFO_WIDTH-1 downto 0 ) := ( others => '0' );
begin


	input_process : process( clk )
	begin
		if rising_edge( clk ) then
			if i_reg_en = '1' then
				addr_wr <= addr_rd; -- since write address is always 1 behind, just update with read address
				addr_rd <= addr_rd + 1; -- read address is always 1 ahead of write address
				fifo( to_integer( addr_wr ) ) <= i_reg_ratio;
			end if;
			
			o_reg_ratio <= fifo( to_integer( addr_rd ) );
		end if;
	end process input_process;

end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity reg_average is
	generic (
		REG_FIFO_WIDTH	: integer range 4 to 11 := 11
	);
	port (
		clk			: in  std_logic;
		rst			: in  std_logic;
		
		ptr_rst		: in  std_logic;
		
		ratio			: in  unsigned( 23 downto 0 );
		ratio_en		: in  std_logic;
		
		ave_out		: out unsigned( 23 downto 0 ) := ( others => '0' );
		ave_valid	: out std_logic := '0'
	);
end reg_average;

architecture rtl of reg_average is
	signal ptr_reset	: std_logic_vector( 1 downto 0 ) := ( others => '0' );
	
	signal sr_in			: unsigned( 23 downto 0 ) := ( others => '0' );
	signal sr_en			: std_logic := '0';
	
	signal sr_out			: unsigned( 23 downto 0 ) := ( others => '0' );
	alias  ratio_del		: unsigned( 23 downto 0 ) is sr_out( 23 downto 0 );
	
	signal preload			: std_logic := '0';
	signal preload_cnt	: unsigned( REG_FIFO_WIDTH-1 downto 0 ) := ( others => '0' );
	signal preload_out	: std_logic := '0';
	
	signal buf_ratio		: unsigned( 23 downto 0 ) := ( others => '0' );
	signal buf_ratio_en	: std_logic := '0';
	signal buf_ratio_en0	: std_logic := '0';
	
	signal moving_sum		: unsigned( 23+REG_FIFO_WIDTH downto 0 ) := ( others => '0' );
	signal moving_sum0	: unsigned( 23+REG_FIFO_WIDTH downto 0 ) := ( others => '0' );
begin

	ave_out <= moving_sum( 23+REG_FIFO_WIDTH downto REG_FIFO_WIDTH );
	
	sr_in <= buf_ratio;
	sr_en <= preload or buf_ratio_en;
	
	preload_out <= '1' when preload_cnt = ( ( 2**REG_FIFO_WIDTH ) - 1 ) else '0';

	ptr_reset_process : process( clk )
	begin
		if rising_edge( clk ) then
			ptr_reset <= ptr_reset( 0 ) & ptr_rst;
		end if;
	end process ptr_reset_process;
	
	prelaod_cnt_process : process( clk )
	begin
		if rising_edge( clk ) then
			if preload = '1' then
				preload_cnt <= preload_cnt + 1;
			end if;
		end if;
	end process prelaod_cnt_process;
	
	prelaod_process : process( clk )
	begin
		if rising_edge( clk ) then
			if ptr_reset( 1 ) = '1' then
				preload <= '1';
			elsif ( rst or preload_out ) = '1' then
				preload <= '0';
			end if;
		end if;
	end process prelaod_process;
	
	data_process : process( clk )
	begin
		if rising_edge( clk ) then
			buf_ratio_en <= ratio_en;
			buf_ratio_en0 <= buf_ratio_en;
			ave_valid <= buf_ratio_en0;
			if sr_en = '1' then
				buf_ratio <= ratio;
			end if;
		end if;
	end process data_process;
	
	moving_sum_process : process( clk )
	begin
		if rising_edge( clk ) then
			moving_sum <= moving_sum0;
			
			if buf_ratio_en = '1' then
				moving_sum0 <= moving_sum + buf_ratio - ratio_del;
			elsif preload = '1' then
				moving_sum0( 23+REG_FIFO_WIDTH downto REG_FIFO_WIDTH ) <= buf_ratio;
				moving_sum0( REG_FIFO_WIDTH-1 downto 0 ) <= ( others => '0' );
			end if;
		end if;
	end process moving_sum_process;
	
	INST_FIFO : reg_average_fifo
		generic map (
			REG_FIFO_WIDTH	=> REG_FIFO_WIDTH
		)
		port map (
			clk			=> clk,
			
			i_reg_ratio	=> sr_in,
			i_reg_en		=> sr_en,
			
			o_reg_ratio	=> sr_out
		);

end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity reg_count is
	port (
		clk			: in  std_logic;
		rst			: in  std_logic;
		
		--------------------------------------------------
		-- DATA Interfaces
		--------------------------------------------------
		i_sample_en	: in  std_logic;
		
		i_reg_ack	: in  std_logic;
		o_reg			: out unsigned( 19 downto 0 ) := ( others => '0' );
		o_reg_en		: out std_logic := '0'
	);
end reg_count;

architecture rtl of reg_count is
	signal clock_count	: unsigned( 19 downto 0 ) := ( 0 => '1', others => '0' );
	signal frame_buf		: unsigned( 19 downto 0 ) := ( others => '0' );
	signal frame_count	: unsigned(  1 downto 0 ) := ( others => '0' );
	signal frame_en		: std_logic := '0';
	signal state			: std_logic := '0';
begin

	o_reg <= frame_buf( 19 downto 0 );
	o_reg_en <= frame_en;

	count_process : process( clk )
	begin
		if rising_edge( clk ) then
			
			if i_reg_ack = '1' then
				frame_en  <= '0';
			end if;
			
			clock_count <= clock_count + 1;
			
			if i_sample_en = '1' and state = '1' then
				frame_count <= frame_count + 1;
				
				if frame_count = 3 then
					clock_count <= ( 0 => '1', others => '0' );
					frame_buf	<= clock_count;
					frame_en		<= '1';
				end if;
			end if;
		end if;
	end process count_process;
	
	state_process : process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				state <= '0';
			elsif i_sample_en = '1' then
				state <= '1';
			end if;
		end if;
	end process state_process;

end rtl;
