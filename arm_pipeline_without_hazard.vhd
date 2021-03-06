---------------------------------------------------------------
-- arm_pipeline.vhd - PCS3612
-- Pipeline implementation of a subset of ARMv4
-- Matheus Guilherme Gonçalves - 9345126
-- Paulo Massayoshi Hirami - 8992711
-- Rafael Augusto Baptista C. das Neves - 9373372
-- Based on arm_single.vhd implementation from
-- David_Harris@hmc.edu, Sarah.Harris@unlv.edu 6 March 2014
--
-- Compile in ModelSim at the command line with the command 
-- vcom -check_synthesis -2008 arm_pipeline.vhd
-- Expect plenty of simulation warnings of metavalues detected
-- vsim -c -do "run -all" testbench
-- Expect at time 205 ns a message of
-- Failure: NO ERRORS: Simulation succeeded
-- when the value 7 is written to address 100 (0x64)
---------------------------------------------------------------

library IEEE; 
use IEEE.STD_LOGIC_1164.all; use IEEE.NUMERIC_STD_UNSIGNED.all;
entity testbench is
end;

architecture test of testbench is
  component top
    port(clk, reset:          in  STD_LOGIC;
         WriteData, DatAadr:  out STD_LOGIC_VECTOR(31 downto 0);
         MemWrite:            out STD_LOGIC);
  end component;
  signal WriteData, DataAdr:     STD_LOGIC_VECTOR(31 downto 0);
  signal clk, reset,  MemWrite:  STD_LOGIC;
