# deepspeed-work-skills

围绕 Hygon DCU / DTK 适配版 DeepSpeed（DAS）日常工作的 skill 集合。每个子目录是一个独立 skill，可单独触发，也可由总控 skill `ds-workflow` 串联。

| Skill | 用途 | 典型触发语 |
| --- | --- | --- |
| [`ds-workflow`](ds-workflow/SKILL.md) | 总控：环境检查、任务分类、串联下列 skill、统一约定 | “帮我把上游合进来并编译跑测试” |
| [`ds-merge`](ds-merge/SKILL.md) | 拉取上游 commit/tag 合入本地分支，解决冲突，校验本地适配未丢失 | “合并上游 master / v0.20.0” |
| [`ds-build`](ds-build/SKILL.md) | 基于 DTK 环境编译 wheel、安装并验证 | “编译一下当前分支” |
| [`ds-test`](ds-test/SKILL.md) | 跑全量或指定单测、判断完成状态、提取并分诊失败用例 | “跑一下单测 / 只跑 test_zero.py” |
| [`ds-opensource`](ds-opensource/SKILL.md) | 按开源规范从内部分支生成开源分支：剔除内部资产、敏感信息扫描、生成报告 | “把 ds-v0.20.1-dev 做开源处理” |

## 目录结构

```
<skill>/
  SKILL.md          # 触发描述 + 工作流（必需）
  references/       # 按需加载的详细规则、命令、环境说明
  scripts/          # 可直接执行的辅助脚本（相对 SKILL.md 引用）
  templates/        # 输出报告模板
  agents/openai.yaml# 其他 agent 前端的展示信息（可选）
```

## 安装

skill 需放在 Claude Code 能发现的位置之一：

```bash
# 全局可用（推荐）
mkdir -p ~/.claude/skills
for s in ds-workflow ds-merge ds-build ds-test ds-opensource; do
  ln -sfn "$(pwd)/$s" ~/.claude/skills/$s
done

# 或者只对 DeepSpeed 仓库生效
cd <deepspeed-repo> && mkdir -p .claude/skills
for s in ...; do ln -sfn <本仓库>/$s .claude/skills/$s; done
```

注意：DeepSpeed 上游自带 `.claude/skills/pr-checklist`（指向 `.agents/skills/`），不要覆盖它。

## 全局约定

所有 skill 共用 [`ds-workflow/references/conventions.md`](ds-workflow/references/conventions.md)：提交信息格式、哪些操作必须先征得确认、日志与报告的存放位置。修改约定只改这一处。

## 维护

- 环境相关的值（DTK 路径、镜像源、DCU 卡号）集中在 [`ds-workflow/references/environment.md`](ds-workflow/references/environment.md)。
- 每次工作流踩到新坑，把结论补进对应 skill 的 `references/`，而不是 `SKILL.md` 正文，保持 `SKILL.md` 简短。
