# Final 原理理解问题

使用方式：每位同学随机抽 3 个问题。题目难度尽量保持一致，重点考察是否理解 CPU 基本数据通路、指令执行过程、单周期/流水线区别，以及常见模块作用。答案用折叠块隐藏，提问时可以先隐藏。

## 1. 找出一条运算指令解释实现原理

### 1.1 解释 `add x3, x1, x2` 在 CPU 中如何执行。

<details>
<summary>参考答案</summary>

`add` 是 R-type 指令。CPU 从指令中取出 `rs1=x1`、`rs2=x2`、`rd=x3`。

执行过程：

```text
RF 读出 x1 和 x2
ALU 做加法
结果写回 x3
PC 变成 PC + 4
```

主要控制信号：

```text
RegWrite = 1
MemWrite = 0
ALUSrc = 0
WDSel = ALU
```

</details>

### 1.2 解释 `addi x5, x0, 0xff` 在 CPU 中如何执行。

<details>
<summary>参考答案</summary>

`addi` 是 I-type 指令。CPU 从指令中取出 `rs1=x0`、`rd=x5` 和 12 位立即数 `0xff`。

执行过程：

```text
RF 读出 x0 = 0
立即数进行符号扩展
ALU 计算 x0 + imm
结果写回 x5
PC 变成 PC + 4
```

主要控制信号：

```text
RegWrite = 1
ALUSrc = 1
WDSel = ALU
MemWrite = 0
```

</details>

### 1.3 解释 `slt x27, x25, x26` 在 CPU 中如何执行。

<details>
<summary>参考答案</summary>

`slt` 是 R-type 有符号比较指令。

执行过程：

```text
RF 读出 x25 和 x26
ALU 按 signed 比较 x25 < x26
如果成立，结果为 1
如果不成立，结果为 0
结果写回 x27
```

实现时要注意使用有符号比较：

```verilog
($signed(A) < $signed(B))
```

`sltu` 与它类似，但使用无符号比较。

</details>

### 1.4 解释 `slli x27, x19, 16` 在 CPU 中如何执行。

<details>
<summary>参考答案</summary>

`slli` 是 I-type 移位指令。

执行过程：

```text
RF 读出 x19
从指令中取出 shamt = 16
ALU 计算 x19 << 16
结果写回 x27
PC 变成 PC + 4
```

移位量只需要低 5 位，因为 RV32I 寄存器是 32 位，移动范围是 0 到 31。

</details>

## 2. 找出一条跳转或分支指令解释实现原理

### 2.1 解释 `beq x7, x23, label` 在 CPU 中如何执行。

<details>
<summary>参考答案</summary>

`beq` 是 B-type 条件分支指令。

执行过程：

```text
RF 读出 x7 和 x23
比较二者是否相等
如果相等，PC = 当前 PC + branch 立即数
如果不相等，PC = PC + 4
```

`beq` 不写寄存器，也不写数据内存：

```text
RegWrite = 0
MemWrite = 0
```

流水线 CPU 中，如果分支成立，需要把已经取进来的错误路径指令 flush。

</details>

### 2.2 解释 `bne x5, x7, label` 在 CPU 中如何执行。

<details>
<summary>参考答案</summary>

`bne` 表示不相等则跳转。

执行过程：

```text
RF 读出 x5 和 x7
比较 x5 != x7
如果不相等，PC = 当前 PC + branch 立即数
如果相等，PC = PC + 4
```

它和 `beq` 的区别只是跳转条件相反。

`bne` 不写 RF，也不访问数据内存。

</details>

### 2.3 解释 `jal x1, target` 在 CPU 中如何执行。

<details>
<summary>参考答案</summary>

`jal` 是无条件跳转并保存返回地址。

它做两件事：

```text
x1 = 当前 PC + 4
PC = 当前 PC + J-type 立即数
```

所以 `x1` 通常作为返回地址寄存器。

主要控制信号：

```text
RegWrite = 1
WDSel = PC + 4
NPCOp = jump
```

