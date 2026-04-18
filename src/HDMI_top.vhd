library ieee;
use ieee.std_logic_1164.all;

entity HDMI_top is
    port (
        clk        : in  std_logic; -- 27 MHz
        resetn     : in  std_logic;

        pi_pclk, pi_valid  : in std_logic;
        pi_data            : in  std_logic_vector(7 downto 0);

        tmds_clk_n : out std_logic;
        tmds_clk_p : out std_logic;
        tmds_d_n   : out std_logic_vector(2 downto 0);
        tmds_d_p   : out std_logic_vector(2 downto 0)
    );
end entity;

   architecture rtl of HDMI_top is

    signal clk_p, clk_p5, pll_lock, sys_resetn : std_logic;
    signal combined_reset : std_logic;

    component Gowin_rPLL port (  
        clkin  : in  std_logic; -- 27MHz main clock
        clkout : out std_logic; -- 200 MHz PLL output clock
        lock   : out std_logic; 
        clkfb  : in  std_logic 
    ); 
    end component;

    component Gowin_CLKDIV port (  
        clkout : out std_logic;  -- 40 MHz out
        hclkin : in std_logic;   --200MHz in
        resetn : in std_logic 
    );  
    end component;

    component Reset_Sync port (  
        clk, ext_reset : in std_logic;  
        resetn : out std_logic 
    );  
    end component;
    
    component svo_hdmi_top
        generic ( SVO_HOR_PIXELS : integer; SVO_VER_PIXELS : integer );  
        port (  
            clk, resetn, clk_pixel, clk_5x_pixel, locked : in std_logic;
            tmds_clk_n, tmds_clk_p : out std_logic;
            tmds_d_n, tmds_d_p : out std_logic_vector(2 downto 0);
            pi_pclk       : in std_logic; 
            pi_valid      : in std_logic;
            pi_data       : in  std_logic_vector(7 downto 0)
        );
    end component;

begin

    combined_reset <= resetn and pll_lock;

    u_pll : Gowin_rPLL port map (
      clkin  => clk,     -- Input (27 MHz)
      clkout => clk_p5,  -- Output (200 MHz)
      lock   => pll_lock,
      clkfb  => clk_p5
    );
    
    u_div : Gowin_CLKDIV port map (
     clk_p, clk_p5, pll_lock
    );
    
    u_reset : Reset_Sync port map (
     clk_p, combined_reset, sys_resetn
    );


    u_hdmi : svo_hdmi_top 
        generic map (SVO_HOR_PIXELS => 1024, SVO_VER_PIXELS => 600) 
        port map (
            clk => clk_p, resetn => sys_resetn,
            clk_pixel => clk_p, clk_5x_pixel => clk_p5,
            locked => pll_lock,
            tmds_clk_n => tmds_clk_n, tmds_clk_p => tmds_clk_p,
            tmds_d_n => tmds_d_n, tmds_d_p => tmds_d_p, pi_pclk => pi_pclk, pi_valid => pi_valid, pi_data => pi_data 
        );

end rtl;
