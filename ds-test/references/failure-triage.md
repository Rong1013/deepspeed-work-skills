# 失败用例分诊

先看 `reason` 和复跑输出中的**第一个**异常，再归类。

| category | 典型特征 | 处理 |
| --- | --- | --- |
| `env-missing-module` | `ModuleNotFoundError: No module named 'xxx'` | 判断是 Python 包还是系统库。Python 包：`pip install xxx -i http://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com`（常见：`absl-py`、`evaluate`、`cupy`、`mpi4py`）。**不要**升级/降级 torch。系统库：记录并问用户 |
| `network` | `ConnectionError`、`HTTPSConnectionPool`、`huggingface.co` 超时 | `export HF_ENDPOINT=https://hf-mirror.com` 后复跑；仍失败则记录所需模型名 |
| `code-defect` | 断言失败、`AttributeError`、`TypeError`，且与 DCU 无关 | 先对比 `upstream/master` 同名文件是否已修复（`git log upstream/master -- <file>`）；按框架逻辑修复，最小改动 |
| `dcu-unsupported` | `hipErrorInvalidDeviceFunction`、`no kernel image`、warp size 相关、`bf16` 被跳过、`NCCL/RCCL` 不支持的操作、NVIDIA 专有特性（nvtx、cutlass sm90） | 确认是平台限制而非适配缺失：查 ds-merge 的 LOST 列表中是否有相关文件。确属平台限制 → 记录，建议在 `run_test.sh` 中注释并写明原因（需用户确认） |
| `flaky` | 复跑通过、或数值容差边缘失败 | 复跑 3 次记录通过率；不要直接放宽容差 |
| `resource` | `OOM`、`hipErrorOutOfMemory`、端口占用 `Address already in use`、超时 1400s | 检查 `hy-smi` 是否有他人占卡；端口占用可设 `MASTER_PORT`；记录 |
| `other` | 以上都不符合 | 根据报错分析并尝试解决，无法解决则写明卡在哪里 |

## 已知用例背景

- `tests/unit/v1/zero/test_zero_autocast.py`：上游的 `bf16_required_version_check()` 守卫在 ROCm 下返回 False，会让 bf16 用例全部 skip；本地适配是移除该守卫。如果看到 bf16 用例大量 SKIPPED，先检查此处是否在合并中被还原。
- `NCCL_P2P_DISABLE=1` 已在 `run_test.sh` 中用于 autosp 用例。
- 带 `-m inference` 的用例需要显式 marker。

## 复跑命令

```bash
cd tests
pytest -v --timeout=1400 "unit/path/test_x.py::TestClass::test_case[param]" 2>&1 | tail -80
# 多卡用例看 rank 日志时加 -s
```

## 记录要求

`issue` 字段写成「原因 → 处理 → 结果」，例如：
`缺少 absl-py → pip install absl-py → 复跑通过`
`hipblasLt 不支持 fp8 e5m2 → 平台限制，未修改 → 建议注释（待确认）`
