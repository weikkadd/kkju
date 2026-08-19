#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

// 在后台启动 start.sh（不阻塞）
spawn('bash', ['start.sh'], { stdio: 'inherit', detached: false });

// 等几秒后轮询 list.txt，打印节点链接
function pollLinks(attempts) {
  const files = ['.npm/list.txt', '.npm/sub.txt'];
  let found = false;
  for (const f of files) {
    try {
      const content = fs.readFileSync(f, 'utf-8').trim();
      if (content) {
        if (!found) process.stdout.write('\n');
        console.log('=== ' + path.basename(f) + ' ===');
        console.log(content);
        found = true;
      }
    } catch (_) {}
  }
  if (found) return;
  if (attempts <= 0) {
    console.log('[info] 链接生成超时，手动查看: cat .npm/list.txt');
    return;
  }
  setTimeout(() => pollLinks(attempts - 1), 3000);
}

setTimeout(() => pollLinks(30), 8000);
