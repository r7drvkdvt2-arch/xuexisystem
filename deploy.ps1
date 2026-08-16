# 学习系统一键部署三站(Windows PowerShell 版,免 bash/免 PATH 配置)
# 用法: pwsh C:\Users\Administrator\Desktop\xuexisystem-deploy\deploy.ps1
# 凭据存于同目录 local-secrets.ps1(不入库)。无任何交互。
# 推送一律最新版, GitHub 强制覆盖(用户已认可)。
$ErrorActionPreference = 'Continue'

$main = "C:\Users\Administrator\Desktop\学习系统.html"
$dir  = "C:\Users\Administrator\Desktop\xuexisystem-deploy"
$surge  = "C:\Users\Administrator\npm-global\surge.cmd"
$vercel = "C:\Users\Administrator\npm-global\vercel.cmd"

# 读本地私密凭据(不入库)
$sec = Join-Path $dir "local-secrets.ps1"
if (Test-Path $sec) { . $sec } else { Write-Host "[FAIL] 缺少 local-secrets.ps1(凭据文件)"; exit 1 }
$ghUrl = "https://$ghTok@github.com/r7drvkdvt2-arch/xuexisystem.git"

# 1/4 同步主文件
Copy-Item -LiteralPath $main -Destination "$dir\index.html" -Force
Write-Host "[1/4] 主文件已同步 -> index.html"

# 2/4 Surge(带 token 免交互)
& $surge $dir xuexisystem.surge.sh
Write-Host "[2/4] Surge 部署完成: https://xuexisystem.surge.sh/"

# 3/4 GitHub Pages(强制推最新版)
git -C $dir add -A
git -C $dir commit -m "update" 2>$null
git -C $dir push --force $ghUrl HEAD:main
Write-Host "[3/4] GitHub 推送完成: https://r7drvkdvt2-arch.github.io/xuexisystem/ (国内访问可能需代理)"

# 4/4 Vercel(已登录才部署)
if (Test-Path "$env:USERPROFILE\.vercel") {
  & $vercel --prod --yes
  Write-Host "[4/4] Vercel 部署完成: https://xuexisystem.vercel.app/"
} else {
  Write-Host "[4/4] Vercel 未登录,跳过(登录后: vercel login)"
}

Write-Host "=== 部署完成 ==="
