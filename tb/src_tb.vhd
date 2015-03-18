LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

library std;
use std.textio.all;

ENTITY src_tb IS
END src_tb;
 
ARCHITECTURE behavior OF src_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT src_top
	 generic(
		clock_count : integer
	 );
    PORT(
         clk : IN  std_logic;
         rst : IN  std_logic;
         ctrl_locked : OUT  std_logic;
         ctrl_ratio : OUT  unsigned(23 downto 0);
         i_sample_en_i : IN  std_logic;
         i_sample_en_o : IN  std_logic;
         i_data0 : IN  signed(23 downto 0);
         i_data1 : IN  signed(23 downto 0);
         o_data_en : OUT  std_logic;
         o_data0 : OUT  signed(23 downto 0);
         o_data1 : OUT  signed(23 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal clk_i : std_logic := '0';
   signal clk_i_buf : std_logic_vector( 2 downto 0 ) := ( others => '0' );
   signal clk_i_en : std_logic := '0';
   signal clk_o : std_logic := '0';
   signal clk_o_buf : std_logic_vector( 2 downto 0 ) := ( others => '0' );
   signal clk_o_en : std_logic := '0';
   signal rst : std_logic := '1';
   signal i_sample_en_i : std_logic := '0';
   signal i_sample_en_o : std_logic := '0';
   signal i_data0 : signed(23 downto 0) := (others => '0');
   signal i_data1 : signed(23 downto 0) := (others => '0');

 	--Outputs
   signal ctrl_locked : std_logic;
   signal ctrl_ratio : unsigned(23 downto 0);
   signal o_data_en : std_logic;
   signal o_data0 : signed(23 downto 0);
   signal o_data1 : signed(23 downto 0);
	
	

   -- Clock period definitions
   constant clk_period : time :=    5.086 ns;
   constant clk_o_period : time :=  2.604 us;
   constant clk_i_period : time := 22.676 us;
	
	signal wav_cnt : unsigned( 3 downto 0 ) := x"0";
	-- Channel A: sinewave with frequency=Freq/12
	type sine16 is array (0 to 15) of signed(15 downto 0);
	signal channel_a : sine16 := ((x"8000"), (x"b0fb"), (x"da82"), (x"f641"),
											(x"ffff"), (x"f641"), (x"da82"), (x"b0fb"),
											(x"8000"), (x"4f04"), (x"257d"), (x"09be"),
											(x"0000"), (x"09be"), (x"257d"), (x"4f04"));
											
	-- channel B: sinewave with frequency=Freq/24
	type sine8 is array (0 to 7) of signed(0 to 15);
	signal channel_b : sine8 := ((x"8000"), (x"da82"), (x"ffff"), (x"da82"),
										  (x"8000"), (x"257d"), (x"0000"), (x"257d"));
	
	impure function fetch_channel_a( cnt : unsigned( 3 downto 0 ) )
		return signed is
		variable int : integer;
	begin
		int := to_integer( channel_a( to_integer( cnt ) ) - x"8000" ) ;
		
		return to_signed( int * 2**8, 24 );
	end function fetch_channel_a;
	
	impure function fetch_channel_b( cnt : unsigned( 2 downto 0 ) )
		return signed is
		
		variable int : integer;
		variable tmp : signed( 23 downto 0 );
	begin
		int := to_integer( channel_b( to_integer( cnt ) ) - x"8000" ) ;
		int := int * 2**7 + to_integer( fetch_channel_a( cnt ) )/2;
		
		return to_signed( int, 24 );
	end function fetch_channel_b;
	
BEGIN

	pipe_process : process( clk )
		file		outfile	: text is out "./tb/src_test.txt";
		variable outline	: line;
	begin
		if rising_edge( clk ) then
			if o_data_en = '1' then
				write( outline, to_integer( o_data1 ) );
				writeline( outfile, outline );
			end if;
		end if;
	end process;


	clk_o_en <= ( clk_o_buf( 2 ) xor clk_o_buf( 1 ) ) and clk_o_buf( 1 );
	clk_i_en <= ( clk_i_buf( 2 ) xor clk_i_buf( 1 ) ) and clk_i_buf( 1 );
 
	-- Instantiate the Unit Under Test (UUT)
   uut: src_top 
		generic map (
			clock_count => 512
		)
		PORT MAP (
          clk => clk,
          rst => rst,
          ctrl_locked => ctrl_locked,
          ctrl_ratio => ctrl_ratio,
          i_sample_en_i => i_sample_en_i,
          i_sample_en_o => i_sample_en_o,
          i_data0 => i_data0,
          i_data1 => i_data1,
          o_data_en => o_data_en,
          o_data0 => o_data0,
          o_data1 => o_data1
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
	
   clk_o_process :process
   begin
		clk_o <= '0';
		wait for clk_o_period/2;
		clk_o <= '1';
		wait for clk_o_period/2;
   end process;
	
   clk_i_process :process
   begin
		clk_i <= '0';
		wait for clk_i_period/2;
		clk_i <= '1';
		wait for clk_i_period/2;
   end process;
	
	strobe_process : process( clk )
	begin
		if rising_edge( clk ) then
			clk_i_buf <= clk_i_buf( 1 downto 0 ) & clk_i;
			clk_o_buf <= clk_o_buf( 1 downto 0 ) & clk_o;
		end if;
	end process;
 
	stimulus_process : process( clk )
	begin
		if rising_edge( clk ) then
			i_sample_en_i <= clk_i_en;
			i_sample_en_o <= clk_o_en;
			if clk_i_en = '1' then
				wav_cnt <= wav_cnt + 1;
				
				i_data0 <= fetch_channel_a( wav_cnt );
				i_data1 <= fetch_channel_b( wav_cnt );
			end if;
		end if;
	end process;

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;
		rst <= '0';

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
