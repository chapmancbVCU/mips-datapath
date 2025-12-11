-------------------------------------------------------------------------------
--  npkips.vhd: Simple non-pipelined MIPS processor
--  Egre 426: Computer organization and design
--  Needs pkips in pkg_npkips.vhd
-------------------------------------------------------------------------------
LIBRARY IEEE;
USE work.all;
USE IEEE.Std_Logic_1164.all; 
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use pkg_npkips.all;
entity npkips is
  port(res:     in    std_logic;
       clk:     in    std_logic;
       maddr:   out   STD_LOGIC_vector(31 downto 0);
       data:    inout STD_LOGIC_vector(31 downto 0);
       nrd:     out   std_logic := '1';
       nwr:     out   std_logic := '1'
       );
  end;

architecture arch of npkips is
----Types, subtypes, and constants
  type regfiletype is array(0 to 31) of std_logic_vector(31 downto 0);
  type memtype is array(0 to memsize - 1) of std_logic_vector(31 downto 0);
  subtype dword30 is STD_LOGIC_vector(29 downto 0);
----Global signals
  signal op:  STD_LOGIC_VECTOR(5 downto 0);
  signal iRS, iRT, iRD: integer range 0 to 31; -- Address of RS, RT, RD
  signal iPC: integer range 0 to MEMSIZE - 1;
  signal iALUout: integer;
  --signal RS, RT, RD: std_logic_vector(31 downto 0);
  signal n: std_logic_vector(15 downto 0);
  signal shamt: std_logic_vector(10 downto 6);
  signal func: std_logic_vector(5 downto 0);
  signal addr: std_logic_vector(25 downto 0);
  signal S: A_State;
  -- Registers
  signal ir:  STD_LOGIC_vector(31 downto 0) := (others => 'X'); -- IR    
  signal pc:  STD_LOGIC_vector(31 downto 0) := (others => 'X'); -- PC    
  --signal bta: STD_LOGIC_vector(31 downto 0) := (others => 'X'); -- BTA   
  signal a:   STD_LOGIC_vector(31 downto 0) := (others => 'X'); -- A     
  signal b:   STD_LOGIC_vector(31 downto 0) := (others => 'X'); -- B     
  signal mdr: STD_LOGIC_vector(31 downto 0) := (others => 'X'); -- MDR
  signal ALUOUT: STD_LOGIC_vector(31 downto 0) := (others => 'X'); -- ALUOUT
  signal gpr: regfiletype := (others => (others => 'X')); -- GPR 
  -- Memory  
  signal M: memtype := (others => (others => 'X')); -- Memory
  function extend32(n: in STD_LOGIC_vector(15 downto 0)) return STD_LOGIC_vector is 
        variable nextend: STD_LOGIC_vector(31 downto 0);
    begin
        nextend(15 downto 0) := n;
        nextend(31 downto 16) := (others => n(15));
        return nextend;
    end;
  function extend30(n: in nofst) return std_logic_vector is 
    variable nextend: std_logic_vector(29 downto 0);
    begin
        nextend(15 downto 0) := n;
        nextend(29 downto 16) := (others => n(15));
        return nextend;
    end;
-- for debug only
--signal RS, RT, RD: std_logic_vector(31 downto 0);
--Type Inst_type is (J, BEQ, R_TYPE, LW, SW, ADDI);
--signal inst: inst_type;
----------------
begin
-- For debug only    
--Rs <= GPR(iRS);
--Rt <= GPR(iRT);
--Rd <= GPR(iRD);
--process(op)
--begin
--    case op is
--        when op_lw => inst <= LW;
--        when op_sw => inst <= SW;
--        when op_R_type => inst <= R_type;
--        when op_j => inst <= J;
--        when op_beq => inst <= BEQ;
--       when op_addi => inst <= ADDI;
--        when others => null;
--    end case;
--end process;
-----------
    U1: entity work.cu(arch) port map( clk, res, op, func, s); 
    OP <= IR(31 downto 26);
    iRS <= CONV_INTEGER(IR(25 downto 21));
    iRT <= CONV_INTEGER(IR(20 downto 16));
    iRD <= CONV_INTEGER(IR(15 downto 11));
    iPC <= CONV_INTEGER(PC);
    n <= IR(15 downto 0);
    shamt <= IR(10 downto 6);
    func <= IR(5 downto 0);
    addr <= IR(25 downto 0);
-- generate rd and wr signals    
    rdwr: process(clk)
    begin
        if clk'event then 
            if clk = '0' then
                case S is
                    when S0 | S3 =>  -- memory read states
                        nrd <= '0';
                        nwr <= '1';
                    when S5     =>  -- memory write states
                        nrd <= '1';
                        nwr <= '0';                       
                    when others =>
                        nrd <= '1';
                        nwr <= '1';
                end case;
            else
                nrd <= '1';
                nwr <= '1';
            end if;
        end if;
    end process; 
    
    write_mem: process(S)
    begin
         case S is
             when S5 =>  -- memory read states
                 data <= b;
                 --ALUout <= b;      -- original stmt data <= b;
                 --data <= ALUout;
             when others =>
                data <= (others => 'Z');
         end case;
    end process; 
   
    do_address: process(S, PC, ALUout)
    begin
        case S is
            when S0 =>
                maddr <= PC;
            when S3 | S5 =>                  -- was when S3 | S5 => maddr <= ALUout;
                maddr <= ALUout;
            --when S5 => ALUout <= B;      -- did not exist until recent change noted above
            when others =>
                maddr <= (others => 'Z');
        end case;        
    end process;
    
    process(res, clk)
    begin
       -- data <= (others => 'Z');
        if res = '1' then
            pc <= (others => '0');
        elsif clk'event and clk = '1' then
            case S is
                when S0 =>
                    PC <= PC + 4;
                    IR <= data; -- Memory read
                when S1 =>
                    if iRS = 0 then
                        A <= (others => '0');
                    else
                        A <= GPR(iRS) after 4 ns;
                    end if;
                    if iRT = 0 then
                        B <= (others => '0');
                   else
                        B <= GPR(iRT) after 4 ns;
                    end if;
                    ALUout <= PC + (extend30(n) & "00");
                when S2 =>  -- LW or SW
                    ALUout <= A +extend32(n);-- (extend30(n) & "00");
                when S3 =>
                    MDR <= data; -- Memory read
                when S4 =>
                    GPR(iRt) <= MDR after 4 ns;
                when S5 =>
                    null;
        --            data <= B;
                when S6 =>
                    case func is
                        when func_add =>
                            ALUout <= A + B after 7 ns;
                        when others =>
                            --ALUout <= A + B;-- after 7 ns;
                            NULL;
                        end case;    
                when S7 =>
                    GPR(iRd) <= ALUout after 4 ns;
                when S8 =>
                    if A = B then
                        PC <= ALUout;
                    end if;    
                when S9 =>
                    PC <= PC(31 downto 28) & addr & "00";
                when S11 =>
                    ALUout <= A + extend32(n); 
                when S12 =>
                    GPR(iRT) <= ALUout after 4 ns; 
                when others =>
                     null;                                        
            end case;
        end if;
    end process;
end;
