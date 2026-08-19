#!/bin/bash
set -e

# ================== 端口设置 ==================
# Render/Railway 等平台注入 $PORT (默认 10000) → Reality 默认监听它(唯一对外端口)
# 其它协议可选, 填了才部署
export DEFAULT_PORT="${PORT:-10000}"
export TUIC_PORT=${TUIC_PORT:-""}
export HY2_PORT=${HY2_PORT:-""}
export REALITY_PORT=${REALITY_PORT:-"$DEFAULT_PORT"}
export SOCKS_PORT=${SOCKS_PORT:-""} # 🐾 SOCKS5 端口 (可选, 留空禁用)

# ================== 强制切换到脚本所在目录 ==================
cd "$(dirname "$0")"

# ================== 环境变量 & 绝对路径 ==================
export FILE_PATH="${PWD}/.npm"
export DATA_PATH="${PWD}/singbox_data"
mkdir -p "$FILE_PATH" "$DATA_PATH"

# ================== UUID 固定保存（核心逻辑）==================
UUID_FILE="${FILE_PATH}/uuid.txt"
if [ -f "$UUID_FILE" ]; then
  UUID=$(cat "$UUID_FILE")
  echo -e "\e[1;33m[UUID] 复用固定 UUID: $UUID\e[0m"
else
  UUID=$(cat /proc/sys/kernel/random/uuid)
  echo "$UUID" > "$UUID_FILE"
  chmod 600 "$UUID_FILE"
  echo -e "\e[1;32m[UUID] 首次生成并永久保存: $UUID\e[0m"
fi

# ================== 创建目录 ==================
[ ! -d "${FILE_PATH}" ] && mkdir -p "${FILE_PATH}"

# ================== 架构检测 & 下载 sing-box ==================
ARCH=$(uname -m)
BASE_URL=""
if [[ "$ARCH" == "arm"* ]] || [[ "$ARCH" == "aarch64" ]]; then
  BASE_URL="https://arm64.ssss.nyc.mn"
elif [[ "$ARCH" == "amd64"* ]] || [[ "$ARCH" == "x86_64" ]]; then
  BASE_URL="https://amd64.ssss.nyc.mn"
elif [[ "$ARCH" == "s390x" ]]; then
  BASE_URL="https://s390x.ssss.nyc.mn"
else
  echo "不支持的架构: $ARCH"
  exit 1
fi

FILE_INFOS=("sb sing-box")
declare -A FILE_MAP

