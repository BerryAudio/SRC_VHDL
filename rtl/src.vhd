library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package src is
	
	--******************************************************************
	-- constants - GENERAL
	--******************************************************************
	constant ROM_FILE_SRC			: string  := "rom/rom_src_6144x32b_cand.txt";
	constant ROM_FILE_BIT			: natural range 24 to 32 := 32;
	constant ROM_FILE_HB				: string  := "rom/rom_hb.txt";
	
	constant INTERP_MAC_PIPELINE	: boolean := TRUE;
	constant INTERP_PTR_INCREMENT	: integer := 64;
	constant RING_BUF_PTR_OFFSET	: integer := 16;
	constant REG_AVE_WIDTH			: integer range 4 to 6 := 6;
	
	constant NOISE_LFSR_WIDTH		: integer range 11 to 34 := 11;
	constant NOISE_FILT_WIDTH		: integer range 11 to 34 := 16;

	--******************************************************************
	-- types
	--******************************************************************
	-- ports for math stuff - curretly only mac, and only
	-- to reduce port clutter really
	--******************************************************************
	type mac_i is record
		en			: std_logic;
		acc		: std_logic;
		cmp		: std_logic;
		data00	: signed( 34 downto 0 );
		data01	: signed( 34 downto 0 );
		data10	: signed( 34 downto 0 );
		data11	: signed( 34 downto 0 );
	end record mac_i;
	
	type mac_o is record
		en			: std_logic;
		data0		: signed( 69 downto 0 );
		data1		: signed( 69 downto 0 );
	end record mac_o;
	
	constant mac_i_init : mac_i := (
		en			=> '0',
		acc		=> '0',
		cmp		=> '0',
		data00	=> ( others => '0' ),
		data01	=> ( others => '0' ),
		data10	=> ( others => '0' ),
		data11	=> ( others => '0' )
	);
	
	constant mac_o_init : mac_o := (
		en			=> '0',
		data0		=> ( others => '0' ),
		data1		=> ( others => '0' )
	);
	
	--******************************************************************
	-- components
	--******************************************************************
	-- top level components
	--******************************************************************
	component regulator_top is
		generic (
			CLOCK_COUNT		: integer := 512
		);
		port (
			clk				: in  std_logic;
			rst				: in  std_logic;
			
			i_sample_en		: in  std_logic;
			o_sample_en		: in  std_logic;
			i_fifo_level	: in  unsigned( 10 downto 0 );
			
			o_ratio			: out unsigned( 23 downto 0 );
			o_locked			: out std_logic;
			o_ratio_en		: out std_logic;
		
			div_busy			: in  std_logic;
			div_remainder	: in  unsigned( 24 downto 0 );
			
			div_en			: out std_logic;
			div_divisor		: out unsigned( 26 downto 0 );
			div_dividend	: out unsigned( 26 downto 0 )
		);
	end component regulator_top;
	
	component filter_top is
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
			
			i_phase		: in  unsigned(  5 downto 0 );
			i_delta		: in  unsigned( 21 downto 0 );
			i_en			: in  std_logic;

			rd_en			: out std_logic := '0';
			rd_step		: out std_logic := '0';
			rd_data0		: in  signed( 23 downto 0 );
			rd_data1		: in  signed( 23 downto 0 );
			
			o_data_en	: out std_logic := '0';
			o_data0		: out signed( 34 downto 0 );
			o_data1		: out signed( 34 downto 0 );
		
			-- mac signals
			mac_sel			: out std_logic_vector( 1 downto 0 );
			
			o_mac0			: in  mac_o;
			o_mac2			: in  mac_o;
			
			i_mac0			: out mac_i;
			i_mac1			: out mac_i;
			i_mac2			: out mac_i;
			
			-- mac signals
			i_div_remainder: in  unsigned( 24 downto 0 );
			o_div_en			: out std_logic := '0';
			o_div_dividend	: out unsigned( 26 downto 0 );
			o_div_divisor	: out unsigned( 26 downto 0 )
		);
	end component filter_top;
	
	component hb_filter_top is
		generic (
			ROM_FILE : string := ROM_FILE_HB
		);
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
			
			i_data_en0	: in  std_logic;
			i_data_en1	: in  std_logic;
			i_data0		: in  signed( 34 downto 0 );
			i_data1		: in  signed( 34 downto 0 );
			
			o_data_en	: out std_logic;
			o_data0		: out signed( 34 downto 0 );
			o_data1		: out signed( 34 downto 0 );
			
			o_mac			: in  mac_o;
			i_mac			: out mac_i
		);
	end component hb_filter_top;

	component dither_top is
		generic (
			LFSR_WIDTH	: integer := NOISE_LFSR_WIDTH;
			FILT_WIDTH	: integer := NOISE_FILT_WIDTH
		);
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
			ctrl_width	: in  std_logic_vector( 1 downto 0 );
			
			i_data_en	: in  std_logic;
			i_data0		: in  signed( 34 downto 0 );
			i_data1		: in  signed( 34 downto 0 );
			
			o_data_en	: out std_logic;
			o_data0		: out signed( 23 downto 0 );
			o_data1		: out signed( 23 downto 0 );
			
			i_mac			: out mac_i;
			o_mac			: in  mac_o
		);
	end component dither_top;

	--******************************************************************
	-- interpolator components
	--******************************************************************
	component interpolator is
		port (
			clk				: in  std_logic;
			rst				: in  std_logic;
			
			int_en			: in  std_logic;
			int_fin			: out std_logic := '0';
			
			i_phase			: in  unsigned(  5 downto 0 );
			i_delta			: in  unsigned( 21 downto 0 );
			
			fbuf_en			: out std_logic := '0';
			fbuf_data		: out signed( 34 downto 0 );
			
			mac_sel			: out std_logic;
			o_mac				: in  mac_o;
			i_mac0			: out mac_i;
			i_mac1			: out mac_i
		);
	end component interpolator;
	
	component interp_lagrange is
		port (
			clk			 : in  std_logic;
			rst			 : in  std_logic;
			
			delta			 : in  unsigned( 21 downto 0 );
			delta_en		 : in  std_logic;
			
			i_mac			 : out mac_i;
			o_mac			 : in  mac_o;
			
			lagrange_h0	 : out signed( 34 downto 0 );
			lagrange_h1	 : out signed( 34 downto 0 );
			lagrange_h2	 : out signed( 34 downto 0 );
			lagrange_h3	 : out signed( 34 downto 0 );
			lagrange_en	 : out std_logic
		);
	end component interp_lagrange;
	
	component interp_fir is
		generic (
			PTR_INC		: integer := INTERP_PTR_INCREMENT;
			ROM_FILE		: string := ROM_FILE_SRC;
			ROM_BIT		: natural range 24 to 32 := ROM_FILE_BIT
		);
		port (
			clk			 : in  std_logic;
			rst			 : in  std_logic;
			
			-- signal when complete
			o_fir_step	 : out std_logic;
			o_fir_fin	 : out std_logic;
			o_fir_data	 : out signed( 34 downto 0 );
			
			-- phase information
			phase			 : in  unsigned( 5 downto 0 );
			phase_en		 : in  std_logic;
			
			i_mac			 : out mac_i;
			o_mac			 : in  mac_o;
			
			-- lagrange coefficients
			lagrange_h0	 : in  signed( 34 downto 0 );
			lagrange_h1	 : in  signed( 34 downto 0 );
			lagrange_h2	 : in  signed( 34 downto 0 );
			lagrange_h3	 : in  signed( 34 downto 0 );
			lagrange_en	 : in  std_logic
		);
	end component interp_fir;
	
	component fir is
		port (
			clk			 	: in  std_logic;
			rst			 	: in  std_logic;
			
			-- start/end the fir convolution
			fir_en		 	: in  std_logic;
			fir_fin		 	: out std_logic;
			
			-- convolution output
			o_data_en	 	: out std_logic;
			o_data0		 	: out signed( 34 downto 0 );
			o_data1		 	: out signed( 34 downto 0 );
			
			-- coefficient buffer interface
			fbuf_en		 	: out std_logic := '0';
			fbuf_cnt		 	: in  unsigned( 6 downto 0 );
			fbuf_data	 	: in  signed( 34 downto 0 );
			fbuf_accum	 	: in  signed( 34 downto 0 );
			
			-- ring buffer interface
			rbuf_en		 	: out std_logic;
			rbuf_step	 	: out std_logic;
			rbuf_data0	 	: in  signed( 23 downto 0 );
			rbuf_data1	 	: in  signed( 23 downto 0 );
			
			-- mac interfaces
			i_mac				: out mac_i;
			o_mac				: in  mac_o;
			
			-- divider interfaces
			i_div_remainder: in  unsigned( 24 downto 0 );
			o_div_en			: out std_logic;
			o_div_dividend	: out unsigned( 26 downto 0 );
			o_div_divisor	: out unsigned( 26 downto 0 )
		);
	end component fir;
	
	component fir_filter_rom is
		generic (
			ROM_FILE 	: string := ROM_FILE_SRC;
			ROM_BIT		: natural range 24 to 32 := ROM_FILE_BIT
		);
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
			
			addr0			: in  unsigned( 13 downto 0 );
			addr1			: in  unsigned( 13 downto 0 );
			
			data0			: out signed( ROM_FILE_BIT-1 downto 0 );
			data1			: out signed( ROM_FILE_BIT-1 downto 0 )
		);
	end component fir_filter_rom;

	--******************************************************************
	-- half band filter components
	--******************************************************************
	component hb_filter_rom is
		generic (
			ROM_FILE : string := ROM_FILE_HB
		);
		port (
			clk			: in  std_logic;
			
			addr			: in  unsigned( 5 downto 0 );
			data			: out signed( 34 downto 0 )
		);
	end component hb_filter_rom;
	
	component hb_ring_buffer is
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
		
			wr_en			: in  std_logic;
			wr_data0		: in  signed( 34 downto 0 );	
			wr_data1		: in  signed( 34 downto 0 );
			
			rd_en0		: in  std_logic;
			rd_en1		: in  std_logic;
			rd_step		: in  std_logic;
			rd_data0		: out signed( 34 downto 0 );
			rd_data1		: out signed( 34 downto 0 )
		);
	end component hb_ring_buffer;
	
	--******************************************************************
	-- ratio regulator components
	--******************************************************************
	component reg_ratio is
		port (
			clk				: in  std_logic;
			rst				: in  std_logic;
			
			i_fifo_level	: in  unsigned( 10 downto 0 );
			i_ratio			: in  unsigned( 23 downto 0 );
			i_ratio_en		: in  std_logic;
			o_sample_en		: in  std_logic;
			
			o_locked			: out std_logic;
			o_ratio			: out unsigned( 23 downto 0 );
			o_ratio_en		: out std_logic
		);
	end component reg_ratio;
	
	component reg_average is
		generic (
			REG_AVE_WIDTH	: integer range 0 to 6 := REG_AVE_WIDTH
		);
		port (
			clk				: in  std_logic;
			rst				: in  std_logic;
			
			ptr_rst			: in  std_logic;
			
			ratio				: in  unsigned( 23 downto 0 );
			ratio_en			: in  std_logic;
			
			ave_out			: out unsigned( 23 downto 0 );
			ave_valid		: out std_logic
		);
	end component reg_average;
	
	component reg_count is
		port (
			clk				: in  std_logic;
			rst				: in  std_logic;
			
			i_sample_en		: in  std_logic;
			i_reg_ack		: in  std_logic;
			o_reg				: out unsigned( 19 downto 0 );
			o_reg_en			: out std_logic
		);
	end component reg_count;
	
	--******************************************************************
	-- ring and fir buffer components
	--******************************************************************
	component fir_buffer is
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
			
			buf_ini		: in  std_logic;
			
			int_en		: in  std_logic;
			int_dat		: in  signed( 34 downto 0 );
			
			fir_en		: in  std_logic;
			fir_cnt		: out unsigned( 6 downto 0 ) := ( others => '0' );
			fir_dat		: out signed( 34 downto 0 ) := ( others => '0' );
			fir_accum	: out signed( 34 downto 0 ) := ( others => '0' )
		);
	end component fir_buffer;
	
	component ring_buffer is
		generic (
			PTR_OFFSET : natural range 0 to 32 := RING_BUF_PTR_OFFSET
		);
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
			
			buf_rdy		: out std_logic;
			buf_level	: out unsigned( 10 downto 0 );
			buf_ptr		: out unsigned( 23 downto 0 );
			
			fir_en		: in  std_logic;
			fir_step		: in  std_logic;
			fir_fin		: in  std_logic;
			
			locked		: in  std_logic;
			ratio			: in  unsigned( 23 downto 0 );
			
			wr_en			: in  std_logic;
			wr_data0		: in  signed( 23 downto 0 );	
			wr_data1		: in  signed( 23 downto 0 );
			
			rd_data0		: out signed( 23 downto 0 );
			rd_data1		: out signed( 23 downto 0 )
		);
	end component ring_buffer;
	
	--******************************************************************
	-- dither components
	--******************************************************************
	component dither is
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
			
			i_rand		: in  unsigned( 9 downto 0 );
			i_data		: in  signed( 34 downto 0 );
			i_data_en	: in  std_logic;
			
			o_data		: out signed( 23 downto 0 );
			o_data_en	: out std_logic
		);
	end component dither;
	
	--******************************************************************
	-- math components
	--******************************************************************
	
	component mac_mux_3 is
		port (
			clk		: in  std_logic;
			rst		: in  std_logic;
			sel		: in  std_logic_vector( 1 downto 0 );
		
			i_mac0	: in  mac_i;
			o_mac0	: out mac_o;
			
			i_mac1	: in  mac_i;
			
			i_mac2	: in  mac_i;
			o_mac2	: out mac_o
		);
	end component mac_mux_3;
	
	component mac_mux_2 is
		port (
			clk		: in  std_logic;
			rst		: in  std_logic;
			sel		: in  std_logic;
		
			i_mac0	: in  mac_i;
			o_mac0	: out mac_o;
			
			i_mac1	: in  mac_i;
			o_mac1	: out mac_o
		);
	end component mac_mux_2;
	
	component mac is
		port (
			clk		: in  std_logic;
			rst		: in  std_logic;
			
			i_mac		: in  mac_i;
			o_mac		: out mac_o
		);
	end component mac;
	
	component div_mux is 
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
			sel			: in  std_logic;
			
			i0_en			: in  std_logic;
			i0_divisor	: in  unsigned( 26 downto 0 );
			i0_dividend	: in  unsigned( 26 downto 0 );
			
			i1_en			: in  std_logic;
			i1_divisor	: in  unsigned( 26 downto 0 );
			i1_dividend	: in  unsigned( 26 downto 0 );
			
			o_busy		: out std_logic;
			o_remainder	: out unsigned( 24 downto 0 )
		);
	end component div_mux;
	
	component div is 
		port (
			clk			: in  std_logic;
			rst			: in  std_logic;
			
			i_en			: in  std_logic;
			i_divisor	: in  unsigned( 26 downto 0 );
			i_dividend	: in  unsigned( 26 downto 0 );
			
			o_busy		: out std_logic;
			o_remainder	: out unsigned( 24 downto 0 )
		);
	end component div;

	--******************************************************************
	-- function and procedure definitions
	--******************************************************************
	function COMPLEMENT( val :   signed ) return   signed;
	function COMPLEMENT( val : unsigned ) return unsigned;
end src;

package body src is
	function COMPLEMENT( val : signed ) return signed is
	begin
		return ( not( val ) + 1 );
	end function COMPLEMENT;
	
	function COMPLEMENT( val : unsigned ) return unsigned is
	begin
		return ( not( val ) + 1 );
	end function COMPLEMENT;
end src;
