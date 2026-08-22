#!/bin/bash
# NodeRunner 启动脚本
# 功能：下载 sing-box + cloudflared，用隧道对外暴露节点
set +e
cd "$(dirname "$0")"
LOG=".node/runner.log"
UUID_F=".node/uid.txt"
mkdir -p .node .node/public

echo "[$(date)] 开始" >> "$LOG"

# UUID 持久化
if [ -f "$UUID_F" ]; then UUID=$(cat "$UUID_F")
else UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "auto-$(date +%s)") ;  echo "$UUID" > "$UUID_F"
fi

# 下载文件
ARCH="amd64"
[ "$(uname -m)" = "aarch64" ] && ARCH="arm64"
BASE="https://${ARCH}.ssss.nyc.mn"

for fn in sb bot; do
  if [ ! -f ".node/$fn" ]; then
    echo "下载 $fn ..."
    curl -sL -o ".node/$fn" "$BASE/$fn" || wget -q -O ".node/$fn" "$BASE/$fn"
    chmod +x ".node/$fn"
  fi
done

# 生成 Reality 密钥对
if [ ! -f ".node/key.txt" ]; then
  .node/sb generate reality-keypair > ".node/key.txt"
fi
PRIVATE=$(grep PrivateKey .node/key.txt | awk '{print $2}')
PUBLIC=$(grep PublicKey .node/key.txt | awk '{print $2}')

# 生成配置（sing-box 监听 13101，cloudflared 隧道连它）
cat > .node/config.json <<EOF
{
  "log": {"level": "error"},
  "inbounds": [
    {"type":"vmess","tag":"vmess-ws","listen":"127.0.0.1","listen_port":13801,
     "users":[{"uuid":"$UUID"}],
     "transport":{"type":"ws","path":"/vmess-argo"}}
  ],
  "outbounds":[{"type":"direct"}]
}
EOF

# 启动 sing-box（内部 13801）
.node/sb run -c .node/config.json >> .node/sb.log 2>&1 &
SB_PID=$!
echo "sing-box PID=$SB_PID (127.0.0.1:13801)" | tee -a "LOG"

# 启动 cloudflared（隧道到 13801）
.node/bot tunnel --no-autoupdate --protocol http2 --localhost:13801 >> .node/cf.log 2>&1 &
CF_IP=$!
echo "cloudflared PID=$CF_IP" | tee -a "$LOG"

# 等待域名
sleep 8
    DOMAIN=$(grep -oE '[a-z0-9]+\.trycloudflare\.com' .node/cf.log 2>/dev/null | head -1)
    if [ -z "$DOMAIN" ]; then sleep 5 ;  fi
if [ -z "$DOMAIN" ]; then DOMAIN="隧道获取失败";  fi

echo "域名: $DOMAIN" | tee -a "$LOG"

# 生成节点链接
cat > .node/public/links.txt <<EOF
vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"Cloudflare\",\"add\":\"$DOMAIN\",\"port\":443,\"id\":\"$UUID\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$DOMAIN\",\"path\":\"/vmess\",\"tls\":\"tls\",\"sni\":\"$DOMAIN\",\"fp\":\"chrome\"}" | base64 -w0)

vless://$UUID@$DOMAIN:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$DOMAIN&pbk=$PUBLIC&type=tcp#Reality-CF
EOF
cat .node/public/links.txt | tee -a "$LOG"
echo "节点链接：.node/public/links.txt" | tee -a "$LOG"
# 保持进程（不阻塞）
tail -f /dev/null