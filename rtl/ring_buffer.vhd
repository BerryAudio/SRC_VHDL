library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity ring_buffer is
	generic (
		PTR_OFFSET : natural range 0 to 32 := 16
	);
	port (
		clk			: in  std_logic;
		rst			: in  std_logic;
		
		--------------------------------------------------
		-- Ring Buffer Control
		--------------------------------------------------
		buf_rdy		: out std_logic := '0';
		buf_level	: out unsigned( 14 downto 0 ) := ( others => '0' );
		buf_ptr		: out unsigned( 27 downto 0 ) := ( others => '0' );
		
		fir_en		: in  std_logic;
		fir_step		: in  std_logic;
		fir_fin		: in  std_logic;
		
		locked		: in  std_logic;
		ratio			: in  unsigned( 29 downto 0 );
		
		--------------------------------------------------
		-- Ring Buffer Data
		--------------------------------------------------
		wr_en			: in  std_logic;
		wr_data0		: in  signed( 23 downto 0 );	
		wr_data1		: in  signed( 23 downto 0 );
		
		rd_data0		: out signed( 23 downto 0 ) := ( others => '0' );
		rd_data1		: out signed( 23 downto 0 ) := ( others => '0' )
	);
end ring_buffer;

architecture rtl of ring_buffer is
	type RAM_TYPE is array ( 127 downto 0 ) of unsigned( 47 downto 0 );
	signal ram : ram_type := ( others => ( others => '0' ) );
	signal ram_data	: unsigned( 47 downto 0 ) := ( others => '0' );
	
	signal wr_state	: std_logic := '0';
	signal wr_ptr		: unsigned(  6 downto 0 ) := ( others => '0' );
	
	signal rd_ptr		: unsigned( 36 downto 0 ) := ( others => '0' );
	signal rd_ptr_it	: unsigned(  6 downto 0 ) := ( others => '0' );
	
	signal buf_data0	: signed( 23 downto 0 ) := ( others => '0' );
	signal buf_data1	: signed( 23 downto 0 ) := ( others => '0' );
	
	signal ptr_level	: unsigned( 14 downto 0 ) := ( others => '0' );
	signal lock_buf	: std_logic := '0';
	signal lock_stb	: std_logic := '0';
begin
	
	buf_ptr   <= rd_ptr( 29 downto 2 );
	buf_level <= ptr_level;
	lock_stb  <= ( lock_buf and not( locked ) ) or rst;
	
	write_process : process( clk )
	begin
		if rising_edge( clk ) then
			lock_buf <= locked;
			buf_rdy <= '1';
			if lock_stb = '1' then
				wr_ptr <= ( others => '0' );
				buf_rdy <= '0';
				wr_state <= '0';
			else
				if wr_state = '0' then
					buf_rdy <= '0';
					wr_ptr <= wr_ptr + 1;
					ram( to_integer( wr_ptr ) ) <= ( others => '0' );
					if wr_ptr = 127 then
						wr_state <= '1';
					end if;
				elsif wr_en = '1' then
					buf_rdy <= '1';
					wr_ptr <= wr_ptr + 1;
					ram( to_integer( wr_ptr ) ) <= unsigned( wr_data1 ) & unsigned( wr_data0 );
				end if;
			end if;
		end if;
	end process write_process;
	
	read_process : process( clk )
	begin
		if rising_edge( clk ) then
			ram_data <= ram( to_integer( rd_ptr_it ) );
			
			rd_data0  <= signed( ram_data( 23 downto  0 ) );
			rd_data1  <= signed( ram_data( 47 downto 24 ) );
			
			if rst = '1' then
				ptr_level <= ( others => '0' );
				ram_data <= ( others => '0' );
			else
				-- buffer level
				if locked = '0' or fir_en = '1' then
					ptr_level <= ( wr_ptr & x"00" ) - rd_ptr( 36 downto 22 );
				end if;
				
				-- iterator
				if fir_en = '1' then
					rd_ptr_it <= rd_ptr( 36 downto 30 );
				elsif fir_step = '1' then
					rd_ptr_it <= rd_ptr_it - 1;
				end if;
				
				-- read pointer - a minor guard band
				if locked = '0' then
						rd_ptr( 36 downto 30 ) <= wr_ptr - PTR_OFFSET;
						rd_ptr( 29 downto  0 ) <= ( others => '0' );
				elsif fir_fin = '1' then
					rd_ptr <= rd_ptr + ratio;
				end if;
			end if;
		end if;
	end process read_process;
	
end rtl;
