library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity mac_mux_3 is
	port (
		clk		: in  std_logic;
		rst		: in  std_logic;
		sel		: in  std_logic_vector( 1 downto 0 );
	
		i_mac0	: in  mac_i;
		o_mac0	: out mac_o := mac_o_init;
		
		i_mac1	: in  mac_i;
		
		i_mac2	: in  mac_i;
		o_mac2	: out mac_o := mac_o_init
	);
end mac_mux_3;

architecture rtl of mac_mux_3 is
	component mac is
		port (
			clk		: in  std_logic;
			rst		: in  std_logic;
			
			i_mac		: in  mac_i;
			o_mac		: out mac_o
		);
	end component mac;

	signal i0		: mac_i := mac_i_init;
	signal i1		: mac_i := mac_i_init;
	signal i2		: mac_i := mac_i_init;
	signal o			: mac_i := mac_i_init;
	
	signal i_mac	: mac_i := mac_i_init;
	signal o_mac	: mac_o := mac_o_init;
begin

	i0		 <= i_mac0;
	i1		 <= i_mac1;
	i2		 <= i_mac2;

	o <= i0 when sel = "00" else
		  i1 when sel = "01" else
		  i2;
	
	input_process : process( clk )
	begin
		if rising_edge( clk ) then
			i_mac	<= o;
		end if;
	end process input_process;
	
	INST_MAC : mac
		port map (
			clk	=> clk,
			rst	=> rst,
			
			i_mac	=> i_mac,
			o_mac => o_mac
		);
	
	o_mac2 <= o_mac;
	
	output_process : process( clk )
	begin
		if rising_edge( clk ) then
			o_mac0 <= mac_o_init;
			
			if sel( 1 ) = '0' then
				o_mac0 <= o_mac;
			end if;
		end if;
	end process output_process;
	
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity mac_mux_2 is
	port (
		clk		: in  std_logic;
		rst		: in  std_logic;
		sel		: in  std_logic;
	
		i_mac0	: in  mac_i;
		o_mac0	: out mac_o := mac_o_init;
		
		i_mac1	: in  mac_i;
		o_mac1	: out mac_o := mac_o_init
	);
end mac_mux_2;

architecture rtl of mac_mux_2 is
	component mac is
		port (
			clk		: in  std_logic;
			rst		: in  std_logic;
			
			i_mac		: in  mac_i;
			o_mac		: out mac_o
		);
	end component mac;

	signal i0		: mac_i := mac_i_init;
	signal i1		: mac_i := mac_i_init;
	signal o			: mac_i := mac_i_init;
	
	signal i_mac	: mac_i := mac_i_init;
	signal o_mac	: mac_o := mac_o_init;
begin

	i0		 <= i_mac0;
	i1		 <= i_mac1;

	o <= i0 when sel = '0' else i1;
	
	input_process : process( clk )
	begin
		if rising_edge( clk ) then
			i_mac	<= o;
		end if;
	end process input_process;
	
	INST_MAC : mac
		port map (
			clk	=> clk,
			rst	=> rst,
			
			i_mac	=> i_mac,
			o_mac => o_mac
		);
	
	o_mac0 <= o_mac;
	o_mac1 <= o_mac;
	
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity mac is
	port (
		clk		: in  std_logic;
		rst		: in  std_logic;
		
		i_mac		: in  mac_i;
		o_mac		: out mac_o := mac_o_init
	);
end mac;

architecture rtl of mac is
	type MUL_TYPE is array ( 6 downto 0 ) of signed( 69 downto 0 );
		
	signal mul_out0: MUL_TYPE := ( others => ( others => '0' ) );
	signal mul_out1: MUL_TYPE := ( others => ( others => '0' ) );
	signal mul_acc : std_logic_vector( 6 downto 0 ) := ( others => '0' );
	signal mul_en  : std_logic_vector( 5 downto 0 ) := ( others => '0' );
	signal mac_cmp : std_logic_vector( 7 downto 0 ) := ( others => '0' );
	
	alias buf_out0	: signed( 69 downto 0 ) is mul_out0( 6 );
	alias buf_out1	: signed( 69 downto 0 ) is mul_out1( 6 );
	alias buf_acc	: std_logic is mul_acc( 6 );
	alias buf_cmp 	: std_logic is mac_cmp( 6 );
	
	signal acc_out0: signed( 69 downto 0 ) := ( others => '0' );
	signal acc_out1: signed( 69 downto 0 ) := ( others => '0' );
	signal acc_en	: std_logic := '0';
begin

	o_mac.en <= mac_cmp( 7 );
	o_mac.data0 <= acc_out0;
	o_mac.data1 <= acc_out1;
	
	mul_process : process( clk )
	begin
		if rising_edge( clk ) then
			if rst = '1' then
				mul_out0<= ( others => ( others => '0' ) );
				mul_out1<= ( others => ( others => '0' ) );
			else
				mul_out0<= mul_out0( 5 downto 0 ) & ( i_mac.data00 * i_mac.data01 );
				mul_out1<= mul_out1( 5 downto 0 ) & ( i_mac.data10 * i_mac.data11 );
				mul_acc <= mul_acc ( 5 downto 0 ) & i_mac.acc;
				mul_en  <= mul_en  ( 4 downto 0 ) & i_mac.en;
				mac_cmp <= mac_cmp ( 6 downto 0 ) & i_mac.cmp;
			end if;
		end if;
	end process mul_process;
		
	acc_process: process( clk )
	begin
		if rising_edge( clk ) then
			acc_en <= mac_cmp( 5 ) or mul_en( 5 );
			if rst = '1' then
				acc_out0<= ( others => '0' );
				acc_out1<= ( others => '0' );
				acc_en <= '0';
			elsif acc_en = '1' then
				acc_out0 <= buf_out0;
				acc_out1 <= buf_out1;
				if buf_acc = '1' then
					acc_out0 <= acc_out0 + buf_out0;
					acc_out1 <= acc_out1 + buf_out1;
				end if;
			end if;
		end if;
	end process acc_process;
	
end rtl;
