LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

library work;
use work.src.all;

ENTITY regulator_tb IS
END regulator_tb;
 
ARCHITECTURE behavior OF regulator_tb IS 
 
   -- Component Declaration for the Unit Under Test (UUT)
	constant REG_CNT_WIDTH : integer range 2 to 6 := 4;
	constant REG_AVE_WIDTH : integer range 4 to 6 := 6;

   --Inputs
   signal clk : std_logic := '0';
   signal clk_147 : std_logic := '0';
   signal rst : std_logic := '0';
   signal i_sample_en : std_logic := '0';
   signal o_sample_en : std_logic := '0';
   signal i_fifo_level : unsigned(10 downto 0) := (others => '0');
   signal div_busy : std_logic := '0';
   signal div_remainder : unsigned(24 downto 0) := (others => '0');

 	--Outputs
   signal o_ratio : unsigned(23 + REG_AVE_WIDTH downto 0);
	signal ratio : unsigned( 29 downto 0 );
   signal o_locked : std_logic;
   signal o_ratio_en : std_logic;
   signal div_en : std_logic;
   signal div_divisor : unsigned(26 downto 0);
   signal div_dividend : unsigned(26 downto 0);
	
	constant zero24 : unsigned( 23 downto 0 ) := ( others => '0' );

   -- Clock period definitions
   constant clk_period : time := 22.676 us;
	constant clk_147_period : time := 6.78 ns;
	
	signal clk_edge : std_logic_vector( 1 downto 0 ) := "00";
	signal rd_en : std_logic := '0';
BEGIN
 
	i_sample_en <= ( clk_edge( 0 ) xor clk_edge( 1 ) ) and clk_edge( 1 );
 
	-- Instantiate the Unit Under Test (UUT)
   uut: regulator_top 
		generic map (
			CLOCK_COUNT => 384,
			REG_AVE_WIDTH => REG_AVE_WIDTH,
			REG_CNT_WIDTH => REG_CNT_WIDTH
		) PORT MAP (
          clk => clk_147,
          rst => rst,
          i_sample_en => i_sample_en,
          o_sample_en => o_sample_en,
          i_fifo_level => i_fifo_level,
          o_ratio => o_ratio,
          o_locked => o_locked,
          o_ratio_en => o_ratio_en,
          div_busy => div_busy,
          div_remainder => div_remainder,
          div_en => div_en,
          div_divisor => div_divisor,
          div_dividend => div_dividend
        );
	dv : div 
		port map (
			clk			=> clk_147,
			rst			=> rst,
			
			i_en			=> div_en,
			i_divisor	=> div_divisor,
			i_dividend	=> div_dividend,
			
			o_busy		=> div_busy,
			o_remainder	=> div_remainder
		);
	
	ratio <= RESIZE( o_ratio, 30 ) sll ( 6-REG_AVE_WIDTH );
	
	rb : ring_buffer
		port map (
			clk			=> clk_147,
			rst			=> rst,
			
			buf_rdy		=> open,
			buf_level	=> i_fifo_level,
			buf_ptr		=> open,
			
			fir_en		=> rd_en,
			fir_step		=> '0',
			fir_fin		=> o_sample_en,
			
			locked		=> o_locked,
			ratio			=> ratio,
			
			wr_en			=> i_sample_en,
			wr_data0		=> ( others => '0' ),
			wr_data1		=> ( others => '0' ),
			
			rd_data0		=> open,
			rd_data1		=> open
		);

   -- Clock process definitions

   -- Clock process definitions
	clk_147_process :process
   begin
		clk_147 <= '0';
		wait for clk_147_period/2;
		clk_147 <= '1';
		wait for clk_147_period/2;
   end process;
	
	clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
	
	process( clk_147 )
	begin
		if rising_edge( clk_147 ) then
			clk_edge <= clk_edge( 0 ) & clk;
		end if;
	end process;
	
	process( clk_147 )
		variable cnt : integer := 0;
	begin
		if rising_edge( clk_147 ) then
			o_sample_en <= '0';
			rd_en <= '0';
			if cnt = 191 then
				rd_en <= '1';
			end if;
			
			if cnt = 383 then
				o_sample_en <= '1';
				cnt := 0;
			else
				cnt := cnt + 1;
			end if;
		end if;
	end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