流水线中，`jal` 后面顺序取到的指令需要 flush。

</details>

### 2.4 解释 `jalr x0, x1, 0` 为什么可以作为函数返回。

<details>
<summary>参考答案</summary>

`jalr` 的跳转目标是：

```text
PC = (rs1 + imm) & 0xfffffffe
```

对于：

```asm
jalr x0, x1, 0
```

就是：

```text
PC = x1
```

其中最低位会清 0。因为 `rd=x0`，所以不会保存新的返回地址，但跳转仍然发生。

如果前面 `jal x1, func` 把返回地址存在 `x1`，那么 `jalr x0, x1, 0` 就能返回。

</details>

## 3. 解释单周期 CPU 和多周期流水线 CPU 的区别

### 3.1 单周期 CPU 一条指令如何完成？

<details>
<summary>参考答案</summary>

单周期 CPU 中，一条指令在一个时钟周期内完成所有工作：

```text
取指 -> 译码 -> 读寄存器 -> ALU -> 访存 -> 写回 -> 计算下一 PC
```

例如 `lw`：

```text
PC 取指
RF 读 rs1
ALU 计算地址
dm 读数据
写回 rd
```

单周期 CPU 结构直观，但一个周期必须足够长，能容纳最慢指令的完整路径。

</details>

### 3.2 五级流水线 CPU 每一级做什么？

<details>
<summary>参考答案</summary>

五级流水线通常是：

```text
IF  : 取指
ID  : 译码、读寄存器
EX  : ALU 运算或分支判断
MEM : 访问数据内存
WB  : 写回寄存器
```

阶段之间有流水寄存器：

```text
IF/ID
ID/EX
EX/MEM
MEM/WB
```

每个时钟周期，指令向后推进一级。

</details>

### 3.3 为什么流水线 CPU 需要保存控制信号？

<details>
<summary>参考答案</summary>

流水线中，一条指令不会在一个周期内完成。它在 ID 阶段译码得到控制信号，但真正使用这些信号可能在后面的 EX、MEM、WB 阶段。

例如 `lw`：

```text
ID 阶段知道它需要 MemRead、RegWrite、WDSel=MEM
MEM 阶段才真正读内存
WB 阶段才写回寄存器
```

所以 `RegWrite`、`MemWrite`、`MemRead`、`WDSel`、`rd` 等必须跟着这条指令一起存入流水寄存器，逐级传递。

</details>

### 3.4 流水线 CPU 为什么需要处理数据冲突？

<details>
<summary>参考答案</summary>

流水线中多条指令同时执行，后一条指令可能需要前一条还没写回的结果。

例如：

```asm
add x3, x1, x2
sub x4, x3, x5
```

`sub` 需要 `x3`，但 `add` 可能还没写回 RF。

常见处理方法：

```text
forwarding：从 EX/MEM 或 MEM/WB 把结果直接送回 EX
stall：如果是 lw 后立即使用，暂停一拍
```

</details>

## 4. 其他代码解释

### 4.1 `im` 模块是做什么的？

<details>
<summary>参考答案</summary>

`im` 是指令存储器。

典型实现：

```verilog
reg [31:0] RAM[0:127];
assign dout = RAM[addr];
```

CPU 输出 `PC`，顶层用：

```verilog
PC[31:2]
```

作为 `im.addr`，因为指令是 4 字节对齐的 32 位 word。

testbench 通常用 `$readmemh` 或 `$fscanf` 把 `.dat` 机器码加载到 `im.RAM`。

</details>

### 4.2 `dm` 模块是做什么的？

<details>
<summary>参考答案</summary>

`dm` 是数据存储器，主要服务 `lw/sw`。

`sw` 时：

```text
CPU 给出地址 addr
CPU 给出写数据 din
MemWrite = 1
时钟沿写入 dmem[addr[8:2]]
```

`lw` 时：

```text
CPU 给出地址 addr
dm 输出 dout
CPU 在 WB 阶段把 dout 写回 rd
```

