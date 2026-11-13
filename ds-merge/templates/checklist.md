# DeepSpeed 上游合并清单（<upstream-ref> → 本地 <branch>）

- 仓库：`<repo path>`
- 本地起点：`<short-hash>`（<subject>）
- 合并来源：`<upstream-ref>` @ `<short-hash>`（<subject>）
- 共同祖先：`<short-hash>`（<subject>）
- 合并跨度：上游 <N> 个提交，本地 <M> 个提交
- 状态：已暂存 / **未提交**（`MERGE_HEAD` = `<hash>`）
- 备份：分支 `backup/<branch>-before-merge-<date>`
- 变更规模：<files> 个文件，新增 <A> / 删除 <D> / 重命名 <R> / 修改 <M>
  - 复现：`git diff --cached --name-status -M ORIG_HEAD | cut -c1 | sort | uniq -c`

## 一、合并规则执行情况

| 规则 | 结果 | 验证方式 |
| --- | --- | --- |
| 1. 本地 README.md 不动，远程 README 存 README_ORIGIN.md | ✅/❌ | `git diff --quiet ORIG_HEAD -- README.md`；`git rev-parse :README_ORIGIN.md` == `git rev-parse <ref>:README.md` |
| 2. 保留 ROCm/DCU 适配 | KEPT=<> MIXED=<> SAME=<> **LOST=<>** DELETED=<> | `check_adaptations.sh` 输出 |
| 3. 冲突解决 | <n> 处，全部解决 / <k> 处待确认 | `git diff --name-only --diff-filter=U` |

## 二、冲突解决明细

### A. 取上游
| 文件 | 依据（上游等价修复的 commit / 配套单测） |
| --- | --- |

### B. 保留本地
| 文件 | 依据（丢失的适配是什么） |
| --- | --- |

### C. 手工合并
| 文件 | 采用了上游什么 / 保留了本地什么 |
| --- | --- |

## 三、LOST / DELETED 复核

| 文件 | 状态 | 结论（有意接受并说明原因 / 已恢复） |
| --- | --- | --- |

## 四、上游带来的结构性变化

- 新增：<n>（主要能力摘要）
- 删除：<n>（下线特性摘要；本地曾适配的已确认无引用）
- 重命名：<n>
- 版本号：`version.txt` <old> → <new>

## 五、验证结果

| 检查项 | 结果 |
| --- | --- |
| 未合并路径 | |
| 冲突标记残留 | |
| 符号链接 | |
| 变更 .py 语法（py_compile） | |
| `import deepspeed` | |
| 编译（ds-build） | 未执行 / 通过 / 失败（日志路径） |

## 六、需要用户确认的事项

1. …
