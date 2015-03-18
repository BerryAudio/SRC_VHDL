
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
 
ENTITY mac_tb IS
END mac_tb;
 
ARCHITECTURE behavior OF mac_tb IS 
 
    COMPONENT mac
    PORT(
         clk : IN  std_logic;
         rst : IN  std_logic;
         i_en : IN  std_logic;
         i_acc : IN  std_logic;
         i_cmp : IN  std_logic;
         i_data00 : IN  signed(34 downto 0);
         i_data01 : IN  signed(34 downto 0);
         i_data10 : IN  signed(34 downto 0);
         i_data11 : IN  signed(34 downto 0);
         o_en : OUT  std_logic;
         o_data0 : OUT  signed(69 downto 0);
         o_data1 : OUT  signed(69 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal rst : std_logic := '0';
   signal i_en : std_logic := '0';
   signal i_acc : std_logic := '0';
   signal i_cmp : std_logic := '0';
   signal i_data00 : signed(34 downto 0) := (others => '0');
   signal i_data01 : signed(34 downto 0) := (others => '0');
   signal i_data10 : signed(34 downto 0) := (others => '0');
   signal i_data11 : signed(34 downto 0) := (others => '0');

 	--Outputs
   signal o_en : std_logic;
   signal o_data0 : signed(69 downto 0);
   signal o_data1 : signed(69 downto 0);
	
	signal data0 : signed(23 downto 0);
   signal data1 : signed(23 downto 0);

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: mac PORT MAP (
          clk => clk,
          rst => rst,
          i_en => i_en,
          i_acc => i_acc,
          i_cmp => i_cmp,
          i_data00 => i_data00,
          i_data01 => i_data01,
          i_data10 => i_data10,
          i_data11 => i_data11,
          o_en => o_en,
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
		
		data0 <= o_data0( 61 downto 38 );
		data1 <= o_data1( 61 downto 38 );
 

   -- Stimulus process
   stim_proc: process
   begin
      wait until rising_edge( clk );
		i_data00 <= to_signed( 15, 35 );
		i_data01 <= x"05555555" & b"010";
		
		i_data10 <= x"10000000" & b"000";
		i_data11 <= x"05555555" & b"010";
		
		i_cmp <= '1';
		
      wait until rising_edge( clk );
		i_cmp <= '0';

      wait;
   end process;

END;
