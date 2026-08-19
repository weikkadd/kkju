#!/usr/bin/env node
const fs = require('fs');
const { spawn } = require('child_process');

// 启动 start.sh（它会用 $PORT 跑 sing-box，占 10000）
spawn('bash', ['start.sh'], { stdio: 'inherit' });

// 不断重试读取 list.txt，拿到就打印
let printed = false;
function poll() {
  if (printed) return;
  try {
    const links = fs.readFileSync('.npm/list.txt', 'utf-8').trim();
    if (links) {
      console.log('\n========================================');
      console.log('        节 点 链 接');
      console.log('========================================');
      console.log(links);
      console.log('========================================\n');
      printed = true;
      return;
    }
  } catch (_) {}
  setTimeout(poll, 3000);
}
setTimeout(poll, 10000);
