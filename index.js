#!/usr/bin/env node
const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const PORT = process.env.PORT || 10000;
const SUB_PATH = process.env.SUB_PATH || '/';

// 在后台启动 start.sh
spawn('bash', ['start.sh'], { stdio: 'inherit', detached: true });

// HTTP 服务 —— 直接显示节点链接
http.createServer((req, res) => {
  const html = [];
  html.push('<html><body style="font-family:monospace;padding:20px">');
  html.push('<h2>kkju Node</h2><hr>');

  // list.txt (明文节点)
  try {
    const list = fs.readFileSync('.npm/list.txt', 'utf-8').trim();
    html.push('<h3>节点链接 (list.txt)</h3><pre>');
    html.push(escHtml(list));
    html.push('</pre>');
  } catch (_) {
    html.push('<p>等待节点生成中… (大约 15 秒)</p>');
  }

  // sub.txt (base64 订阅)
  try {
    const sub = fs.readFileSync('.npm/sub.txt', 'utf-8').trim();
    html.push('<h3>base64 节点链接 (sub.txt)</h3><pre>');
    html.push(escHtml(sub));
    html.push('</pre>');
  } catch (_) {}

  html.push('<hr><small>kkju · kju.onrender.com</small>');
  res.writeHead(200, { 'Content-Type': 'text/html; chars=utf-8' });
  res.end(html.join(''));
}).listen(PORT, '0.0.0.0', () => {
  console.log('[server] 监听: 0.0.0.0:' + PORT);
});

function escHtml(s) {
  return s.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;');
}
