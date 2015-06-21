library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.audio.all;

entity outputs_top is
	generic (
		DAC_IF		: string := "PCM1794"
	);
	port (
		clk_src		: in  std_logic;
		clk_out		: in  std_logic;
		rst			: in  std_logic;
		
		-- 147 MHz clock
		i_data0		: in  signed( 23 downto 0 );
		i_data1		: in  signed( 23 downto 0 );
		i_data_en	: in  std_logic;
		
		o_sample_en	: out std_logic := '0';
		
		-- 196 MHz clock
		o_i2s_lrck	: out std_logic := '0';
		o_i2s_bclk	: out std_logic := '0';
		o_i2s_data0	: out std_logic := '0';
		o_i2s_data1	: out std_logic := '0';
		
		o_spdif		: out std_logic := '0'
	);
end outputs_top;

architecture rtl of outputs_top is

	signal clk_cnt_wr		: unsigned( 7 downto 0 ) := ( others => '0' );
	signal clk_cnt_rd		: unsigned( 6 downto 0 ) := ( others => '0' );
	
	signal fifo_out0		: signed( 23 downto 0 ) := ( others => '0' );
	signal fifo_out1		: signed( 23 downto 0 ) := ( others => '0' );
	signal fifo_ext0		: signed( 31 downto 0 ) := ( others => '0' );
	signal fifo_ext1		: signed( 31 downto 0 ) := ( others => '0' );
	signal fifo_en			: std_logic := '0';
	
	signal rst_sync		: std_logic_vector( 2 downto 0 ) := ( others => '0' );
	
	component output_fifo is
		port (
			clk_out		: in  std_logic;
			clk_src		: in  std_logic;
			rst			: in  std_logic;
			
			wr_data0		: in  signed( 23 downto 0 );
			wr_data1		: in  signed( 23 downto 0 );
			wr_data_en	: in  std_logic;
			
			rd_data0		: out signed( 23 downto 0 ) := ( others => '0' );
			rd_data1		: out signed( 23 downto 0 ) := ( others => '0' );
			rd_data_en	: in  std_logic
		);
	end component output_fifo;
begin

	fifo_en <= '1' when clk_cnt_rd = 127 else '0';
	
	clk_cnt_wr_process : process( clk_src )
	begin
		if rising_edge( clk_src ) then
			clk_cnt_wr <= clk_cnt_wr + 1;
			
			o_sample_en <= '0';
			if clk_cnt_wr = 191 then
				clk_cnt_wr <= ( others => '0' );
				o_sample_en <= '1';
			end if;
		end if;
	end process clk_cnt_wr_process;

	clk_cnt_rd_process : process( clk_out )
	begin
		if rising_edge( clk_out ) then
			clk_cnt_rd <= clk_cnt_rd + 1;
		end if;
	end process clk_cnt_rd_process;
	
	rst_sync_process : process( clk_out )
	begin
		if rising_edge( clk_out ) then
			rst_sync <= rst_sync( 1 downto 0 ) & rst;
		end if;
	end process rst_sync_process;
	
	INST_DAC : dac_top
		generic map (
			DAC_IF		=> DAC_IF
		)
		port map (
			clk			=> clk_out,
			rst			=> rst_sync( 2 ),
			clk_cnt		=> clk_cnt_rd,
			
			i_data0		=> fifo_out0,
			i_data1		=> fifo_out1,
			
			o_lrck		=> o_i2s_lrck,
			o_bclk		=> o_i2s_bclk,
			o_data0		=> o_i2s_data0,
			o_data1		=> o_i2s_data1
		);
	
	INST_SPDIF_TX : spdif_tx_top
		port map (
			clk			=> clk_out,
			rst			=> rst_sync( 2 ),
			clk_cnt		=> clk_cnt_rd( 1 downto 0 ),
			
			i_data0		=> fifo_out0,
			i_data1		=> fifo_out1,
			i_data_en	=> fifo_en,
			
			o_spdif		=> o_spdif
		);
	
	INST_FIFO : output_fifo
		port map (
			clk_out		=> clk_out,
			clk_src		=> clk_src,
			rst			=> rst,
			
			wr_data0		=> i_data0,
			wr_data1		=> i_data1,
			wr_data_en	=> i_data_en,
			
			rd_data0		=> fifo_out0,
			rd_data1		=> fifo_out1,
			rd_data_en	=> fifo_en
		);

end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity output_fifo is
	port (
		clk_out		: in  std_logic;
		clk_src		: in  std_logic;
		rst			: in  std_logic;
		
		wr_data0		: in  signed( 23 downto 0 );
		wr_data1		: in  signed( 23 downto 0 );
		wr_data_en	: in  std_logic;
		
		rd_data0		: out signed( 23 downto 0 ) := ( others => '0' );
		rd_data1		: out signed( 23 downto 0 ) := ( others => '0' );
		rd_data_en	: in  std_logic
	);
end output_fifo;

architecture rtl of output_fifo is
	type RAM_TYPE is array( 0 to 3 ) of signed( 47 downto 0 );
	signal ram	: RAM_TYPE := ( others => ( others => '0' ) );
	
	signal addr_wr	: unsigned( 1 downto 0 ) := ( others => '0' );
	signal addr_rd	: unsigned( 1 downto 0 ) := ( others => '0' );
	
begin
	rd_data0 <= ram( to_integer( addr_rd ) )( 23 downto  0 );
	rd_data1 <= ram( to_integer( addr_rd ) )( 47 downto 24 );
	
	read_process : process( clk_out )
	begin
		if rising_edge( clk_out ) then
			if rd_data_en = '1' then
				addr_rd <= addr_rd + 1;
			end if;
		end if;
	end process read_process;

	write_process : process( clk_src )
	begin
		if rising_edge( clk_src ) then
			if wr_data_en = '1' then
				ram( to_integer( addr_wr ) ) <= wr_data1 & wr_data0;
				if rst = '1' then
					ram( to_integer( addr_wr ) ) <= ( others => '0' );
				end if;
				
				addr_wr <= addr_wr + 1;
			end if;
		end if;
	end process write_process;

end rtl;