begin

  -- instantiate device to be tested
  dut: top port map(clk, reset, WriteData, DataAdr, MemWrite);

  -- Generate clock with 10 ns period
  process begin
    clk <= '1';
    wait for 5 ns; 
    clk <= '0';
    wait for 5 ns;
  end process;

  -- Generate reset for first two clock cycles
  process begin
    reset <= '1';
    wait for 22 ns;
    reset <= '0';
    wait;
  end process;

  -- check that 7 gets written to address 84 
  -- at end of program
  process (clk) begin
    if (clk'event and clk = '0' and MemWrite = '1') then
      if (to_integer(DataAdr) = 100 and 
          to_integer(WriteData) = 7) then 
        report "NO ERRORS: Simulation succeeded" severity failure;
      elsif (DataAdr /= 96) then 
        report "Simulation failed" severity failure;
      end if;
    end if;
  end process;
end;

library IEEE; 
use IEEE.STD_LOGIC_1164.all; use IEEE.NUMERIC_STD_UNSIGNED.all;
entity top is -- top-level design for testing
  port(clk, reset:           in     STD_LOGIC;
       WriteData, DataAdr:   buffer STD_LOGIC_VECTOR(31 downto 0);
       MemWrite:             buffer STD_LOGIC);
end;

architecture test of top is
  component arm 
    port(clk, reset:        in  STD_LOGIC;
         PC:                out STD_LOGIC_VECTOR(31 downto 0);
         Instr:             in  STD_LOGIC_VECTOR(31 downto 0);
         MemWrite:          out STD_LOGIC;
         ALUResult, WriteData: out STD_LOGIC_VECTOR(31 downto 0);
         ReadData:          in  STD_LOGIC_VECTOR(31 downto 0));
  end component;
  component imem
    port(a:  in  STD_LOGIC_VECTOR(31 downto 0);
         rd: out STD_LOGIC_VECTOR(31 downto 0));
  end component;
  component dmem
    port(clk, we:  in STD_LOGIC;
         a, wd:    in STD_LOGIC_VECTOR(31 downto 0);
         rd:       out STD_LOGIC_VECTOR(31 downto 0));
  end component;
  signal PC, Instr, 
         ReadData: STD_LOGIC_VECTOR(31 downto 0);
begin
  -- instantiate processor and memories
  i_arm: arm port map(clk, reset, PC, Instr, MemWrite, DataAdr, 
                       WriteData, ReadData);
  i_imem: imem port map(PC, Instr);
  i_dmem: dmem port map(clk, MemWrite, DataAdr, 
                             WriteData, ReadData);
end;

-- Begin implementation

library IEEE; 
use IEEE.STD_LOGIC_1164.all; use STD.TEXTIO.all;
use IEEE.NUMERIC_STD_UNSIGNED.all; 
entity dmem is -- data memory
  port(clk, we:  in STD_LOGIC;
       a, wd:    in STD_LOGIC_VECTOR(31 downto 0);
       rd:       out STD_LOGIC_VECTOR(31 downto 0));
end;

architecture behave of dmem is
begin
  process is
    type ramtype is array (63 downto 0) of 
                    STD_LOGIC_VECTOR(31 downto 0);
    variable mem: ramtype;
  begin -- read or write memory
    loop
      if clk'event and clk = '1' then
          if (we = '1') then 
            mem(to_integer(a(7 downto 2))) := wd;
          end if;
      end if;
      rd <= mem(to_integer(a(7 downto 2))); 
      wait on clk, a;
    end loop;
  end process;
end;

library IEEE; 
use IEEE.STD_LOGIC_1164.all; use STD.TEXTIO.all;
use IEEE.NUMERIC_STD_UNSIGNED.all;  
entity imem is -- instruction memory
  port(a:  in  STD_LOGIC_VECTOR(31 downto 0);
       rd: out STD_LOGIC_VECTOR(31 downto 0));
end;
architecture behave of imem is -- instruction memory
begin
  process is
    file mem_file: TEXT;
    variable L: line;
    variable ch: character;
    variable i, index, result: integer;
    type ramtype is array (63 downto 0) of 
                    STD_LOGIC_VECTOR(31 downto 0);
    variable mem: ramtype;
  begin
    -- initialize memory from file
    for i in 0 to 63 loop -- set all contents low
      mem(i) := (others => '0'); 
    end loop;
    index := 0; 
    FILE_OPEN(mem_file, "memfile.dat", READ_MODE);
    while not endfile(mem_file) loop
      readline(mem_file, L);
      result := 0;
      for i in 1 to 8 loop
        read(L, ch);
        if '0' <= ch and ch <= '9' then 
            result := character'pos(ch) - character'pos('0');
        elsif 'a' <= ch and ch <= 'f' then
           result := character'pos(ch) - character'pos('a')+10;
        elsif 'A' <= ch and ch <= 'F' then
           result := character'pos(ch) - character'pos('A')+10;
        else report "Format error on line " & integer'image(index)
             severity error;
        end if;
        mem(index)(35-i*4 downto 32-i*4) := 
          to_std_logic_vector(result,4);
      end loop;
      index := index + 1;
    end loop;

    -- read memory
    loop
      rd <= mem(to_integer(a(7 downto 2))); 
      wait on a;
    end loop;
  end process;
end;

library IEEE; use IEEE.STD_LOGIC_1164.all;
entity arm is -- single cycle processor
  port(clk, reset:        in  STD_LOGIC;
       PC:                out STD_LOGIC_VECTOR(31 downto 0);
       Instr:             in  STD_LOGIC_VECTOR(31 downto 0);
       MemWrite:          out STD_LOGIC;
       ALUResult, WriteData: out STD_LOGIC_VECTOR(31 downto 0);
       ReadData:          in  STD_LOGIC_VECTOR(31 downto 0));
end;

architecture struct of arm is
  component controller
    port(clk, reset:        in  STD_LOGIC;
         InstrD:             in  STD_LOGIC_VECTOR(31 downto 12);
         ALUFlags:          in  STD_LOGIC_VECTOR(3 downto 0);
         RegSrcD:            out STD_LOGIC_VECTOR(1 downto 0);
         RegWriteW:          out STD_LOGIC;
         ImmSrcD:            out STD_LOGIC_VECTOR(1 downto 0);
         ALUSrcE:            out STD_LOGIC;
         ALUControlE:        out STD_LOGIC_VECTOR(1 downto 0);
         MemWriteM:          out STD_LOGIC;
         MemtoRegW:          out STD_LOGIC;
         FlagWriteD:         out STD_LOGIC_VECTOR(1 downto 0);
         FlagWriteE:         in STD_LOGIC_VECTOR(1 downto 0);
         PCSrcW:             out STD_LOGIC);
  end component;
  component datapath
    port(clk, reset:        in  STD_LOGIC;
         RegSrcD:            in  STD_LOGIC_VECTOR(1 downto 0);
         RegWriteW:          in  STD_LOGIC;
         ImmSrcD:            in  STD_LOGIC_VECTOR(1 downto 0);
         ALUSrcE:            in  STD_LOGIC;
         ALUControlE:        in  STD_LOGIC_VECTOR(1 downto 0);
         MemtoRegW:          in  STD_LOGIC;
         PCSrcW:             in  STD_LOGIC;
		 MemWriteD:          in STD_LOGIC;
         FlagWriteD:         in STD_LOGIC_VECTOR(1 downto 0);
         FlagWriteE:         out STD_LOGIC_VECTOR(1 downto 0);
         ALUFlags:          out STD_LOGIC_VECTOR(3 downto 0);
         PC:                buffer STD_LOGIC_VECTOR(31 downto 0);
         Instr:             in  STD_LOGIC_VECTOR(31 downto 0);
         InstrD:            out STD_LOGIC_VECTOR(31 downto 0);
         ALUResultW, WriteDataW: buffer STD_LOGIC_VECTOR(31 downto 0);
         ReadDataW:          in  STD_LOGIC_VECTOR(31 downto 0));
  end component;
  signal RegWrite, ALUSrc, MemtoReg, PCSrc: STD_LOGIC;
  signal RegSrc, ImmSrc, ALUControl, FlagWrite1, FlagWrite2: STD_LOGIC_VECTOR(1 downto 0);
  signal ALUFlags: STD_LOGIC_VECTOR(3 downto 0);
  signal instrD: STD_LOGIC_VECTOR(31 downto 0);
begin
  cont: controller port map(clk, reset, InstrD(31 downto 12), 
                            ALUFlags, RegSrc, RegWrite, ImmSrc, 
                            ALUSrc, ALUControl, MemWrite, 
                            MemtoReg, FlagWrite1, FlagWrite2, PCSrc);
  dp: datapath port map(clk, reset, RegSrc, RegWrite, ImmSrc, 
                        ALUSrc, ALUControl, MemtoReg, PCSrc, MemWrite,
                        FlagWrite1, FlagWrite2, ALUFlags, PC, Instr, 
                        InstrD, ALUResult, WriteData, ReadData);
end;

library IEEE; use IEEE.STD_LOGIC_1164.all;
entity controller is -- single cycle control decoder
  port(clk, reset:        in  STD_LOGIC;
       InstrD:             in  STD_LOGIC_VECTOR(31 downto 12);
       ALUFlags:          in  STD_LOGIC_VECTOR(3 downto 0);
       RegSrcD:            out STD_LOGIC_VECTOR(1 downto 0);
       RegWriteW:          out STD_LOGIC;
       ImmSrcD:            out STD_LOGIC_VECTOR(1 downto 0);
       ALUSrcE:            out STD_LOGIC;
       ALUControlE:        out STD_LOGIC_VECTOR(1 downto 0);
       MemWriteM:          out STD_LOGIC;
       MemtoRegW:          out STD_LOGIC;
       FlagWriteD:         out STD_LOGIC_VECTOR(1 downto 0);
       FlagWriteE:         in STD_LOGIC_VECTOR(1 downto 0);
       PCSrcW:             out STD_LOGIC);
end;

architecture struct of controller is
  component decoder
    port(Op:               in  STD_LOGIC_VECTOR(1 downto 0);
         Funct:            in  STD_LOGIC_VECTOR(5 downto 0);
         Rd:               in  STD_LOGIC_VECTOR(3 downto 0);
         FlagW:            out STD_LOGIC_VECTOR(1 downto 0);
         PCS, RegW, MemW:  out STD_LOGIC;
         MemtoReg, ALUSrc: out STD_LOGIC;
         ImmSrc, RegSrc:   out STD_LOGIC_VECTOR(1 downto 0);
         ALUControl:       out STD_LOGIC_VECTOR(1 downto 0));
  end component;
  component condlogic
    port(clk, reset:       in  STD_LOGIC;
         Cond:             in  STD_LOGIC_VECTOR(3 downto 0);
         ALUFlags:         in  STD_LOGIC_VECTOR(3 downto 0);
         FlagW:            in  STD_LOGIC_VECTOR(1 downto 0);
         PCS, RegW, MemW:  in  STD_LOGIC;
         PCSrc, RegWrite:  out STD_LOGIC;
         MemWrite:         out STD_LOGIC);
  end component;
  signal FlagW: STD_LOGIC_VECTOR(1 downto 0);
  signal PCS, RegW, MemW: STD_LOGIC;
begin
  dec: decoder port map(InstrD(27 downto 26), InstrD(25 downto 20),
                       InstrD(15 downto 12), FlagWriteD, PCS, 
                       RegW, MemW, MemtoRegW, ALUSrcE, ImmSrcD, 
                       RegSrcD, ALUControlE);
  cl: condlogic port map(clk, reset, InstrD(31 downto 28), 
                         ALUFlags, FlagWriteE, PCS, RegW, MemW,
                         PCSrcW, RegWriteW, MemWriteM); 
end;

library IEEE; use IEEE.STD_LOGIC_1164.all;
entity decoder is -- main control decoder
  port(Op:               in  STD_LOGIC_VECTOR(1 downto 0);
       Funct:            in  STD_LOGIC_VECTOR(5 downto 0);
       Rd:               in  STD_LOGIC_VECTOR(3 downto 0);
       FlagW:            out STD_LOGIC_VECTOR(1 downto 0);
       PCS, RegW, MemW:  out STD_LOGIC;
       MemtoReg, ALUSrc: out STD_LOGIC;
       ImmSrc, RegSrc:   out STD_LOGIC_VECTOR(1 downto 0);
       ALUControl:       out STD_LOGIC_VECTOR(1 downto 0));
end;

architecture behave of decoder is
  signal controls:      STD_LOGIC_VECTOR(9 downto 0);
  signal ALUOp, Branch: STD_LOGIC;
  signal op2:           STD_LOGIC_VECTOR(3 downto 0);
begin
  op2 <= (Op, Funct(5), Funct(0));
  process(all) begin -- Main Decoder
    case? (op2) is
      when "000-" => controls <= "0000001001";
      when "001-" => controls <= "0000101001";
      when "01-0" => controls <= "1001110100";
      when "01-1" => controls <= "0001111000";
      when "10--" => controls <= "0110100010";
      when others => controls <= "----------";
    end case?;
  end process;

  (RegSrc, ImmSrc, ALUSrc, MemtoReg, RegW, MemW, 
    Branch, ALUOp) <= controls;
    
  process(all) begin -- ALU Decoder
    if (ALUOp) then
      case Funct(4 downto 1) is
        when "0100" => ALUControl <= "00"; -- ADD
        when "0010" => ALUControl <= "01"; -- SUB
        when "0000" => ALUControl <= "10"; -- AND
        when "1100" => ALUControl <= "11"; -- ORR
        when others => ALUControl <= "--"; -- unimplemented
      end case;
      FlagW(1) <= Funct(0);
      FlagW(0) <= Funct(0) and (not ALUControl(1));
    else 
      ALUControl <= "00";
      FlagW <= "00";
    end if;
  end process;
  
  PCS <= ((and Rd) and RegW) or Branch;
end;

library IEEE; use IEEE.STD_LOGIC_1164.all;
entity condlogic is -- Conditional logic
  port(clk, reset:       in  STD_LOGIC;
       Cond:             in  STD_LOGIC_VECTOR(3 downto 0);
       ALUFlags:         in  STD_LOGIC_VECTOR(3 downto 0);
       FlagW:            in  STD_LOGIC_VECTOR(1 downto 0);
       PCS, RegW, MemW:  in  STD_LOGIC;
       PCSrc, RegWrite:  out STD_LOGIC;
       MemWrite:         out STD_LOGIC);
end;

architecture behave of condlogic is
  component condcheck
    port(Cond:           in  STD_LOGIC_VECTOR(3 downto 0);
         Flags:          in  STD_LOGIC_VECTOR(3 downto 0);
         CondEx:         out STD_LOGIC);
  end component;
  component flopenr generic(width: integer);
    port(clk, reset, en: in  STD_LOGIC;
         d:          in  STD_LOGIC_VECTOR(width-1 downto 0);
         q:          out STD_LOGIC_VECTOR(width-1 downto 0));
  end component;
  signal FlagWrite: STD_LOGIC_VECTOR(1 downto 0);
  signal Flags:     STD_LOGIC_VECTOR(3 downto 0);
  signal CondEx:    STD_LOGIC;
begin
  flagreg1: flopenr generic map(2)
    port map(clk, reset, FlagWrite(1), 
             ALUFlags(3 downto 2), Flags(3 downto 2));
  flagreg0: flopenr generic map(2)
    port map(clk, reset, FlagWrite(0), 
             ALUFlags(1 downto 0), Flags(1 downto 0));
  cc: condcheck port map(Cond, Flags, CondEx);
  
  FlagWrite <= FlagW and (CondEx, CondEx); 
  RegWrite  <= RegW  and CondEx;
  MemWrite  <= MemW  and CondEx;
  PCSrc     <= PCS   and CondEx;
end;

library IEEE; use IEEE.STD_LOGIC_1164.all;
entity condcheck is 
  port(Cond:           in  STD_LOGIC_VECTOR(3 downto 0);
       Flags:          in  STD_LOGIC_VECTOR(3 downto 0);
       CondEx:         out STD_LOGIC);
end;

architecture behave of condcheck is
  signal neg, zero, carry, overflow, ge: STD_LOGIC;
begin
  (neg, zero, carry, overflow) <= Flags;
  ge <= (neg xnor overflow);
  
  process(all) begin -- Condition checking
    case Cond is
      when "0000" => CondEx <= zero;
      when "0001" => CondEx <= not zero;
      when "0010" => CondEx <= carry;
      when "0011" => CondEx <= not carry;
      when "0100" => CondEx <= neg;
      when "0101" => CondEx <= not neg;
      when "0110" => CondEx <= overflow;
      when "0111" => CondEx <= not overflow;
      when "1000" => CondEx <= carry and (not zero);
      when "1001" => CondEx <= not(carry and (not zero));
      when "1010" => CondEx <= ge;
      when "1011" => CondEx <= not ge;
      when "1100" => CondEx <= (not zero) and ge;
      when "1101" => CondEx <= not ((not zero) and ge);
      when "1110" => CondEx <= '1';
      when others => CondEx <= '-';
    end case;
  end process;
end;

library IEEE; use IEEE.STD_LOGIC_1164.all; 
entity datapath is  
  port(clk, reset:        in  STD_LOGIC;
       RegSrcD:            in  STD_LOGIC_VECTOR(1 downto 0);
       RegWriteW:          in  STD_LOGIC;
       ImmSrcD:            in  STD_LOGIC_VECTOR(1 downto 0);
       ALUSrcE:            in  STD_LOGIC;
       ALUControlE:        in  STD_LOGIC_VECTOR(1 downto 0);
       MemtoRegW:          in  STD_LOGIC;
       PCSrcW:             in  STD_LOGIC;
	   MemWriteD:          in STD_LOGIC;
       FlagWriteD:         in STD_LOGIC_VECTOR(1 downto 0);
       FlagWriteE:         out STD_LOGIC_VECTOR(1 downto 0);
       ALUFlags:          out STD_LOGIC_VECTOR(3 downto 0);
       PC:                buffer STD_LOGIC_VECTOR(31 downto 0);
       Instr:             in  STD_LOGIC_VECTOR(31 downto 0);
       InstrD:            out STD_LOGIC_VECTOR(31 downto 0);
       ALUResultW, WriteDataW: buffer STD_LOGIC_VECTOR(31 downto 0);
       ReadDataW:          in  STD_LOGIC_VECTOR(31 downto 0));
end;

architecture struct of datapath is
  component alu
    port(a, b:       in  STD_LOGIC_VECTOR(31 downto 0);
         ALUControl: in  STD_LOGIC_VECTOR(1 downto 0);
         Result:     buffer STD_LOGIC_VECTOR(31 downto 0);
         ALUFlags:      out STD_LOGIC_VECTOR(3 downto 0));
  end component;
  component regfile
    port(clk:           in  STD_LOGIC;
         we3:           in  STD_LOGIC;
         ra1, ra2, wa3: in  STD_LOGIC_VECTOR(3 downto 0);
         wd3, r15:      in  STD_LOGIC_VECTOR(31 downto 0);
         rd1, rd2:      out STD_LOGIC_VECTOR(31 downto 0));
  end component;
  component adder
    port(a, b: in  STD_LOGIC_VECTOR(31 downto 0);
         y:    out STD_LOGIC_VECTOR(31 downto 0));
  end component;
  component extend
    port(Instr:  in  STD_LOGIC_VECTOR(23 downto 0);
         ImmSrc: in  STD_LOGIC_VECTOR(1 downto 0);
         ExtImm: out STD_LOGIC_VECTOR(31 downto 0));
  end component;
  component flopr generic(width: integer);
    port(clk, reset: in  STD_LOGIC;
         d:          in  STD_LOGIC_VECTOR(width-1 downto 0);
         q:          out STD_LOGIC_VECTOR(width-1 downto 0));
  end component;
  component mux2 generic(width: integer);
    port(d0, d1: in  STD_LOGIC_VECTOR(width-1 downto 0);
         s:      in  STD_LOGIC;
         y:      out STD_LOGIC_VECTOR(width-1 downto 0));
  end component;
  component mux4 generic(width: integer);
    port(D0, D1, D2, D3  : in std_logic_vector(width-1 downto 0);
         S               : in std_logic_vector(1 downto 0);
         Y               : out std_logic_vector(width-1 downto 0));
  end component;
  component regF
    port(clk:    in STD_LOGIC;
         instrF: in STD_LOGIC_VECTOR(31 downto 0);
         instrD: out STD_LOGIC_VECTOR(31 downto 0));
  end component;
  component regD generic(width: integer);
    port(clk:         in STD_LOGIC;
         PCSrcD:      in STD_LOGIC;
         RegWriteD:   in STD_LOGIC;
         MemtoRegD:   in STD_LOGIC;
         MemWriteD:   in STD_LOGIC;
         ALUControlD: in STD_LOGIC_VECTOR(1 downto 0);
         BranchD:     in STD_LOGIC_VECTOR(width-1 downto 0);
         ALUSrcD:     in STD_LOGIC;
         FlagWriteD:  in STD_LOGIC_VECTOR (1 downto 0);
         CondD:       in STD_LOGIC_VECTOR(3 downto 0);
         FlagsD:      in STD_LOGIC_VECTOR(3 downto 0);
         rd1D:        in STD_LOGIC_VECTOR(width-1 downto 0);
         rd2D:        in STD_LOGIC_VECTOR(width-1 downto 0);
         ExtImmD:     in STD_LOGIC_VECTOR(31 downto 0);
         WA3D:        in STD_LOGIC_VECTOR(3 downto 0);
         PCSrcE:      out STD_LOGIC;
         RegWriteE:   out STD_LOGIC;
         MemtoRegE:   out STD_LOGIC;
         MemWriteE:   out STD_LOGIC;
         ALUControlE: out STD_LOGIC_VECTOR(1 downto 0);
         BranchE:     out STD_LOGIC_VECTOR(width-1 downto 0);
         ALUSrcE:     out STD_LOGIC; 
         FlagWriteE:  out STD_LOGIC_VECTOR(1 downto 0);
         CondE:       out STD_LOGIC_VECTOR(3 downto 0);
         FlagsE:      out STD_LOGIC_VECTOR(3 downto 0);
         rd1E:        out STD_LOGIC_VECTOR(width-1 downto 0); 
         rd2E:        out STD_LOGIC_VECTOR(width-1 downto 0);
         ExtImmE:     out STD_LOGIC_VECTOR(31 downto 0);
         WA3E:        out STD_LOGIC_VECTOR(3 downto 0));
  end component;
  component regE generic(width: integer);
    port(clk:        in STD_LOGIC;
         PCSrcE:     in STD_LOGIC;
         RegWriteE:  in STD_LOGIC;
         MemtoRegE:  in STD_LOGIC;
         MemWriteE:  in STD_LOGIC;
         ALUResultE: in STD_LOGIC_VECTOR(width-1 downto 0);
         WriteDataE: in STD_LOGIC_VECTOR(width-1 downto 0);
         WA3E:       in STD_LOGIC_VECTOR(3 downto 0);
         PCSrcM:     out STD_LOGIC;
         RegWriteM:  out STD_LOGIC;
         MemtoRegM:  out STD_LOGIC;
         MemWriteM:  out STD_LOGIC;
         ALUResultM: out STD_LOGIC_VECTOR(width-1 downto 0);
         WriteDataM: out STD_LOGIC_VECTOR(width-1 downto 0);
         WA3M:       out STD_LOGIC_VECTOR(3 downto 0));
  end component;
  component regM generic(width: integer);
    port(clk:       in STD_LOGIC;
         PCSrcM:    in STD_LOGIC;
         RegWriteM: in STD_LOGIC;
         MemtoRegM: in STD_LOGIC;
         ReadDataM: in STD_LOGIC_VECTOR(width-1 downto 0);
         ALUOutM:   in STD_LOGIC_VECTOR(width-1 downto 0);
         WA3M:      in STD_LOGIC_VECTOR(3 downto 0);
         PCSrcW:    out STD_LOGIC;
         RegWriteW: out STD_LOGIC;
         MemtoRegW: out STD_LOGIC;
         ReadDataW: out STD_LOGIC_VECTOR(width-1 downto 0);
         ALUOutW:   out STD_LOGIC_VECTOR(width-1 downto 0);
         WA3W:      out STD_LOGIC_VECTOR(3 downto 0));
  end component;
  signal PCNext, PCNext2, PCPlus4: STD_LOGIC_VECTOR(31 downto 0);
  signal ExtImm, Result:           STD_LOGIC_VECTOR(31 downto 0);
  signal SrcA, SrcAE, SrcBE, ReadDataWb:   STD_LOGIC_VECTOR(31 downto 0);
  signal AluResultE, WriteData, WriteDataM: STD_LOGIC_VECTOR(31 downto 0);
  signal ALUOutM, ALUOutW: STD_LOGIC_VECTOR(31 downto 0);
  signal RA1, RA2, WA3W, WA3M:                 STD_LOGIC_VECTOR(3 downto 0);
  signal PCSrcE, RegWriteE, MemtoRegE, MemWriteE, ALUSrcEx: STD_LOGIC;
  signal PCSrcM, RegWriteM, MemtoRegM, MemWriteM: STD_LOGIC;
  signal MemtoRegWb, PCSrcWb, RegWriteWb: STD_LOGIC;
  signal ALUControlEx: STD_LOGIC_VECTOR(1 downto 0);
  signal BranchE, rd1E, rd2E, ExtImmE, WriteDataE: STD_LOGIC_VECTOR(31 downto 0);
  signal CondE, FlagsE, WA3E: STD_LOGIC_VECTOR(3 downto 0);
begin
  -- Fetch Stage
  pcmux1: mux2 generic map(32)
              port map(PCPlus4, Result, PCSrcWb, PCNext);
  -- pcmux2: mux2 generic map(32)
              -- port map(PCNext, ALUResultE, BranchTakenE, PCNext2);
  pcreg: flopr generic map(32) port map(clk, reset, PCNext, PC);
  pcadd1: adder port map(PC, X"00000004", PCPlus4);
  regFD: regF port map (clk, Instr, InstrD);

  -- Decode Stage
  ra1mux: mux2 generic map (4)
    port map(InstrD(19 downto 16), "1111", RegSrcD(0), RA1);
  ra2mux: mux2 generic map (4) port map(InstrD(3 downto 0), 
             InstrD(15 downto 12), RegSrcD(1), RA2);
  rf: regfile port map(clk, RegWriteW, RA1, RA2, WA3W, Result, 
                      PCPlus4, SrcA, WriteData);
  ext: extend port map(InstrD(23 downto 0), ImmSrcD, ExtImm);
  regDE: regD generic map (32)
    port map(clk, PCSrcW, RegWriteW, MemToRegW, MemWriteD, ALUControlE, "00000000000000000000000000000000", ALUSrcE, FlagWriteD,
             InstrD(31 downto 28), "0000", SrcA, WriteData, ExtImm, InstrD(15 downto 12), PCSrcE, RegWriteE, 
             MemtoRegE, MemWriteE, ALUControlEx, BranchE, ALUSrcEx, FlagWriteE, CondE, FlagsE, rd1E,
             rd2E, ExtImmE, WA3E);

  -- Execute Stage
  -- muxSrcA: mux4 generic map(32)
  --   port map(rd1E, Result, ALUOutM, "00000000000000000000000000000000", ForwardAE, SrcAE);
  -- muxSrcB: mux4 generic map(32)
  --   port map(rd2E, Result, ALUOutM, "00000000000000000000000000000000", ForwardBE, WriteDataE);
  srcbmux: mux2 generic map(32) 
    port map(rd2E, ExtImmE, ALUSrcE, SrcBE);
  i_alu: alu port map(rd1E, SrcBE, ALUControlE, ALUResultE, ALUFlags);
  regEM: regE generic map (32)
    port map(clk, PCSrcE, RegWriteE, MemtoRegE, MemWriteE, ALUResultE, WriteDataE, WA3E,
             PCSrcM, RegWriteM, MemtoRegM, MemWriteM, ALUOutM, WriteDataM, WA3M);

  -- Memory Stage
  regMW: regM generic map (32)
    port map(clk, PCSrcM, RegWriteM, MemtoRegM, ReadDataW, ALUOutM, WA3M, PCSrcWb, RegWriteWb, MemtoRegWb,
             ReadDataWb, ALUOutW, WA3W);

  -- Write Back Stage
  muxWB: mux2 generic map(32)
    port map(ReadDataWb, ALUOutW, MemtoRegWb, Result);
end;

library IEEE; use IEEE.STD_LOGIC_1164.all; 
use IEEE.NUMERIC_STD_UNSIGNED.all;
entity regfile is -- three-port register file
  port(clk:           in  STD_LOGIC;
       we3:           in  STD_LOGIC;
       ra1, ra2, wa3: in  STD_LOGIC_VECTOR(3 downto 0);
       wd3, r15:      in  STD_LOGIC_VECTOR(31 downto 0);
       rd1, rd2:      out STD_LOGIC_VECTOR(31 downto 0));
end;

architecture behave of regfile is
  type ramtype is array (31 downto 0) of 
    STD_LOGIC_VECTOR(31 downto 0);
  signal mem: ramtype;
begin
  process(clk) begin
    if rising_edge(clk) then
       if we3 = '1' then mem(to_integer(wa3)) <= wd3;
       end if;
    end if;
  end process;
  process(all) begin
    if (to_integer(ra1) = 15) then rd1 <= r15; 
    else rd1 <= mem(to_integer(ra1));
    end if;
    if (to_integer(ra2) = 15) then rd2 <= r15; 
    else rd2 <= mem(to_integer(ra2));
    end if;
  end process;
end;

library IEEE; use IEEE.STD_LOGIC_1164.all;
entity regF is 
  port(clk:    in STD_LOGIC;
       instrF: in STD_LOGIC_VECTOR(31 downto 0);
       instrD: out STD_LOGIC_VECTOR(31 downto 0));
end regF;

architecture behave of regF is
begin
  process(clk)
  begin
    if(clk'event and clk = '1') then
      instrD <= instrF;
    end if;
  end process;
end behave;

library IEEE; use IEEE.STD_LOGIC_1164.all;
entity regD is generic(width : integer);
  port(clk:         in STD_LOGIC;
       PCSrcD:      in STD_LOGIC;
       RegWriteD:   in STD_LOGIC;
       MemtoRegD:   in STD_LOGIC;
       MemWriteD:   in STD_LOGIC;
       ALUControlD: in STD_LOGIC_VECTOR(1 downto 0);
       BranchD:     in STD_LOGIC_VECTOR(width-1 downto 0);
       ALUSrcD:     in STD_LOGIC;
       FlagWriteD:  in STD_LOGIC_VECTOR (1 downto 0);
       CondD:       in STD_LOGIC_VECTOR(3 downto 0);
       FlagsD:      in STD_LOGIC_VECTOR(3 downto 0);
       rd1D:        in STD_LOGIC_VECTOR(width-1 downto 0);
       rd2D:        in STD_LOGIC_VECTOR(width-1 downto 0);
       ExtImmD:     in STD_LOGIC_VECTOR(31 downto 0);
       WA3D:        in STD_LOGIC_VECTOR(3 downto 0);
       PCSrcE:      out STD_LOGIC;
       RegWriteE:   out STD_LOGIC;
       MemtoRegE:   out STD_LOGIC;
       MemWriteE:   out STD_LOGIC;
       ALUControlE: out STD_LOGIC_VECTOR(1 downto 0);
       BranchE:     out STD_LOGIC_VECTOR(width-1 downto 0);
       ALUSrcE:     out STD_LOGIC; 
       FlagWriteE:  out STD_LOGIC_VECTOR(1 downto 0);
       CondE:       out STD_LOGIC_VECTOR(3 downto 0);
       FlagsE:      out STD_LOGIC_VECTOR(3 downto 0);
       rd1E:        out STD_LOGIC_VECTOR(width-1 downto 0); 
       rd2E:        out STD_LOGIC_VECTOR(width-1 downto 0);
       ExtImmE:     out STD_LOGIC_VECTOR(31 downto 0);
       WA3E:        out STD_LOGIC_VECTOR(3 downto 0));
end regD;

architecture behave of regD is
begin
  process(clk)
  begin
    if(clk'event and clk = '1') then
      PCSrcE <= PCSrcD;
      RegWriteE <= RegWriteD;
      MemtoRegE <= MemtoRegD;
      MemWriteE <= MemWriteD;
      ALUControlE <= ALUControlD;
      BranchE <= BranchD;
      ALUSrcE <= ALUSrcD;
      FlagWriteE <= FlagWriteD;
      CondE <= CondD;
      FlagsE <= FlagsD;
      rd1E <= rd1D;
      rd2E <= rd2D;
      ExtImmE <= ExtImmD;
      WA3E <= WA3D;
    end if;
  end process;
end behave;

library IEEE; use IEEE.STD_LOGIC_1164.all;
entity regE is generic(width : integer);
  port(clk:        in STD_LOGIC;
       PCSrcE:     in STD_LOGIC;
       RegWriteE:  in STD_LOGIC;
       MemtoRegE:  in STD_LOGIC;
       MemWriteE:  in STD_LOGIC;
       ALUResultE: in STD_LOGIC_VECTOR(width-1 downto 0);
       WriteDataE: in STD_LOGIC_VECTOR(width-1 downto 0);
       WA3E:       in STD_LOGIC_VECTOR(3 downto 0);
       PCSrcM:     out STD_LOGIC;
       RegWriteM:  out STD_LOGIC;
       MemtoRegM:  out STD_LOGIC;
       MemWriteM:  out STD_LOGIC;
       ALUResultM: out STD_LOGIC_VECTOR(width-1 downto 0);
       WriteDataM: out STD_LOGIC_VECTOR(width-1 downto 0);
       WA3M:       out STD_LOGIC_VECTOR(3 downto 0));
end regE;

architecture behave of regE is
begin
  process(clk)
  begin
    if(clk'event and clk = '1') then
      PCSrcM <= PCSrcE;
      RegWriteM <= RegWriteE;
      MemtoRegM <= MemtoRegE;
      MemWriteM <= MemWriteE;
      ALUResultM <= ALUResultE;
      WriteDataM <= WriteDataE;
      WA3M <= WA3E;
    end if;
  end process;
end behave;

library IEEE; use IEEE.STD_LOGIC_1164.all;
entity regM is generic(width : integer);
  port(clk:       in STD_LOGIC;
       PCSrcM:    in STD_LOGIC;
       RegWriteM: in STD_LOGIC;
       MemtoRegM: in STD_LOGIC;
       ReadDataM: in STD_LOGIC_VECTOR(width-1 downto 0);
       ALUOutM:   in STD_LOGIC_VECTOR(width-1 downto 0);
       WA3M:      in STD_LOGIC_VECTOR(3 downto 0);
       PCSrcW:    out STD_LOGIC;
       RegWriteW: out STD_LOGIC;
       MemtoRegW: out STD_LOGIC;
       ReadDataW: out STD_LOGIC_VECTOR(width-1 downto 0);
       ALUOutW:   out STD_LOGIC_VECTOR(width-1 downto 0);
       WA3W:      out STD_LOGIC_VECTOR(3 downto 0));
end regM;

architecture behave of regM is
begin
  process(clk)
  begin
    if(clk'event and clk = '1') then
      PCSrcW <= PCSrcM;
      RegWriteW <= RegWriteM;
      MemtoRegW <= MemtoRegM;
      ReadDataW <= ReadDataM;
      ALUOutW <= ALUOutM;
      WA3W <= WA3M;
    end if;
  end process;
end behave;

library IEEE; use IEEE.STD_LOGIC_1164.all; 
use IEEE.NUMERIC_STD_UNSIGNED.all;
entity adder is -- adder
  port(a, b: in  STD_LOGIC_VECTOR(31 downto 0);
       y:    out STD_LOGIC_VECTOR(31 downto 0));
end;

architecture behave of adder is
begin
  y <= a + b;
end;

library IEEE; use IEEE.STD_LOGIC_1164.all;
entity extend is 
  port(Instr:  in  STD_LOGIC_VECTOR(23 downto 0);
       ImmSrc: in  STD_LOGIC_VECTOR(1 downto 0);
       ExtImm: out STD_LOGIC_VECTOR(31 downto 0));
end;

architecture behave of extend is
begin
  process(all) begin
    case ImmSrc is
      when "00"   => ExtImm <= (X"000000", Instr(7 downto 0));
      when "01"   => ExtImm <= (X"00000", Instr(11 downto 0));
      when "10"   => ExtImm <= (Instr(23), Instr(23), Instr(23), 
        Instr(23), Instr(23), Instr(23), Instr(23 downto 0), "00");
      when others => ExtImm <= X"--------";
    end case;
  end process;
end;

library IEEE; use IEEE.STD_LOGIC_1164.all;  
entity flopenr is -- flip-flop with enable and asynchronous reset
  generic(width: integer);
  port(clk, reset, en: in  STD_LOGIC;
       d:          in  STD_LOGIC_VECTOR(width-1 downto 0);
       q:          out STD_LOGIC_VECTOR(width-1 downto 0));
end;

architecture asynchronous of flopenr is
begin
  process(clk, reset) begin
    if reset then q <= (others => '0');
    elsif rising_edge(clk) then
      if en then 
        q <= d;
      end if;
    end if;
  end process;
end;

library IEEE; use IEEE.STD_LOGIC_1164.all;  
entity flopr is -- flip-flop with asynchronous reset
  generic(width: integer);
  port(clk, reset: in  STD_LOGIC;
       d:          in  STD_LOGIC_VECTOR(width-1 downto 0);
       q:          out STD_LOGIC_VECTOR(width-1 downto 0));
end;

architecture asynchronous of flopr is
begin
  process(clk, reset) begin
    if reset then  q <= (others => '0');
    elsif rising_edge(clk) then
      q <= d;
    end if;
  end process;
end;

library IEEE; use IEEE.STD_LOGIC_1164.all;
entity mux2 is -- two-input multiplexer
  generic(width: integer);
  port(d0, d1: in  STD_LOGIC_VECTOR(width-1 downto 0);
       s:      in  STD_LOGIC;
       y:      out STD_LOGIC_VECTOR(width-1 downto 0));
end;

architecture behave of mux2 is
begin
  y <= d1 when s else d0;
end;

library IEEE; use IEEE.STD_LOGIC_1164.all;
entity mux4 is
	generic(width: integer);
   port (
		D0, D1, D2, D3  : in std_logic_vector(width-1 downto 0);
		S: in std_logic_vector(1 downto 0);
		Y               : out std_logic_vector(width-1 downto 0)
	);
end mux4;

architecture behave of mux4 is
begin
  with S select
    Y <= D0 when "00",
       D1 when "01",
       D2 when "10",
       D3 when others;
end behave;

library IEEE; use IEEE.STD_LOGIC_1164.all; 
use IEEE.NUMERIC_STD_UNSIGNED.all;
entity alu is 
  port(a, b:       in  STD_LOGIC_VECTOR(31 downto 0);
       ALUControl: in  STD_LOGIC_VECTOR(1 downto 0);
       Result:     buffer STD_LOGIC_VECTOR(31 downto 0);
       ALUFlags:      out STD_LOGIC_VECTOR(3 downto 0));
end;

architecture behave of alu is
  signal condinvb: STD_LOGIC_VECTOR(31 downto 0);
  signal sum:      STD_LOGIC_VECTOR(32 downto 0);
  signal neg, zero, carry, overflow: STD_LOGIC;
begin
  condinvb <= not b when ALUControl(0) else b;
  sum <= ('0', a) + ('0', condinvb) + ALUControl(0);

  process(all) begin
    case? ALUControl(1 downto 0) is
      when "0-"   => result <= sum(31 downto 0); 
      when "10"   => result <= a and b; 
      when "11"   => result <= a or b; 
      when others => result <= (others => '-');
    end case?;
  end process;

  neg      <= Result(31);
  zero     <= '1' when (Result = 0) else '0';
  carry    <= (not ALUControl(1)) and sum(32);
  overflow <= (not ALUControl(1)) and
             (not (a(31) xor b(31) xor ALUControl(0))) and
             (a(31) xor sum(31));
  ALUFlags    <= (neg, zero, carry, overflow);
end;