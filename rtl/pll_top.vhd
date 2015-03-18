library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity pll_top is
	port (
		clk_sel		: in  std_logic;
		sys_lock		: out std_logic := '0';
		
		i_clk_22		: in  std_logic;
		i_clk_24		: in  std_logic;
		
		o_clk_src	: out std_logic := '0';
		o_clk_i2s	: out std_logic := '0'
	);
end pll_top;

architecture rtl of pll_top is
	constant PERIOD_24 : real := 40.6901;
	
	component pll is
		generic (
			PERIOD	: real
		);
		port (
			sys_clk	 : in  std_logic;
			sys_lock	 : out std_logic;
			
			clk_src	 : out std_logic
		);
	end component pll;
	
	component clk_mux is
		port (
			clk0		: in  std_logic;
			clk1		: in  std_logic;
			clk_sel	: in  std_logic;
			
			clk_out	: out std_logic
		);
	end component clk_mux;
	
	signal pll24_lock	 : std_logic;
	
	signal clk_src		 : std_logic;
	signal clk24_i2s	 : std_logic;
begin

	sys_lock <= pll24_lock;
	
	INST_CLK_I2S : clk_mux
		port map (
			clk0		=> i_clk_22,
			clk1		=> i_clk_24,
			clk_sel	=> clk_sel,
			clk_out	=> o_clk_i2s
		);
	
	INST_PLL_GENERATE_24 : pll
		generic map (
			PERIOD	 => PERIOD_24
		)
		port map (
			sys_clk	  => i_clk_24,
			sys_lock	  => pll24_lock,
			
			clk_src	 => clk_src
		);
	
	INST_BUFG : BUFG
		port map (
			I	=> clk_src,
			O	=> o_clk_src
		);
		
end rtl;

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity clk_mux is
	port (
		clk0		: in  std_logic;
		clk1		: in  std_logic;
		clk_sel	: in  std_logic;
		clk_out	: out std_logic := '0'
	);
end clk_mux;

architecture rtl of clk_mux is
	signal sel_clk0	: std_logic := '0';
	signal sel_clk1	: std_logic := '0';
	signal sel			: std_logic := '0';
begin
	
	sel <= not( sel_clk0 ) and sel_clk1;

	clk0_process : process( clk0 )
	begin
		if falling_edge( clk0 ) then
			sel_clk0 <= not( sel_clk1 ) and not( clk_sel );
		end if;
	end process clk0_process;

	clk1_process : process( clk1 )
	begin
		if falling_edge( clk1 ) then
			sel_clk1 <= not( sel_clk0 ) and    ( clk_sel );
		end if;
	end process clk1_process;
	
	INST_BUFG : BUFGMUX
		port map (
			I0	=> clk0,
			I1	=> clk1,
			S	=> sel,
			O	=> clk_out
		);

end rtl;

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity pll is
	generic (
		PERIOD	: real := 40.690104167
	);
	port (
		sys_clk		: in  std_logic;
		sys_lock		: out std_logic := '0';
		
		clk_src		: out std_logic := '0'
	);
end pll;

architecture rtl of pll is
	constant PLL_PERIOD : real := PERIOD;
	signal PLL_CLK_FB	: std_logic;
begin

	INST_PLL_BASE : PLL_BASE
		generic map (
			BANDWIDTH				 => "OPTIMIZED",
			CLKFBOUT_MULT			 => 40, -- (i.e. 36 = 147.546 MHz, 40 = 196.608 MHz)
			CLKFBOUT_PHASE			 => 0.0,
			CLKIN_PERIOD			 => PLL_PERIOD,
			
			CLKOUT0_DIVIDE			 =>  5, -- clk - src (i.e. 6 = 147.546 MHz, 5 = 196.608 MHz)
			CLKOUT1_DIVIDE			 => 40, -- clk - i2s (i.e.  24.576 MHz)
			CLKOUT2_DIVIDE			 => 10, 
			CLKOUT3_DIVIDE			 => 10,
			CLKOUT4_DIVIDE			 => 10,
			CLKOUT5_DIVIDE			 => 10,
			
			CLKOUT0_DUTY_CYCLE	 => 0.5,
			CLKOUT1_DUTY_CYCLE	 => 0.5,
			CLKOUT2_DUTY_CYCLE	 => 0.5,
			CLKOUT3_DUTY_CYCLE	 => 0.5,
			CLKOUT4_DUTY_CYCLE	 => 0.5,
			CLKOUT5_DUTY_CYCLE	 => 0.5,
			
			CLKOUT0_PHASE			 => 0.0,
			CLKOUT1_PHASE			 => 0.0,
			CLKOUT2_PHASE			 => 0.0,
			CLKOUT3_PHASE			 => 0.0,
			CLKOUT4_PHASE			 => 0.0,
			CLKOUT5_PHASE			 => 0.0,
			
			CLK_FEEDBACK			 => "CLKFBOUT",
			COMPENSATION			 => "INTERNAL",
			DIVCLK_DIVIDE			 => 1,
			REF_JITTER				 => 0.100,
			RESET_ON_LOSS_OF_LOCK => FALSE
		)
		port map (
			CLKFBOUT => PLL_CLK_FB,
			CLKOUT0	=> clk_src,
			CLKOUT1	=> open,
			CLKOUT2	=> open,
			CLKOUT3	=> open,
			CLKOUT4	=> open,
			CLKOUT5	=> open,
			LOCKED	=> sys_lock,
			CLKFBIN	=> PLL_CLK_FB,
			CLKIN		=> sys_clk,
			RST		=> '0'
	);

end rtl;