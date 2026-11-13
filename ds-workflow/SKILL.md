---
name: ds-workflow
description: Orchestrates DeepSpeed DAS (Hygon DCU/DTK port) work in a DeepSpeed checkout — environment checks, deciding which stages are needed, and chaining ds-merge, ds-build, ds-test and ds-opensource. Use when a request spans more than one of merge/compile/test/open-source, when the user asks for "the full flow", or when it is unclear which DeepSpeed stage is needed.
---

# DeepSpeed DAS 总控工作流

在 DeepSpeed 仓库根目录下使用。本 skill 只负责**判断做什么、按什么顺序做、做完怎么汇报**；具体步骤在各子 skill 中。

开始前先读 [references/conventions.md](references/conventions.md)（提交、确认、产物约定），涉及编译或测试再读 [references/environment.md](references/environment.md)。

## 1. 环境检查

按需执行，只检查本次任务会用到的部分：

| 检查 | 命令 | 需要的阶段 |
| --- | --- | --- |
| 位于仓库根目录 | `test -f setup.py -a -d deepspeed -a -d op_builder` | 全部 |
| 工作区状态 | `git status -sb`；`test -f .git/MERGE_HEAD` 判断是否有未完成的合并 | 全部 |
| DCU 可用且空闲 | `hy-smi`（看 VRAM%/HCU% 是否接近 0） | 编译、测试 |
| torch 可用 | `python3 -c "import torch;print(torch.__version__, torch.rand(2,3).cuda())"` | 编译、测试 |
| GitHub 可达 | `git ls-remote --heads upstream master` | 合并、开源 |

存在未提交改动或未完成的合并时，**先向用户说明现状**，不要自行 stash / reset / abort。

## 2. 任务分类

根据用户原话选择阶段，**不要自行扩大范围**（用户只说跑一个文件，就不要跑全量）：

| 用户意图 | 阶段 |
| --- | --- |
| 合并上游 | ds-merge（其内部包含语法检查；是否继续编译需问用户或按用户原话） |
| 只编译 / 安装 | ds-build |
| 只跑测试 / 指定用例 | ds-test（如安装的包不是当前代码，先提示是否需要重编） |
| 只提取失败用例 | ds-test 第 4 步 |
| 开源处理 | ds-opensource（依赖 ds-build 做编译验证） |
| 全流程 | ds-merge → ds-build → ds-test → 汇总 |

## 3. 阶段串联规则

- 每个阶段结束都要产出该阶段的报告（见 conventions.md「产物」），并给出**通过 / 失败 / 需确认**结论，再决定是否进入下一阶段。
- 上一阶段失败时停止，不带着失败往后走。例外：用户明确说「编译失败也继续跑能跑的测试」。
- ds-merge 只做到**暂存不提交**；提交前必须让用户审阅 checklist（见 conventions.md「必须确认的操作」）。
- 长任务（编译、全量单测）放后台运行，用完成标记判断结束，不要高频轮询。

## 4. 最终汇报

按以下结构汇报，失败项要附日志路径和关键报错行：

1. 做了哪些阶段，各自结论
2. 产物路径（checklist、编译日志、wheel、测试日志、失败用例表、开源报告）
3. 需要用户决定的事项（逐条列出，附推荐选项）
4. 未做的事项及原因（如未提交、未推送、未跑全量）
