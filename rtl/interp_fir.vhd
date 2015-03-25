library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.src.all;

entity interp_fir is
	generic (
		PTR_INC	: integer := INTERP_PTR_INCREMENT;
		ROM_FILE : string := ROM_FILE_SRC;
		ROM_BIT	: natural range 24 to 32 := ROM_FILE_BIT
	);
	port (
		clk			 : in  std_logic;
		rst			 : in  std_logic;
		
		-- signal when complete
		o_fir_step	 : out std_logic := '0';
		o_fir_fin	 : out std_logic := '0';
		o_fir_data	 : out signed( 34 downto 0 ) := ( others => '0' );
		
		-- phase information
		phase			 : in  unsigned( 5 downto 0 );
		phase_en		 : in  std_logic;
		
		i_mac			 : out mac_i := mac_i_init;
		o_mac			 : in  mac_o;
		
		-- lagrange coefficients
		lagrange_h0	 : in  signed( 34 downto 0 ) := ( others => '0' );
		lagrange_h1	 : in  signed( 34 downto 0 ) := ( others => '0' );
		lagrange_h2	 : in  signed( 34 downto 0 ) := ( others => '0' );
		lagrange_h3	 : in  signed( 34 downto 0 ) := ( others => '0' );
		lagrange_en	 : in  std_logic
	);
end interp_fir;

architecture rtl of interp_fir is
	type STATE_TYPE_I is ( S0_INIT, S1_RUN, S2_RUN );
	signal state_i : STATE_TYPE_I := S0_INIT;
	
	signal state_o	: std_logic := '0';
	
	signal rom_ptr		: unsigned( 13 downto 0 ) := ( others => '0' );
	signal rom_ptr_t	: unsigned( 13 downto 0 ) := ( others => '0' );
	signal rom_addr0	: unsigned( 13 downto 0 ) := ( others => '0' );
	signal rom_addr1	: unsigned( 13 downto 0 ) := ( others => '0' );
	signal rom_addr2	: unsigned( 13 downto 0 ) := ( others => '0' );
	signal rom_addr3	: unsigned( 13 downto 0 ) := ( others => '0' );
	
	signal rom_a0		: unsigned( 13 downto 0 ) := ( others => '0' );
	signal rom_a1		: unsigned( 13 downto 0 ) := ( others => '0' );
	signal rom_d0		: signed( 34 downto 0 ) := ( others => '0' );
	signal rom_d1		: signed( 34 downto 0 ) := ( others => '0' );
	
	signal coe_sum		: signed( 69 downto 0 ) := ( others => '0' );
	signal coe_final  : std_logic_vector( 10 downto 0 ) := ( others => '0' );
	
	signal l0			: signed( 34 downto 0 ) := ( others => '0' );
	signal l1			: signed( 34 downto 0 ) := ( others => '0' );
	signal l2			: signed( 34 downto 0 ) := ( others => '0' );
	signal l3			: signed( 34 downto 0 ) := ( others => '0' );
begin
	
	rom_addr0 <= RESIZE( rom_ptr    , 14 );
	rom_addr1 <= RESIZE( rom_ptr + 1, 14 );
	rom_addr2 <= RESIZE( rom_ptr + 2, 14 );
	rom_addr3 <= RESIZE( rom_ptr + 3, 14 );
	
	coe_sum <= o_mac.data0 + o_mac.data1;
	
	i_mac.data00 <= rom_d0;
	i_mac.data01 <= lagrange_h0 when ( state_i = S2_RUN ) else lagrange_h2;
	
	i_mac.data10<= rom_d1;
	i_mac.data11 <= lagrange_h1 when ( state_i = S2_RUN ) else lagrange_h3;
	
	INST_FILTER_ROM : fir_filter_rom
		generic map (
			ROM_FILE => ROM_FILE,
			ROM_BIT	=> ROM_BIT
		)
		port map (	
			clk	=> clk,
			rst	=> rst,
			
			addr0	=> rom_a0,
			addr1	=> rom_a1,
			
			data0	=> rom_d0( 34 downto ( 35 - ROM_BIT ) ),
			data1	=> rom_d1( 34 downto ( 35 - ROM_BIT ) )
		);
	
	state_i_process : process( clk )
	begin
		if rising_edge( clk ) then
			coe_final <= coe_final( coe_final'length-2 downto 0 ) & '0';
			
			if rst = '1' then
				state_i <= S0_INIT;
				rom_ptr <= ( others => '0' );
				i_mac.en  <= '0'; -- accept mac inputs
				i_mac.acc <= '0'; -- accumulate mac result
				i_mac.cmp <= '0'; -- indicate when mac has completed
			else
				i_mac.en  <= '0';
				i_mac.acc <= '0';
				i_mac.cmp <= '0';
				
				rom_a0 <= rom_addr0;
				rom_a1 <= rom_addr1;
				
				if phase_en = '1' then
					rom_ptr <= RESIZE( phase, 14 );
				end if;
				
				case state_i is
					when S0_INIT =>
						if lagrange_en = '1' then
							state_i <= S1_RUN;
						end if;
						
					when S1_RUN => -- data 0/1
						rom_a0 <= rom_addr2;
						rom_a1 <= rom_addr3;
						
						i_mac.en  <= '1';
						
						rom_ptr <= rom_ptr + PTR_INC;
						state_i <= S2_RUN;
						
						if rom_ptr > 6144 then
							i_mac.en  <= '0';
							coe_final( 0 ) <= '1';
							state_i <= S0_INIT;
						end if;
						
					when S2_RUN => -- data 2/3
						
						i_mac.acc <= '1';
						i_mac.cmp <= '1';
						
						state_i <= S1_RUN;
						
				end case;
			end if;
		end if;
	end process state_i_process;
	
	state_o_process : process( clk )
	begin
		if rising_edge( clk ) then
			o_fir_fin <= coe_final( coe_final'length-1 );
			o_fir_step <= '0';
			o_fir_data <= ( others => '0' );
		
			if rst = '1' then
				state_o <= '0';
				o_fir_fin <= '0';
			elsif state_o = '0' then
				if lagrange_en = '1' then
					state_o <= '1';
				end if;
			else
				o_fir_data <= coe_sum( 69 downto 35 );
				o_fir_step <= o_mac.en;
				
				if coe_final( coe_final'length-1 ) = '1' then
					state_o <= '0';
				end if;
				
			end if;
		end if;
	end process state_o_process;
	
end rtl;
