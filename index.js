#!/usr/bin/env node
const http = require('http');
const fs = require('fs');
const PORT = process.env.PORT || 10000;

// 后台启动 start.sh（不依赖 start.sh 成功与否）
const { spawn } = require('child_process');
spawn('bash', ['start.sh'], { stdio: 'ignore', detached: true });

// HTTP 服务：访问 /、/list、/sub 返回节点链接
http.createServer((req, res) => {
  try {
    let body = '';
    let type = 'text/plain';

    if (req.url === '/sub') {
      body = fs.readFileSync('.npm/sub.txt', 'utf-8').trim() || '等待生成...';
    } else {
      // / 或 /list 返回明文节点
      body = fs.readFileSync('.npm/list.txt', 'utf-8').trim() || '等待节点生成（约15秒）';
    }

    res.writeHead(200, { 'Content-Type': type + '; charset=utf-8' });
    res.end(body);
  } catch (e) {
    res.writeHead(503);
    res.end('节点尚未生成，请稍后刷新');
  }
}).listen(PORT, () => {
  console.log('[OK] HTTP on :' + PORT);
});
