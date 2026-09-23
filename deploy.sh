#!/usr/bin/env bash
# 学习系统一键部署三站：GitHub Pages / Surge / Vercel
# 用法: bash ~/Desktop/xuexisystem-deploy/deploy.sh
#
# ── 2026-09-23 重构说明（根因修复）──────────────────────────────
# 旧版用 `set -e` 全局中止，且顺序是 Surge → Vercel → GitHub。
# 后果：Vercel 未登录时脚本在第 3 步退出，**GitHub 推送整段被跳过** ——
#       这就是线上 GitHub Pages 整整 2 周没更新的原因（8,141,867 B 停在 09-08）。
# 现在：① 去掉 set -e，每站独立 try；② GitHub 放最前；
#       ③ 用 local-secrets.ps1 里的 PAT 认证，不依赖本机凭据缓存；
#       ④ 末尾汇总成功/失败，任一失败以非 0 退出（便于上层感知）。
# ────────────────────────────────────────────────────────────

cd "$(dirname "$0")" || exit 1

MAIN="C:/Users/Administrator/Desktop/学习系统.html"
GH_SLUG="r7drvkdvt2-arch/xuexisystem"
GH_PAGES="https://r7drvkdvt2-arch.github.io/xuexisystem/"
SURGE_DOMAIN="xuexisystem.surge.sh"
VERCEL_DOMAIN="xuexisystem.vercel.app"

OK=()
FAIL=()

mask() { sed -E 's/(ghp_|gho_|ghu_|ghs_|ghr_)[A-Za-z0-9]+/\1***/g'; }

# ── 0. 同步主文件 ────────────────────────────────────────────
cp "$MAIN" ./index.html || { echo "!! 主文件同步失败，终止"; exit 1; }
echo "[0/3] 主文件已同步 -> index.html ($(wc -c < ./index.html) B)"

# ── 1. GitHub Pages（放最前，避免被其他站失败连带跳过）────────
echo "[1/3] 推送 GitHub Pages ..."
GH_TOK=$(grep -oP '(?<=\$ghTok = ")[^"]+' local-secrets.ps1 2>/dev/null)
if [ -n "$GH_TOK" ]; then
  GH_URL="https://${GH_TOK}@github.com/${GH_SLUG}.git"
else
  GH_URL="https://github.com/${GH_SLUG}.git"   # 退化为依赖本机凭据缓存
  echo "  (未读到 PAT，退化为本机凭据缓存)"
fi
git add index.html
if git diff --cached --quiet; then
  echo "  (index.html 无变更)"
else
  git commit -m "update $(date +%Y%m%d-%H%M%S)" >/dev/null
fi
out=$(git push "$GH_URL" HEAD:main 2>&1); rc=$?
echo "$out" | mask
if [ $rc -eq 0 ]; then OK+=("GitHub  $GH_PAGES"); else FAIL+=("GitHub  $GH_PAGES"); fi

# ── 2. Surge ────────────────────────────────────────────────
echo "[2/3] 部署 Surge ..."
SURGE_LOGIN="${SURGE_LOGIN:-105968690@qq.com}" \
SURGE_TOKEN="${SURGE_TOKEN:-2bc0ac42fdaa952bbb730051791ab642}" \
  surge ./ "$SURGE_DOMAIN" 2>&1 | tail -6
if [ "${PIPESTATUS[0]}" -eq 0 ]; then
  OK+=("Surge   https://$SURGE_DOMAIN/")
else
  FAIL+=("Surge   https://$SURGE_DOMAIN/")
fi

# ── 3. Vercel ───────────────────────────────────────────────
echo "[3/3] 部署 Vercel ..."
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
