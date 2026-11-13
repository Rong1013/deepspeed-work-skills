---
name: ds-test
description: Run DeepSpeed DAS unit tests on Hygon DCU — the full tests/run_test.sh suite or targeted pytest files/nodes — detect whether the run finished or died, extract FAILED/ERROR cases from the pytest log, and triage each failure (re-run, classify, fix or record). Use when the user asks to run tests, run the unit suite, re-run a failing case, check why tests fail, or extract failed cases from a pytest log.
---

# 单元测试与失败分诊

在 DeepSpeed 仓库根目录执行。失败分类与处理方法见 [references/failure-triage.md](references/failure-triage.md)。

## 0. 前提

- 测试的是**已安装**的 deepspeed：先确认 `python3 -c "import deepspeed;print(deepspeed.__version__, deepspeed.__file__)"` 与当前代码一致（版本 = `version.txt`，且不是旧 wheel）。不一致时询问是否先调用 ds-build。
- `hy-smi` 确认测试要用的卡空闲；有他人任务占卡时告知用户，不要抢占。

## 1. 选择范围（不要自行扩大）

| 用户说法 | 执行 |
| --- | --- |
| 跑某个文件 / 某个用例 | `cd tests && pytest -v --timeout=1400 <path>[::node]` |
| 跑某个目录 | `cd tests && pytest -v --timeout=1400 <dir>` |
| 跑全量 / 跑单测 | `bash <skill>/scripts/run_suite.sh`（执行 `tests/run_test.sh`） |
| 只提取失败 | 跳到第 3 步 |

## 2. 全量运行

```bash
bash <skill>/scripts/run_suite.sh [--log-dir DIR] [--retries 2]
```

- 全量耗时数小时：**后台运行，等待完成通知**；期间最多偶尔用 `tail -3` 看进度，不要频繁查询。
- 完成判定：日志末尾有 `=== DS_TEST_DONE exit=<code> ===` 才算跑完。`run_test.sh` 本身不因单个用例失败而停止，所以 `exit` 只反映最后一条命令，**不代表全部通过**，通过与否看第 3 步的提取结果。
  - 旧规则「最后一个 case 是 `test_zero.py`」已失效（`run_test.sh` 后面又追加了大量用例），不要再用。
- 无 DONE 标记（被 kill、OOM、机器重启）：脚本自动从中断处续跑，最多重试 `--retries` 次；仍失败则停止并报告最后运行的用例。

## 3. 提取失败用例

```bash
python3 <skill>/scripts/extract_failed_cases.py <log> [--output failures.csv] [--xlsx]
```

输出字段：`type`（FAILED/ERROR）、`test`、`reason`，并预留 `category`、`rerun`、`issue` 三列供第 4 步填写。没有失败用例时也会生成只有表头的文件，并打印 `0 records`。

## 4. 分诊

对每个失败用例（先按 `reason` 分组，同因的只需代表性复现一个）：

1. 单独复跑：`cd tests && pytest -v --timeout=1400 "<test>" 2>&1 | tail -80`
2. 按 failure-triage.md 归类并处理，填写：
   - `category`：`env-missing-module` / `network` / `code-defect` / `dcu-unsupported` / `flaky` / `resource` / `other`
   - `rerun`：`PASS` / `FAIL` / `SKIP`
   - `issue`：原因与处理说明（改了哪个文件、装了什么包，或为何无法解决）
3. 修改代码或测试的，列出 diff 交用户确认；**跳过/注释用例、放宽断言需用户确认**。

## 5. 汇报

总用例数（来自 pytest summary）、FAILED/ERROR 数、按 category 统计、复跑后仍失败的清单、日志与失败表路径、需要用户决定的事项。
