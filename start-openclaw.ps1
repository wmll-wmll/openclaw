param(
  [string]$EnvFile = "e:\GitHub\.env",
  [string]$ProjectDir = "e:\GitHub\openclaw",
  [int]$Port = 18789,
  [string]$Bind = "lan"
)
function Import-DotEnv($path) {
  if (Test-Path $path) {
    Get-Content -Path $path | ForEach-Object {
      $line = $_.Trim()
      if ($line -and -not $line.StartsWith("#")) {
        $kv = $line.Split("=", 2)
        if ($kv.Length -eq 2) {
          [System.Environment]::SetEnvironmentVariable($kv[0], $kv[1], "Process")
        }
      }
    }
  }
}
Write-Host "加载环境变量: $EnvFile"
Import-DotEnv -path $EnvFile
Set-Location $ProjectDir
Write-Host "启用 Corepack 并激活 pnpm"
corepack enable | Out-Null
corepack prepare pnpm@latest --activate | Out-Null
Write-Host "安装依赖"
if (-not (Test-Path "$ProjectDir\node_modules")) {
  $env:OPENCLAW_PREFER_PNPM = "1"
  pnpm install --frozen-lockfile
}
Write-Host "构建项目"
pnpm build
Write-Host "构建 UI"
$env:OPENCLAW_PREFER_PNPM = "1"
pnpm ui:build
Write-Host "启动网关: 绑定=$Bind 端口=$Port"
$argsList = @("openclaw.mjs", "gateway", "--bind", $Bind, "--port", "$Port", "--allow-unconfigured")
$proc = Start-Process -FilePath "node" -ArgumentList $argsList -WorkingDirectory $ProjectDir -PassThru
Start-Sleep -Seconds 3
try {
  $health = Invoke-RestMethod -Method GET -Uri "http://127.0.0.1:$Port/healthz" -TimeoutSec 5
  Write-Host "健康检查通过" -ForegroundColor Green
} catch {
  Write-Host "健康检查失败: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host "进程ID: $($proc.Id)"
