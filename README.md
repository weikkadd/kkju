# kkju - Node 节点一键部署

Render / Railway / 任意 Node.js 环境部署 sing-box 节点（含哪吒监控，无定时重启）

## 部署

- 启动命令: `node index.js`
- 构建指令: 留空
- 语言: Node.js

## 环境变量

| 变量 | 说明 |
|---|---|
| `UUID` | 节点 UUID（每台机器唯一） |
| `REALITY_PORT` | VLESS Reality 端口（Render 上建议填 `10000` = $PORT） |
| `HY2_PORT` | Hysteria2 端口 |
| `TUIC_PORT` | TUIC 端口 |
| `NEZHA_SERVER` | 哪吒面板 `ip:port` |
| `NEZHA_KEY` | 哪吒密钥 |