使用 `addr[8:2]` 是因为当前实现按 32 位 word 访问。

</details>

### 4.3 `RF` 模块是做什么的？

<details>
<summary>参考答案</summary>

`RF` 是寄存器堆，也就是 RISC-V 的 `x0` 到 `x31`。

它通常有：

```text
两个读端口：rs1、rs2
一个写端口：rd
```

读：

```text
A1=rs1 -> RD1
A2=rs2 -> RD2
```

写：

```text
如果 RegWrite=1 且 rd != x0
在时钟沿把 WD 写入 rd
```

`x0` 永远读作 0，不能被写坏。

</details>

### 4.4 `ctrl` 或译码逻辑是做什么的？

<details>
<summary>参考答案</summary>

`ctrl` 根据指令的 `opcode/funct3/funct7` 判断这是什么指令，并产生控制信号。

例如 `lw`：

```text
RegWrite = 1
MemRead = 1
MemWrite = 0
ALUSrc = 1
WDSel = MEM
```

例如 `sw`：

```text
RegWrite = 0
MemWrite = 1
ALUSrc = 1
```

所以 `ctrl` 可以理解为 CPU 的指挥模块，它告诉 RF、ALU、dm、PC 选择逻辑该怎么工作。

</details>

### 4.5 `Test_30_Instr.dat` 和学号排序程序分别主要检查什么？

<details>
<summary>参考答案</summary>

`Test_30_Instr.dat` 主要检查单条或一组指令是否实现正确，例如：

```text
算术逻辑
移位
比较
lw/sw
分支
jal/jalr
```

学号排序程序更像完整程序测试，会检查：

```text
循环
多次分支
子过程调用和返回
连续数据相关
内存读写
```

排序程序通常把：

```text
原始学号写到 mem[0x180]
排序结果写到 mem[0x184]
```

如果 `dm` 用 `addr[8:2]`，对应 `dmem[96]` 和 `dmem[97]`。

</details>

### 4.6 学号排序程序里，学号是怎么初始化出来的？

<details>
<summary>参考答案</summary>

程序把每一位十进制学号当成一个 4 bit 十六进制数字，也就是 BCD 风格保存。

初始化代码大致是：

```asm
addi x2, x0, 0x54
slli x2, x2, 8
addi x2, x2, 0x87
slli x2, x2, 16
addi x3, x0, 0x35
slli x3, x3, 8
addi x3, x3, 0x30
add  x2, x2, x3
sw   x2, 0x180(x0)
```

执行后：

```text
x2 = 0x54873530
mem[0x180] = 0x54873530
```

可以理解为把学号数字一段一段拼起来：

```text
0x54 -> 0x5487 -> 0x54870000
0x35 -> 0x3530
0x54870000 + 0x3530 = 0x54873530
```

所以原始学号是：

```text
54873530
```

</details>

### 4.7 学号排序程序如何得到排序后的结果？

<details>
<summary>参考答案</summary>

程序把 `0x54873530` 看成 8 个 4 bit 数字：

```text
5 4 8 7 3 5 3 0
```

排序过程使用两层循环。外层循环确定当前位置 `i`，内层循环在后面的位置中找出最大数字 `tmpMax` 和它的位置 `bestj`。如果最大数字不在当前位置，就调用 `swap` 交换两个 4 bit 数字。

关键寄存器含义：

```text
x15 = 当前正在排序的学号
x4  = mask0，用来取第 i 位数字
x5  = mask1，用来取第 j 位数字
x7  = a，第 i 位数字
x8  = b，第 j 位数字
x12 = bestj，当前最大数字的位置
x13 = tmpMax，当前找到的最大数字
```

排序完成后：

```text
原始学号: 54873530
排序后  : 03345578
```

程序会把结果写到：

```text
mem[0x184] = 0x03345578
x15        = 0x03345578
```

如果数据存储器使用 `dmem[addr[8:2]]`，那么：

```text
mem[0x180] -> dmem[96]
mem[0x184] -> dmem[97]
```

</details>