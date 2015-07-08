LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY regulator_tb IS
END regulator_tb;
 
ARCHITECTURE behavior OF regulator_tb IS 
 
   -- Component Declaration for the Unit Under Test (UUT)
	constant REG_AVE_WIDTH : integer range 4 to 6 := 6;

   --Inputs
   signal clk : std_logic := '0';
   signal clk_147 : std_logic := '0';
   signal rst : std_logic := '0';
   signal i_sample_en : std_logic := '0';
   signal o_sample_en : std_logic := '0';
   signal i_fifo_level : unsigned(10 downto 0) := (others => '0');
   signal div_busy : std_logic := '0';
   signal div_remainder : unsigned(26 downto 0) := (others => '0');

 	--Outputs
   signal o_ratio : unsigned( 25 downto 0 );
   signal o_locked : std_logic;
   signal o_ratio_en : std_logic;
   signal div_en : std_logic;
   signal div_divisor : unsigned(26 downto 0);
   signal div_dividend : unsigned(26 downto 0);
	
	constant zero24 : unsigned( 19 downto 0 ) := ( others => '0' );

   -- Clock period definitions
   constant clk_period : time := 22.676 us;
	constant clk_147_period : time := 6.78 ns;
	
	signal clk_edge : std_logic_vector( 1 downto 0 ) := "00";
	signal rd_en : std_logic := '0';
	
	component regulator_top is
		generic (
			CLOCK_COUNT		: integer := 384;
			REG_AVE_WIDTH	: integer range 2 to 6 := 4
		);
		port (
			clk				: in  std_logic;
			rst				: in  std_logic;
			
			-- input/output sample has arrived
			-- input from ring buffer
			-- let's us know how full the buffer is
			i_sample_en		: in  std_logic;
			o_sample_en		: in  std_logic;
			i_fifo_level	: in  unsigned( 10 downto 0 );
			
			-- ratio data - indicate that a ratio has been calculated
			-- locked status indicator
			o_ratio			: out unsigned( 25 downto 0 ) := ( others => '0' );
			o_locked			: out std_logic := '0';
			o_ratio_en		: out std_logic := '0';
			
			-- shared divider i/o
			div_busy			: in  std_logic;
			div_remainder	: in  unsigned( 26 downto 0 );
			
			div_en			: out std_logic := '0';
			div_divisor		: out unsigned( 26 downto 0 ) := ( others => '0' );
			div_dividend	: out unsigned( 26 downto 0 ) := to_unsigned( CLOCK_COUNT * 16, 27 )
			
		);
	end component regulator_top;
	
	component div is 
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
			
			i_en			: in  std_logic;
			i_divisor	: in  unsigned( 26 downto 0 );
			i_dividend	: in  unsigned( 26 downto 0 );
			
			o_busy		: out std_logic := '0';
			o_remainder	: out unsigned( 26 downto 0 ) := ( others => '0' )
		);
	end component div;
	
	component ring_buffer is
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
			buf_level	: out unsigned( 10 downto 0 ) := ( others => '0' );
			buf_ptr		: out unsigned( 25 downto 0 ) := ( others => '0' );
			
			fir_en		: in  std_logic;
			fir_step		: in  std_logic;
			fir_fin		: in  std_logic;
			
			locked		: in  std_logic;
			ratio			: in  unsigned( 25 downto 0 );
			
			--------------------------------------------------
			-- Ring Buffer Data
			--------------------------------------------------
			wr_en			: in  std_logic;
			wr_data0		: in  signed( 23 downto 0 );	
			wr_data1		: in  signed( 23 downto 0 );
			
			rd_data0		: out signed( 23 downto 0 ) := ( others => '0' );
			rd_data1		: out signed( 23 downto 0 ) := ( others => '0' )
		);
	end component ring_buffer;
BEGIN
 
	i_sample_en <= ( clk_edge( 0 ) xor clk_edge( 1 ) ) and clk_edge( 1 );
 
	-- Instantiate the Unit Under Test (UUT)
   uut: regulator_top 
		generic map (
			CLOCK_COUNT => 384,
			REG_AVE_WIDTH => REG_AVE_WIDTH
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
	
	rb : ring_buffer
		generic map (
			PTR_OFFSET	=> 16
		)
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
			ratio			=> o_ratio,
			
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
