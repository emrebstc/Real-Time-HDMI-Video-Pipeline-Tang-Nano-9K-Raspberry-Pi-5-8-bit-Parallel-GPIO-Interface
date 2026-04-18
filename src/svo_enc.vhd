library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity svo_enc is
    generic (
      SVO_HOR_PIXELS : integer := 1024;
      SVO_VER_PIXELS : integer := 600;

      SVO_VER_FRONT_PORCH : integer := 3;
      SVO_VER_SYNC        : integer := 10;
      SVO_VER_BACK_PORCH  : integer := 11;

      SVO_HOR_FRONT_PORCH : integer := 48;
      SVO_HOR_SYNC        : integer := 96;
      SVO_HOR_BACK_PORCH  : integer := 144;

      SVO_BITS_PER_PIXEL  : integer := 24 
    );
    port (
        clk             : in  std_logic;
        resetn          : in  std_logic;
        in_axis_tvalid  : in  std_logic;
        in_axis_tready  : out std_logic;
        in_axis_tdata   : in  std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
        in_axis_tuser   : in  std_logic_vector(0 downto 0);
        out_axis_tvalid : out std_logic;
        out_axis_tready : in  std_logic;
        out_axis_tdata  : out std_logic_vector(SVO_BITS_PER_PIXEL-1 downto 0);
        out_axis_tuser  : out std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of svo_enc is
    signal h_cnt : integer range 0 to 2047 := 0;
    signal v_cnt : integer range 0 to 2047 := 0;
    signal h_sync, v_sync, de : std_logic;
begin

    de <= '1' when (h_cnt < SVO_HOR_PIXELS) and (v_cnt < SVO_VER_PIXELS) else '0';
    
    h_sync <= '1' when (h_cnt >= SVO_HOR_PIXELS + SVO_HOR_FRONT_PORCH) and 
                       (h_cnt < SVO_HOR_PIXELS + SVO_HOR_FRONT_PORCH + SVO_HOR_SYNC) else '0';
                       
    v_sync <= '1' when (v_cnt >= SVO_VER_PIXELS + SVO_VER_FRONT_PORCH) and 
                       (v_cnt < SVO_VER_PIXELS + SVO_VER_FRONT_PORCH + SVO_VER_SYNC) else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                h_cnt <= 0;
                v_cnt <= 0;
                out_axis_tvalid <= '0';
            else
                if out_axis_tready = '1' then

                    out_axis_tvalid <= de; 
                    

                    if de = '1' then
                        out_axis_tdata <= in_axis_tdata;
                    else
                        out_axis_tdata <= (others => '0');
                    end if;

                    out_axis_tuser <= (not de) & v_sync & h_sync & in_axis_tuser(0);

                    if h_cnt = (SVO_HOR_PIXELS + SVO_HOR_FRONT_PORCH + SVO_HOR_SYNC + SVO_HOR_BACK_PORCH - 1) then
                        h_cnt <= 0;
                        if v_cnt = (SVO_VER_PIXELS + SVO_VER_FRONT_PORCH + SVO_VER_SYNC + SVO_VER_BACK_PORCH - 1) then
                            v_cnt <= 0;
                        else
                            v_cnt <= v_cnt + 1;
                        end if;
                    else
                        h_cnt <= h_cnt + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    in_axis_tready <= de and out_axis_tready;

end rtl;