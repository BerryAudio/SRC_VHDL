library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity hb_filter_top is
		generic (
			ROM_FILE : string := ROM_FILE_HB
		);
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
			
			i_data_en0	: in  std_logic;
			i_data_en1	: in  std_logic;
			i_data0		: in  signed( 34 downto 0 );
			i_data1		: in  signed( 34 downto 0 );
			
			o_data_en	: out std_logic;
			o_data0		: out signed( 34 downto 0 ) := ( others => '0' );
			o_data1		: out signed( 34 downto 0 ) := ( others => '0' );
			
			o_mac			: in  mac_o;
			i_mac			: out mac_i := mac_i_init
		);
end hb_filter_top;

architecture rtl of hb_filter_top is
	type STATE_TYPE is ( S0_INIT, S1_MID, S1_MID_FIN, S2_FIR_INIT, S2_FIR, S2_FIR_FIN );
	signal state : STATE_TYPE := S0_INIT;
	
	constant MAC_NORM : signed( 34 downto 0 ) := ( 33 => '1', others => '0' );
	
	signal mac_en		: std_logic_vector( 1 downto 0 ) := ( others => '0' );
	signal mac_acc		: std_logic_vector( 1 downto 0 ) := ( others => '0' );
	signal mac_cmp		: std_logic_vector( 1 downto 0 ) := ( others => '0' );
	
	signal rom_addr	: unsigned( 5 downto 0 ) := ( others => '0' );
	signal rom_data	: signed( 34 downto 0 )  := ( others => '0' );
	
	signal rbuf_step	: std_logic := '0';
	signal rbuf_data0	: signed( 34 downto 0 ) := ( others => '0' );
	signal rbuf_data1	: signed( 34 downto 0 ) := ( others => '0' );
begin
	
	i_mac.en  <= mac_en ( 1 );
	i_mac.acc <= mac_acc( 1 );
	i_mac.cmp <= mac_cmp( 1 );
	
	-- RBUFFERed data
	i_mac.data00 <= rbuf_data0;
	i_mac.data10 <= rbuf_data1;
	
	-- FIR Coefficients
	i_mac.data01 <= rom_data;
	i_mac.data11 <= rom_data;
	
	state_process : process( clk )
	begin
		if rising_edge( clk ) then
			o_data_en <= '0';
			rbuf_step <= '0';
			
			mac_en  <= mac_en ( 0 ) & '0';
			mac_acc <= mac_acc( 0 ) & '0';
			mac_cmp <= mac_cmp( 0 ) & '0';
			
			if rst = '1' then
				o_data0 <= ( others => '0' );
				o_data1 <= ( others => '0' );
				
				mac_en  <= ( others => '0' );
				mac_acc <= ( others => '0' );
				mac_cmp <= ( others => '0' );
				
				rom_addr <= ( others => '0' );
			else
				case state is
					when S0_INIT =>
						rom_addr <= ( others => '0' );
						if i_data_en0 = '1' then
							state <= S1_MID;
							
						elsif i_data_en1 = '1' then
							state <= S2_FIR_INIT;
							
						end if;
					
					when S1_MID =>
						-- delay while waiting for RBUFFER to update output
						state <= S1_MID_FIN;
					
					when S1_MID_FIN =>
						o_data0 <= rbuf_data0;
						o_data1 <= rbuf_data1;
						o_data_en <= '1';
						
						state <= S0_INIT;
					
					when S2_FIR_INIT =>
						-- enqueue the mac enable
						mac_en ( 0 ) <= '1';
						
						-- start incrementing through the ring buffer
						rbuf_step <= '1';
						
						-- start incrementing through the rom
						rom_addr <= rom_addr + 1;
						
						-- next state
						state <= S2_FIR;
						
					when S2_FIR =>
						-- enqueue both enable and acc for accumulation
						mac_en ( 0 ) <= '1';
						mac_acc( 0 ) <= '1';
						
						-- keep incrementing through the rom
						rbuf_step <= '1';
						
						-- start incrementing through the rom
						rom_addr <= rom_addr + 1;
						
						-- if the rom address is maxed, next state
						-- fir is complete
						if rom_addr = 63 then
							mac_cmp( 0 ) <= '1';
							
							state <= S2_FIR_FIN;
							
						end if;
					
					when S2_FIR_FIN =>
						-- wait for the normalised mac result
						if o_mac.en = '1' then
							-- output data
							o_data_en <= '1';
							o_data0	 <= o_mac.data0( 67 downto 33 );
							o_data1	 <= o_mac.data1( 67 downto 33 );

							-- return to init
							state <= S0_INIT;
						end if;
						
				end case;
			end if;
		end if;
	end process state_process;
	
	INST_HB_ROM : hb_filter_rom
		generic map (
			ROM_FILE 	=> ROM_FILE
		)
		port map (
			clk			=> clk,
			
			addr			=> rom_addr,
			data			=> rom_data
		);

	INST_HB_RBUF : hb_ring_buffer
		port map (
			clk			=> clk,
			rst			=> rst,
		
			wr_en			=> i_data_en0,
			wr_data0		=> i_data0,
			wr_data1		=> i_data1,
			
			rd_en0		=> i_data_en0,
			rd_en1		=> i_data_en1,
			rd_step		=> rbuf_step,
			rd_data0		=> rbuf_data0,
			rd_data1		=> rbuf_data1
		);
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

