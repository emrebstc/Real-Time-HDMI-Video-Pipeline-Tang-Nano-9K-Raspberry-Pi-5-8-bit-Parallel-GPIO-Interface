library ieee;
use ieee.std_logic_1164.all;

entity Gowin_CLKDIV is
    port (
        clkout  : out std_logic;
        hclkin  : in  std_logic;
        resetn  : in  std_logic
    );
end entity;

architecture rtl of Gowin_CLKDIV is
    signal gw_gnd : std_logic := '0';

    component CLKDIV
        generic (
            DIV_MODE : string := "5";
            GSREN    : string := "false"
        );
        port (
            CLKOUT : out std_logic;
            HCLKIN : in  std_logic;
            RESETN : in  std_logic;
            CALIB  : in  std_logic
        );
    end component;

begin
    clkdiv_inst : CLKDIV
        generic map (
            DIV_MODE => "5"
        )
        port map (
            CLKOUT => clkout,
            HCLKIN => hclkin,
            RESETN => resetn,
            CALIB  => gw_gnd
        );
end rtl;