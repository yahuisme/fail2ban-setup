#!/bin/bash

# ==============================================================================
# Fail2ban 增强安装与配置脚本
#
# 此脚本运行时不会有任何警告或确认提示，并提供
# 带有颜色的、美化的中文输出界面以提升用户体验。
# ==============================================================================

set -e

# --- 颜色定义 ---
# 检查标准输出是否为终端，以决定是否使用颜色，否则留空。
if [ -t 1 ]; then
  NC='\033[0m' # 无颜色
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  WHITE='\033[1;37m'
else
  NC=''
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  CYAN=''
  WHITE=''
fi

# --- 日志输出辅助函数 ---
msg_info() {
  echo -e "${BLUE}ℹ  $1${NC}"
}
msg_step() {
  echo -e "\n${CYAN}==> $1${NC}"
}
msg_ok() {
  echo -e "${GREEN}✓  $1${NC}"
}
msg_error() {
  echo -e "${RED}✗  错误: $1${NC}" >&2
  exit 1
}

# --- 默认变量 ---
SSH_PORT="22"

# --- 函数：显示用法 ---
show_usage() {
    echo -e "${WHITE}用法: $0 [-p | --port <额外端口>] [-h | --help]${NC}"
    echo ""
    echo "此脚本将自动安装和配置 Fail2ban 以保护 SSH 服务。"
    echo "脚本总是会保护标准的 22 端口。"
    echo ""
    echo -e "${YELLOW}选项:${NC}"
    echo "  -p, --port <额外端口>   除了 22 端口外，额外指定一个需要保护的 SSH 端口。"
    echo "  -h, --help                显示此帮助信息。"
    exit 0
}

# --- 解析命令行参数 ---
CUSTOM_PORT_SPECIFIED=false
if [[ "$#" -gt 0 ]]; then
    case $1 in
        -p|--port)
            SSH_PORT="$2"
            CUSTOM_PORT_SPECIFIED=true
            shift; shift
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            msg_error "未知参数: $1"
            ;;
    esac
fi

# --- 验证端口号 (如果已指定) ---
if $CUSTOM_PORT_SPECIFIED; then
    if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
        msg_error "无效的端口号 '$SSH_PORT'。请输入 1 到 65535 之间的数字。"
    fi
fi

# --- 生成最终的端口列表 ---
if [ "$SSH_PORT" -eq 22 ]; then
    PORT_LIST="22"
else
    # 如果用户指定了自定义端口，则同时保护 22 端口和该端口
    PORT_LIST="22,${SSH_PORT}"
fi

# --- 开始部署 ---
echo -e "${WHITE}"
echo "================================================="
echo "      Fail2ban 自动化部署脚本"
echo "================================================="
echo -e "${NC}"
msg_info "将要保护的端口: ${YELLOW}${PORT_LIST}${NC}"
msg_info "封禁策略: 3次失败后永久封禁"
msg_info "日志后端: ${YELLOW}systemd${NC}"


# --- 步骤 1: 安装 Fail2ban ---
msg_step "[1/4] 检测系统并安装 Fail2ban..."
if [ -x "$(command -v apt-get)" ]; then
  sudo apt-get update -y > /dev/null
  sudo apt-get install -y fail2ban > /dev/null
elif [ -x "$(command -v dnf)" ]; then
  sudo dnf install -y epel-release > /dev/null
  sudo dnf install -y fail2ban > /dev/null
elif [ -x "$(command -v yum)" ]; then
  sudo yum install -y epel-release > /dev/null
  sudo yum install -y fail2ban > /dev/null
else
  msg_error "无法找到 apt, dnf, 或 yum。此脚本不支持你的操作系统。"
fi
msg_ok "Fail2ban 安装成功。"

# --- 步骤 2: 创建配置文件 ---
msg_step "[2/4] 创建配置文件 /etc/fail2ban/jail.local..."
sudo systemctl stop fail2ban
sudo bash -c "cat > /etc/fail2ban/jail.local" << EOF
# --- 由一键脚本自动生成 ---

[DEFAULT]
bantime = -1
findtime = 300
maxretry = 3
banaction = iptables-allports
action = %(action_mwl)s

[sshd]
ignoreip = 127.0.0.1/8
enabled = true
filter = sshd
port = ${PORT_LIST}
backend = systemd
maxretry = 3
findtime = 300
bantime = -1
banaction = iptables-allports
action = %(action_mwl)s
EOF
msg_ok "配置文件创建成功。"

# --- 步骤 3: 启动并启用服务 ---
msg_step "[3/4] 启动并启用 Fail2ban 服务..."
sudo systemctl enable fail2ban > /dev/null 2>&1
sudo systemctl start fail2ban
msg_ok "Fail2ban 服务已启动。"

# --- 步骤 4: 验证配置 ---
msg_step "[4/4] 验证 sshd jail 状态..."
sleep 2 # 等待服务完全启动
sudo fail2ban-client status sshd > /tmp/fail2ban_status.txt
echo -e "${WHITE}-------------------------------------------------${NC}"
cat /tmp/fail2ban_status.txt
echo -e "${WHITE}-------------------------------------------------${NC}"
rm /tmp/fail2ban_status.txt
msg_ok "状态检查完成。"

# --- 最终总结 ---
echo ""
echo -e "${GREEN}================================================="
echo -e "✓  操作完成！"
echo -e "   Fail2ban 已成功部署。"
echo -e "   正在保护的端口: ${YELLOW}${PORT_LIST}${NC}"
echo -e "=================================================${NC}"
echo ""
echo -e "${YELLOW}重要提示：请务必记住如何手动解封IP，以防万一！"
echo -e "手动解封命令: ${WHITE}sudo fail2ban-client set sshd unbanip <你的IP地址>${NC}"
echo ""
