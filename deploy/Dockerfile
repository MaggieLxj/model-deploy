
FROM vllm/vllm-openai:v0.22.1

USER root

# 安装必要的系统依赖
RUN apt-get update && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade nvidia-cutlass-dsl[cu13]==4.5.0

# 保留 /dev/shm 用于更大的共享内存
VOLUME ["/dev/shm"]



