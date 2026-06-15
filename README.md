# LLM 模型服务部署文档

本仓库记录了在 NVIDIA H100 (8×80GB) 服务器上部署 DeepSeek、GLM、MiniMax、Qwen 四个大语言模型推理服务的完整方案，包括部署配置、资源占用、运维脚本等。

## 目录结构

```
├── README.md                          # 本文档
├── docs/
│   └── 部署说明.md                     # 详细部署说明与资源占用分析
├── deploy/
│   ├── docker-compose.deepseek2.yaml  # DeepSeek V4 Flash 服务配置
│   ├── docker-compose.glm5.yaml       # GLM-5.1 GGUF 服务配置
│   ├── docker-compose.minimax.yaml    # MiniMax M2.7 GGUF 服务配置
│   ├── docker-compose.qwen.yaml       # Qwen 3.6 27B 服务配置
│   └── Dockerfile                     # DeepSeek 专用 vLLM 镜像
├── scripts/
│   ├── start-model.sh                 # 统一启动脚本
│   └── stop-model.sh                  # 统一停止脚本
└── TASK_RECORD.md                     # 任务记录
```

## 服务概览

| 模型 | 推理框架 | 端口 | GPU 分配 | 量化方式 | 模型文件大小 | 最大上下文长度 |
|------|----------|------|----------|----------|-------------|---------------|
| DeepSeek V4 Flash | vLLM (自定义镜像) | 9996 | GPU 4-7 (4卡) | FP8 权重 + FP8 KV Cache | 149 GB | 384K |
| GLM-5.1 | llama.cpp | 9996 | GPU 4-7 (4卡) | UD-Q2_K_XL (GGUF) | 236 GB | 405K |
| MiniMax M2.7 | llama.cpp | 9996 | GPU 2-3 (2卡) | UD-IQ4_XS (GGUF) | 101 GB | 196K |
| Qwen 3.6 27B | vLLM (官方镜像) | 9993 | GPU 7 (1卡) | BF16 + FP8 KV Cache | 52 GB | 262K |

> 详细说明请参阅 [docs/部署说明.md](docs/部署说明.md)。

## 快速使用

### 启动服务

```bash
./scripts/start-model.sh deepseek   # 启动 DeepSeek
./scripts/start-model.sh glm5       # 启动 GLM-5.1
./scripts/start-model.sh minimax    # 启动 MiniMax
./scripts/start-model.sh qwen       # 启动 Qwen
```

### 停止服务

```bash
./scripts/stop-model.sh deepseek    # 停止 DeepSeek
./scripts/stop-model.sh glm5        # 停止 GLM-5.1
./scripts/stop-model.sh             # 停止所有服务
```

## 硬件环境

- **GPU**: 8 × NVIDIA H100 80GB HBM3
- **GPU 显存**: 每卡 81559 MiB (约 80 GB)
- **总显存**: 8 × 80 GB ≈ 640 GB

## GPU 分配策略

| GPU 编号 | 分配服务 | 说明 |
|----------|----------|------|
| 0-1 | 保留 | 可用于其他任务 |
| 2-3 | MiniMax M2.7 | 2卡 tensor split |
| 4-7 | DeepSeek V4 / GLM-5.1 | 4卡并行（互斥，不可同时运行） |
| 7 | Qwen 3.6 27B | 单卡运行 |

> **注意**: DeepSeek 和 GLM-5 共用 GPU 4-7，不可同时运行。Qwen 与 DeepSeek/GLM 共用 GPU 7，需注意冲突。

## API 端点

所有服务均兼容 OpenAI API 格式：

| 模型 | API Base URL | 模型名称 |
|------|-------------|----------|
| DeepSeek V4 Flash | `http://localhost:9996/v1` | `ds-4-flash` |
| GLM-5.1 | `http://localhost:9996/v1` | `glm-5` |
| MiniMax M2.7 | `http://localhost:9996/v1` | `minimax-m2.7` |
| Qwen 3.6 27B | `http://localhost:9993/v1` | `qwen-3.6-27b` |