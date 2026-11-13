# 开源处理报告：<源分支> → <公开分支>

- 源分支：`<branch>` @ `<hash>`
- 上游基点：`<hash>`（<subject>）
- 本地开源分支：`ds-v<ver>-os`（已暂存 / 已提交 / **未推送**）
- 公开目标：`opensource` → `v<ver>-dev`
- 历史策略：squash / 保留历史（理由）
- 相对上游的差异：<n> 个文件（复现：`git diff --cached --shortstat <base>`）

## 一、剔除的文件

| 路径 | 原因 |
| --- | --- |

## 二、敏感信息扫描

命令：`scan_sensitive.sh --base <base> --ref INDEX [--history]`

| 位置 | 命中内容（脱敏） | 处理：删除 / 替换 / 确认可公开（理由） |
| --- | --- | --- |

结论：CLEAN / 已全部处理 / <k> 项待确认

## 三、License 检查

- 缺少 SPDX 头的新增文件：<列表或「无」>
- `LICENSE`、`THIRD_PARTY_NOTICES.md`：存在 / 缺失

## 四、人工检查项

- [ ] README 链接均为公开地址
- [ ] Dockerfile 基础镜像可公开拉取
- [ ] 注释中无内部 issue / 人员 / 讨论
- [ ] 无内部 CI 专用的硬编码

## 五、编译验证

| 项 | 结果 |
| --- | --- |
| ds-build（`--ops default`） | 通过 / 失败（日志） |
| `import deepspeed` / `ds_report` | |
| 指定测试（如执行） | |

## 六、待用户确认

1. 是否提交：`[das] chore(release): open-source v<ver> based on upstream <hash>`
2. 是否推送：`git push opensource ds-v<ver>-os:v<ver>-dev`（**公开且不可撤回**）
3. …
