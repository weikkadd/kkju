#!/usr/bin/env node
const fs = require('fs');
const { spawn } = require('child_process');

// 后台启动 start.sh（sing-box 占 10000）
spawn('bash', ['start.sh'], { stdio: 'inherit' });

// 不停地轮询 list.txt，有内容就打印到日志
let printed = false;
setInterval(() => {
  if (printed) return;
  try {
    const list = fs.readFileSync('.npm/list.txt', 'utf-8').trim();
    if (list) {
      console.log('\n========================================');
      console.log('  ✅ 节点链接（复制到 v2rayN Ctrl+V）');
      console.log('========================================');
      console.log(list);
      console.log('========================================\n');
      printed = true;
    }
  } catch(_) {}
}, 4000);
