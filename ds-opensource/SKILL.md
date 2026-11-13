---
name: ds-opensource
description: Prepare an internal DeepSpeed DAS branch (e.g. ds-v0.20.1-dev) for publishing to the public HYGON-AI/Deepspeed-das GitHub repo — strip internal CI and infrastructure, scan the tree and history for internal IPs, hosts, paths, credentials and personal data, check license headers, squash onto the upstream base, compile-verify, and produce a release report. Use when the user asks to open-source, publish, release externally, make an -os branch, or clean a branch for GitHub.
---

# 开源处理

在 DeepSpeed 仓库根目录执行。完整规范见 [references/opensource-rules.md](references/opensource-rules.md)，剔除清单见 [references/exclude-paths.txt](references/exclude-paths.txt)。

**推送到 `opensource` 即公开发布，无法真正撤回。本 skill 只在本地生成开源分支和报告，推送必须由用户明确确认。**

## 0. 确定参数并复述给用户

| 参数 | 默认 |
| --- | --- |
| 源分支 | 用户指定，如 `ds-v0.20.1-dev` |
| 上游基点 | 源分支最近一次合入的上游提交：`git merge-base <源分支> upstream/master`（合的是 tag 时用该 tag） |
| 本地开源分支 | `ds-v<版本>-os` |
| 公开分支名 | `opensource` 上的 `v<版本>-dev`（与已发布的 `v0.19.2-dev`、`v0.19.7-dev` 一致） |
| 历史策略 | **squash**：上游基点 + 一个 DAS 提交（见规范「历史策略」）。如用户要求保留历史，必须对整段历史做扫描 |

## 1. 生成开源分支（本地，不推送）

```bash
bash <skill>/scripts/prepare_os_branch.sh --src ds-v0.20.1-dev [--base <upstream-commit>] [--name ds-v0.20.1-os]
```

脚本：从上游基点建分支 → 取源分支的完整树 → 删除 exclude-paths.txt 中的路径 → 暂存（不提交）。

## 2. 敏感信息扫描（必做）

```bash
bash <skill>/scripts/scan_sensitive.sh --base <upstream-base> --ref INDEX    # 本次要公开的新增内容
bash <skill>/scripts/scan_sensitive.sh --base <upstream-base> --ref <源分支> --history   # 仅保留历史时
```

每个命中逐条判定：**删除 / 替换为公开地址或占位符 / 确认可公开（写明理由）**。无法判断的问用户。扫描结果为 0 不代表安全，还要人工过一遍规范中的「人工检查项」。

## 3. 规范检查

- 新增文件的 license 头（规范「License」一节）：`python3 scripts/check-license.py` 若仓库提供则运行，否则用规范中的 grep。
- `README.md` 为对外 DAS 说明，下载链接、联系方式必须是公开地址。
- 提交信息、作者邮箱不含内部账号（squash 后由用户本人作为作者提交）。

## 4. 编译验证

调用 ds-build（`--ops default`），确认剔除内部文件后仍能编译、安装、`import deepspeed`。可选：按用户要求跑 ds-test 的指定用例。

## 5. 报告与确认

用 [templates/os-report.md](templates/os-report.md) 生成 `$DS_WORK_DIR/opensource-<分支>-<日期>/report.md`：剔除的文件、扫描命中及处理、license 检查、编译结果、待确认项。

用户确认后：
1. 提交：`[das] chore(release): open-source v<版本> based on upstream <base 11位hash>`（格式见 conventions.md）。
2. 推送命令只给出、由用户执行或用户明确说「推送」后再执行：
   `git push opensource ds-v<版本>-os:v<版本>-dev`
