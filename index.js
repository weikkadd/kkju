#!/usr/bin/env node
const { spawn } = require('child_process');
const fs = require('fs');

// start.sh 在后台运行 （sing-box 独占 $PORT=10000）
spawn('bash', ['start.sh'], { stdio: 'inherit' });

// 轮询 list.txt 并在控制台打印（Render 日志将捕获）
let printed = false;
setInterval(() => {
  if (printed) return;
  try {
    const d = fs.readFileSync('.npm/list.txt', 'utf-8').trim();
    if (d) {
      console.log('\n============================');
      console.log('🎯 节点链接（复制到节点客户端）');
      console.log('============================');
      console.log(d);
      console.log('============================\n');
      printed = true;
    }
  } catch(e) {}
}, 3000);

// 保持进程存活
process.stdin.resume();
