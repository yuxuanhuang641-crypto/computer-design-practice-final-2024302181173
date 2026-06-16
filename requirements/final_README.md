# Final：扩展指令验收与评分说明

## 目标

最终验收要求学生在现有单周期 CPU 和流水线 CPU demo 的基础上扩展指令，并用 `iverilog` 测试点进行自动验收。

本目录提供两部分内容：

- `QUESTIONS.md`：面向学生的原理理解问题，数量超过 10 个。
- `iverilog-tests/`：可复用的 `iverilog` 评分 testbench 模板。
- 本 README：说明最终验收的指令范围、测试设计要求和评分建议。

## 单周期 CPU 需要实现的指令

```text
slt, sltu,
andi, ori, xori,
srli, srai, slli,
slti, sltiu,
bne, bge, bgeu, blt, bltu,
jalr
```

说明：老师原文中的 `sltui` 按 RISC-V 标准应理解为 `sltiu`。

## 流水线 CPU 需要实现的指令

```text
slt, sltu,
andi, ori, xori,
srli, srai, slli,
slti, sltiu,
beq, bne, bge, bgeu, blt, bltu,
jal, jalr
```

## 按点给分测试要求

最终测试不应该只用一个大程序判断是否通过，而应该拆成很多小测试点。每个测试点只验证一个或一组高度相关的行为，这样学生能定位错误。

建议每条指令至少覆盖以下情况：

- `slt`、`sltu`：正数、负数、零、相等、不相等、有符号和无符号差异。
- `andi`、`ori`、`xori`：不同立即数、全 0、全 1、交错 bit、符号扩展立即数。
- `srli`、`srai`、`slli`：移位 0、移位 1、移位多位、正数、负数。
- `slti`、`sltiu`：正数、负数、零、相等、不相等、有符号和无符号差异。
- `beq`、`bne`、`bge`、`bgeu`、`blt`、`bltu`：跳转成立和不成立都要测。
- `jal`、`jalr`：检查跳转目标、link 寄存器写回值、被跳过指令是否没有生效。

## 推荐评分方式

每个测试点可以包含多个检查项：

- 寄存器检查：例如 `x5 == 0x00000001`。
- 内存检查：例如 `mem[4] == 0x12345678`。
- 跳转检查：通过被跳过指令对应的寄存器是否保持 0 判断。
- 流水线额外检查：通过连续相关指令判断转发、阻塞和冲刷是否正确。

总分建议直接按检查项累计，例如：

```text
[PASS] sc_slt_signed: 5/5
[PASS] sc_branch_bge: 4/4
[FAIL] pl_jalr_flush: 3/5
Score: 92/100
```

## 学生提交建议

学生最终应提交：

1. 单周期 CPU 修改后的源码。
2. 流水线 CPU 修改后的源码。
3. `iverilog` 测试截图或评分脚本输出。
4. 对 `QUESTIONS.md` 中问题的回答。
5. 如果做了上板展示，补充开发板照片或视频截图。

## 与 lab-6 的关系

`lab-6` 已经给出单周期 CPU 跑学号排序的参考实现。最终验收时，学生可以参考 lab-6 中的这些实现：

- `slt` 如何作为比较指令写回 0/1。
- `slli`、`srl` 如何使用低 5 位作为移位量。
- `bne` 如何复用 ALU 比较结果决定是否跳转。
- `jalr` 如何返回 `swap` 子过程。

流水线 CPU 不能只照搬单周期逻辑，还需要考虑冒险处理和流水线冲刷。