library std;
use std.textio.all;

entity hb_filter_rom is
	generic (
		ROM_FILE : string := "rom/rom_hb_0.400_35b.txt"
	);
	port (
		clk	: in  std_logic;
		
		addr	: in  unsigned( 5 downto 0 );
		data	: out signed( 34 downto 0 ) := ( others => '0' )
	);
end hb_filter_rom;

architecture rtl of hb_filter_rom is
	type FIR_ROM_TYPE is array( 31 downto 0 ) of signed( 34 downto 0 );
	
	impure function FIR_ROM_INIT( rom_file_name : in string ) return FIR_ROM_TYPE is
		file rom_file		: text open read_mode is rom_file_name;
		variable rom_line	: line;
		variable temp_bv	: std_logic_vector( 35 downto 0 );
		variable temp_mem	: FIR_ROM_TYPE;
	begin
		for i in 0 to 31 loop
			readline( rom_file, rom_line );
			HREAD( rom_line, temp_bv );
			temp_mem( i ) := signed( temp_bv( 34 downto 0 ) );
		end loop;
		return temp_mem;
	end function FIR_ROM_INIT;
	
	function COMPLEMENT( val : unsigned ) return unsigned is
	begin
		return ( not( val ) + 1 );
	end function COMPLEMENT;
	
	signal rom : FIR_ROM_TYPE := FIR_ROM_INIT( ROM_FILE );
	signal trans_addr : unsigned( 5 downto 0 ) := ( others => '0' );
begin
	rom_process : process( clk )
	begin
		if rising_edge( clk ) then
			trans_addr <= addr;
			if addr > 31 then
				trans_addr <= ( 31 + COMPLEMENT( addr ) );
			end if;
			data <= rom( to_integer( trans_addr( 4 downto 0 ) ) );
		end if;
	end process rom_process;
	
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hb_ring_buffer is
	port (
		clk			: in  std_logic;
		rst			: in  std_logic;
	
		wr_en			: in  std_logic;
		wr_data0		: in  signed( 34 downto 0 );	
		wr_data1		: in  signed( 34 downto 0 );
		
		rd_en0		: in  std_logic;
		rd_en1		: in  std_logic;
		rd_step		: in  std_logic;
		rd_data0		: out signed( 34 downto 0 ) := ( others => '0' );
		rd_data1		: out signed( 34 downto 0 ) := ( others => '0' )
	);
end hb_ring_buffer;

architecture rtl of hb_ring_buffer is
	type RAM_TYPE is array ( 63 downto 0 ) of signed( 69 downto 0 );
	
	signal ring_buf : RAM_TYPE := ( others => ( others => '0' ) );
	signal wr_addr : unsigned( 5 downto 0 ) := ( others => '0' );
	signal rd_addr : unsigned( 5 downto 0 ) := ( others => '0' );
	
	signal wr_rdy	: std_logic := '0';
begin

	wr_process : process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				wr_rdy <= '0';
				wr_addr <= ( others => '0' );
			elsif wr_rdy = '0' then
				wr_addr <= wr_addr + 1;
				ring_buf( to_integer( wr_addr ) ) <= ( others => '0' );
				
				if wr_addr = 63 then
					wr_rdy <= '1';
				end if;
			elsif wr_en = '1' then
				-- ensure that wr_addr cannot refer to out of bounds
				wr_addr <= wr_addr + 1;
				
				-- write data to ring buffer
				ring_buf( to_integer( wr_addr ) ) <= wr_data1 & wr_data0;
			end if;
		end if;
	end process wr_process;
	
	rd_process : process( clk )
	begin
		if rising_edge( clk ) then
			if ( rst or not( wr_rdy ) ) = '1' then
				rd_data1 <= ( others => '0' );
				rd_data0 <= ( others => '0' );
				rd_addr <= ( others => '0' );
			else
				rd_data1 <= ring_buf( to_integer( rd_addr ) )( 69 downto 35 );
				rd_data0 <= ring_buf( to_integer( rd_addr ) )( 34 downto  0 );
				
				if rd_en0 = '1' then
					rd_addr <= wr_addr - 32;
				elsif rd_en1 = '1' then
					rd_addr <= wr_addr - 1;
				elsif rd_step = '1' then
					rd_addr <= rd_addr - 1;
				end if;
			end if;
		end if;
	end process rd_process;

end rtl;
