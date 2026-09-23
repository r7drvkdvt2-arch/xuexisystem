#!/usr/bin/env bash
# 学习系统一键部署三站：GitHub Pages / Surge / Vercel
# 用法: bash ~/Desktop/xuexisystem-deploy/deploy.sh
#
# ── 2026-09-23 重构说明（两轮）──────────────────────────────────
# 【第一轮·根因修复】旧版用 `set -e` 全局中止且顺序为 Surge → Vercel → GitHub，
#   Vercel 未登录时脚本在第 3 步退出 ⇒ GitHub 推送整段被跳过 ⇒ 线上 Pages 落后 2 周。
#   现在：去掉 set -e、GitHub 放最前、PAT 认证、每站独立 try、末尾汇总。
#
# 【第二轮·网页版】单文件版 29.7 MB（其中 15.7 MB 是 base64 内嵌字体）在本网络下
#   **传不完**：浏览器只拿到约 1 MB 就断流 ⇒ 白屏（实测 `switchMode` 不存在、bodyText 空）。
#   改为部署「网页版」：字体拆成 fonts/*.woff2 独立文件、按档按需下载。
#   首屏 gzip 16.4 MB → **5.0 MB**。构建脚本：dsh/web_fonts_20260923/build_web.py
#   ⚠️ 本地单文件版（Desktop\学习系统.html）保持不变，仍含全部内嵌字体。
# ────────────────────────────────────────────────────────────

cd "$(dirname "$0")" || exit 1

MAIN="C:/Users/Administrator/Desktop/学习系统.html"
BUILD="C:/Users/Administrator/Desktop/dsh/web_fonts_20260923"
PY="C:/Users/Administrator/.workbuddy-ai/binaries/python/versions/3.13.12/python.exe"
GH_SLUG="r7drvkdvt2-arch/xuexisystem"
GH_PAGES="https://r7drvkdvt2-arch.github.io/xuexisystem/"
SURGE_DOMAIN="xuexisystem.surge.sh"
VERCEL_DOMAIN="xuexisystem.vercel.app"

OK=()
FAIL=()
mask() { sed -E 's/(ghp_|gho_|ghu_|ghs_|ghr_)[A-Za-z0-9]+/\1***/g'; }

# ── 0. 构建网页版（字体外置）──────────────────────────────────
echo "[0/4] 构建网页版（字体外置）..."
if ! "$PY" "$BUILD/build_web.py"; then
  echo "!! 构建失败，终止（盘上未改动）"; exit 1
fi
cp "$BUILD/web/index.html" ./index.html || { echo "!! index.html 同步失败"; exit 1; }
rm -rf ./fonts && cp -r "$BUILD/web/fonts" ./fonts || { echo "!! fonts 同步失败"; exit 1; }
echo "      index.html = $(wc -c < ./index.html) B ; fonts = $(ls ./fonts | wc -l) 个"

# ── 1. GitHub Pages（放最前，避免被其他站失败连带跳过）────────
echo "[1/4] 推送 GitHub Pages ..."
GH_TOK=$(grep -oP '(?<=\$ghTok = ")[^"]+' "$HOME/.xuexisystem-secrets.ps1" 2>/dev/null)
# ★ 凭据已移出部署目录（2026-09-23 泄露事故后）：Surge 整目录上传，.gitignore 挡不住。
#   若 ~/.xuexisystem-secrets.ps1 不存在，才回退读旧位置（同目录）——但旧位置会随 Surge 公开。
if [ -z "$GH_TOK" ]; then
  GH_TOK=$(grep -oP '(?<=\$ghTok = ")[^"]+' ./local-secrets.ps1 2>/dev/null)
  [ -n "$GH_TOK" ] && echo "  ⚠️ 正在使用部署目录内的 local-secrets.ps1 —— 该文件会被 Surge 公开！请尽快移到 ~/.xuexisystem-secrets.ps1"
fi
if [ -n "$GH_TOK" ]; then
  GH_URL="https://${GH_TOK}@github.com/${GH_SLUG}.git"
else
  GH_URL="https://github.com/${GH_SLUG}.git"; echo "  (未读到 PAT，退化为本机凭据缓存)"
fi
git add index.html fonts
if git diff --cached --quiet; then
  echo "  (无变更)"
else
  git commit -m "update $(date +%Y%m%d-%H%M%S)" >/dev/null
fi
rc=1
for i in 1 2 3; do
  out=$(git push "$GH_URL" HEAD:main 2>&1); rc=$?
  echo "$out" | mask | sed 's/^/  /'
  [ $rc -eq 0 ] && break
  echo "  (第 $i 次失败，重试…)"      # 代理偶发 502，必须重试
  sleep 6
done
if [ $rc -eq 0 ]; then OK+=("GitHub  $GH_PAGES"); else FAIL+=("GitHub  $GH_PAGES"); fi

# ── 2. Surge ────────────────────────────────────────────────
echo "[2/4] 部署 Surge ..."
SURGE_LOGIN="${SURGE_LOGIN:-105968690@qq.com}" \
SURGE_TOKEN="${SURGE_TOKEN:-2bc0ac42fdaa952bbb730051791ab642}" \
  surge ./ "$SURGE_DOMAIN" 2>&1 | tail -6
if [ "${PIPESTATUS[0]}" -eq 0 ]; then OK+=("Surge   https://$SURGE_DOMAIN/"); else FAIL+=("Surge   https://$SURGE_DOMAIN/"); fi

# ── 3. Vercel ───────────────────────────────────────────────
echo "[3/4] 部署 Vercel ..."
if ! vercel whoami >/dev/null 2>&1; then
  echo "  !! Vercel 未登录，跳过。先执行： vercel login"
  FAIL+=("Vercel  未登录，需先 vercel login")
else
  out=$(vercel --prod --yes 2>&1); rc=$?
  echo "$out" | tail -8
  if [ $rc -eq 0 ]; then OK+=("Vercel  https://$VERCEL_DOMAIN/"); else FAIL+=("Vercel  https://$VERCEL_DOMAIN/"); fi
fi

# ── 汇总 ────────────────────────────────────────────────────
echo
echo "================ 部署汇总 ================"
for x in "${OK[@]}";   do echo "  ✔ $x"; done
for x in "${FAIL[@]}"; do echo "  ✘ $x"; done
echo "========================================="
[ ${#FAIL[@]} -eq 0 ] || exit 2
