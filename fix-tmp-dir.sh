#!/bin/bash
# 修复 openclaw 在 Termux 中的 /tmp 目录问题

echo "正在修复 openclaw 的 /tmp 目录问题..."

# 设置变量
NPM_GLOBAL="$HOME/.npm-global"
BASE_DIR="$NPM_GLOBAL/lib/node_modules/openclaw"
LOG_DIR="$HOME/openclaw-logs"

# 1. 创建必要的目录
echo "[1/3] 创建目录..."
mkdir -p "$LOG_DIR"
mkdir -p "$HOME/tmp"

# 2. 创建 /tmp 目录和符号链接
echo "[2/3] 创建 /tmp 符号链接..."
mkdir -p /tmp 2>/dev/null || true
rm -rf /tmp/openclaw 2>/dev/null || true
ln -sf "$LOG_DIR" /tmp/openclaw

# 3. 应用补丁（如果 logger 文件存在）
echo "[3/3] 应用 logger 补丁..."
LOGGER_FILE="$BASE_DIR/dist/logging/logger.js"
if [ -f "$LOGGER_FILE" ]; then
    node -e "const fs = require('fs'); const file = '$LOGGER_FILE'; let c = fs.readFileSync(file, 'utf8'); c = c.replace(/\/tmp\/openclaw/g, process.env.HOME + '/openclaw-logs'); fs.writeFileSync(file, c);" && echo "✓ Logger 补丁应用成功"
else
    echo "⚠ Logger 文件不存在，跳过补丁"
fi

echo ""
echo "✓ 修复完成！"
echo ""
echo "现在可以启动 openclaw："
echo "export PATH=$NPM_GLOBAL/bin:\$PATH"
echo "export TMPDIR=\$HOME/tmp"
echo "export OPENCLAW_GATEWAY_TOKEN=你的token"
echo "openclaw gateway --bind lan --port 18789 --token \$OPENCLAW_GATEWAY_TOKEN --allow-unconfigured"
