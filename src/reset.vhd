library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity Reset_Sync is
    port (
        clk       : in  std_logic;
        ext_reset : in  std_logic;
        resetn    : out std_logic
    );
end entity;

architecture rtl of Reset_Sync is
    signal reset_cnt : std_logic_vector(3 downto 0) := (others => '0');
    signal internal_resetn : std_logic;
begin
    process(clk, ext_reset)
    begin
        if ext_reset = '0' then
            reset_cnt <= (others => '0');
        elsif rising_edge(clk) then
            if internal_resetn = '0' then
                reset_cnt <= reset_cnt + 1;
            end if;
        end if;
    end process;

    internal_resetn <= '1' when reset_cnt = "1111" else '0';
    resetn <= internal_resetn;
end rtl;