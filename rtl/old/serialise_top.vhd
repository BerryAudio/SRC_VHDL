----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    09:19:14 06/19/2015 
-- Design Name: 
-- Module Name:    serialise_top - rtl 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity serialise_top is
	port (
		clk			: in  std_logic;
		
		i_sample_0		: in  signed( 23 downto 0 );
		i_sample_1		: in  signed( 23 downto 0 );
		i_sample_en		: in  std_logic;
		
		o_sample_0		: out signed( 23 downto 0 ) := ( others => '0' );
		o_sample_1		: out signed( 23 downto 0 ) := ( others => '0' );
		o_sample_en		: out std_logic := '0'
	);
	
	attribute equivalent_register_removal	: string;
	attribute register_balancing				: string;
	attribute equivalent_register_removal of serialise_top : entity is "no";
	attribute register_balancing			  of serialise_top : entity is "no";
end serialise_top;

architecture rtl of serialise_top is
	signal i_sr_data	: signed( 47 downto 0 ) := ( others => '0' );
	signal i_sr_en		: std_logic := '0';

	signal o_sr_data	: signed( 47 downto 0 ) := ( others => '0' );
	signal o_sr_en		: signed( 47 downto 0 ) := ( others => '0' );

begin

	o_sample_0  <= o_sr_data( 47 downto 24 );
	o_sample_1  <= o_sr_data( 23 downto  0 );
	o_sample_en <= o_sr_en( 47 );

	sr_process : process( clk )
	begin
		if rising_edge( clk ) then
			i_sr_data <= i_sr_data( 46 downto 0 ) & '0';
			i_sr_en	 <= i_sample_en;
			
			o_sr_data <= o_sr_data( 46 downto 0 ) & i_sr_data( 47 );
			o_sr_en   <= o_sr_en  ( 46 downto 0 ) & i_sr_en;
			
			if i_sample_en = '1' then
				i_sr_data <= i_sample_0 & i_sample_1;
			end if;
		end if;
	end process sr_process;

end rtl;

