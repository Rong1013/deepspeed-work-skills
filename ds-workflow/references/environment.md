# 环境说明（Hygon DCU + DTK）

> 本文件集中存放与机器相关的值。换机器/换 DTK 版本时只改这里。

## 关键路径与变量

| 名称 | 默认值 | 说明 |
| --- | --- | --- |
| DTK 环境脚本 | `/opt/dtk/env.sh` | 编译前必须 `source`，提供 `ROCM_PATH`、`DTKROOT`、hipcc |
| DTK 版本文件 | `$DTKROOT/.info/rocm_version` | 用于确认 DTK 版本 |
| torch lib | `$(python3 -c 'import torch,os;print(os.path.dirname(torch.__file__))')/lib` | 不要写死 `python3.10` 路径 |
| libaio | `$BUILD_ROOT/third_party/libaio_build/{include,lib}` | 系统无 libaio-dev 时使用；Ubuntu 可 `apt install libaio-dev`，Rocky/CentOS 用 `yum install libaio-devel` |
| pip 镜像 | `-i http://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com` | |
| HF 镜像 | `export HF_ENDPOINT=https://hf-mirror.com` | 测试下载模型失败时使用 |
| 可见卡 | `CUDA_VISIBLE_DEVICES=0,1,2,3` | DCU 下沿用 CUDA 变量名；先用 `hy-smi` 确认这些卡空闲 |
| 工作目录 | `DS_WORK_DIR=/workspace/deepspeed-work` | 存放日志和报告 |

## Remote 约定

| remote | 地址 | 用途 |
| --- | --- | --- |
| `upstream` | `https://github.com/deepspeedai/DeepSpeed.git` | 上游源码 |
| `origin` | 内部 GitLab | 内部开发分支，含内部 CI |
| `opensource` | `https://github.com/HYGON-AI/Deepspeed-das.git` | 对外开源仓库，**推送即公开** |

缺少 `upstream` 时：`git remote add upstream https://github.com/deepspeedai/DeepSpeed.git`。

## 已知环境坑

- `bf16_required_version_check()` 在 ROCm 下返回 False，上游测试中的该守卫会让 bf16 用例整体被跳过；本地分支已刻意移除部分守卫。
- `deepspeed/git_version_info_installed.py` 是构建产物（不入 git），版本号显示旧值时重新编译安装即可刷新。
- `third_party/libaio_build/lib/libaio.so.1` 曾被误提交为损坏的符号链接，链接失败时先检查它。
