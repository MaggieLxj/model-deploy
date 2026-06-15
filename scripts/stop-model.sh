#!/bin/bash
# 停止GLM5、Qwen、DeepSeek或MiniMax模型服务
# 使用方法:
#   ./stop-model.sh - 停止所有服务
#   ./stop-model.sh glm5 - 停止GLM5服务
#   ./stop-model.sh qwen - 停止Qwen服务
#   ./stop-model.sh deepseek - 停止DeepSeek服务
#   ./stop-model.sh minimax - 停止MiniMax服务
#   ./stop-model.sh help - 显示帮助信息

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 脚本路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
stop_help() {
    cat << EOF
========================================
    模型服务停止脚本
========================================

使用方法:
    $0 [model_type]

可用选项:
    无参数        - 停止所有运行中的服务
    glm5          - 停止GLM-5-GGUF服务
    qwen          - 停止Qwen3.5-27B服务
    deepseek      - 停止DeepSeek-V4-Flash服务
    minimax       - 停止MiniMax-M2.7-GGUF服务
    help          - 显示此帮助信息

示例:
    $0            # 停止所有服务
    $0 glm5       # 停止GLM5服务
    $0 qwen       # 停止Qwen服务
    $0 deepseek   # 停止DeepSeek服务
    $0 minimax    # 停止MiniMax服务

EOF
}

# 停止服务
stop_service() {
    local model_type=$1

    case $model_type in
        glm5)
            print_info "停止GLM-5-GGUF服务..."
            docker-compose -f docker-compose.glm5.yaml down
            print_info "GLM5服务已停止"
            ;;

        qwen)
            print_info "停止Qwen3.5-27B服务..."
            docker-compose -f docker-compose.qwen.yaml down
            print_info "Qwen服务已停止"
            ;;

        deepseek)
            print_info "停止DeepSeek-V4-Flash服务..."
            docker-compose -f docker-compose.deepseek2.yaml down
            print_info "DeepSeek服务已停止"
            ;;

        minimax)
            print_info "停止MiniMax-M2.7-GGUF服务..."
            docker-compose -f docker-compose.minimax.yaml down
            print_info "MiniMax服务已停止"
            ;;

        "")
            print_warning "停止所有运行中的服务..."

            if docker ps | grep -q "glm5-llama-server"; then
                print_info "停止GLM5服务..."
                docker-compose -f docker-compose.glm5.yaml down
            fi

            if docker ps | grep -q "qwen35-server"; then
                print_info "停止Qwen服务..."
                docker-compose -f docker-compose.qwen.yaml down
            fi

            if docker ps | grep -q "vllm-ds4-server"; then
                print_info "停止DeepSeek服务..."
                docker-compose -f docker-compose.deepseek2.yaml down
            fi

            if docker ps | grep -q "minimax27-llama-server"; then
                print_info "停止MiniMax服务..."
                docker-compose -f docker-compose.minimax.yaml down
            fi

            if ! docker ps | grep -q "glm5-llama-server" && ! docker ps | grep -q "qwen35-server" && ! docker ps | grep -q "vllm-ds4-server" && ! docker ps | grep -q "minimax27-llama-server"; then
                print_info "所有服务已停止"
            else
                print_error "停止服务时出现错误"
                exit 1
            fi
            ;;

        help|--help|-h)
            stop_help
            exit 0
            ;;

        *)
            print_error "未知参数: $model_type"
            echo ""
            stop_help
            exit 1
            ;;
    esac
}

# 检查服务是否运行
check_running() {
    if [ "$1" = "glm5" ] && docker ps | grep -q "glm5-llama-server"; then
        return 0
    elif [ "$1" = "qwen" ] && docker ps | grep -q "qwen35-server"; then
        return 0
    elif [ "$1" = "deepseek" ] && docker ps | grep -q "vllm-ds4-server"; then
        return 0
    elif [ "$1" = "minimax" ] && docker ps | grep -q "minimax27-llama-server"; then
        return 0
    else
        return 1
    fi
}

# 主流程
main() {
    local model_type=$1

    # 检查并设置执行权限
    chmod +x "$SCRIPT_DIR/start-model.sh"
    chmod +x "$SCRIPT_DIR/stop-model.sh"

    if [ -n "$model_type" ]; then
        if check_running "$model_type"; then
            stop_service "$model_type"
        else
            print_warning "服务未运行: $model_type"
        fi
    else
        # 检查是否有服务在运行
        if ! docker ps | grep -qE "glm5-llama-server|qwen35-server|vllm-ds4-server|minimax27-llama-server"; then
            print_info "没有运行中的服务"
            exit 0
        fi
        stop_service ""
    fi
}

main
