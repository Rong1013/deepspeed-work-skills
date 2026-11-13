---
name: ds-merge
description: Merge upstream deepspeedai/DeepSpeed commits or a release tag into a local DeepSpeed DAS (Hygon DCU/ROCm) branch, resolve conflicts while preserving local ROCm/DCU adaptations, verify no adaptation was silently dropped, and write a merge checklist. Use when the user asks to merge, sync or rebase onto upstream DeepSpeed, pull the latest upstream commits, continue an in-progress upstream merge, or bring a new DeepSpeed version (e.g. v0.20.0) into a ds-v*-dev branch.
---

# 上游合并

在 DeepSpeed 仓库根目录执行。详细规则与冲突处理策略见 [references/merge-rules.md](references/merge-rules.md)，**解决冲突前必须先读**。全局约定见 `../ds-workflow/references/conventions.md`。

## 0. 确定合并参数

| 参数 | 默认 | 用户可指定 |
| --- | --- | --- |
| 上游 ref | `upstream` 最新 release tag（`git tag -l 'v*' --sort=-v:refname \| head -1`） | 指定 tag，或 `master` |
| 本地分支 | 当前分支 | 指定分支（先 checkout） |
| 是否新建分支 | 合并 tag 时新建 `ds-v<tag版本>-dev`（从当前分支切出）；合并 `master` 时直接在当前分支 | 用户指定 |

把确定的参数复述给用户后再开始。

## 1. 预检

```bash
bash <skill>/scripts/merge_preflight.sh <upstream-ref>
```

脚本只读，输出：工作区是否干净、是否已有未完成合并（MERGE_HEAD）、本地/上游提交数、共同祖先、**本地适配文件清单**（共同祖先 → 本地 HEAD 改过的文件），以及上游新提交与本地适配文件的重叠。

- 已有未完成合并、且只是上游又有新提交 → 走 merge-rules.md「叠加到未完成的合并」，**不要**为了继续而自行提交。
- 工作区不干净 → 停下询问用户。

合并前创建备份分支：`git branch backup/<branch>-before-merge-<YYYYMMDD>`。

## 2. 执行合并

```bash
git fetch upstream --tags
git merge --no-commit --no-ff <upstream-ref>
```

## 3. 解决冲突

逐个文件按 merge-rules.md 的判定顺序处理，每个文件记录：**取上游 / 保留本地 / 手工合并** + 一句依据。

- `README.md` 永远保留本地；上游 README 写入 `README_ORIGIN.md`：`git show <upstream-ref>:README.md > README_ORIGIN.md`。
- 无法确定的冲突：保留冲突标记，汇总后一次性向用户提问，附双方代码片段和推荐方案。

## 4. 校验（必做，不可跳过）

```bash
# 本地适配是否被静默丢弃（最重要）
bash <skill>/scripts/check_adaptations.sh --local ORIG_HEAD --upstream MERGE_HEAD
# 冲突标记 / 未合并路径
git diff --name-only --diff-filter=U
git grep -n -E '^(<<<<<<<|>>>>>>>)( |$)' -- . ':!*.md' || echo none
# 变更的 py 文件语法
git diff --cached --name-only --diff-filter=AMR ORIG_HEAD -- '*.py' | xargs -r -n50 python3 -m py_compile
# 符号链接、导入
git ls-files -s | awk '$1=="120000"'
python3 -c "import deepspeed; print(deepspeed.__version__)"
```

合并已提交后复查：`check_adaptations.sh --local <merge>^1 --upstream <merge>^2 --result <merge>`。

`check_adaptations.sh` 报告 `LOST` 的文件：本地改过、但合并结果与上游逐字节一致 → 本地适配被丢弃。逐个确认是否有意（上游已用等价方式修复则可接受，写明依据），否则恢复。**自动合并成功的文件也可能 LOST**，不要只看冲突文件。

## 5. 产出 checklist

用 [templates/checklist.md](templates/checklist.md) 生成 `$DS_WORK_DIR/merge-<YYYYMMDD>/checklist.md`，文件清单用：

```bash
git diff --cached --name-status -M ORIG_HEAD > lists_vs_local.txt     # 本次变更
git diff --cached --name-status <upstream-ref> > lists_vs_upstream.txt # 保留的本地差异
```

checklist 中的每个数字都要能用上面命令复现。

## 6. 收尾

- 保持**已暂存、未提交**状态，向用户汇报：冲突解决明细、LOST 检查结果、需确认事项。
- 用户确认后，按 conventions.md 格式提交：`[das] chore(merge): sync upstream <ref> on <date>`。
- 是否编译验证：按用户要求调用 ds-build。
