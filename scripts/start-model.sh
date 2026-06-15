#!/bin/bash
# 自动启动GLM5、Qwen、DeepSeek或MiniMax模型服务
# 使用方法:
#   ./start-model.sh glm5     - 启动GLM-5-GGUF服务
#   ./start-model.sh qwen     - 启动Qwen3.5-27B服务
#   ./start-model.sh deepseek - 启动DeepSeek-V4-Flash服务
#   ./start-model.sh minimax  - 启动MiniMax-M2.7-GGUF服务
#   ./start-model.sh help     - 显示帮助信息

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 默认模型类型
MODEL_TYPE=${1:-help}

# 脚本路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打印带颜色的消息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要的Docker命令
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装，请先安装Docker"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose未安装，请先安装Docker Compose"
        exit 1
    fi
}

# 检查GPU可用性
check_gpu() {
    print_info "检查GPU可用性..."

    if ! command -v nvidia-smi &> /dev/null; then
        print_warning "nvidia-smi未找到，可能是本地开发环境"
        return 1
    fi

    # 获取GPU数量
    GPU_COUNT=$(nvidia-smi --list-gpus | wc -l)
    print_info "检测到 $GPU_COUNT 个GPU"

    if [ $GPU_COUNT -lt 4 ]; then
        print_warning "GPU数量不足，服务可能无法正常启动"
        sleep 2
    fi

    return 0
}

# 检查模型文件是否存在
check_model() {
    local model_type=$1

    case $model_type in
        glm5)
            MODEL_DIR="./GLM-5.1-GGUF/UD-Q2_K_XL"
            PORT=9996
            ;;
        qwen)
            MODEL_DIR="./Qwen3.5-27B"
            PORT=9993
            ;;
        deepseek)
            MODEL_DIR="./DeepSeek-V4-Flash"
            PORT=9996
            ;;
        minimax)
            MODEL_DIR="./MiniMax-M2.7-GGUF/UD-IQ4_XS"
            PORT=9996
            ;;
        *)
            return 1
            ;;
    esac

    if [ ! -d "$MODEL_DIR" ]; then
        print_error "模型目录不存在: $MODEL_DIR"
        print_error "请先下载模型文件"
        return 1
    fi

    print_info "模型目录存在: $MODEL_DIR"
    return 0
}

# 显示帮助信息
show_help() {
    cat << EOF
========================================
    模型服务自动启动脚本
========================================

使用方法:
    $0 <model_type>

可用模型类型:
    glm5     - 启动 GLM-5-GGUF 服务
             端口: 9996
             GPU:  4-7

    qwen     - 启动 Qwen3.5-27B 服务
             端口: 9993
             GPU:  8-11

    deepseek - 启动 DeepSeek-V4-Flash 服务
             端口: 9996
             GPU:  4-7

    minimax  - 启动 MiniMax-M2.7-GGUF 服务
             端口: 9996
             GPU:  2-3

    help     - 显示此帮助信息

示例:
    $0 glm5       # 启动GLM5服务
    $0 qwen       # 启动Qwen服务
    $0 deepseek   # 启动DeepSeek服务
    $0 minimax    # 启动MiniMax服务

注意事项:
    - 确保已安装 Docker 和 Docker Compose
    - 确保 GPU 已正确配置
    - 确保模型文件已下载到相应目录

EOF
}

# 构建镜像
build_image() {
    local model_type=$1

    print_info "检查镜像是否存在..."

    if [ "$model_type" = "glm5" ]; then
        IMAGE_NAME="ghcr.io/ggml-org/llama.cpp:full-cuda"
        DOCKER_COMPOSE_FILE="docker-compose.glm5.yaml"

        # GLM5使用预构建镜像，不需要构建
        print_info "GLM5使用预构建镜像: $IMAGE_NAME"
    elif [ "$model_type" = "deepseek" ]; then
        IMAGE_NAME="vllm/vllm-openai:deepseekv4-cu130"
        DOCKER_COMPOSE_FILE="docker-compose.deepseek2.yaml"

        # DeepSeek使用预构建镜像，不需要构建
        print_info "DeepSeek使用预构建镜像: $IMAGE_NAME"
    elif [ "$model_type" = "minimax" ]; then
        IMAGE_NAME="ghcr.io/ggml-org/llama.cpp:full-cuda"
        DOCKER_COMPOSE_FILE="docker-compose.minimax.yaml"

        # MiniMax使用预构建镜像，不需要构建
        print_info "MiniMax使用预构建镜像: $IMAGE_NAME"
    else
        IMAGE_NAME="custom-vllm-qwen"
        DOCKER_COMPOSE_FILE="docker-compose.qwen.yaml"

        # 构建镜像
        print_info "构建Qwen服务镜像..."
        docker-compose -f DOCKER_COMPOSE_FILE build
    fi

    print_info "镜像构建完成"
}

