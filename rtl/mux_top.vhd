library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mux_top is
	port (
		clk			: in  std_logic;
		rst			: in  std_logic;
		sel			: in  std_logic;
		
		i_data0_0	: in  signed( 23 downto 0 );
		i_data0_1	: in  signed( 23 downto 0 );
		i_data0_en	: in  std_logic;
		
		i_data1_0	: in  signed( 23 downto 0 );
		i_data1_1	: in  signed( 23 downto 0 );
		i_data1_en	: in  std_logic;
		
		o_data0		: out signed( 23 downto 0 ) := ( others => '0' );
		o_data1		: out signed( 23 downto 0 ) := ( others => '0' );
		o_data_en	: out std_logic := '0'
	);
end mux_top;

architecture rtl of mux_top is
	signal data0		: signed( 23 downto 0 ) := ( others => '0' );
	signal data1		: signed( 23 downto 0 ) := ( others => '0' );
	
	signal data_cnt	: unsigned( 4 downto 0 ) := ( others => '1' );
	signal cnt_en		: std_logic := '0';
	signal sel_mux		: std_logic := '0';
begin
	
	o_data0 <= data0;
	o_data1 <= data1;

	sel_mux <= i_data0_en when sel = '0' else i_data1_en;
	cnt_en <= '1' when data_cnt < 24 else '0';
	
	data_cnt_process : process( clk )
	begin
		if rising_edge( clk ) then
			o_data_en <= '0';
			if rst = '1' then
				data_cnt <= ( others => '1' );
			
			elsif sel_mux = '1' then
				data_cnt <= ( others => '0' );
			
			elsif cnt_en ='1' then
				data_cnt <= data_cnt + 1;
				if data_cnt = 23 then
					o_data_en <= '1';
				end if;
			end if;
		end if;
	end process data_cnt_process;
	
	data_process : process( clk )
		variable data : signed( 23 downto 0 );
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				data0 <= ( others => '0' );
				data1 <= ( others => '0' );
			elsif cnt_en = '1' then
				if sel = '0' then
					data := i_data0_0 sll to_integer( data_cnt );
					data0 <= data0( 22 downto 0 ) & data( 23 );
					data := i_data0_1 sll to_integer( data_cnt );
					data1 <= data1( 22 downto 0 ) & data( 23 );
				else
					data := i_data1_0 sll to_integer( data_cnt );
					data0 <= data0( 22 downto 0 ) & data( 23 );
					data := i_data1_1 sll to_integer( data_cnt );
					data1 <= data1( 22 downto 0 ) & data( 23 );
				end if;
			end if;
		end if;
	end process data_process;

end rtl;

