# 全局约定（所有 ds-* skill 共用）

## 必须先征得用户确认的操作

| 操作 | 说明 |
| --- | --- |
| `git commit` | 合并、修复、开源处理都只暂存，提交前给出变更摘要等用户确认 |
| `git push` / 推送到任何 remote | 尤其是 `opensource`（公开 GitHub），推送即公开，无法真正撤回 |
| `Signed-off-by` | DCO 签名是人的声明，agent 不得自行添加 `--signoff`；用户要求时由用户执行 `git commit --amend -s --no-edit` |
| `git reset --hard` / `merge --abort` / `stash` / 删除分支 | 会丢失工作，先说明影响 |
| 删除 `dist/`、日志、旧 wheel | 先移到 `dist/old/` 等备份目录，而不是直接删 |
| 跳过 / 注释测试用例、修改测试断言 | 属于「降低测试标准」，需说明理由并确认 |
| `pip install` 升级/降级 torch 等核心包 | 可能破坏 DTK 配套环境 |

只读操作（fetch、log、diff、grep、py_compile、跑测试）无需确认。

## 提交信息格式

```
[das] <type>(<scope>): <subject>

<body：做了什么、为什么>

Prepared with the help of an AI assistant (Claude Code); resolutions were
reviewed and approved before being applied.

Co-Authored-By: <实际执行的模型名> <noreply@anthropic.com>
```

- `type`：`feat` / `fix` / `chore` / `ci` / `docs` / `test` / `refactor`
- 上游同步固定为：`[das] chore(merge): sync upstream <ref> on <YYYY-MM-DD>`，body 写 `Merge deepspeedai/DeepSpeed <ref>@ <11位hash> into <branch>.`
- 日期用实际执行当天日期；`Co-Authored-By` 写**真实**模型名，不照抄模板。

## 产物

所有报告与日志统一放在仓库外的工作目录，避免污染仓库或被误提交：

```
${DS_WORK_DIR:-/workspace/deepspeed-work}/
  merge-<YYYYMMDD>/checklist.md, lists.md
  build/compile_<version>_<YYYYMMDD-HHMM>.log
  test/test_ds_<version>_<YYYYMMDD-HHMM>.log, failures_<...>.csv
  opensource-<branch>-<YYYYMMDD>/report.md
```

报告里的结论必须可复现：写出用来得出结论的命令或哈希比较方式。

## 分支命名

| 用途 | 规则 | 例 |
| --- | --- | --- |
| 开发分支 | `ds-v<上游版本>-dev` | `ds-v0.20.1-dev` |
| 本地开源分支 | `ds-v<上游版本>-os` | `ds-v0.20.1-os` |
| 公开仓库分支（`opensource`） | `v<上游版本>-dev` | `v0.20.1-dev`（已发布：`v0.19.2-dev`、`v0.19.7-dev`） |
| 合并前备份 | `backup/<branch>-before-merge-<YYYYMMDD>` | |
