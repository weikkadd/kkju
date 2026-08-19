#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
require('child_process').execSync('bash start.sh', { stdio: 'inherit' });
// 启动完成后打印节点链接到日志（等 sing-box 和链接生成就绪）
setTimeout(() => {
  const files = ['.npm/list.txt', '.npm/sub.txt'];
  for (const f of files) {
    try {
      const content = fs.readFileSync(f, 'utf-8').trim();
      if (content) {
        console.log('\n=== ' + path.basename(f) + ' ===');
        console.log(content);
      }
    } catch (_) {}
  }
}, 5000);