download_file() {
  local URL=$1
  local FILENAME=$2
  if command -v curl >/dev/null 2>&1; then
    curl -L -sS -o "$FILENAME" "$URL" && echo -e "\e[1;32m下载 $FILENAME (curl)\e[0m"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$FILENAME" "$URL" && echo -e "\e[1;32m下载 $FILENAME (wget)\e[0m"
  else
    echo -e "\e[1;31m未找到 curl 或 wget\e[0m"
    exit 1
  fi
}

for entry in "${FILE_INFOS[@]}"; do
  URL=$(echo "$entry" | cut -d ' ' -f1)
  NAME=$(echo "$entry" | cut -d ' ' -f2)
  NEW_NAME="${FILE_PATH}/$(head /dev/urandom | tr -dc a-z0-9 | head -c6)"
  download_file "${BASE_URL}/${URL}" "$NEW_NAME"
  chmod +x "$NEW_NAME"
  FILE_MAP[$NAME]="$NEW_NAME"
done

# ================== 固定 Reality 密钥 ==================
KEY_FILE="${FILE_PATH}/key.txt"
if [ -f "$KEY_FILE" ]; then
  echo -e "\e[1;33m[密钥] 检测到已有密钥，复用...\e[0m"
  private_key=$(grep "PrivateKey:" "$KEY_FILE" | awk '{print $2}')
  public_key=$(grep "PublicKey:" "$KEY_FILE" | awk '{print $2}')
else
  echo -e "\e[1;33m[密钥] 首次生成 Reality 密钥对...\e[0m"
  output=$("${FILE_MAP[sing-box]}" generate reality-keypair)
  echo "$output" > "$KEY_FILE"
  private_key=$(echo "$output" | awk '/PrivateKey:/ {print $2}')
  public_key=$(echo "$output" | awk '/PublicKey:/ {print $2}')
  chmod 600 "$KEY_FILE"
  echo -e "\e[1;32m[密钥] 密钥已保存，重启后保持不变\e[0m"
fi

# ================== 生成证书（自签或固定）==================
if ! command -v openssl >/dev/null 2>&1; then
  cat > "${FILE_PATH}/private.key" <<'EOF'
-----BEGIN EC PARAMETERS-----
BgqghkjOPQQBw==
-----END EC PARAMETERS-----
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIM4792SEtPqIt1ywqTd/0bYidBqpYV/+siNnfBYsdUYsAoGCCqGSM49
AwEHoUQDQgAE1kHafPj07rJG+HboH2ekAI4r+e6TL38GWASAnngZreoQDF16ARa
/TsyLyFoPkhTxSbehH/OBEjHtSZGaDhMqQ==
-----END EC PRIVATE KEY-----
EOF
  cat > "${FILE_PATH}/cert.pem" <<'EOF'
-----BEGIN CERTIFICATE-----
MIIBejCCASGgAwIBAgIUFWeQL3556PNJLp/veCFxGNj9crkwCgYIKoZIzj0EAwIw
EzERMA8GA1UEAwwIYmluZy5jb20wHhcNMjUwMTAxMDEwMTAwWhcNMzUwMTAxMDEw
MTAwWjATMREwDwYDVQQDDAhiaW5nLmNvbTBNBgqgGzM9AgEGCCqGSM49AwEHA0IA
BNZB2nz49O6yRvh26B9npACOK/nuky9/BlgEgDZ54Ga3qEAxdeWv07Mi8h
d5IR8Um3oR/zQRIx7UmRmg4TKmjUzBRMB0GA1UdDgQWBQTV1cFID7UISE7PLTBR
BfGbgrkMNzAfBgNVHSMEGDAWgBTV1cFID7UISE7PLTBRBfGbgrkMNzAPBgNVHRMB
Af8EBTADAQH/MAoGCCqGSM49BAMCA0cAMEQCIARDAJvg0vd/ytrQVvEcSm6XTlB+
eQ6OFb9LbLYL9Zi+AiffoMbi4y/0YUQlTtz7as9S8/lciBF5VCUoVIKS+vX2g==
-----END CERTIFICATE-----
EOF
else
  openssl ecparam -genkey -name prime256v1 -out "${FILE_PATH}/private.key" 2>/dev/null
  openssl req -new -x509 -days 3650 -key "${FILE_PATH}/private.key" -out "${FILE_PATH}/cert.pem" -subj "/CN=bing.com" 2>/dev/null
fi
chmod 600 "${FILE_PATH}/private.key"

# ================== 生成 config.json ==================
cat > "${FILE_PATH}/config.json" <<EOF
{
  "log": { "disabled": true },
  "inbounds": [$( \
    [ "$SOCKS_PORT" != "" ] && [ "$SOCKS_PORT" != "0" ] && echo "{
      \"type\": \"socks\",
      \"listen\": \"::\",
      \"listen_port\": $SOCKS_PORT,
      \"users\": [{\"username\": \"$UUID\", \"password\": \"admin\"}]
    },"; \
    [ "$TUIC_PORT" != "" ] && [ "$TUIC_PORT" != "0" ] && echo "{
      \"type\": \"tuic\",
      \"listen\": \"::\",
      \"listen_port\": $TUIC_PORT,
      \"users\": [{\"uuid\": \"$UUID\", \"password\": \"admin\"}],
      \"congestion_control\": \"bbr\",
      \"tls\": {\"enabled\": true, \"alpn\": [\"h3\"], \"certificate_path\": \"${FILE_PATH}/cert.pem\", \"key_path\": \"${FILE_PATH}/private.key\"}
    },"; \
    [ "$HY2_PORT" != "" ] && [ "$HY2_PORT" != "0" ] && echo "{
      \"type\": \"hysteria2\",
      \"listen\": \"::\",
      \"listen_port\": $HY2_PORT,
      \"users\": [{\"password\": \"$UUID\"}],
      \"masquerade\": \"https://bing.com\",
      \"tls\": {\"enabled\": true, \"alpn\": [\"h3\"], \"certificate_path\": \"${FILE_PATH}/cert.pem\", \"key_path\": \"${FILE_PATH}/private.key\"}
    },"; \
    [ "$REALITY_PORT" != "" ] && [ "$REALITY_PORT" != "0" ] && echo "{
      \"type\": \"vless\",
      \"listen\": \"::\",
      \"listen_port\": $REALITY_PORT,
      \"users\": [{\"uuid\": \"$UUID\", \"flow\": \"xtls-rprx-vision\"}],
      \"tls\": {
        \"enabled\": true,
        \"server_name\": \"www.nazhumi.com\",
        \"reality\": {
          \"enabled\": true,
          \"handshake\": {\"server\": \"www.nazhumi.com\", \"server_port\": 443},
          \"private_key\": \"$private_key\",
          \"short_id\": [\"\"]
        }
      }
    }"; \
  )],
  "outbounds": [{"type": "direct"}]
}
EOF

# ================== 启动 sing-box ==================
"${FILE_MAP[sing-box]}" run -c "${FILE_PATH}/config.json" &
SINGBOX_PID=$!
echo "[SING-BOX] 启动完成 PID=$SINGBOX_PID"

# ================== 获取 IP & ISP ==================
IP=$(curl -s --max-time 2 ipv4.ip.sb || curl -s --max-time 1 api.ipify.org || echo "IP_ERROR")
ISP=$(curl -s --max-time 2 https://speed.cloudflare.com/meta | awk -F'"' '{print $26"-"$18}' || echo "0.0")

# ================== 生成订阅 ==================
> "${FILE_PATH}/list.txt"
[ "$SOCKS_PORT" != "" ] && [ "$SOCKS_PORT" != "0" ] && echo "socks5://${UUID}:admin@${IP}:${SOCKS_PORT}#SOCKS5-${ISP}" >> "${FILE_PATH}/list.txt"
[ "$TUIC_PORT" != "" ] && [ "$TUIC_PORT" != "0" ] && echo "tuic://${UUID}:admin@${IP}:${TUIC_PORT}?sni=www.bing.com&alpn=h3&congestion_control=bbr&allowInsecure=1#TUIC-${ISP}" >> "${FILE_PATH}/list.txt"
[ "$HY2_PORT" != "" ] && [ "$HY2_PORT" != "0" ] && echo "hysteria2://${UUID}@${IP}:${HY2_PORT}/?sni=www.bing.com&insecure=1#Hysteria2-${ISP}" >> "${FILE_PATH}/list.txt"
[ "$REALITY_PORT" != "" ] && [ "$REALITY_PORT" != "0" ] && echo "vless://${UUID}@${IP}:${REALITY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.nazhumi.com&fp=firefox&pbk=${public_key}&type=tcp#Reality-${ISP}" >> "${FILE_PATH}/list.txt"

# base64 编码 (兼容 GNU base64 / openssl / busybox)
if command -v base64 >/dev/null 2>&1; then
  base64 "${FILE_PATH}/list.txt" | tr -d '\n' > "${FILE_PATH}/sub.txt"
elif command -v openssl >/dev/null 2>&1; then
  openssl base64 -in "${FILE_PATH}/list.txt" -A > "${FILE_PATH}/sub.txt" 2>/dev/null || openssl enc -base64 -A -in "${FILE_PATH}/list.txt" > "${FILE_PATH}/sub.txt"
else
  cp "${FILE_PATH}/list.txt" "${FILE_PATH}/sub.txt"
  echo "[警告] 未找到 base64/openssl, sub.txt 为明文(大部分客户端仍可识别)"
fi
cat "${FILE_PATH}/list.txt"
echo -e "\n\e[1;32m${FILE_PATH}/sub.txt 已保存\e[0m"

# ================== 哪吒监控 agent（直连面板） ==================
set +e   # 哪吒段独立容错
NZ_DIR="${FILE_PATH}/nezha"
mkdir -p "$NZ_DIR"
NZ_BIN="${NZ_DIR}/nezha-agent"

NZ_ASSET=""
case "$ARCH" in
  aarch64|arm64) NZ_ASSET="nezha-agent_linux_arm64.zip" ;;
  amd64|x86_64)  NZ_ASSET="nezha-agent_linux_amd64.zip" ;;
  *) echo "[哪吒] 不支持的架构 $ARCH，跳过 agent" ;;
