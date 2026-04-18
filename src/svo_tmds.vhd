library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity svo_tmds is
    port (
        clk    : in  std_logic;
        resetn : in  std_logic;
        de     : in  std_logic;
        ctrl   : in  std_logic_vector(1 downto 0);
        din    : in  std_logic_vector(7 downto 0);
        dout   : out std_logic_vector(9 downto 0)
    );
end entity;

architecture rtl of svo_tmds is
    signal cnt : integer range -255 to 255 := 0;
    signal dout_reg : std_logic_vector(9 downto 0) := (others => '0');

    function count_ones(s : std_logic_vector(7 downto 0)) return integer is
        variable n : integer := 0;
    begin
        for i in 0 to 7 loop
            if s(i) = '1' then n := n + 1; end if;
        end loop;
        return n;
    end function;

begin
    dout <= dout_reg;

    process(clk)
        variable q_m : std_logic_vector(8 downto 0);
        variable n1d, n1qm, n0qm : integer;
    begin
        if rising_edge(clk) then
            if resetn = '0' then
                cnt <= 0;
                dout_reg <= (others => '0');
            elsif de = '0' then
                cnt <= 0;
                case ctrl is
                    when "00" => dout_reg <= "1101010100";
                    when "01" => dout_reg <= "0010101011";
                    when "10" => dout_reg <= "0101010100";
                    when others => dout_reg <= "1010101011";
                end case;
            else
                n1d := count_ones(din);
                if (n1d > 4) or (n1d = 4 and din(0) = '0') then
                    q_m(0) := din(0);
                    for i in 1 to 7 loop q_m(i) := q_m(i-1) xnor din(i); end loop;
                    q_m(8) := '0';
                else
                    q_m(0) := din(0);
                    for i in 1 to 7 loop q_m(i) := q_m(i-1) xor din(i); end loop;
                    q_m(8) := '1';
                end if;

                n1qm := count_ones(q_m(7 downto 0));
                n0qm := 8 - n1qm;

                if (cnt = 0) or (n1qm = n0qm) then
                    dout_reg(9) <= not q_m(8);
                    dout_reg(8) <= q_m(8);
                    if q_m(8) = '1' then
                        dout_reg(7 downto 0) <= q_m(7 downto 0);
                        cnt <= cnt + (n1qm - n0qm);
                    else
                        dout_reg(7 downto 0) <= not q_m(7 downto 0);
                        cnt <= cnt + (n0qm - n1qm);
                    end if;
                elsif ((cnt > 0) and (n1qm > n0qm)) or ((cnt < 0) and (n0qm > n1qm)) then
                    dout_reg(9) <= '1';
                    dout_reg(8) <= q_m(8);
                    dout_reg(7 downto 0) <= not q_m(7 downto 0);
                    if q_m(8) = '1' then
                        cnt <= cnt + (n0qm - n1qm) + 2;
                    else
                        cnt <= cnt + (n0qm - n1qm);
                    end if;
                else
                    dout_reg(9) <= '0';
                    dout_reg(8) <= q_m(8);
                    dout_reg(7 downto 0) <= q_m(7 downto 0);
                    if q_m(8) = '1' then
                        cnt <= cnt + (n1qm - n0qm);
                    else
                        cnt <= cnt + (n1qm - n0qm) - 2;
                    end if;
                end if;
            end if;
        end if;
    end process;
end rtl;