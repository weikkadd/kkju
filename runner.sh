#!/bin/bash
# ============================================================
#  NodeRunner 启动脚本 — 不依赖 .so, 直接下载二进制运行
#  由 NodeRunner.jar 插件在服务器启动时自动执行
# ============================================================
set +e
cd "$(dirname "$0")"
LOG="runner.log"
UUID_FILE=".node/uuid.txt"
mkdir -p .node

echo "[runner] 开始 $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG"

# ---- 1. 固定 UUID ----
if [ -f "$UUID_FILE" ]; then
  UUID=$(cat "$UUID_FILE")
  echo "[runner] 复用 UUID: $UUID" | tee -a "$LOG"
else
  UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "9c41f7d2-8be3-4a15-a6c7-3b5e9d1f2c80")
  echo "$UUID" > "$UUID_FILE"
  echo "[runner] 新 UUID: $UUID" | tee -a "$LOG"
fi

# ---- 2. 架构 ----
ARCH=$(uname -m)
case "$ARCH" in
  aarch64|arm64) BIN_URL="https://arm64.ssss.nyc.mn/sb" ;;
  *) BIN_URL="https://amd64.ssss.nyc.mn/sb" ;;
esac

# ---- 3. 下载 sing-box 二进制 ----
SB=".node/sing-box"
if [ ! -x "$SB" ]; then
  echo "[runner] 下载 sing-box: $BIN_URL" | tee -a "$LOG"
  if command -v curl >/dev/null 2>&1; then
    curl -L -sS -o "$SB" "$BIN_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$SB" "$BIN_URL"
  fi
  chmod +x "$SB" 2>/dev/null
fi

if [ ! -x "$SB" ]; then
  echo "[runner] ERROR: 无法下载 sing-box" | tee -a "$LOG"
  exit 1
fi
echo "[runner] sing-box 就绪" | tee -a "$LOG"

# ---- 4. 生成 Reality 密钥 ----
KEY_FILE=".node/key.txt"
if [ -f "$KEY_FILE" ]; then
  private_key=$(grep "PrivateKey:" "$KEY_FILE" | awk '{print $2}')
  public_key=$(grep "PublicKey:" "$KEY_FILE" | awk '{print $2}')
else
  output=$("$SB" generate reality-keypair 2>/dev/null)
  echo "$output" > "$KEY_FILE"
  private_key=$(echo "$output" | awk '/PrivateKey:/ {print $2}')
  public_key=$(echo "$output" | awk '/PublicKey:/ {print $2}')
fi

# ---- 5. 端口 (Render 用 $PORT, 其他用默认) ----
REALITY_PORT="${REALITY_PORT:-${PORT:-10000}}"
HY2_PORT="${HY2_PORT:-}"

# ---- 6. 生成 config.json ----
cat > .node/config.json <<EOF
{
  "log": { "level": "info" },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-reality",
      "listen": "::",
      "listen_port": $REALITY_PORT,
      "users": [{"uuid": "$UUID", "flow": "xtls-rprx-vision"}],
      "tls": {
        "enabled": true,
        "server_name": "www.bing.com",
        "reality": {
          "enabled": true,
          "handshake": {"server": "www.bing.com", "server_port": 443},
          "private_key": "$private_key",
          "short_id": [""]
        }
      }
    }
  ],
  "outbounds": [{"type": "direct"}]
}
EOF
echo "[runner] config.json 已生成" | tee -a "$LOG"

# ---- 7. 生成节点链接文件 ----
IP=$(curl -s -m 3 ipv4.ip.sb 2>/dev/null || curl -s -m 3 api.ipify.org 2>/dev/null || echo "YOUR_IP")
mkdir -p links
cat > links/links.txt <<EOF
vless://$UUID@$IP:$REALITY_PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.bing.com&fp=chrome&pbk=$public_key&type=tcp#Reality-$IP
EOF
cat > links/sub.txt <<EOF
$(base64 < links/links.txt | tr -d '\n')
EOF
echo "[runner] 节点链接已写入 links/links.txt" | tee -a "$LOG"
echo "=========== 节点链接 ===========" | tee -a "$LOG"
cat links/links.txt | tee -a "$LOG"
echo "===============================" | tee -a "$LOG"

# ---- 8. 启动 sing-box (后台, 不阻塞) ----
echo "[runner] 启动 sing-box ..." | tee -a "$LOG"
"$SB" run -c .node/config.json >> .node/sing-box.log 2>&1 &
SB_PID=$!
echo "[runner] sing-box PID: $SB_PID" | tee -a "$LOG"

# ---- 9. 保持前台 (防容器退出) ----
while kill -0 "$SB_PID" 2>/dev/null; do
  sleep 30
done
echo "[runner] sing-box 已退出, 重启..." | tee -a "$LOG"
exec bash "$0"