esac

if [ -n "$NZ_ASSET" ] && [ ! -x "$NZ_BIN" ]; then
  download_file "https://github.com/nezhahq/agent/releases/download/v1.15.0/${NZ_ASSET}" "${NZ_DIR}/agent.zip" || true
  if [ -f "${NZ_DIR}/agent.zip" ]; then
    ( cd "$NZ_DIR" && { unzip -o agent.zip >/dev/null 2>&1 || busybox unzip -o agent.zip >/dev/null 2>&1 || python3 -c "import zipfile;zipfile.ZipFile('agent.zip').extractall()"; } ) || true
    chmod +x "$NZ_BIN" 2>/dev/null || true
    rm -f "${NZ_DIR}/agent.zip"
  fi
fi

if [ -x "$NZ_BIN" ]; then
  NZ_UUID_FILE="${FILE_PATH}/nz_uuid.txt"
  [ -f "$NZ_UUID_FILE" ] && NZ_UUID=$(cat "$NZ_UUID_FILE") || { NZ_UUID=$(cat /proc/sys/kernel/random/uuid); echo "$NZ_UUID" > "$NZ_UUID_FILE"; }

  cat > "${NZ_DIR}/config.yml" <<EOF
debug: true
tls: false
disable_auto_update: true
disable_force_update: true
client_secret: JeWdlQ8SPwqZaZghw0CQu9qCuPaC2S89
server: 35.212.223.198:443
uuid: $NZ_UUID
EOF

  "${NZ_BIN}" -c "${NZ_DIR}/config.yml" >"${NZ_DIR}/agent.log" 2>&1 &
  echo "[哪吒 agent] 启动 PID=$!，日志 ${NZ_DIR}/agent.log（45秒内无内容属正常）"
else
  echo "[哪吒] 警告: nezha-agent 不存在/不可执行，跳过。排查："
  echo "       1) 鸡能否访问 github (curl -I https://github.com/nezhahq/agent)"
  echo "       2) 有没有 unzip/python3 能解压"
  echo "       3) ${NZ_DIR} 目录内容"
fi
set -e

# ================== 保持前台运行 ==================
echo "[start.sh] 所有服务已启动，保持前台（无定时重启）..."
tail -f /dev/null