library ieee;
use ieee.std_logic_1164.all;

entity svo_hdmi_top is
    generic (
        SVO_HOR_PIXELS : integer := 1024;
        SVO_VER_PIXELS : integer := 600
    );
    port (
        clk           : in  std_logic;
        resetn        : in  std_logic;
        clk_pixel     : in  std_logic;
        clk_5x_pixel  : in  std_logic;
        locked        : in  std_logic;
        tmds_clk_n    : out std_logic;
        tmds_clk_p    : out std_logic;
        tmds_d_n      : out std_logic_vector(2 downto 0);
        tmds_d_p      : out std_logic_vector(2 downto 0);

        pi_pclk       : in std_logic; 
        pi_valid      : in std_logic;
        pi_data       : in  std_logic_vector(7 downto 0)  
    );
end entity;

architecture rtl of svo_hdmi_top is

    component pixels
        generic ( SVO_HOR_PIXELS : integer; SVO_VER_PIXELS : integer );
        port ( 
          clk, resetn     : in std_logic;
          out_axis_tvalid : out std_logic; 
          out_axis_tready : in std_logic; 
          out_axis_tdata : out std_logic_vector(23 downto 0); 
          out_axis_tuser : out std_logic_vector(0 downto 0);
          pi_pclk        : in std_logic;
          pi_valid       : in std_logic;    
          pi_data        : in  std_logic_vector(7 downto 0) );
    end component;

    component svo_enc
        generic ( SVO_HOR_PIXELS : integer; SVO_VER_PIXELS : integer );
        port ( clk, resetn : in std_logic; in_axis_tvalid : in std_logic; in_axis_tready : out std_logic;
               in_axis_tdata : in std_logic_vector(23 downto 0); in_axis_tuser : in std_logic_vector(0 downto 0);
               out_axis_tvalid : out std_logic; out_axis_tready : in std_logic;
               out_axis_tdata : out std_logic_vector(23 downto 0); out_axis_tuser : out std_logic_vector(3 downto 0) );
    end component;

    component svo_tmds
        port ( clk, resetn, de : in std_logic; ctrl : in std_logic_vector(1 downto 0);
               din : in std_logic_vector(7 downto 0); dout : out std_logic_vector(9 downto 0) );
    end component;

    component OSER10
        generic ( GSREN : string := "false"; LSREN : string := "true" );
        port ( Q : out std_logic; D0, D1, D2, D3, D4, D5, D6, D7, D8, D9 : in std_logic;
               PCLK, FCLK, RESET : in std_logic );
    end component;

    component ELVDS_OBUF
        port ( I : in std_logic; O, OB : out std_logic );
    end component;

    signal video_tvalid, video_tready : std_logic;
    signal video_enc_tvalid, video_enc_tready : std_logic; 
    signal video_tdata, video_enc_tdata : std_logic_vector(23 downto 0);
    signal video_tuser : std_logic_vector(0 downto 0);
    signal video_enc_tuser : std_logic_vector(3 downto 0);
    
    type tmds_array is array (0 to 3) of std_logic_vector(9 downto 0);
    signal tmds_10b : tmds_array;
    signal ser_out : std_logic_vector(3 downto 0);
    signal oser_reset : std_logic;
    signal tmds_de : std_logic;
    signal tmds_ctrl_0 : std_logic_vector(1 downto 0);

begin
    oser_reset <= not locked;
    tmds_de <= not video_enc_tuser(3);
    tmds_ctrl_0 <= video_enc_tuser(2 downto 1);
    video_enc_tready <= '1';

    u_pixels : pixels 
        generic map (SVO_HOR_PIXELS => SVO_HOR_PIXELS, SVO_VER_PIXELS => SVO_VER_PIXELS)
        port map (clk_pixel, resetn, video_tvalid, video_tready, video_tdata, video_tuser, pi_pclk, pi_valid, pi_data);

    u_enc : svo_enc 
        generic map (SVO_HOR_PIXELS => SVO_HOR_PIXELS, SVO_VER_PIXELS => SVO_VER_PIXELS)
        port map (clk_pixel, resetn, video_tvalid, video_tready, video_tdata, video_tuser, 
                 video_enc_tvalid, video_enc_tready, video_enc_tdata, video_enc_tuser);

    u_tmds_blue : svo_tmds port map (clk_pixel, resetn, tmds_de, tmds_ctrl_0, video_enc_tdata(7 downto 0), tmds_10b(0));
    u_tmds_green: svo_tmds port map (clk_pixel, resetn, tmds_de, "00", video_enc_tdata(15 downto 8), tmds_10b(1));
    u_tmds_red  : svo_tmds port map (clk_pixel, resetn, tmds_de, "00", video_enc_tdata(23 downto 16), tmds_10b(2));
    
    tmds_10b(3) <= "1111100000";

    gen_ser: for i in 0 to 3 generate
        u_oser : OSER10 port map (
            Q => ser_out(i), PCLK => clk_pixel, FCLK => clk_5x_pixel, RESET => oser_reset,
            D0 => tmds_10b(i)(0), D1 => tmds_10b(i)(1), D2 => tmds_10b(i)(2), D3 => tmds_10b(i)(3),
            D4 => tmds_10b(i)(4), D5 => tmds_10b(i)(5), D6 => tmds_10b(i)(6), D7 => tmds_10b(i)(7),
            D8 => tmds_10b(i)(8), D9 => tmds_10b(i)(9)
        );
    end generate;

    u_buf_0   : ELVDS_OBUF port map (ser_out(0), tmds_d_p(0), tmds_d_n(0));
    u_buf_1   : ELVDS_OBUF port map (ser_out(1), tmds_d_p(1), tmds_d_n(1));
    u_buf_2   : ELVDS_OBUF port map (ser_out(2), tmds_d_p(2), tmds_d_n(2));
    u_buf_clk : ELVDS_OBUF port map (ser_out(3), tmds_clk_p, tmds_clk_n);

end rtl;