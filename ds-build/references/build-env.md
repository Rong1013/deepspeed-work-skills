# 编译环境与选项

## 环境变量

```bash
source /opt/dtk/env.sh
export BUILD_ROOT=$(pwd)
TORCH_LIB=$(python3 -c 'import torch,os;print(os.path.join(os.path.dirname(torch.__file__),"lib"))')
export LD_LIBRARY_PATH=$TORCH_LIB:$BUILD_ROOT/third_party/libaio_build/lib:$LD_LIBRARY_PATH
export C_INCLUDE_PATH=$BUILD_ROOT/third_party/libaio_build/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$BUILD_ROOT/third_party/libaio_build/include:$CPLUS_INCLUDE_PATH
export CFLAGS="-I$BUILD_ROOT/third_party/libaio_build/include"
export LDFLAGS="-L$BUILD_ROOT/third_party/libaio_build/lib"
export CXX=hipcc CC=hipcc
export DS_ACCELERATOR=cuda
```

> 旧文档中的 `C_PLUS_INCLUDE_PATH` 是拼写错误，正确变量名为 `CPLUS_INCLUDE_PATH`。

## 依赖

requirements 文件在 `requirements/` 子目录（旧文档写在根目录，已过时）：

```bash
PIP="pip3 install -i http://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com"
$PIP -r requirements/requirements.txt
$PIP -r requirements/requirements-dev.txt --no-deps
$PIP -r requirements/requirements-inf.txt --no-deps
$PIP -r requirements/requirements-autotuning.txt
$PIP -r requirements/requirements-autotuning-ml.txt
$PIP -r requirements/requirements-sd.txt
$PIP -r requirements/requirements-deepcompile.txt
$PIP pluggy iniconfig execnet evaluate
```

- `requirements-1bit-mpi.txt` 已随上游删除 1-bit 通信后端一并移除，不要再安装。
- `cupy` 仅部分测试需要，按需安装。
- 系统 libaio：Ubuntu `apt install libaio-dev`；Rocky/CentOS `yum install libaio-devel`。

## 编译选项

| 预设 | 选项 | 用途 |
| --- | --- | --- |
| `default` | `DS_BUILD_OPS=1 DS_BUILD_EVOFORMER_ATTN=0 DS_BUILD_CUTLASS_OPS=1 DS_BUILD_FP_QUANTIZER=1 DS_BUILD_GDS=1 DS_BUILD_DEEP_COMPILE=1` | 发布 / 全量测试 |
| `minimal` | `DS_BUILD_OPS=0` | 只验证 Python 层，op 运行时 JIT |
| `all` | `DS_BUILD_OPS=1` | 排查哪些 op 编不过 |

- `DS_BUILD_SPARSE_ATTN` 对应的 builder 已被上游删除，设置与否都无效，不再传。
- 编译命令：`python3 setup.py bdist_wheel`，然后 `pip install --force-reinstall --no-deps dist/deepspeed-*.whl`。旧流程的 `setup.py install bdist_wheel` 会重复编译，不再使用。
- 想快速装到当前环境做测试：`pip install --no-build-isolation .`。

## 常见编译错误

| 现象 | 处理 |
| --- | --- |
| `fatal error: libaio.h: No such file` | 检查 `C_INCLUDE_PATH`/`CPLUS_INCLUDE_PATH`；检查 `third_party/libaio_build/include` 是否存在 |
| `cannot find -laio` / `libaio.so.1` 链接失败 | `third_party/libaio_build/lib/libaio.so.1` 曾被误提交为损坏的符号链接（`git cat-file -p` 查看内容）；改用系统 libaio |
| `hipcc: command not found` | 未 `source /opt/dtk/env.sh` |
| 模板参数遮蔽 / `constexpr` 相关报错（fp_quantizer） | 对比上游同名文件是否已修复，优先取上游修复 |
| `warpSize`、`__shfl_*` 相关 | DCU warp size 为 64，检查本地适配是否在合并中丢失（ds-merge 的 `check_adaptations.sh`） |
| `rocm_version` 读取失败 | `DTKROOT` 未设置或 DTK 版本文件路径变化 |

定位规则：**从日志中第一条 `error:` 开始看**，后面的报错多为连锁反应。
