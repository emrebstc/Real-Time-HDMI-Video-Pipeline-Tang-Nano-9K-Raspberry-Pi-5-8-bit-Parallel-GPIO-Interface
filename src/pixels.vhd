library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pixels is
    generic (
        SVO_HOR_PIXELS : integer := 1024;
        SVO_VER_PIXELS : integer := 600
    );
    port (  
        clk, resetn     : in  std_logic;
        out_axis_tvalid : out std_logic;
        out_axis_tready : in  std_logic;
        out_axis_tdata  : out std_logic_vector(23 downto 0);
        out_axis_tuser  : out std_logic_vector(0 downto 0);

        pi_pclk          : in  std_logic;
        pi_valid         : in  std_logic;
        pi_data          : in  std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of pixels is

    component Gowin_SDPB_24_16384
        port (
            dout: out std_logic_vector(23 downto 0);
            clka: in std_logic;
            cea: in std_logic;
            reseta: in std_logic;
            clkb: in std_logic;
            ceb: in std_logic;
            resetb: in std_logic;
            oce: in std_logic;
            ada: in std_logic_vector(13 downto 0);
            din: in std_logic_vector(23 downto 0);
            adb: in std_logic_vector(13 downto 0)
        );
    end component;

    signal rgb_assemble  : std_logic_vector(23 downto 0);
    signal byte_cnt      : integer range 0 to 2 := 0;
    signal pclk_sync     : std_logic_vector(2 downto 0) := "000";
    
    signal wr_addr       : unsigned(13 downto 0) := (others => '0');
    signal rd_addr       : unsigned(13 downto 0) := (others => '0');
    signal ram_wr_en     : std_logic := '0';
    signal ram_out       : std_logic_vector(23 downto 0);
    
    signal pix_cnt       : integer range 0 to 2047 := 0;
    signal line_cnt      : integer range 0 to 1023 := 0;

    signal rst_internal  : std_logic;

    constant WIN_X_START : integer := 448; 
    constant WIN_Y_START : integer := 236; 

begin

    rst_internal <= not resetn;

    out_axis_tvalid <= '1';

    process(clk)
    begin
        if rising_edge(clk) then
            pclk_sync <= pclk_sync(1 downto 0) & pi_pclk;
            ram_wr_en <= '0';

            if pi_valid = '0' then
                byte_cnt <= 0;
                wr_addr <= (others => '0');
            else
                if pclk_sync(2 downto 1) = "01" then
                    if byte_cnt = 0 then
                        rgb_assemble(23 downto 16) <= pi_data;
                        byte_cnt <= 1;
                    elsif byte_cnt = 1 then
                        rgb_assemble(15 downto 8) <= pi_data;
                        byte_cnt <= 2;
                    else
                        rgb_assemble(7 downto 0) <= pi_data;
                        byte_cnt <= 0;
                        ram_wr_en <= '1';
                        if wr_addr < 16383 then
                            wr_addr <= wr_addr + 1;
                        else
                            wr_addr <= (others => '0');
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    video_buffer_inst: Gowin_SDPB_24_16384
        port map (
            clka   => clk,
            cea    => ram_wr_en,
            reseta => rst_internal, 
            ada    => std_logic_vector(wr_addr),
            din    => rgb_assemble,
            
            clkb   => clk,
            ceb    => '1',
            resetb => rst_internal,
            oce    => '1',
            adb    => std_logic_vector(rd_addr),
            dout   => ram_out
        );

    process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                pix_cnt <= 0; 
                line_cnt <= 0;
                rd_addr <= (others => '0');
                out_axis_tuser(0) <= '0';
            else
                if out_axis_tready = '1' then
                    
                    if (pix_cnt >= WIN_X_START and pix_cnt < WIN_X_START + 128) and
                       (line_cnt >= WIN_Y_START and line_cnt < WIN_Y_START + 128) then
                        out_axis_tdata <= ram_out;
                        rd_addr <= rd_addr + 1;
                    else
                        out_axis_tdata <= x"101010"; 
                    end if;

                    if pix_cnt < SVO_HOR_PIXELS - 1 then
                        pix_cnt <= pix_cnt + 1;
                    else
                        pix_cnt <= 0;
                        if line_cnt < SVO_VER_PIXELS - 1 then
                            line_cnt <= line_cnt + 1;
                        else
                            line_cnt <= 0;
                            rd_addr <= (others => '0'); 
                        end if;
                    end if;
                end if;

                if pix_cnt = 0 and line_cnt = 0 then
                    out_axis_tuser(0) <= '1';
                else
                    out_axis_tuser(0) <= '0';
                end if;
            end if;
        end if;
    end process;

end rtl;