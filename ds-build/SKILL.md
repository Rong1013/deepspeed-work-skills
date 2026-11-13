---
name: ds-build
description: Compile DeepSpeed DAS from source on Hygon DCU with DTK (hipcc), build the wheel with the required DS_BUILD_* ops, install it, and verify the installed package. Use when the user asks to compile, build, rebuild, make a wheel, install DeepSpeed from source, verify a merge compiles, or when ds_report / op import errors suggest a stale or broken build.
---

# 编译与安装验证

在 DeepSpeed 仓库根目录执行。环境变量、依赖安装、编译选项的完整说明见 [references/build-env.md](references/build-env.md)。机器相关值见 `../ds-workflow/references/environment.md`。

## 1. 编译前检查

- 在仓库根目录；`git status -sb` 记下分支和 HEAD（写进日志头）。
- `hy-smi` 确认 DCU 可用；`python3 -c "import torch;print(torch.__version__, torch.version.hip)"` 确认是 DTK 配套 torch（`torch.version.hip` 非空）。
- 依赖：缺什么装什么，按 build-env.md「依赖」一节；**不要升级/降级 torch**。
- `dist/` 中已有 wheel：移到 `dist/old/<时间戳>/`，不要直接删除。
- 向用户输出将要执行的完整编译命令（含 `DS_BUILD_*`），用户未指定时使用默认选项。

## 2. 编译

```bash
bash <skill>/scripts/build.sh [--ops default|all|minimal] [--no-install] [--log-dir DIR]
```

- 编译耗时较长：用后台方式运行，等待完成通知，不要高频查看日志。
- 日志：`$DS_WORK_DIR/build/compile_<version>_<YYYYMMDD-HHMM>.log`，脚本会在末尾写入 `=== DS_BUILD_DONE exit=<code> ===`。

## 3. 判定结果

| 条件 | 结论 |
| --- | --- |
| 日志末尾 `exit=0` 且 `dist/*.whl` 新生成 | 编译成功 |
| `exit!=0` 或没有 wheel | 编译失败：从日志中定位**第一条** `error:`（不是最后一条），按 build-env.md「常见编译错误」处理 |
| 日志无 DONE 标记 | 进程被中断，报告并询问是否重跑 |

修复编译错误属于代码修改：改完列出 diff 让用户确认，不自动提交。

## 4. 安装后验证

```bash
bash <skill>/scripts/verify_install.sh
```

`--ops minimal` 编译时用 `verify_install.sh none`（op 未预编译，不检查）。

检查：`import deepspeed` 版本与 `version.txt` 一致、`hcu_version` 存在、`ds_report` 中预期编译的 op 为 `[OKAY]`、torch/hip 信息。任一项不符即判定为失败。

## 5. 汇报

编译命令、耗时、wheel 路径与大小、日志路径、验证结果；失败时附第一条错误的上下文（前后约 20 行）。
