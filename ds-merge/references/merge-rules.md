# 合并规则与冲突处理

## 三条硬规则

1. **本地 `README.md` 不动**；上游 README 另存为 `README_ORIGIN.md`（仓库历史一直用这个名字，不要改成 `README_ORI.md`）。
2. **尽量保留 ROCm / AMD / DCU 层面的修改**。
3. **冲突尽量解决；解决不了的汇总后申请用户确认**，不要猜。

## 冲突判定顺序

对每个冲突文件依次判断，命中即停：

| # | 情形 | 处理 |
| --- | --- | --- |
| 1 | `README.md` | 保留本地 |
| 2 | 本地改动是 DCU/ROCm 适配（hip、`is_rocm_pytorch`、`ROCM_HOME`、`__HIP_PLATFORM_AMD__`、hcu、dtk、hyhal/hyfile、warp size 64、`rocblas`/`hipblas`） | 保留本地适配，同时吸收上游的非冲突改动（手工合并） |
| 3 | 上游已用等价或更完整的方式修复同一问题，且有配套单测 | 取上游，在 checklist 写明「上游等价修复：<commit>」 |
| 4 | 上游删除了文件，本地对它有适配 | 先 `git grep` 确认合并后无任何引用；无引用则接受删除并记录，有引用则问用户 |
| 5 | 测试文件：本地移除了在 ROCm 上会误跳过的守卫（如 `bf16_required_version_check`） | 保留本地 |
| 6 | 测试文件：其他冲突 | 以上游为主体，再把本地的设备/精度/容差适配补回去 |
| 7 | `setup.py` | 手工合并：采用上游结构，保留本地 `hcu_version`、`compatible_ops`、`DTKROOT`/`dtk_version_str`、`git_tag or git_branch` 等 DCU 逻辑 |
| 8 | 其余无法判断 | 保留冲突标记，问用户 |

## 已知需要特别关注的本地适配区域

`setup.py`、`op_builder/{builder,async_io,gds}.py`、`csrc/includes/*`、`csrc/transformer/**`、`csrc/gds/py_lib/*`、`csrc/fp_quantizer/*`、`deepspeed/inference/v2/kernels/**`、`deepspeed/comm/torch.py`、`deepspeed/runtime/zero/stage_1_and_2.py`、`tests/conftest.py`、`tests/run_test.sh`、`tests/extract_fail.py`、`.gitlab-ci.yml`、`.github/scripts/*`、`docker/Dockerfile.rocm`。

这些文件在合并后若与上游完全一致，几乎一定是适配丢失，必须复核。

## 叠加到未完成的合并

场景：上次合并已解决冲突并暂存，但还没提交（用户尚未审阅），此时上游又有新提交。**不要为继续合并而自行提交。**

```bash
bash <skill>/scripts/fold_into_pending_merge.sh <new-upstream-ref>
```

脚本做法：
1. 把当前暂存树存为一个悬空提交 `C`（父为 `HEAD` 和旧 `MERGE_HEAD`），并用 `refs/backup/pending-merge-<旧hash>` 指向它，可随时恢复；
2. 在临时 worktree 中从 `C` 合并新 ref（合并基自然为旧 `MERGE_HEAD`）；
3. 无冲突时把结果树读回主工作区并把 `MERGE_HEAD` 改为新 ref；有冲突则停下，保留临时 worktree 路径供处理。

最终仍是一个待提交的合并，父提交为本地 `HEAD` 和最新上游。

## 合并上游 tag 时的分支流程

```bash
git checkout <本地分支>
git checkout -b ds-v<tag版本>-dev        # 例：v0.20.0 -> ds-v0.20.0-dev
git merge --no-commit --no-ff v<tag版本>
```

## 版本号

`version.txt` 跟随上游，不做本地修改；本地版本标识由 `setup.py` 中的 `hcu_version` 体现。

## 测试脚本更新
如果 `deepspeed/test/` 目录中有新增或删除测试文件，需要同步更新该目录下的 `run_test.sh` 脚本。
