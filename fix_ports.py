import io

with io.open('start.sh', 'r', encoding='utf-8') as f:
    content = f.read()

old = '''# ================== 端口设置 ==================
export TUIC_PORT=${TUIC_PORT:-"28086"}
export HY2_PORT=${HY2_PORT:-"20032"}
export REALITY_PORT=${REALITY_PORT:-"28086"}
export SOCKS_PORT=${SOCKS_PORT:-""} # 🐾 SOCKS5 端口 (可选, 留空禁用)'''

new = '''# ================== 端口设置 ==================
# Render/Railway 等平台注入 $PORT(默认 10000) → Reality 默认监听它(唯一对外端口)
# 其它协议可选, 填了才部署
export DEFAULT_PORT="${PORT:-10000}"
export TUIC_PORT=${TUIC_PORT:-""}
export HY2_PORT=${HY2_PORT:-""}
export REALITY_PORT=${REALITY_PORT:-"$DEFAULT_PORT"}
export SOCKS_PORT=${SOCKS_PORT:-""} # 🐾 SOCKS5 端口 (可选, 留空禁用)'''

assert old in content, "old block not found"
content = content.replace(old, new, 1)

with io.open('start.sh', 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)

print("OK")
