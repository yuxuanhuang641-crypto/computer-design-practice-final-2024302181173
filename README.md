# 计算机设计实践最终验收提交

姓名：黄宇轩  
学号：2024302181173  
课程任务：RISC-V 单周期 CPU 与五级流水线 CPU 扩展指令实现、仿真验收与开发板展示

## 提交内容

- `single-cycle/`：单周期 CPU 修改后的 Verilog 源码。
- `pipeline/`：五级流水线 CPU 修改后的 Verilog 源码。
- `tb/`：最终验收与老师展示用 testbench。
- `tests/`：按点验收测试程序与预期结果。
- `outputs/`：四组老师要求测试及自动评分输出记录。
- `screenshots/`：四组测试截图、开发板照片、diff 截图和自动评分截图。
- `diff-report/`：代码修改 diff patch 与 HTML 报告。
- `requirements/`：final/README.md 与更新后的 QUESTIONS.md。

## 完成情况

单周期 CPU 完成：

```text
slt, sltu,
andi, ori, xori,
srli, srai, slli,
slti, sltiu,
bne, bge, bgeu, blt, bltu,
jalr
```

流水线 CPU 完成：

```text
slt, sltu,
andi, ori, xori,
srli, srai, slli,
slti, sltiu,
beq, bne, bge, bgeu, blt, bltu,
jal, jalr
```

自动评分结果：

```text
Score: 100/100
Raw score: 92/92
```

## 四组展示测试

| 测试点 | CPU | 程序 | 关键结果 |
|---|---|---|---|
| 测试 1 | 单周期 | `Test_30_Instr.dat` | `x1=000000cc`, `x27=3dcc0000`, `m0=0000000c`, `m4=0000055c` |
| 测试 2 | 流水线 | `Test_30_Instr.dat` | 关键寄存器/内存值与单周期一致 |
| 测试 3 | 单周期 | `riscv_sidascsorting_sim.dat` | `x15=03345578`, `m96=54873530`, `m97=03345578` |
| 测试 4 | 流水线 | `riscv_sidascsorting_sim.dat` | `x15=03345578`, 写入 `0x180/0x184`，`m96=54873530`, `m97=03345578` |

## 关键实现说明

- `ctrl.v`：根据 `opcode/funct3/funct7` 译码，生成 `RegWrite`、`MemWrite`、`EXTOp`、`ALUOp`、`NPCOp`、`ALUSrc`、`WDSel` 等控制信号。
- `alu.v`：扩展 `slt/sltu`、立即数逻辑运算、移位和分支比较，分支类 ALUOp 的 `Zero` 表示条件是否成立。
- `NPC.v`：支持 `PC+4`、分支目标、`jal` 目标和 `jalr` 目标；`jalr` 使用 `(RS1 + IMM) & 32'hffff_fffe`。
- `PLCPU.v`：新增 MEM/WB 转发路径、`jump_flush` 控制冲刷，以及 IF/ID、ID/EX、EX/MEM、MEM/WB 流水寄存器控制信号传递。
