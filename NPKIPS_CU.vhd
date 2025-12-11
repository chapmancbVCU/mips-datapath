LiBRARY IEEE;
USE work.ALL;
USE IEEE.std_logic_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use pkg_npkips.all;
ENTITY CU IS
    PORT (CLK   : IN  STD_LOGIC;
          RES   : IN  STD_LOGIC;
          OP    : in  STD_LOGIC_VECTOR(5 downto 0);
          FUNC  : in  STD_LOGIC_VECTOR(5 downto 0);
          S     : OUT A_STATE
         );
END ENTITY CU;

ARCHITECTURE arch OF CU IS
    SIGNAL STATE, Next_State : A_State;
BEGIN
    S <= STATE;
    PROCESS(State, op)
BEGIN
    CASE State IS
        WHEN S0 =>
            Next_State <= S1;
        WHEN S1 =>
            CASE OP IS
                WHEN op_lw | op_sw =>
                    Next_State <= S2;
                WHEN op_R_type =>
                    if FUNC = Func_jr then 
                       Next_State <= S10;
                    else 
                       Next_State <= S6;
                    end if;
                WHEN op_BEQ =>
                    Next_State <= S8;
                WHEN op_J =>
                    Next_State <= S9;
                WHEN Op_addi =>
                    Next_State <= S11;
                WHEN others =>
                    NEXT_STATE <= S0;
            END CASE;
        WHEN S2 =>
            IF OP = op_lw then
                Next_State <= S3;
            ELSE
                Next_State <= S5;
            END IF;
        WHEN S3 =>
            NEXT_STATE <= S4;
        WHEN S4 | S5 | S7 | S8 | S9 | S10 | S12 =>
            NEXT_STATE <= S0;
        WHEN S6 =>
            NEXT_STATE <= S7;
        WHEN S11 =>
             NEXT_STATE <= S12;           
        WHEN others =>
            Next_State <= S0;
        END CASE;
    END PROCESS;
    -- 
    PROCESS(CLK, RES)
    BEGIN
        IF (RES = '1') THEN
            State <= S0;
        ELSIF clk'event and clk = '1' THEN
            State <= Next_State;
        END IF;
    END PROCESS;
END arch;
