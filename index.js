#!/usr/bin/env node
const http = require('http');
const fs = require('fs');
const { execSync } = require('child_process');
const PORT = process.env.PORT || 10000;

// 先执行 start.sh（nohup 方式后台启动 sing-box 后立即退出）
try {
  execSync('bash start.sh', { stdio: 'inherit', timeout: 120000 });
} catch(e) {
  // start.sh 正常退出（没有 tail -f 阻塞）
}

// 现在可以安全启动 HTTP 服务在 PORT 上（10000）
http.createServer((req, res) => {
  try {
    const list = fs.readFileSync('.npm/list.txt', 'utf8').trim();
    if (list) {
      res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end(list);
    } else {
      res.writeHead(503);
      res.end('节点链接文件为空');
    }
  } catch(e) {
    res.writeHead(503);
    res.end('节点待生成…');
  }
}).listen(PORT, () => {
  console.log('[server] HTTP on :' + PORT);
});
