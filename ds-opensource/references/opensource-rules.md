# 开源规范

> 标注 **[待确认]** 的条目是根据现有分支推断的，尚未得到明确规定。确认后请删掉标注，或改成正确的规则。

## 一、哪些内容不能公开

| 类别 | 说明 | 处理 |
| --- | --- | --- |
| 内部 CI / 构建基础设施 | `.gitlab-ci.yml`、`.github/scripts/*`（内网 pip 源、文件服务器、DTK 安装包路径、内部 whl 链接） | 整体剔除（exclude-paths.txt） |
| 内网地址 | `10.x.x.x`、`172.16-31.x.x`、`192.168.x.x`、`42.228.13.241` 等内部服务 IP、内部 GitLab 域名 | 删除或替换为公开地址 |
| 内部路径 | `/public/home/...`、`/ArchivedFile/...`、个人 home 目录、`/workspace/...` 中的个人路径 | 改成通用写法（如 `$DTKROOT`、`<path-to-repo>`） |
| 凭据 | token、密码、私钥、AK/SK、`.netrc`、带密码的 URL | **立即停止**，告知用户；即使从树中删除，历史中仍存在 → 必须用 squash 策略并考虑轮换凭据 |
| 个人信息 | 内部邮箱、工号、姓名（`Co-Authored-By` 等 AI 署名不算） | 删除；提交作者使用用户的公开身份 |
| 内部调试产物 | `tmp.txt`、`*.log`、`dist/`、`build/`、构建生成的 `git_version_info_installed.py` | 剔除 |
| 未发布的硬件信息 | 未公开的 DCU 型号、内部代号 **[待确认：具体清单]** | 问用户 |

## 二、需要保留的内容

- 所有 DCU/ROCm 适配代码（`csrc/`、`op_builder/`、`setup.py` 中的 `hcu_version`/DTK 逻辑等）。
- `README.md`（DAS 对外说明）、`README_ORIGIN.md`（上游 README 存档）。
- `docker/Dockerfile.rocm`：检查基础镜像是否为公开镜像（光源/hub 公开地址）**[待确认]**。
- `tests/run_test.sh`、`tests/extract_fail.py`：此前的开源分支 `ds-v0.19.2-os` 中保留了 `run_test.sh` **[待确认：extract_fail.py 是否公开]**。

## 三、历史策略

| 策略 | 做法 | 适用 |
| --- | --- | --- |
| **squash（默认）** | 公开分支 = 上游基点 + 一个 DAS 提交，提交内容为剔除后的完整差异 | 内部历史中出现过内网地址或凭据（`.gitlab-ci.yml` 在历史中已存在，所以默认必须 squash） |
| 保留历史 | 直接推送清理后的分支 | 仅当 `scan_sensitive.sh --history` 对整段内部历史均为 0 命中 |

**仅在树中删除文件不能消除历史中的内容。** 只要历史中出现过 `.gitlab-ci.yml`，就不能带着内部历史推送。

**[待确认]** 已发布的 `opensource/v0.19.2-dev`、`v0.19.7-dev` 采用的是哪种策略。本地没有这两个提交，拉取超时，暂时无法核对。

## 四、License

- 仓库整体为 Apache-2.0，保留 `LICENSE`，以及上游的 `THIRD_PARTY_NOTICES.md`。
- 修改的上游文件：保留原有 SPDX 头和 `# DeepSpeed Team`，不删改。
- DAS 新增文件需要 SPDX 头：
  ```python
  # Copyright (c) <year> <版权方> **[待确认：版权方写法]**
  # SPDX-License-Identifier: Apache-2.0

  # DeepSpeed Team
  ```
  C/C++/CUDA 文件用 `//` 注释。
- 检查新增文件是否缺少 SPDX 头：
  ```bash
  git diff --cached --name-only --diff-filter=A <base> | grep -E '\.(py|sh|cpp|h|cu|cuh)$' \
    | xargs -r grep -L 'SPDX-License-Identifier'
  ```

## 五、人工检查项（扫描不能代替）

- [ ] README 中的下载链接、镜像地址、联系方式都是公开的
- [ ] Dockerfile 的基础镜像可公开拉取
- [ ] 代码注释中没有内部 issue 链接、内部人员姓名、内部讨论
- [ ] 没有内部 CI 才会用到的硬编码（如 `REPORTS_DIR`、内部 runner tag `nmz`）
- [ ] 版本号与公开分支名一致（`version.txt` 跟随上游，DAS 版本由 `hcu_version` 体现）
