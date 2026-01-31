#!/bin/bash

# ==========================================
# Openclaw Termux 极部署脚本 v2.0
# ==========================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${BLUE}=========================================="
echo -e "   🦞 Openclaw Termux 零门槛部署工具"
echo -e "==========================================${NC}"

# --- 核心优化：自愈环境检查 ---
echo -e "${YELLOW}🔍 正在检查基础运行环境...${NC}"

# 定义需要的基础包
DEPS=("nodejs" "git" "openssh" "tmux" "termux-api" "termux-tools" "cmake" "python" "golang" "which")
MISSING_DEPS=()

for dep in "${DEPS[@]}"; do
    if ! command -v $dep &> /dev/null; then
        MISSING_DEPS+=($dep)
    fi
done

node -v
npm -v 

touch ~/.bashrc 2>/dev/null

npm config set registry https://registry.npmmirror.com

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo -e "${YELLOW}补充安装缺失组件: ${MISSING_DEPS[*]}...${NC}"
    pkg update -y && pkg upgrade -y
    pkg install ${MISSING_DEPS[*]} -y
else
    echo -e "${GREEN}✅ 基础环境已就绪${NC}"
fi

# --- 交互配置 ---
read -p "请输入 Gateway 端口号 [默认: 18789]: " PORT
PORT=${PORT:-18789}

read -p "是否需要开启开机自启动? (y/n) [默认: y]: " AUTO_START
AUTO_START=${AUTO_START:-y}

# --- 路径与安装 ---
echo -e "\n${YELLOW}🏗️  正在配置 Openclaw...${NC}"

# 配置 NPM 全局环境
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
grep -qxF 'export PATH=$HOME/.npm-global/bin:$PATH' ~/.bashrc || echo 'export PATH=$HOME/.npm-global/bin:$PATH' >> ~/.bashrc
export PATH=$HOME/.npm-global/bin:$PATH

# 安装 Openclaw (静默安装)
npm i -g openclaw > /dev/null 2>&1

BASE_DIR="$HOME/.npm-global/lib/node_modules/openclaw"
LOG_DIR="$HOME/openclaw-logs"
mkdir -p "$LOG_DIR" "$HOME/tmp"

# --- 补丁植入 ---
echo -e "${YELLOW}🛠️  正在应用 Android 兼容性补丁...${NC}"

# 修复 Logger
LOGGER_FILE="$BASE_DIR/dist/logging/logger.js"
if [ -f "$LOGGER_FILE" ]; then
    node -e "const fs = require('fs'); const file = '$LOGGER_FILE'; let c = fs.readFileSync(file, 'utf8'); c = c.replace(/\/tmp\/openclaw/g, process.env.HOME + '/openclaw-logs'); fs.writeFileSync(file, c);"
fi

# 修复剪贴板
CLIP_FILE="$BASE_DIR/node_modules/@mariozechner/clipboard/index.js"
if [ -f "$CLIP_FILE" ]; then
    node -e "const fs = require('fs'); const file = '$CLIP_FILE'; const mock = 'module.exports = { availableFormats:()=>[], getText:()=>\"\", setText:()=>false, hasText:()=>false, getImageBinary:()=>null, getImageBase64:()=>null, setImageBinary:()=>false, setImageBase64:()=>false, hasImage:()=>false, getHtml:()=>\"\", setHtml:()=>false, hasHtml:()=>false, getRtf:()=>\"\", setRtf:()=>false, hasRtf:()=>false, clear:()=>{}, watch:()=>({stop:()=>{}}), callThreadsafeFunction:()=>{} };'; fs.writeFileSync(file, mock);"
fi

# --- 启动逻辑 ---
if [ "$AUTO_START" == "y" ]; then
    sed -i '/# --- Openclaw Start ---/,/# --- Openclaw End ---/d' ~/.bashrc
    cat << EOT >> ~/.bashrc
# --- Openclaw Start ---
export TERMUX_VERSION=1
export TMPDIR=\$HOME/tmp
export PATH=\$HOME/.npm-global/bin:\$PATH
sshd 2>/dev/null
termux-wake-lock 2>/dev/null
alias ocr='pkill -9 node 2>/dev/null; tmux kill-session -t openclaw 2>/dev/null; sleep 1; tmux new -d -s openclaw "export PATH=$HOME/.npm-global/bin:$PATH; openclaw gateway --bind lan --port 18789 --allow-unconfigured --token 123456 || read"'
alias oclog='tmux attach -t openclaw'
alias ockill='pkill -9 node 2>/dev/null; tmux kill-session -t openclaw 2>/dev/null'
# --- OpenClaw End ---
EOF

source ~/.bashrc

# 8. 激活唤醒锁 防止休眠
echo -e "${YELLOW}[5/6] 激活唤醒锁...${NC}"
if command -v termux-wake-lock >/dev/null; then
    termux-wake-lock
    echo -e "${GREEN}✅ Wake-lock 已激活${NC}"
else
    echo -e "${YELLOW}⚠️  termux-api 未安装，建议: pkg install termux-api${NC}"
fi

# 9. 启动
echo -e "${YELLOW}[6/6] 启动服务...${NC}"
ocr
sleep 3

echo -e "${GREEN}部署完成！运行 'oclog' 查看日志${NC}"