#!/usr/bin/env bash
# 学习系统一键部署三站：GitHub Pages / Surge / Vercel
# 用法: bash ~/Desktop/xuexisystem-deploy/deploy.sh
# 前提: 能连通 github.com（GitHub 页面前需网络通畅，git 凭据已配置）
set -e
cd "$(dirname "$0")"

cp "C:/Users/cxq/Desktop/学习系统.html" ./index.html
echo "[1/4] 主文件已同步 -> index.html"

echo "[2/4] 部署 Surge ..."
SURGE_LOGIN="105968690@qq.com" SURGE_TOKEN="2bc0ac42fdaa952bbb730051791ab642" surge ./ xuexisystem.surge.sh

echo "[3/4] 部署 Vercel ..."
vercel --prod --yes

echo "[4/4] 推送 GitHub Pages ..."
git add index.html
if git diff --cached --quiet; then
  echo "  (无变更，跳过 commit)"
else
  git commit -m "update"
fi
git push origin main

echo "=== 三站部署完成 ==="
echo "GitHub:  https://r7drvkdvt2-arch.github.io/xuexisystem/"
echo "Surge:   https://xuexisystem.surge.sh/"
echo "Vercel:  https://xuexisystem.vercel.app/"
