library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dac_top is
	generic (
		DAC_IF		: string := "AD1955"
	);
	port (
		clk			: in  std_logic;
		rst			: in  std_logic;
		
		i_data0		: in  signed( 23 downto 0 );
		i_data1		: in  signed( 23 downto 0 );
		i_data_en	: in  std_logic;
		
		o_sample_en	: out std_logic := '0';
		o_lrck		: out std_logic := '0';
		o_bclk		: out std_logic := '0';
		o_data0		: out std_logic := '0';
		o_data1		: out std_logic := '0'
	);
end dac_top;

architecture rtl of dac_top is
	signal CLOCK_START	: natural;
	signal clock_count	: unsigned( 8 downto 0 ) := ( others => '0' );
	
	signal fifo_out0		: signed( 23 downto 0 ) := ( others => '0' );
	signal fifo_out1		: signed( 23 downto 0 ) := ( others => '0' );
	signal fifo_ext0		: signed( 31 downto 0 ) := ( others => '0' );
	signal fifo_ext1		: signed( 31 downto 0 ) := ( others => '0' );
	signal fifo_en			: std_logic := '0';
	
	signal buf_data0		: signed( 31 downto 0 ) := ( others => '0' );
	signal buf_data1		: signed( 31 downto 0 ) := ( others => '0' );
	signal buf_shift		: std_logic := '0';
	
	component dac_fifo is
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
			
			i_data0		: in  signed( 23 downto 0 );
			i_data1		: in  signed( 23 downto 0 );
			i_data_en	: in  std_logic;
			
			o_data0		: out signed( 23 downto 0 ) := ( others => '0' );
			o_data1		: out signed( 23 downto 0 ) := ( others => '0' );
			o_data_en	: in  std_logic
		);
	end component dac_fifo;
begin
	
	buf_shift <= '1' when clock_count( 2 downto 0 ) = o"0" else '0';
	
	o_data0 <= buf_data0( 31 );
	o_data1 <= buf_data1( 31 );
	
	o_sample_en <= fifo_en;

	count_process : process( clk )
	begin
		if rising_edge( clk ) then
			clock_count <= clock_count + 1;
			
			fifo_en <= '0';
			if clock_count( 7 downto 0 ) = 0 then
				fifo_en <= '1';
			end if;
		end if;
	end process count_process;
	
	buffer1_process : process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				buf_data0 <= ( others => '0' );
				buf_data1 <= ( others => '0' );
			else
				if clock_count( 7 downto 0 ) = CLOCK_START then
					buf_data0 <= fifo_ext0;
					buf_data1 <= fifo_ext1;
				elsif buf_shift = '1' then
					buf_data0 <= buf_data0 sll 1;
					buf_data1 <= buf_data1 sll 1;
				end if;
			end if;
		end if;
	end process buffer1_process;

	GEN_AD1955 : if DAC_IF = "AD1955" generate
	begin
		CLOCK_START <= 8;
	
		fifo_ext0 <= fifo_out0 & x"00";
		fifo_ext1 <= fifo_out1 & x"00";
		
		output_process : process( clk )
		begin
			if rising_edge( clk ) then
				o_bclk <= not clock_count( 2 );
				o_lrck <= '0';
				if clock_count( 7 downto 3 ) = 0 then
					o_lrck <= '1';
				end if;
			end if;
		end process output_process;
	end generate GEN_AD1955;

	GEN_PCM1794 : if DAC_IF = "PCM1794" generate
	begin
		CLOCK_START <= 0;
	
		fifo_ext0 <= RESIZE( fifo_out0, 32 );
		fifo_ext1 <= RESIZE( fifo_out1, 32 );
		
		output_process : process( clk )
		begin
			if rising_edge( clk ) then
				o_bclk <= clock_count( 2 );
				o_lrck <= clock_count( 7 );
			end if;
		end process output_process;
	end generate GEN_PCM1794;
	
	INST_FIFO : dac_fifo
		port map (
			clk			=> clk,
			rst			=> rst,
			
			i_data0		=> i_data0,
			i_data1		=> i_data1,
			i_data_en	=> i_data_en,
			
			o_data0		=> fifo_out0,
			o_data1		=> fifo_out1,
			o_data_en	=> fifo_en
		);
	
end rtl;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dac_fifo is
	port (
		clk			: in  std_logic;
		rst			: in  std_logic;
		
		i_data0		: in  signed( 23 downto 0 );
		i_data1		: in  signed( 23 downto 0 );
		i_data_en	: in  std_logic;
		
		o_data0		: out signed( 23 downto 0 ) := ( others => '0' );
		o_data1		: out signed( 23 downto 0 ) := ( others => '0' );
		o_data_en	: in  std_logic
	);
end dac_fifo;

architecture rtl of dac_fifo is
	type RAM_TYPE is array( 0 to 3 ) of signed( 47 downto 0 );
	signal ram	: RAM_TYPE := ( others => ( others => '0' ) );
	
	signal addr_wr	: unsigned( 1 downto 0 ) := ( others => '0' );
	signal addr_rd	: unsigned( 1 downto 0 ) := ( others => '0' );
	
begin
	o_data0 <= ram( to_integer( addr_rd ) )( 23 downto  0 );
	o_data1 <= ram( to_integer( addr_rd ) )( 47 downto 24 );

	clock_process : process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				addr_rd <= addr_wr( 1 ) & not( addr_wr( 0 ) );
			elsif o_data_en = '1' then
				addr_rd <= addr_rd + 1;
			end if;
			
			if i_data_en = '1' then
				ram( to_integer( addr_wr ) ) <= i_data1 & i_data0;
				if rst = '1' then
					ram( to_integer( addr_wr ) ) <= ( others => '0' );
				end if;
				addr_wr <= addr_wr + 1;
			end if;
		end if;
	end process clock_process;

end rtl;