# 启动服务
start_service() {
    local model_type=$1

    case $model_type in
        glm5)
            DOCKER_COMPOSE_FILE="docker-compose.glm5.yaml"

            print_info "启动GLM-5-GGUF服务..."
            docker-compose -f "$DOCKER_COMPOSE_FILE" up -d

            # 等待服务启动
            print_info "等待服务启动（约30秒）..."
            sleep 30

            # 检查服务状态
            if docker ps | grep -q "glm5-llama-server"; then
                print_info "GLM5服务启动成功！"
                echo ""
                print_info "访问地址: http://localhost:9996"
                echo ""
                print_info "Claude Code配置:"
                echo "  API Base URL: http://localhost:9996/v1"
                echo "  模型名称: glm-5"
            else
                print_error "GLM5服务启动失败"
                docker-compose -f "$DOCKER_COMPOSE_FILE" logs
                exit 1
            fi
            ;;

        qwen)
            DOCKER_COMPOSE_FILE="docker-compose.qwen.yaml"
            print_info "启动Qwen3.5-27B服务..."
            docker-compose -f "$DOCKER_COMPOSE_FILE" up -d

            # 等待服务启动
            print_info "等待服务启动（约30秒）..."
            sleep 30

            # 检查服务状态
            if docker ps | grep -q "qwen35-server"; then
                print_info "Qwen服务启动成功！"
                echo ""
                print_info "访问地址: http://localhost:9993"
                echo ""
                print_info "Claude Code配置:"
                echo "  API Base URL: http://localhost:9993/v1"
                echo "  模型名称: qwen-3.5-27b"
            else
                print_error "Qwen服务启动失败"
                docker-compose -f "$DOCKER_COMPOSE_FILE" logs
                exit 1
            fi
            ;;

        deepseek)
            DOCKER_COMPOSE_FILE="docker-compose.deepseek2.yaml"

            print_info "启动DeepSeek-V4-Flash服务..."
            docker-compose -f "$DOCKER_COMPOSE_FILE" up -d

            # 等待服务启动
            print_info "等待服务启动（约30秒）..."
            sleep 30

            # 检查服务状态
            if docker ps | grep -q "vllm-ds4-server"; then
                print_info "DeepSeek服务启动成功！"
                echo ""
                print_info "访问地址: http://localhost:9996"
                echo ""
                print_info "Claude Code配置:"
                echo "  API Base URL: http://localhost:9996/v1"
                echo "  模型名称: ds-4-flash"
            else
                print_error "DeepSeek服务启动失败"
                docker-compose -f "$DOCKER_COMPOSE_FILE" logs
                exit 1
            fi
            ;;

        minimax)
            DOCKER_COMPOSE_FILE="docker-compose.minimax.yaml"

            print_info "启动MiniMax-M2.7-GGUF服务..."
            docker-compose -f "$DOCKER_COMPOSE_FILE" up -d

            # 等待服务启动
            print_info "等待服务启动（约30秒）..."
            sleep 30

            # 检查服务状态
            if docker ps | grep -q "minimax27-llama-server"; then
                print_info "MiniMax服务启动成功！"
                echo ""
                print_info "访问地址: http://localhost:9996"
                echo ""
                print_info "Claude Code配置:"
                echo "  API Base URL: http://localhost:9996/v1"
                echo "  模型名称: minimax-m2.7"
            else
                print_error "MiniMax服务启动失败"
                docker-compose -f "$DOCKER_COMPOSE_FILE" logs
                exit 1
            fi
            ;;
    esac
}

# 主流程
main() {
    case $MODEL_TYPE in
        glm5)
            check_docker
            check_gpu
            check_model "glm5"
            start_service "glm5"
            ;;

        qwen)
            check_docker
            check_gpu
            check_model "qwen"
            start_service "qwen"
            ;;

        deepseek)
            check_docker
            check_gpu
            check_model "deepseek"
            start_service "deepseek"
            ;;

        minimax)
            check_docker
            check_gpu
            check_model "minimax"
            start_service "minimax"
            ;;

        help|--help|-h)
            show_help
            exit 0
            ;;

        *)
            print_error "未知参数: $MODEL_TYPE"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 执行主流程
main
